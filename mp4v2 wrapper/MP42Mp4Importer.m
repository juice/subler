//
//  MP42MkvFileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import "MP42Mp4Importer.h"
#import "lang.h"
#import "MP42File.h"
#import "MP42Sample.h"

@interface Mp4TrackHelper : NSObject {
@public
    MP4SampleId     currentSampleId;
    uint64_t        totalSampleNumber;
    MP4Timestamp    currentTime;
}
@end

@implementation Mp4TrackHelper

-(id)init
{
    if ((self = [super init]))
    {
    }
    return self;
}

- (void) dealloc {
    
    [super dealloc];
}
@end


@implementation MP42Mp4Importer

- (id)initWithDelegate:(id)del andFile:(NSURL *)URL error:(NSError **)outError
{
    if ((self = [super init])) {
        delegate = del;
        fileURL = [URL retain];

        MP42File *sourceFile = [[MP42File alloc] initWithExistingFile:fileURL andDelegate:self];

        if(!sourceFile) {
            if (outError) {
                *outError = MP42Error(@"The movie could not be opened.", @"The file is not a mp4 file.", 100);          
            }

            [self release];
            return nil;
        }

        tracksArray = [[sourceFile tracks] retain];
        for (MP42Track * track in tracksArray) {
            [track setSourceFormat:[track format]];
        }

        metadata = [[sourceFile metadata] retain];

        [sourceFile release];
    }

    return self;
}

- (NSUInteger)timescaleForTrack:(MP42Track *)track
{
    return MP4GetTrackTimeScale(fileHandle, [track sourceId]);
}

- (NSSize)sizeForTrack:(MP42Track *)track
{
    MP42VideoTrack* currentTrack = (MP42VideoTrack*) track;

    return NSMakeSize([currentTrack width], [currentTrack height]);
}

