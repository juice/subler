//
//  MP42MkvFileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import "MP42MkvImporter.h"
#import "MatroskaParser.h"
#import "MatroskaFile.h"
#import "SubUtilities.h"
#import "lang.h"
#import "MP42File.h"

#include "rational.h"
#include "avcodec.h"

u_int32_t MP4AV_Ac3GetSamplingRate(u_int8_t* pHdr);

@interface MatroskaSample : NSObject {
@public
    unsigned long long startTime;
    unsigned long long endTime;
    unsigned long long filePos;
    unsigned int frameSize;
    unsigned int frameFlags;
}
@property(readwrite) unsigned long long startTime;
@property(readwrite) unsigned long long endTime;
@property(readwrite) unsigned long long filePos;
@property(readwrite) unsigned int frameSize;
@property(readwrite) unsigned int frameFlags;

@end

@interface MatroskaTrackHelper : NSObject {
    @public
    NSMutableArray *queue;
    NSMutableArray *offsetsArray;

    NSMutableArray *samplesBuffer;
    uint64_t        current_time;
    int64_t         minDisplayOffset;
    unsigned int buffer, samplesWritten, bufferFlush;

    NSInteger fileFormat;
    SBSubSerializer *ss; 
}
@end

@implementation MatroskaTrackHelper

-(id)init
{
    if ((self = [super init]))
    {
        queue = [[NSMutableArray alloc] init];
        offsetsArray = [[NSMutableArray alloc] init];
        
        samplesBuffer = [[NSMutableArray alloc] initWithCapacity:100];
    }
    return self;
}

- (void) dealloc {
    [queue release], queue = nil;
    [offsetsArray release], offsetsArray = nil;
    [samplesBuffer release], samplesBuffer = nil;
    [ss release], ss = nil;

    [super dealloc];
}
@end

@implementation MatroskaSample
@synthesize startTime;
@synthesize endTime;
@synthesize filePos;
@synthesize frameSize;
@synthesize frameFlags;

@end

@interface MP42MkvImporter (Private)
    - (MP42Metadata*) readMatroskaMetadata;
    - (NSString*) matroskaCodecIDToHumanReadableName:(TrackInfo *)track;
    - (NSString*) matroskaTrackName:(TrackInfo *)track;
@end

@implementation MP42MkvImporter

