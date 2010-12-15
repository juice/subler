//
//  MP42Muxer.m
//  Subler
//
//  Created by Damiano Galassi on 30/06/10.
//  Copyright 2010 Damiano Galassi. All rights reserved.
//

#import "MP42Muxer.h"
#import "MP42File.h"
#import "MP42FileImporter.h"
#import "MP42Sample.h"
#import "SBAudioConverter.h"

@implementation MP42Muxer

- (id)init
{
    if ((self = [super init]))
    {
        workingTracks = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id)initWithDelegate:(id)del
{
    if ((self = [super init])) {
        workingTracks = [[NSMutableArray alloc] init];
        delegate = del;
    }
    
    return self;
}

- (void)addTrack:(MP42Track*)track
{
    if (![track isMemberOfClass:[MP42ChapterTrack class]])
        [workingTracks addObject:track];
}

- (void)prepareWork:(MP4FileHandle)fileHandle
{
    for (MP42Track * track in workingTracks)
    {
        MP4TrackId dstTrackId = 0;
        NSData *magicCookie = [[track trackImporterHelper] magicCookieForTrack:track];
        NSInteger timeScale = [[track trackImporterHelper] timescaleForTrack:track];
        
        if([track isMemberOfClass:[MP42AudioTrack class]] && track.needConversion) {
            track.format = @"AAC";
            SBAudioConverter *audioConverter = [[SBAudioConverter alloc] initWithTrack:(MP42AudioTrack*)track];
            track.trackConverterHelper = audioConverter;
            [audioConverter release];
        }

        // H.264 video track
        if ([track isMemberOfClass:[MP42VideoTrack class]] && [track.format isEqualToString:@"H.264"]) {
            NSSize size = [[track trackImporterHelper] sizeForTrack:track];

            uint8_t* avcCAtom = (uint8_t*)[magicCookie bytes];
            dstTrackId = MP4AddH264VideoTrack(fileHandle, timeScale,
                                              MP4_INVALID_DURATION,
                                              size.width, size.height,
                                              avcCAtom[1],  // AVCProfileIndication
                                              avcCAtom[2],  // profile_compat
                                              avcCAtom[3],  // AVCLevelIndication
                                              avcCAtom[4]); // lengthSizeMinusOne

            SInt64 i;
            int8_t spsCount = (avcCAtom[5] & 0x1f);
            uint8_t ptrPos = 6;
            for (i = 0; i < spsCount; i++) {
                uint16_t spsSize = (avcCAtom[ptrPos++] << 8) & 0xff00;
                spsSize += avcCAtom[ptrPos++] & 0xff;
                MP4AddH264SequenceParameterSet(fileHandle, dstTrackId,
                                               avcCAtom+ptrPos, spsSize);
                ptrPos += spsSize;
            }

            int8_t ppsCount = avcCAtom[ptrPos++];
            for (i = 0; i < ppsCount; i++) {
                uint16_t ppsSize = (avcCAtom[ptrPos++] << 8) & 0xff00;
                ppsSize += avcCAtom[ptrPos++] & 0xff;
                MP4AddH264PictureParameterSet(fileHandle, dstTrackId,
                                              avcCAtom+ptrPos, ppsSize);
                ptrPos += ppsSize;
            }

            MP4SetVideoProfileLevel(fileHandle, 0x15);

            [[track trackImporterHelper] setActiveTrack:track];
        }

        // MPEG-4 Visual video track
        else if ([track isMemberOfClass:[MP42VideoTrack class]] && [track.format isEqualToString:@"MPEG-4 Visual"]) {
            MP4SetVideoProfileLevel(fileHandle, MPEG4_SP_L3);
            // Add video track
            dstTrackId = MP4AddVideoTrack(fileHandle, timeScale,
                                          MP4_INVALID_DURATION,
                                          [(MP42VideoTrack*)track width], [(MP42VideoTrack*)track height],
                                          MP4_MPEG4_VIDEO_TYPE);
            MP4SetTrackESConfiguration(fileHandle, dstTrackId,
                                       [magicCookie bytes],
                                       [magicCookie length]);

            [[track trackImporterHelper] setActiveTrack:track];
        }

        // Photo-JPEG video track
        else if ([track isMemberOfClass:[MP42VideoTrack class]] && [track.format isEqualToString:@"Photo - JPEG"]) {
            // Add video track
            MP4AddMJpegVideoTrack(fileHandle, timeScale,
                                  MP4_INVALID_DURATION, [(MP42VideoTrack*)track width], [(MP42VideoTrack*)track height]);

            [[track trackImporterHelper] setActiveTrack:track];
        }

        // AAC audio track
        else if ([track isMemberOfClass:[MP42AudioTrack class]] && [track.format isEqualToString:@"AAC"]) {
            dstTrackId = MP4AddAudioTrack(fileHandle,
                                          timeScale,
                                          1024, MP4_MPEG4_AUDIO_TYPE);

            if (!track.needConversion) {
                MP4SetTrackESConfiguration(fileHandle, dstTrackId,
                                           [magicCookie bytes],
                                           [magicCookie length]);
            }
            
            [[track trackImporterHelper] setActiveTrack:track];
        }

        // AC-3 audio track
        else if ([track isMemberOfClass:[MP42AudioTrack class]] && [track.format isEqualToString:@"AC-3"]) {
            const uint64_t * ac3Info = (const uint64_t *)[magicCookie bytes];

            dstTrackId = MP4AddAC3AudioTrack(fileHandle,
                                             timeScale,
                                             ac3Info[0],
                                             ac3Info[1],
                                             ac3Info[2],
                                             ac3Info[3],
                                             ac3Info[4],
                                             ac3Info[5]);            
            [[track trackImporterHelper] setActiveTrack:track];
        }

        // 3GPP text track
        else if ([track isMemberOfClass:[MP42SubtitleTrack class]]) {
            NSSize videoSize = [[track trackImporterHelper] sizeForTrack:track];

            if (!videoSize.width) {
                MP4TrackId videoTrack;
                
                videoTrack = findFirstVideoTrack(fileHandle);
                if (videoTrack) {
                    videoSize.width = getFixedVideoWidth(fileHandle, videoTrack);
                    videoSize.height = MP4GetTrackVideoHeight(fileHandle, videoTrack);
                }
                else {
                    videoSize.width = 640;
                    videoSize.height = 480;
                }
            }

            const uint8_t textColor[4] = { 255,255,255,255 };
            dstTrackId = MP4AddSubtitleTrack(fileHandle, timeScale, videoSize.width, 80);

            MP4SetTrackDurationPerChunk(fileHandle, dstTrackId, timeScale / 8);
            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "tkhd.alternate_group", 2);
            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "tkhd.layer", -1);

            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.horizontalJustification", 1);
            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.verticalJustification", -1);

            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.bgColorAlpha", 255);

            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.defTextBoxBottom", 80);
            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.defTextBoxRight", videoSize.width);

            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.fontSize", 24);

            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.fontColorRed", textColor[0]);
            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.fontColorGreen", textColor[1]);
            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.fontColorBlue", textColor[2]);
            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.fontColorAlpha", textColor[3]);

            /* translate the track */
            uint8_t* val;
            uint8_t nval[36];
            uint32_t *ptr32 = (uint32_t*) nval;
            uint32_t size;

            MP4GetTrackBytesProperty(fileHandle, dstTrackId, "tkhd.matrix", &val, &size);
            memcpy(nval, val, size);
            ptr32[7] = CFSwapInt32HostToBig( (videoSize.height - 80) * 0x10000);

            MP4SetTrackBytesProperty(fileHandle, dstTrackId, "tkhd.matrix", nval, size);
            free(val);
            
            [[track trackImporterHelper] setActiveTrack:track];
        }
        // Closed Caption text track
        else if ([track isMemberOfClass:[MP42ClosedCaptionTrack class]]) {
            NSSize videoSize = [[track trackImporterHelper] sizeForTrack:track];

            if (!videoSize.width) {
                MP4TrackId videoTrack;

                videoTrack = findFirstVideoTrack(fileHandle);
                if (videoTrack) {
                    videoSize.width = getFixedVideoWidth(fileHandle, videoTrack);
                    videoSize.height = MP4GetTrackVideoHeight(fileHandle, videoTrack);
                }
                else {
                    videoSize.width = 640;
                    videoSize.height = 480;
                }
            }

            dstTrackId = MP4AddCCTrack(fileHandle, timeScale, videoSize.width, videoSize.height);
            
            [[track trackImporterHelper] setActiveTrack:track];
        }
        else {
            continue;
        }

        track.Id = dstTrackId;
    }
}