- (NSData*)magicCookieForTrack:(MP42Track *)track
{
    if (!fileHandle)
        fileHandle = MP4Read([[fileURL path] UTF8String]);

    NSData *magicCookie;
    MP4TrackId srcTrackId = [track sourceId];

    const char* trackType = MP4GetTrackType(fileHandle, srcTrackId);
    const char *media_data_name = MP4GetTrackMediaDataName(fileHandle, srcTrackId);
    
    if (MP4_IS_AUDIO_TRACK_TYPE(trackType))
    {
        if (!strcmp(media_data_name, "ac-3")) {
            uint64_t fscod, bsid, bsmod, acmod, lfeon, bit_rate_code;
            MP4GetTrackIntegerProperty(fileHandle, srcTrackId, "mdia.minf.stbl.stsd.ac-3.dac3.fscod", &fscod);
            MP4GetTrackIntegerProperty(fileHandle, srcTrackId, "mdia.minf.stbl.stsd.ac-3.dac3.bsid", &bsid);
            MP4GetTrackIntegerProperty(fileHandle, srcTrackId, "mdia.minf.stbl.stsd.ac-3.dac3.bsmod", &bsmod);
            MP4GetTrackIntegerProperty(fileHandle, srcTrackId, "mdia.minf.stbl.stsd.ac-3.dac3.acmod", &acmod);
            MP4GetTrackIntegerProperty(fileHandle, srcTrackId, "mdia.minf.stbl.stsd.ac-3.dac3.lfeon", &lfeon);
            MP4GetTrackIntegerProperty(fileHandle, srcTrackId, "mdia.minf.stbl.stsd.ac-3.dac3.bit_rate_code", &bit_rate_code);

            NSMutableData *ac3Info = [[NSMutableData alloc] init];
            [ac3Info appendBytes:&fscod length:sizeof(uint64_t)];
            [ac3Info appendBytes:&bsid length:sizeof(uint64_t)];
            [ac3Info appendBytes:&bsmod length:sizeof(uint64_t)];
            [ac3Info appendBytes:&acmod length:sizeof(uint64_t)];
            [ac3Info appendBytes:&lfeon length:sizeof(uint64_t)];
            [ac3Info appendBytes:&bit_rate_code length:sizeof(uint64_t)];

            return [ac3Info autorelease];
            
        } else {
            uint8_t *ppConfig; uint32_t pConfigSize;
            MP4GetTrackESConfiguration(fileHandle, srcTrackId, &ppConfig, &pConfigSize);
            magicCookie = [NSData dataWithBytes:ppConfig length:pConfigSize];
        }
        return magicCookie;
    }
    
    else if (!strcmp(trackType, MP4_SUBPIC_TRACK_TYPE)) {
        uint8_t *ppConfig; uint32_t pConfigSize;
        MP4GetTrackESConfiguration(fileHandle, srcTrackId, &ppConfig, &pConfigSize);

        UInt32* paletteG = (UInt32 *) ppConfig;

        int ii;
        for ( ii = 0; ii < 16; ii++ )
            paletteG[ii] = yuv2rgb(EndianU32_BtoN(paletteG[ii]));

        magicCookie = [NSData dataWithBytes:paletteG length:pConfigSize];

        return magicCookie;
    }

    else if (MP4_IS_VIDEO_TRACK_TYPE(trackType))
    {
        if (!strcmp(media_data_name, "avc1")) {
            // Extract and rewrite some kind of avcC extradata from the mp4 file.
            NSMutableData *avcCData = [[[NSMutableData alloc] init] autorelease];

            uint8_t configurationVersion = 1;
            uint8_t AVCProfileIndication;
            uint8_t profile_compat;
            uint8_t AVCLevelIndication;
            uint32_t sampleLenFieldSizeMinusOne;
            uint64_t temp;

            if (MP4GetTrackH264ProfileLevel(fileHandle, srcTrackId,
                                            &AVCProfileIndication,
                                            &AVCLevelIndication) == false) {
                return nil;
            }
            if (MP4GetTrackH264LengthSize(fileHandle, srcTrackId,
                                          &sampleLenFieldSizeMinusOne) == false) {
                return nil;
            }
            sampleLenFieldSizeMinusOne--;
            if (MP4GetTrackIntegerProperty(fileHandle, srcTrackId,
                                           "mdia.minf.stbl.stsd.*[0].avcC.profile_compatibility",
                                           &temp) == false) return nil;
            profile_compat = temp & 0xff;

            [avcCData appendBytes:&configurationVersion length:sizeof(uint8_t)];
            [avcCData appendBytes:&AVCProfileIndication length:sizeof(uint8_t)];
            [avcCData appendBytes:&profile_compat length:sizeof(uint8_t)];
            [avcCData appendBytes:&AVCLevelIndication length:sizeof(uint8_t)];
            [avcCData appendBytes:&sampleLenFieldSizeMinusOne length:sizeof(uint8_t)];

            uint8_t **seqheader, **pictheader;
            uint32_t *pictheadersize, *seqheadersize;
            uint32_t ix, iy;
            MP4GetTrackH264SeqPictHeaders(fileHandle, srcTrackId,
                                          &seqheader, &seqheadersize,
                                          &pictheader, &pictheadersize);
            NSMutableData *seqData = [[NSMutableData alloc] init];
            for (ix = 0 , iy = 0; seqheadersize[ix] != 0; ix++) {
                uint16_t temp = seqheadersize[ix] << 8;
                [seqData appendBytes:&temp length:sizeof(uint16_t)];
                [seqData appendBytes:seqheader[ix] length:seqheadersize[ix]];
                iy++;
            }
            [avcCData appendBytes:&iy length:sizeof(uint8_t)];
            [avcCData appendData:seqData];

            free(seqheader);
            free(seqheadersize);

            NSMutableData *pictData = [[NSMutableData alloc] init];
            for (ix = 0, iy = 0; pictheadersize[ix] != 0; ix++) {
                uint16_t temp = pictheadersize[ix] << 8;
                [pictData appendBytes:&temp length:sizeof(uint16_t)];
                [pictData appendBytes:pictheader[ix] length:pictheadersize[ix]];
                iy++;
            }

            [avcCData appendBytes:&iy length:sizeof(uint8_t)];
            [avcCData appendData:pictData];

            free(pictheader);
            free(pictheadersize);
            
            magicCookie = [avcCData copy];
            [seqData release];
            [pictData release];

            return [magicCookie autorelease];
        }
    }

    return nil;
}