- (id)initWithDelegate:(id)del andFile:(NSString *)fileUrl error:(NSError **)outError
{
    if ((self = [super init])) {
        delegate = del;
        file = [fileUrl retain];

        ioStream = calloc(1, sizeof(StdIoStream)); 
        matroskaFile = openMatroskaFile((char *)[file UTF8String], ioStream);

        if(!matroskaFile) {
            if (outError) {
                *outError = MP42Error(@"The movie could not be opened.", @"The file is not a matroska file.", 100);
            }

            [self release];
            return nil;
        }

        NSInteger trackCount = mkv_GetNumTracks(matroskaFile);
        tracksArray = [[NSMutableArray alloc] initWithCapacity:trackCount];

        NSInteger i;

        for (i = 0; i < trackCount; i++) {
            TrackInfo *mkvTrack = mkv_GetTrackInfo(matroskaFile, i);
            MP42Track *newTrack = nil;

            // Video
            if (mkvTrack->Type == TT_VIDEO)  {
                newTrack = [[MP42VideoTrack alloc] init];

                [(MP42VideoTrack*)newTrack setWidth:mkvTrack->AV.Video.PixelWidth];
                [(MP42VideoTrack*)newTrack setHeight:mkvTrack->AV.Video.PixelHeight];
                
                AVRational dar, invPixelSize, sar;
                dar			   = (AVRational){mkvTrack->AV.Video.DisplayWidth, mkvTrack->AV.Video.DisplayHeight};
                invPixelSize   = (AVRational){mkvTrack->AV.Video.PixelHeight, mkvTrack->AV.Video.PixelWidth};
                sar = av_mul_q(dar, invPixelSize);    
                
                av_reduce(&sar.num, &sar.den, sar.num, sar.den, fixed1);  

                [(MP42VideoTrack*)newTrack setTrackWidth:mkvTrack->AV.Video.PixelWidth * sar.num / sar.den];
                [(MP42VideoTrack*)newTrack setTrackHeight:mkvTrack->AV.Video.PixelHeight];

                [(MP42VideoTrack*)newTrack setHSpacing:sar.num];
                [(MP42VideoTrack*)newTrack setVSpacing:sar.den];
            }

            // Audio
            else if (mkvTrack->Type == TT_AUDIO) {
                newTrack = [[MP42AudioTrack alloc] init];
                [(MP42AudioTrack*)newTrack setChannels:mkvTrack->AV.Audio.Channels];
                [newTrack setAlternate_group:1];

                for (MP42Track* audioTrack in tracksArray) {
                    if ([audioTrack isMemberOfClass:[MP42AudioTrack class]])
                        [newTrack setEnabled:NO];
                }
            }

            // Text
            else if (mkvTrack->Type == TT_SUB) {
                newTrack = [[MP42SubtitleTrack alloc] init];
                [newTrack setAlternate_group:2];

                for (MP42Track* subtitleTrack in tracksArray) {
                    if ([subtitleTrack isMemberOfClass:[MP42SubtitleTrack class]])
                        [newTrack setEnabled:NO];
                }
            }

            if (newTrack) {
                newTrack.format = [self matroskaCodecIDToHumanReadableName:mkvTrack];
                newTrack.sourceFormat = [self matroskaCodecIDToHumanReadableName:mkvTrack];
                newTrack.Id = i;
                newTrack.sourcePath = file;

                if ([newTrack.format isEqualToString:@"H.264"]) {
                    uint8_t* avcCAtom = (uint8_t *)malloc(mkvTrack->CodecPrivateSize); // mkv stores h.264 avcC in CodecPrivate
                    memcpy(avcCAtom, mkvTrack->CodecPrivate, mkvTrack->CodecPrivateSize);
                    if (mkvTrack->CodecPrivateSize >= 3) {
                        [(MP42VideoTrack*)newTrack setOrigProfile:avcCAtom[1]];
                        [(MP42VideoTrack*)newTrack setNewProfile:avcCAtom[1]];
                        [(MP42VideoTrack*)newTrack setOrigLevel:avcCAtom[3]];
                        [(MP42VideoTrack*)newTrack setNewLevel:avcCAtom[3]];
                    }
                    free(avcCAtom);
                }

                double trackTimecodeScale = mkv_TruncFloat(mkvTrack->TimecodeScale);
                SegmentInfo *segInfo = mkv_GetFileInfo(matroskaFile);
                UInt64 scaledDuration = (UInt64)segInfo->Duration / 1000000 * trackTimecodeScale;

                newTrack.duration = scaledDuration;

                if (scaledDuration > fileDuration)
                    fileDuration = scaledDuration;

                if ([self matroskaTrackName:mkvTrack])
                    newTrack.name = [self matroskaTrackName:mkvTrack];
                iso639_lang_t *isoLanguage = lang_for_code2(mkvTrack->Language);
                newTrack.language = [NSString stringWithUTF8String:isoLanguage->eng_name];

                [tracksArray addObject:newTrack];
                [newTrack release];
            }
        }

        Chapter* chapters;
        unsigned count;
        mkv_GetChapters(matroskaFile, &chapters, &count);

        if (count) {
            MP42ChapterTrack *newTrack = [[MP42ChapterTrack alloc] init];
            
            SegmentInfo *segInfo = mkv_GetFileInfo(matroskaFile);
            UInt64 scaledDuration = (UInt64)segInfo->Duration / 1000000;
            [newTrack setDuration:scaledDuration];

            if (count) {
                unsigned int xi = 0;
                for (xi = 0; xi < chapters->nChildren; xi++) {
                    uint64_t timestamp = (chapters->Children[xi].Start) / 1000000;
                    if (!xi)
                        timestamp = 0;
                    if (xi && timestamp == 0)
                        continue;
                    if (chapters->Children[xi].Display && strlen(chapters->Children[xi].Display->String))
                        [newTrack addChapter:[NSString stringWithUTF8String:chapters->Children[xi].Display->String]
                                    duration:timestamp];
                    else
                        [newTrack addChapter:[NSString stringWithFormat:@"Chapter %d", xi+1]
                                    duration:timestamp];
                }
            }
            [tracksArray addObject:newTrack];
            [newTrack release];
        }

        metadata = [[self readMatroskaMetadata] retain];
    }

    return self;
}