- (void)work:(MP4FileHandle)fileHandle
{
    NSMutableArray * trackImportersArray = [[NSMutableArray alloc] init];

    for (MP42Track * track in workingTracks) {
        if (![trackImportersArray containsObject:[track trackImporterHelper]]) {
            [trackImportersArray addObject:[track trackImporterHelper]];
        }
    }

    CGFloat status = 0;
    NSUInteger currentNumber = 0;
    NSInteger tracksNumber = [trackImportersArray count];

    if (tracksNumber == 0) {
        [trackImportersArray release];
        return;
    }

    for (id importerHelper in trackImportersArray) {
        MP42SampleBuffer * sampleBuffer;

        while ((sampleBuffer = [importerHelper copyNextSample]) != nil) {

            // The sample need additional conversion
            if (sampleBuffer->sampleSourceTrack) {
                MP42SampleBuffer *convertedSample;
                SBAudioConverter * audioConverter = sampleBuffer->sampleSourceTrack.trackConverterHelper;
                [audioConverter addSample:sampleBuffer];
                while (![audioConverter needMoreSample]) {
                    if ((convertedSample = [audioConverter copyEncodedSample]) != nil) {
                        MP4WriteSample(fileHandle, convertedSample->sampleTrackId,
                                       convertedSample->sampleData, convertedSample->sampleSize,
                                       convertedSample->sampleDuration, convertedSample->sampleOffset,
                                       convertedSample->sampleIsSync);
                        [convertedSample release];
                    }
                    else {
                        usleep(50);
                    }
                }
                [sampleBuffer release];
            }

            // Write the sample directly to the file
            else {
                MP4WriteSample(fileHandle, sampleBuffer->sampleTrackId,
                               sampleBuffer->sampleData, sampleBuffer->sampleSize,
                               sampleBuffer->sampleDuration, sampleBuffer->sampleOffset,
                               sampleBuffer->sampleIsSync);
                [sampleBuffer release];
            }
            
            if (currentNumber == 300) {
                status = [importerHelper progress] / tracksNumber;

                if ([delegate respondsToSelector:@selector(progressStatus:)]) 
                    [delegate progressStatus:status];
                currentNumber = 0;
            }
            else {
                currentNumber++;
            }
        }
        [importerHelper cleanUp:fileHandle];
    }

    [trackImportersArray release];

    // Write the last samples from the encoder
    for (MP42Track * track in workingTracks) {
        if([track isMemberOfClass:[MP42AudioTrack class]] && track.needConversion) {
            SBAudioConverter * audioConverter = (SBAudioConverter *) track.trackConverterHelper;
            [audioConverter setDone:YES];
            MP42SampleBuffer *convertedSample;
            while (![audioConverter encoderDone]) {
                if ((convertedSample = [audioConverter copyEncodedSample]) != nil) {
                    MP4WriteSample(fileHandle, convertedSample->sampleTrackId,
                                   convertedSample->sampleData, convertedSample->sampleSize,
                                   convertedSample->sampleDuration, convertedSample->sampleOffset,
                                   convertedSample->sampleIsSync);
                    [convertedSample release];
                }
                else {
                    usleep(50);
                }

            }
            NSData *magicCookie = [track.trackConverterHelper magicCookie];
            MP4SetTrackESConfiguration(fileHandle, track.Id,
                                       [magicCookie bytes],
                                       [magicCookie length]);
        }
    }

    //for (MP42Track * track in workingTracks) {
        //[track.trackImporterHelper release];
        //track.trackImporterHelper = nil;
    //}
}

- (void)stopWork:(MP4FileHandle)fileHandle
{
}

- (void) dealloc
{
    [workingTracks release], workingTracks = nil;
    [super dealloc];
}

@end