- (void) fillMovieSampleBuffer: (id)sender
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    if (!fileHandle)
        fileHandle = MP4Read([[fileURL path] UTF8String]);

    NSInteger tracksNumber = [activeTracks count];
    NSInteger tracksDone = 0;
    Mp4TrackHelper * trackHelper;

    for (MP42Track * track in activeTracks) {
        if (track.trackDemuxerHelper == nil) {
            track.trackDemuxerHelper = [[[Mp4TrackHelper alloc] init] autorelease];

            trackHelper = track.trackDemuxerHelper;
            trackHelper->totalSampleNumber = MP4GetTrackNumberOfSamples(fileHandle, [track Id]);
        }
    }

    for (MP42Track * track in activeTracks) {
        while (!isCancelled) {
            while ([samplesBuffer count] >= 200) {
                usleep(200);
            }

            MP4TrackId srcTrackId = [track sourceId];
            uint8_t *pBytes = NULL;
            uint32_t numBytes = 0;
            MP4Duration duration;
            MP4Duration renderingOffset;
            MP4Timestamp pStartTime;
            bool isSyncSample;

            trackHelper = track.trackDemuxerHelper;
            trackHelper->currentSampleId = trackHelper->currentSampleId + 1;

            if (!MP4ReadSample(fileHandle,
                               srcTrackId,
                               trackHelper->currentSampleId,
                               &pBytes, &numBytes,
                               &pStartTime, &duration, &renderingOffset,
                               &isSyncSample)) {
                tracksDone++;
                break;
            }

            MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
            sample->sampleData = pBytes;
            sample->sampleSize = numBytes;
            sample->sampleDuration = duration;
            sample->sampleOffset = renderingOffset;
            sample->sampleTimestamp = pStartTime;
            sample->sampleIsSync = isSyncSample;
            sample->sampleTrackId = track.Id;
            if(track.needConversion)
                sample->sampleSourceTrack = track;

            @synchronized(samplesBuffer) {
                [samplesBuffer addObject:sample];
                [sample release];
            }

            progress = ((trackHelper->currentSampleId / (CGFloat) trackHelper->totalSampleNumber ) * 100 / tracksNumber) +
                        (tracksDone / (CGFloat) tracksNumber * 100);
        }
    }

    if (tracksDone >= tracksNumber)
        readerStatus = 1;

    [pool release];
}

- (MP42SampleBuffer*)copyNextSample
{
    if (!fileHandle)
        fileHandle = MP4Read([[fileURL path] UTF8String]);

    if (samplesBuffer == nil) {
        samplesBuffer = [[NSMutableArray alloc] initWithCapacity:200];
    }    

    if (!dataReader && !readerStatus) {
        dataReader = [[NSThread alloc] initWithTarget:self selector:@selector(fillMovieSampleBuffer:) object:self];
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

- (BOOL)cleanUp:(MP4FileHandle) dstFileHandle
{
    for (MP42Track * track in activeTracks) {
        MP4TrackId srcTrackId = [track sourceId];
        MP4TrackId dstTrackId = [track Id];

        MP4Duration trackDuration = 0;
        uint32_t i = 1, trackEditCount = MP4GetTrackNumberOfEdits(fileHandle, srcTrackId);
        while (i <= trackEditCount) {
            MP4Timestamp editMediaStart = MP4GetTrackEditMediaStart(fileHandle, srcTrackId, i);
            MP4Duration editDuration = MP4ConvertFromMovieDuration(fileHandle,
                                                                   MP4GetTrackEditDuration(fileHandle, srcTrackId, i),
                                                                   MP4GetTimeScale(dstFileHandle));
            trackDuration += editDuration;
            int8_t editDwell = MP4GetTrackEditDwell(fileHandle, srcTrackId, i);
            
            MP4AddTrackEdit(dstFileHandle, dstTrackId, i, editMediaStart, editDuration, editDwell);
            i++;
        }
        if (trackEditCount)
            MP4SetTrackIntegerProperty(dstFileHandle, dstTrackId, "tkhd.duration", trackDuration);
        else if (MP4GetSampleRenderingOffset(dstFileHandle, dstTrackId, 1)) {
            uint32_t firstFrameOffset = MP4GetSampleRenderingOffset(dstFileHandle, dstTrackId, 1);
            MP4Duration editDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                                   srcTrackId,
                                                                   MP4GetTrackDuration(fileHandle, srcTrackId),
                                                                   MP4GetTimeScale(dstFileHandle));
            MP4AddTrackEdit(dstFileHandle, dstTrackId, MP4_INVALID_EDIT_ID, firstFrameOffset,
                            editDuration, 0);
        }
    }

    return YES;
}

- (void) dealloc
{
    if (dataReader)
        [dataReader release];

    if (fileHandle)
        MP4Close(fileHandle);

    if (activeTracks)
        [activeTracks release];
    if (samplesBuffer)
        [samplesBuffer release];

    [metadata release];
	[fileURL release];
    [tracksArray release];

    [super dealloc];
}

@end