- (MP42Metadata*) readMatroskaMetadata
{
    MP42Metadata *mkvMetadata = [[MP42Metadata alloc] init];

    SegmentInfo *segInfo = mkv_GetFileInfo(matroskaFile);
    if (segInfo->Title)
        [mkvMetadata setTag:[NSString stringWithUTF8String:segInfo->Title] forKey:@"Name"];
    
    Tag* tags;
    unsigned count;

    mkv_GetTags(matroskaFile, &tags, &count);
    if (count) {
        unsigned int xi = 0;
        for (xi = 0; xi < tags->nSimpleTags; xi++) {

            if (!strcmp(tags->SimpleTags[xi].Name, "TITLE"))
                [mkvMetadata setTag:[NSString stringWithUTF8String:tags->SimpleTags[xi].Value] forKey:@"Name"];
            
            if (!strcmp(tags->SimpleTags[xi].Name, "DATE_RELEASED"))
                [mkvMetadata setTag:[NSString stringWithUTF8String:tags->SimpleTags[xi].Value] forKey:@"Release Date"];

            if (!strcmp(tags->SimpleTags[xi].Name, "COMMENT"))
                [mkvMetadata setTag:[NSString stringWithUTF8String:tags->SimpleTags[xi].Value] forKey:@"Comments"];

            if (!strcmp(tags->SimpleTags[xi].Name, "DIRECTOR"))
                [mkvMetadata setTag:[NSString stringWithUTF8String:tags->SimpleTags[xi].Value] forKey:@"Director"];

            if (!strcmp(tags->SimpleTags[xi].Name, "COPYRIGHT"))
                [mkvMetadata setTag:[NSString stringWithUTF8String:tags->SimpleTags[xi].Value] forKey:@"Copyright"];

            if (!strcmp(tags->SimpleTags[xi].Name, "ARTIST"))
                [mkvMetadata setTag:[NSString stringWithUTF8String:tags->SimpleTags[xi].Value] forKey:@"Artist"];
        }
    }

    if ([mkvMetadata.tagsDict count])
        return [mkvMetadata autorelease];
    else {
        [mkvMetadata release];
        return nil;
    }
}

- (NSString*) matroskaCodecIDToHumanReadableName:(TrackInfo *)track
{
    if (track->CodecID) {
        if (!strcmp(track->CodecID, "V_MPEG4/ISO/AVC"))
            return @"H.264";
        else if (!strcmp(track->CodecID, "A_AAC"))
            return @"AAC";
        else if (!strcmp(track->CodecID, "A_AC3"))
            return @"AC-3";
        else if (!strcmp(track->CodecID, "V_MPEG4/ISO/SP"))
            return @"MPEG-4 Visual";
        else if (!strcmp(track->CodecID, "V_MPEG4/ISO/ASP"))
            return @"MPEG-4 Visual";
        else if (!strcmp(track->CodecID, "A_DTS"))
            return @"DTS";
        else if (!strcmp(track->CodecID, "A_VORBIS"))
            return @"Vorbis";
        else if (!strcmp(track->CodecID, "A_FLAC"))
            return @"Flac";
        else if (!strcmp(track->CodecID, "A_MPEG/L3"))
            return @"Mp3";
        else if (!strcmp(track->CodecID, "A_TRUEHD"))
            return @"True HD";
        else if (!strcmp(track->CodecID, "A_MLP"))
            return @"MLP";
        else if (!strcmp(track->CodecID, "S_TEXT/UTF8"))
            return @"Plain Text";
        else if (!strcmp(track->CodecID, "S_TEXT/ASS"))
            return @"ASS";
        else if (!strcmp(track->CodecID, "S_TEXT/SSA"))
            return @"SSA";
        else if (!strcmp(track->CodecID, "S_VOBSUB"))
            return @"VobSub";
        else
            return [NSString stringWithUTF8String:track->CodecID];
    }
    else {
        return @"Unknown";
    }
}

- (NSString*) matroskaTrackName:(TrackInfo *)track
{    
    if(track->Name && strlen(track->Name))
        return [NSString stringWithUTF8String:track->Name];
    else
        return nil;
}

- (NSUInteger)timescaleForTrack:(MP42Track *)track
{
    TrackInfo *trackInfo = mkv_GetTrackInfo(matroskaFile, [track sourceId]);
    if (trackInfo->Type == TT_VIDEO)
        return 100000;
    else if (trackInfo->Type == TT_AUDIO) {
        NSUInteger sampleRate = mkv_TruncFloat(trackInfo->AV.Audio.SamplingFreq);
        if (!strcmp(trackInfo->CodecID, "A_AC3")) {
            if (sampleRate < 24000)
                return 48000;
        }

        return mkv_TruncFloat(trackInfo->AV.Audio.SamplingFreq);
    }

    return 1000;
}

- (NSSize)sizeForTrack:(MP42Track *)track
{
      return NSMakeSize([(MP42VideoTrack*)track width], [(MP42VideoTrack*) track height]);
}

