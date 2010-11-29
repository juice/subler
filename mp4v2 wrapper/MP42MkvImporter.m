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
        
        samplesBuffer = [NSMutableArray arrayWithCapacity:100];
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
    NSString* matroskaCodecIDToHumanReadableName(TrackInfo *track);
    NSString* getMatroskaTrackName(TrackInfo *track);
@end

@implementation MP42MkvImporter

- (id)initWithDelegate:(id)del andFile:(NSString *)fileUrl
{
    if ((self = [super init])) {
        delegate = del;
        file = [fileUrl retain];

        ioStream = calloc(1, sizeof(StdIoStream)); 
        matroskaFile = openMatroskaFile((char *)[file UTF8String], ioStream);

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
                newTrack.format = matroskaCodecIDToHumanReadableName(mkvTrack);
                newTrack.sourceFormat = matroskaCodecIDToHumanReadableName(mkvTrack);
                newTrack.Id = i;
                newTrack.sourcePath = file;
                newTrack.sourceInputType = MP42SourceTypeMatroska;
                
                if ([newTrack.format isEqualToString:@"H.264"]) {
                    uint8_t* avcCAtom = (uint8_t *)malloc(mkvTrack->CodecPrivateSize); // mkv stores h.264 avcC in CodecPrivate
                    memcpy(avcCAtom, mkvTrack->CodecPrivate, mkvTrack->CodecPrivateSize);
                    if (mkvTrack->CodecPrivateSize >= 3) {
                        [(MP42VideoTrack*)newTrack setOrigProfile:avcCAtom[1]];
                        [(MP42VideoTrack*)newTrack setNewProfile:avcCAtom[1]];
                        [(MP42VideoTrack*)newTrack setOrigLevel:avcCAtom[3]];
                        [(MP42VideoTrack*)newTrack setNewLevel:avcCAtom[3]];
                    }
                }
                    
                double trackTimecodeScale = (mkvTrack->TimecodeScale.v >> 32);
                SegmentInfo *segInfo = mkv_GetFileInfo(matroskaFile);
                UInt64 scaledDuration = (UInt64)segInfo->Duration / (UInt32)segInfo->TimecodeScale * trackTimecodeScale;

                newTrack.duration = scaledDuration;
                
                if (scaledDuration > fileDuration)
                    fileDuration = scaledDuration;

                newTrack.name = getMatroskaTrackName(mkvTrack);
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

            if (count) {
                unsigned int xi = 0;
                for (xi = 0; xi < chapters->nChildren; xi++) {
                    uint64_t timestamp = (chapters->Children[xi].Start) / 1000000;
                    if (!xi)
                        timestamp = 0;
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
    }

    return self;
}

NSString* matroskaCodecIDToHumanReadableName(TrackInfo *track)
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
        else if (!strcmp(track->CodecID, "A_DTS"))
            return @"DTS";
        else if (!strcmp(track->CodecID, "A_VORBIS"))
            return @"Vorbis";
        else if (!strcmp(track->CodecID, "A_FLAC"))
            return @"Flac";
        else if (!strcmp(track->CodecID, "A_MPEG/L3"))
            return @"Mp3";
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

NSString* getMatroskaTrackName(TrackInfo *track)
{    
    if (!track->Name) {
        if (track->Type == TT_AUDIO)
            return NSLocalizedString(@"Sound Track", @"Sound Track");
        else if (track->Type == TT_VIDEO)
            return NSLocalizedString(@"Video Track", @"Video Track");
        else if (track->Type == TT_SUB)
            return NSLocalizedString(@"Subtitle Track", @"Subtitle Track");
        else
            return NSLocalizedString(@"Unknown Track", @"Unknown Track");
    }
    else
        return [NSString stringWithUTF8String:track->Name];
}

- (NSUInteger)timescaleForTrack:(MP42Track *)track
{
    TrackInfo *trackInfo = mkv_GetTrackInfo(matroskaFile, [track sourceId]);
    if (trackInfo->Type == TT_VIDEO)
        return 90000;
    else if (trackInfo->Type == TT_AUDIO)
        return mkv_TruncFloat(trackInfo->AV.Audio.SamplingFreq);
    
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

        if (fb < FrameSize) {
            fb = FrameSize;
            frame = realloc(frame, fb);
            if (frame == NULL) {
                fprintf(stderr,"Out of memory\n");
                return nil;		
            }
        }

        size_t rd = fread(frame,1,FrameSize,ioStream->fp);
        if (rd != FrameSize) 
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
        else
            return nil;

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

    MP42Track           * track;
    MatroskaTrackHelper * trackHelper = nil;
    MatroskaSample      * frameSample = nil, * currentSample = nil;
    int64_t             offset, minOffset = 0, duration, next_duration;

    unsigned int bufferFlush = 0;
    const unsigned int bufferSize = 20;
    int success = 0;    

    /* mask other tracks because we don't need them */
    unsigned int TrackMask = ~0;

    for (MP42Track* track in activeTracks){
        TrackMask &= ~(1 << [track sourceId]);
        if (track.trackDemuxerHelper == nil) {
            track.trackDemuxerHelper = [[MatroskaTrackHelper alloc] init];
        }    
    }

    mkv_SetTrackMask(matroskaFile, TrackMask);

    while ((success = mkv_ReadFrame(matroskaFile, 0, &Track, &StartTime, &EndTime, &FilePos, &FrameSize, &FrameFlags)) >=0 /*=-1*/) {
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
                    fprintf(stderr,"Short read while reading frame\n");
            }

            MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
            sample->sampleData = frame;
            sample->sampleSize = FrameSize;
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
                    fprintf(stderr,"Short read while reading frame\n");
            }

            NSString *string = [[[NSString alloc] initWithBytes:frame length:FrameSize encoding:NSUTF8StringEncoding] autorelease];
            string = StripSSALine(string);

            if ([string length]) {
                SBSubLine *sl = [[SBSubLine alloc] initWithLine:string start:StartTime/1000000 end:EndTime/1000000];
                [trackHelper->ss addLine:[sl autorelease]];
            }
        }        

        else if (trackInfo->Type == TT_VIDEO) {
            uint64_t timeScale = mkv_GetFileInfo(matroskaFile)->TimecodeScale / mkv_TruncFloat(trackInfo->TimecodeScale) * 1000;

            /* read frames from file */
            if (success == 0) {
                frameSample = [[MatroskaSample alloc] init];
                frameSample->startTime = StartTime;
                frameSample->endTime = EndTime;
                frameSample->filePos = FilePos;
                frameSample->frameSize = FrameSize;
                frameSample->frameFlags = FrameFlags;
                [trackHelper->queue addObject:frameSample];
                [frameSample release];
            }
            else if (success == -1 && bufferFlush == 1) {
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
            if ([trackHelper->queue count] < bufferSize && success == 0)
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
                        fprintf(stderr,"Short read while reading frame\n");
                    break;
                }

                MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                sample->sampleData = frame;
                sample->sampleSize = currentSample->frameSize + trackInfo->CompMethodPrivateSize;
                sample->sampleDuration = duration / (timeScale / 90000.f);
                sample->sampleOffset = offset / (timeScale / 90000.f);
                sample->sampleTimestamp = StartTime;
                sample->sampleIsSync = currentSample->frameFlags & FRAME_KF;
                sample->sampleTrackId = track.Id;

                trackHelper->samplesWritten++;

                if (trackHelper->buffer >= bufferSize)
                    [trackHelper->queue removeObjectAtIndex:0];
                if (trackHelper->buffer < bufferSize && success == 0)
                    trackHelper->buffer++;

                if (success == -1) {
                    trackHelper->bufferFlush++;
                    if (trackHelper->bufferFlush >= bufferSize-1) {
                        mkv_Seek(matroskaFile, 0, 0);
                        break;
                    }
                }

                @synchronized(samplesBuffer) {
                    [samplesBuffer addObject:sample];
                    [sample release];
                }
            }
        }        
    }

    for (MP42Track* track in activeTracks){
        trackHelper = track.trackDemuxerHelper;
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

- (CGFloat)progress {
    return progress;
}

- (void) dealloc
{
    if (dataReader)
        [dataReader release], dataReader = nil;

	[file release];
    [tracksArray release];

	/* close matroska parser */ 
	mkv_Close(matroskaFile); 

	/* close file */ 
	fclose(ioStream->fp); 

    [super dealloc];
}

@end