- (NSData*)magicCookieForTrack:(MP42Track *)track
{
    if (!matroskaFile)
        return nil;

    TrackInfo *trackInfo = mkv_GetTrackInfo(matroskaFile, [track sourceId]);

    if (!strcmp(trackInfo->CodecID, "A_AC3")) {
        mkv_SetTrackMask(matroskaFile, ~(1 << [track sourceId]));

        uint64_t        StartTime, EndTime, FilePos;
        uint32_t        rt, FrameSize, FrameFlags;
        uint32_t        fb = 0;
        uint8_t         *frame = NULL;

		// read first header to create track
		int firstFrame = mkv_ReadFrame(matroskaFile, 0, &rt, &StartTime, &EndTime, &FilePos, &FrameSize, &FrameFlags);
		if (firstFrame != 0)
		{
			return nil;
		}

		if (fseeko(ioStream->fp, FilePos, SEEK_SET)) {
            fprintf(stderr,"fseeko(): %s\n", strerror(errno));
            return nil;				
        } 

        if (trackInfo->CompMethodPrivateSize != 0) {
            frame = malloc(FrameSize + trackInfo->CompMethodPrivateSize);
            memcpy(frame, trackInfo->CompMethodPrivate, trackInfo->CompMethodPrivateSize);
        }
        else
            frame = malloc(FrameSize);
        
        if (fb < FrameSize) {
            fb = FrameSize;
            frame = realloc(frame, fb);
            if (frame == NULL) {
                fprintf(stderr,"Out of memory\n");
                return nil;		
            }
        }

        size_t rd = fread(frame + trackInfo->CompMethodPrivateSize,1,FrameSize,ioStream->fp);
        if (rd != FrameSize || !frame) 
		{
            if (rd == 0)
			{
                if (feof(ioStream->fp))
                    fprintf(stderr,"Unexpected EOF while reading frame\n");
                else
                    fprintf(stderr,"Error reading frame: %s\n",strerror(errno));
            } else
                fprintf(stderr,"Short read while reading frame\n");
			return nil; // we should be able to read at least one frame
        }

		// parse AC3 header
		// collect all the necessary meta information
		// u_int32_t samplesPerSecond;
		uint32_t fscod, frmsizecod, bsid, bsmod, acmod, lfeon;
		uint32_t lfe_offset = 4;

		fscod = (*(frame+4) >> 6) & 0x3;
		frmsizecod = (*(frame+4) & 0x3f) >> 1;
		bsid =  (*(frame+5) >> 3) & 0x1f;
		bsmod = (*(frame+5) & 0xf);
		acmod = (*(frame+6) >> 5) & 0x7;
		if (acmod == 2)
			lfe_offset -= 2;
		else {
			if ((acmod & 1) && acmod != 1)
				lfe_offset -= 2;
			if (acmod & 4)
				lfe_offset -= 2;
		}
		lfeon = (*(frame+6) >> lfe_offset) & 0x1;

		// samplesPerSecond = MP4AV_Ac3GetSamplingRate(frame);

        mkv_Seek(matroskaFile, 0, 0);

        NSMutableData *ac3Info = [[NSMutableData alloc] init];
        [ac3Info appendBytes:&fscod length:sizeof(uint64_t)];
        [ac3Info appendBytes:&bsid length:sizeof(uint64_t)];
        [ac3Info appendBytes:&bsmod length:sizeof(uint64_t)];
        [ac3Info appendBytes:&acmod length:sizeof(uint64_t)];
        [ac3Info appendBytes:&lfeon length:sizeof(uint64_t)];
        [ac3Info appendBytes:&frmsizecod length:sizeof(uint64_t)];
        
        return [ac3Info autorelease];
    }
    else if (!strcmp(trackInfo->CodecID, "S_VOBSUB")) {
        char *string = (char *) trackInfo->CodecPrivate;
        char *palette = strnstr(string, "palette:", trackInfo->CodecPrivateSize);

        UInt32 colorPalette[16];

        if (palette != NULL) {
            sscanf(palette, "palette: %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx", 
                   &colorPalette[ 0], &colorPalette[ 1], &colorPalette[ 2], &colorPalette[ 3], 
                   &colorPalette[ 4], &colorPalette[ 5], &colorPalette[ 6], &colorPalette[ 7], 
                   &colorPalette[ 8], &colorPalette[ 9], &colorPalette[10], &colorPalette[11], 
                   &colorPalette[12], &colorPalette[13], &colorPalette[14], &colorPalette[15]);
        }
        return [NSData dataWithBytes:colorPalette length:sizeof(UInt32)*16];
    }

    NSData * magicCookie = [NSData dataWithBytes:trackInfo->CodecPrivate length:trackInfo->CodecPrivateSize];

    if (magicCookie)
        return magicCookie;
    else
        return nil;
}

// Methods to extract all the samples from the active tracks at the same time

- (void) fillMovieSampleBuffer: (id)sender
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    if (!matroskaFile)
        return;

    uint64_t        StartTime, EndTime, FilePos;
    uint32_t        Track, FrameSize, FrameFlags;
    uint8_t         * frame = NULL;

    MP42Track           * track = nil;
    MatroskaTrackHelper * trackHelper = nil;
    MatroskaSample      * frameSample = nil, * currentSample = nil;
    int64_t             offset, minOffset = 0, duration, next_duration;

    const unsigned int bufferSize = 20;

    /* mask other tracks because we don't need them */
    unsigned int TrackMask = ~0;

    for (MP42Track* track in activeTracks){
        TrackMask &= ~(1 << [track sourceId]);
        if (track.trackDemuxerHelper == nil) {
            trackHelper = [[MatroskaTrackHelper alloc] init];
            track.trackDemuxerHelper = trackHelper;
            [trackHelper release];
        }    
    }

    mkv_SetTrackMask(matroskaFile, TrackMask);

    while (!mkv_ReadFrame(matroskaFile, 0, &Track, &StartTime, &EndTime, &FilePos, &FrameSize, &FrameFlags) && !isCancelled) {
        while ([samplesBuffer count] >= 200) {
            usleep(200);
        }

        progress = (StartTime / fileDuration / 10000);

        for (MP42Track* fTrack in activeTracks){
            if (fTrack.sourceId == Track) {
                trackHelper = fTrack.trackDemuxerHelper;
                track = fTrack;
            }
        }

        if (trackHelper == nil) {
            NSLog(@"trackHelper is nil, aborting");
            return;
        }

        TrackInfo *trackInfo = mkv_GetTrackInfo(matroskaFile, Track);

        if (trackInfo->Type == TT_AUDIO) {
            trackHelper->samplesWritten++;

            if (fseeko(ioStream->fp, FilePos, SEEK_SET)) {
                fprintf(stderr,"fseeko(): %s\n", strerror(errno));
                break;				
            }

            if (trackInfo->CompMethodPrivateSize != 0) {
                frame = malloc(FrameSize + trackInfo->CompMethodPrivateSize);
                memcpy(frame, trackInfo->CompMethodPrivate, trackInfo->CompMethodPrivateSize);
            }
            else
                frame = malloc(FrameSize);

            if (frame == NULL) {
                fprintf(stderr,"Out of memory\n");
                break;		
            }

            size_t rd = fread(frame + trackInfo->CompMethodPrivateSize,1,FrameSize,ioStream->fp);
            if (rd != FrameSize) {
                if (rd == 0) {
                    if (feof(ioStream->fp))
                        fprintf(stderr,"Unexpected EOF while reading frame\n");
                    else
                        fprintf(stderr,"Error reading frame: %s\n",strerror(errno));
                } else
                    fprintf(stderr,"Short read while reading audio frame\n");
				
				free(frame);
				continue;
            }

            MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
            sample->sampleData = frame;
            sample->sampleSize = FrameSize + trackInfo->CompMethodPrivateSize;
            sample->sampleDuration = MP4_INVALID_DURATION;
            sample->sampleOffset = 0;
            sample->sampleTimestamp = StartTime;
            sample->sampleIsSync = YES;
            sample->sampleTrackId = track.Id;
            if(track.needConversion)
                sample->sampleSourceTrack = track;

            @synchronized(samplesBuffer) {
                [samplesBuffer addObject:sample];
                [sample release];
            }
        }

        if (trackInfo->Type == TT_SUB) {
            int vobsub = !strcmp(trackInfo->CodecID, "S_VOBSUB");
            if (!vobsub) {
                if (!trackHelper->ss)
                    trackHelper->ss = [[SBSubSerializer alloc] init];
                trackHelper->samplesWritten++;

                if (fseeko(ioStream->fp, FilePos, SEEK_SET)) {
                    fprintf(stderr,"fseeko(): %s\n", strerror(errno));
                    break;				
                }

                frame = malloc(FrameSize);
                if (frame == NULL) {
                    fprintf(stderr,"Out of memory\n");
                    break;		
                }

                size_t rd = fread(frame,1,FrameSize,ioStream->fp);
                if (rd != FrameSize) {
                    if (rd == 0) {
                        if (feof(ioStream->fp))
                            fprintf(stderr,"Unexpected EOF while reading frame\n");
                        else
                            fprintf(stderr,"Error reading frame: %s\n",strerror(errno));
                    } else
                        fprintf(stderr,"Short read while reading sub frame\n");

                    free(frame);
                    continue;
                }

                NSString *string = [[[NSString alloc] initWithBytes:frame length:FrameSize encoding:NSUTF8StringEncoding] autorelease];
                if (!strcmp(trackInfo->CodecID, "S_TEXT/ASS") || !strcmp(trackInfo->CodecID, "S_TEXT/SSA"))
                    string = StripSSALine(string);

                if ([string length]) {
                    SBSubLine *sl = [[SBSubLine alloc] initWithLine:string start:StartTime/1000000 end:EndTime/1000000];
                    [trackHelper->ss addLine:[sl autorelease]];
                }
                free(frame);
            }
            else {
                BOOL compressed = NO;
                if (trackInfo->CompEnabled)
                        compressed = YES;

                trackHelper->samplesWritten++;
                
                if (fseeko(ioStream->fp, FilePos, SEEK_SET)) {
                    fprintf(stderr,"fseeko(): %s\n", strerror(errno));
                    break;				
                }

                if (trackInfo->CompMethodPrivateSize != 0) {
                    frame = malloc(FrameSize + trackInfo->CompMethodPrivateSize);
                    memcpy(frame, trackInfo->CompMethodPrivate, trackInfo->CompMethodPrivateSize);
                }
                else
                    frame = malloc(FrameSize);

                if (frame == NULL) {
                    fprintf(stderr,"Out of memory\n");
                    break;		
                }

                size_t rd = fread(frame + trackInfo->CompMethodPrivateSize,1,FrameSize,ioStream->fp);
                if (rd != FrameSize) {
                    if (rd == 0) {
                        if (feof(ioStream->fp))
                            fprintf(stderr,"Unexpected EOF while reading frame\n");
                        else
                            fprintf(stderr,"Error reading frame: %s\n",strerror(errno));
                    } else
                        fprintf(stderr,"Short read while reading vobsub frame\n");
                    
                    free(frame);
                    continue;
                }

                if (StartTime > trackHelper->current_time) {
                    MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                    sample->sampleDuration = (StartTime - trackHelper->current_time) / 1000000;
                    sample->sampleTrackId = track.Id;
                    if(track.needConversion)
                        sample->sampleSourceTrack = track;

                    @synchronized(samplesBuffer) {
                        [samplesBuffer addObject:sample];
                        [sample release];
                    }
                }

                MP42SampleBuffer *nextSample = [[MP42SampleBuffer alloc] init];

                if (FrameSize + trackInfo->CompMethodPrivateSize && compressed) {
                    uint8_t                 *codecData = NULL;
                    unsigned int            bufferSize2 = 0;

                    codecData = av_malloc(FrameSize + trackInfo->CompMethodPrivateSize + 2);
                    bufferSize2 = FrameSize + trackInfo->CompMethodPrivateSize + 2;

                    DecompressZlib(&codecData, &bufferSize2, frame, FrameSize + trackInfo->CompMethodPrivateSize + 2);

                    codecData[0] = (bufferSize2 >> 8) & 0xff;
                    codecData[1] = bufferSize2 & 0xff;

                    nextSample->sampleData = malloc(bufferSize2);
                    memcpy(nextSample->sampleData, codecData, bufferSize2);
                    nextSample->sampleSize = bufferSize2;

                    if (codecData)
                        av_free(codecData);
                }
                else {
                    nextSample->sampleData = frame;
                    nextSample->sampleSize = FrameSize + trackInfo->CompMethodPrivateSize;
                }
                nextSample->sampleDuration = (EndTime - StartTime ) / 1000000;
                nextSample->sampleOffset = 0;
                nextSample->sampleTimestamp = StartTime;
                nextSample->sampleIsSync = YES;
                nextSample->sampleTrackId = track.Id;
                if(track.needConversion)
                    nextSample->sampleSourceTrack = track;

                @synchronized(samplesBuffer) {
                    [samplesBuffer addObject:nextSample];
                    [nextSample release];
                }

                trackHelper->current_time = EndTime;
            }
        }

        else if (trackInfo->Type == TT_VIDEO) {

            /* read frames from file */
            frameSample = [[MatroskaSample alloc] init];
            frameSample->startTime = StartTime;
            frameSample->endTime = EndTime;
            frameSample->filePos = FilePos;
            frameSample->frameSize = FrameSize;
            frameSample->frameFlags = FrameFlags;
            [trackHelper->queue addObject:frameSample];
            [frameSample release];

            if ([trackHelper->queue count] < bufferSize)
                continue;
            else {
                currentSample = [trackHelper->queue objectAtIndex:trackHelper->buffer];

                // matroska stores only the start and end time, so we need to recreate
                // the frame duration and the offset from the start time, the end time is useless
                // duration calculation
                duration = [[trackHelper->queue lastObject] startTime] - currentSample->startTime;

                for (MatroskaSample *sample in trackHelper->queue)
                    if (sample != currentSample && (sample->startTime >= currentSample->startTime))
                        if ((next_duration = (sample->startTime - currentSample->startTime)) < duration)
                            duration = next_duration;

                // offset calculation
                offset = currentSample->startTime - trackHelper->current_time;
                // save the minimum offset, used later to keep the all the offset values positive
                if (offset < minOffset)
                    minOffset = offset;

                [trackHelper->offsetsArray addObject:[NSNumber numberWithLongLong:offset]];

                trackHelper->current_time += duration;

                if (fseeko(ioStream->fp, currentSample->filePos, SEEK_SET)) {
                    fprintf(stderr,"fseeko(): %s\n", strerror(errno));
                    break;				
                } 

                if (trackInfo->CompMethodPrivateSize != 0) {
                    frame = malloc(currentSample->frameSize + trackInfo->CompMethodPrivateSize);
                    memcpy(frame, trackInfo->CompMethodPrivate, trackInfo->CompMethodPrivateSize);
                }
                else
                    frame = malloc(currentSample->frameSize);

                if (frame == NULL) {
                    fprintf(stderr,"Out of memory\n");
                    break;		
                }

                size_t rd = fread(frame + trackInfo->CompMethodPrivateSize,1,currentSample->frameSize,ioStream->fp);
                if (rd != currentSample->frameSize) {
                    if (rd == 0) {
                        if (feof(ioStream->fp))
                            fprintf(stderr,"Unexpected EOF while reading frame\n");
                        else
                            fprintf(stderr,"Error reading frame: %s\n",strerror(errno));
                    } else
                        fprintf(stderr,"Short read while reading video frame\n");
                    break;

					free(frame);
					continue;
                }

                MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                sample->sampleData = frame;
                sample->sampleSize = currentSample->frameSize + trackInfo->CompMethodPrivateSize;
                sample->sampleDuration = duration / 10000.0f;
                sample->sampleOffset = offset / 10000.0f;
                sample->sampleTimestamp = StartTime;
                sample->sampleIsSync = currentSample->frameFlags & FRAME_KF;
                sample->sampleTrackId = track.Id;

                trackHelper->samplesWritten++;

                if (sample->sampleOffset < trackHelper->minDisplayOffset)
                    trackHelper->minDisplayOffset = sample->sampleOffset;

                if (trackHelper->buffer >= bufferSize)
                    [trackHelper->queue removeObjectAtIndex:0];
                if (trackHelper->buffer < bufferSize)
                    trackHelper->buffer++;

                @synchronized(samplesBuffer) {
                    [samplesBuffer addObject:sample];
                    [sample release];
                }
            }
        }        
    }

    for (MP42Track* track in activeTracks) {
        trackHelper = track.trackDemuxerHelper;

        if (trackHelper->queue) {
            TrackInfo *trackInfo = mkv_GetTrackInfo(matroskaFile, [track sourceId]);

            while ([trackHelper->queue count]) {
                if (trackHelper->bufferFlush == 1) {
                    // add a last sample to get the duration for the last frame
                    MatroskaSample *lastSample = [trackHelper->queue lastObject];
                    for (MatroskaSample *sample in trackHelper->queue) {
                        if (sample->startTime > lastSample->startTime)
                            lastSample = sample;
                    }
                    frameSample = [[MatroskaSample alloc] init];
                    frameSample->startTime = [lastSample endTime];
                    [trackHelper->queue addObject:frameSample];
                    [frameSample release];
                }
                currentSample = [trackHelper->queue objectAtIndex:trackHelper->buffer];

                // matroska stores only the start and end time, so we need to recreate
                // the frame duration and the offset from the start time, the end time is useless
                // duration calculation
                duration = [[trackHelper->queue lastObject] startTime] - currentSample->startTime;

                for (MatroskaSample *sample in trackHelper->queue)
                    if (sample != currentSample && (sample->startTime >= currentSample->startTime))
                        if ((next_duration = (sample->startTime - currentSample->startTime)) < duration)
                            duration = next_duration;

                // offset calculation
                offset = currentSample->startTime - trackHelper->current_time;
                // save the minimum offset, used later to keep the all the offset values positive
                if (offset < minOffset)
                    minOffset = offset;

                [trackHelper->offsetsArray addObject:[NSNumber numberWithLongLong:offset]];

                trackHelper->current_time += duration;

                if (fseeko(ioStream->fp, currentSample->filePos, SEEK_SET)) {
                    fprintf(stderr,"fseeko(): %s\n", strerror(errno));
                    break;			
                }

                if (trackInfo->CompMethodPrivateSize != 0) {
                    frame = malloc(currentSample->frameSize + trackInfo->CompMethodPrivateSize);
                    memcpy(frame, trackInfo->CompMethodPrivate, trackInfo->CompMethodPrivateSize);
                }
                else
                    frame = malloc(currentSample->frameSize);

                if (frame == NULL) {
                    fprintf(stderr,"Out of memory\n");
                    break;		
                }

                size_t rd = fread(frame + trackInfo->CompMethodPrivateSize,1,currentSample->frameSize,ioStream->fp);
                if (rd != currentSample->frameSize) {
                    if (rd == 0) {
                        if (feof(ioStream->fp))
                            fprintf(stderr,"Unexpected EOF while reading frame\n");
                        else
                            fprintf(stderr,"Error reading frame: %s\n",strerror(errno));
                    } else {
                        fprintf(stderr,"Short read while reading frame\n");
                        break;
                    }
					free(frame);
					continue;
                }

                MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                sample->sampleData = frame;
                sample->sampleSize = currentSample->frameSize + trackInfo->CompMethodPrivateSize;
                sample->sampleDuration = duration / 10000.0f;
                sample->sampleOffset = offset / 10000.0f;
                sample->sampleTimestamp = StartTime;
                sample->sampleIsSync = currentSample->frameFlags & FRAME_KF;
                sample->sampleTrackId = track.Id;

                trackHelper->samplesWritten++;

                if (sample->sampleOffset < trackHelper->minDisplayOffset)
                    trackHelper->minDisplayOffset = sample->sampleOffset;

                if (trackHelper->buffer >= bufferSize)
                    [trackHelper->queue removeObjectAtIndex:0];

                @synchronized(samplesBuffer) {
                    [samplesBuffer addObject:sample];
                    [sample release];
                }

                trackHelper->bufferFlush++;
                if (trackHelper->bufferFlush >= bufferSize - 1) {
                    break;
                }
            }
        }

        if (trackHelper->ss) {
            MP42SampleBuffer *sample;
            MP4TrackId dstTrackId = track.Id;
            SBSubSerializer *ss = trackHelper->ss;

            [ss setFinished:YES];

            while (![ss isEmpty]) {
                SBSubLine *sl = [ss getSerializedPacket];

                if ([sl->line isEqualToString:@"\n"]) {
                    if (!(sample = copyEmptySubtitleSample(dstTrackId, sl->end_time - sl->begin_time))) 
                        break;

                    @synchronized(samplesBuffer) {
                        [samplesBuffer addObject:sample];
                        [sample release];
                        trackHelper->samplesWritten++;
                    }

                    continue;
                }
                if (!(sample = copySubtitleSample(dstTrackId, sl->line, sl->end_time - sl->begin_time)))
                    break;

                @synchronized(samplesBuffer) {
                    [samplesBuffer addObject:sample];
                    [sample release];
                    trackHelper->samplesWritten++;
                }
            }
        }
    }

    readerStatus = 1;
    [pool release];
}

- (MP42SampleBuffer*)copyNextSample {
    if (!matroskaFile)
        return nil;

    if (samplesBuffer == nil) {
        samplesBuffer = [[NSMutableArray alloc] initWithCapacity:200];
    }

    if (!dataReader && !readerStatus) {
        dataReader = [[NSThread alloc] initWithTarget:self selector:@selector(fillMovieSampleBuffer:) object:self];
        [dataReader setName:@"Matroska Demuxer"];
        [dataReader start];
    }

    while (![samplesBuffer count] && !readerStatus)
        usleep(2000);

    if (readerStatus)
        if ([samplesBuffer count] == 0) {
            readerStatus = 0;
            [dataReader release];
            dataReader = nil;
            return nil;
        }

    MP42SampleBuffer* sample;

    @synchronized(samplesBuffer) {
        sample = [samplesBuffer objectAtIndex:0];
        [sample retain];
        [samplesBuffer removeObjectAtIndex:0];
    }

    return sample;
}

- (void)setActiveTrack:(MP42Track *)track {
    if (!activeTracks)
        activeTracks = [[NSMutableArray alloc] init];

    [activeTracks addObject:track];
}

- (CGFloat)progress
{
    return progress;
}

- (BOOL)cleanUp:(MP4FileHandle) fileHandle
{
    for (MP42Track * track in activeTracks) {
        MatroskaTrackHelper * trackHelper = track.trackDemuxerHelper;
        MP4TrackId trackId = [track Id];

        if (trackHelper->minDisplayOffset != 0) {
            int i;
            for (i = 0; i < trackHelper->samplesWritten; i++)
            MP4SetSampleRenderingOffset(fileHandle,
                                        trackId,
                                        1 + i,
                                        MP4GetSampleRenderingOffset(fileHandle, trackId, 1+i) - trackHelper->minDisplayOffset);

            MP4Duration editDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                                   trackId,
                                                                   MP4GetTrackDuration(fileHandle, trackId),
                                                                   MP4GetTimeScale(fileHandle));
            MP4AddTrackEdit(fileHandle, trackId, MP4_INVALID_EDIT_ID, -trackHelper->minDisplayOffset,
                            editDuration, 0);
        }
    }

    return YES;
}

- (void) dealloc
{
    if (dataReader)
        [dataReader release], dataReader = nil;

    [metadata release], metadata = nil;
    [activeTracks release], activeTracks = nil;
    [tracksArray release], tracksArray = nil;
    [samplesBuffer release], samplesBuffer = nil;
	[file release], file = nil;

	/* close matroska parser */ 
	mkv_Close(matroskaFile); 

	/* close file */
    if (ioStream) {
        fclose(ioStream->fp);
        free(ioStream);
    }

    [super dealloc];
}

@end
