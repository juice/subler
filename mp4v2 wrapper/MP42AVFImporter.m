//
//  MP42MkvFileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import "MP42AVFImporter.h"
#import "MP42File.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

#include "lang.h"

@interface AVFTrackHelper : NSObject {
@public
    CMTime              currentTime;
    AVAssetReaderOutput *assetReaderOutput;
    int64_t             minDisplayOffset;
}
@end

@implementation AVFTrackHelper

-(id)init
{
    if ((self = [super init])) {
    }
    return self;
}

- (void) dealloc
{
    [super dealloc];
}
@end

@implementation MP42AVFImporter

- (NSString*)formatForTrack: (AVAssetTrack *)track;
{
    NSString* result = @"";
    
    CMFormatDescriptionRef formatDescription;
    NSArray *formatDescriptions = track.formatDescriptions;
    if ([formatDescriptions count] > 0)
        formatDescription = (CMFormatDescriptionRef)[formatDescriptions objectAtIndex:0];
    
    FourCharCode code = CMFormatDescriptionGetMediaSubType(formatDescription);
    switch (code) {
        case kCMVideoCodecType_H264:
            result = @"H.264";
            break;
        case kCMVideoCodecType_MPEG4Video:
            result = @"MPEG-4 Visual";
            break;
        case kAudioFormatMPEG4AAC:
            result = @"AAC";
            break;
        case kAudioFormatAC3:
        case 'ms \0':
            result = @"AC-3";
            break;
        case kAudioFormatAMR:
            result = @"AMR Narrow Band";
            break;
        case kCMTextFormatType_QTText:
            result = @"Text";
            break;
        case kCMTextFormatType_3GText:
            result = @"3GPP Text";
            break;
        case 'SRT ':
            result = @"Text";
            break;
        case 'SSA ':
            result = @"SSA";
            break;
        case kCMClosedCaptionFormatType_CEA608:
            result = @"CEA-608";
            break;
        case kCMClosedCaptionFormatType_CEA708:
            result = @"CEA-708";
            break;
        case kCMClosedCaptionFormatType_ATSC:
            result = @"ATSC/52 part-4";
            break;
        case kCMTimeCodeFormatType_TimeCode32:
        case kCMTimeCodeFormatType_TimeCode64:
        case kCMTimeCodeFormatType_Counter32:
        case kCMTimeCodeFormatType_Counter64:
            result = @"Timecode";
            break;
        case kCMVideoCodecType_JPEG:
            result = @"Photo - JPEG";
            break;
        default:
            result = @"Unknown";
            break;
    }
    
    return result;
}

- (NSString*)langForTrack: (AVAssetTrack *)track
{
    return [NSString stringWithUTF8String:lang_for_qtcode([[track languageCode] integerValue])->eng_name];
}

- (id)initWithDelegate:(id)del andFile:(NSString *)fileUrl error:(NSError **)outError
{
    if ((self = [super init])) {
        delegate = del;
        file = [fileUrl retain];

        NSURL *url = (NSURL*) CFURLCreateWithFileSystemPath(NULL, (CFStringRef) fileUrl, kCFURLPOSIXPathStyle, NO);
        localAsset = [[AVAsset assetWithURL:url] retain];
        [url release];

        tracksArray = [[NSMutableArray alloc] init];
        NSArray *tracks = [localAsset tracks];

        for (AVAssetTrack *track in tracks) {
            MP42Track *newTrack = nil;

            CMFormatDescriptionRef formatDescription;
            NSArray *formatDescriptions = track.formatDescriptions;
			if ([formatDescriptions count] > 0)
				formatDescription = (CMFormatDescriptionRef)[formatDescriptions objectAtIndex:0];

            if ([[track mediaType] isEqualToString:AVMediaTypeVideo]) {
                newTrack = [[MP42VideoTrack alloc] init];
                CGSize naturalSize = [track naturalSize];

                [(MP42VideoTrack*)newTrack setTrackWidth: naturalSize.width];
                [(MP42VideoTrack*)newTrack setTrackHeight: naturalSize.height];
                
                [(MP42VideoTrack*)newTrack setWidth: naturalSize.width];
                [(MP42VideoTrack*)newTrack setHeight: naturalSize.height];
                
                CFDictionaryRef pixelAspectRatioFromCMFormatDescription = CMFormatDescriptionGetExtension(formatDescription, kCMFormatDescriptionExtension_PixelAspectRatio);
				if (pixelAspectRatioFromCMFormatDescription)
				{
                    NSInteger hSpacing, vSpacing;
                    CFNumberGetValue(CFDictionaryGetValue(pixelAspectRatioFromCMFormatDescription, kCMFormatDescriptionKey_PixelAspectRatioHorizontalSpacing), kCFNumberIntType, &hSpacing);
                    CFNumberGetValue(CFDictionaryGetValue(pixelAspectRatioFromCMFormatDescription, kCMFormatDescriptionKey_PixelAspectRatioVerticalSpacing), kCFNumberIntType, &vSpacing);
                    [(MP42VideoTrack*)newTrack setHSpacing:hSpacing];
                    [(MP42VideoTrack*)newTrack setVSpacing:vSpacing];
				}
            }
            else if ([[track mediaType] isEqualToString:AVMediaTypeAudio]) {
                newTrack = [[MP42AudioTrack alloc] init];

                size_t layoutSize = 1;
                const AudioChannelLayout *layout = CMAudioFormatDescriptionGetChannelLayout(formatDescription, &layoutSize);

                [(MP42AudioTrack*)newTrack setChannels: AudioChannelLayoutTag_GetNumberOfChannels(layout->mChannelLayoutTag)];
                [(MP42AudioTrack*)newTrack setChannelLayoutTag: layout->mChannelLayoutTag];
            }
            else if ([[track mediaType] isEqualToString:AVMediaTypeSubtitle]) {
                newTrack = [[MP42SubtitleTrack alloc] init];
            }

            newTrack.format = [self formatForTrack:track];
            newTrack.Id = [track trackID];
            newTrack.sourcePath = file;
            newTrack.sourceFileHandle = localAsset;
            //newTrack.name = [track attributeForKey:QTTrackDisplayNameAttribute];
            newTrack.language = [self langForTrack:track];

            CMTimeRange timeRange = [track timeRange];
            newTrack.duration = timeRange.duration.value / timeRange.duration.timescale * 1000;

            [tracksArray addObject:newTrack];
            [newTrack release];
        }
    }

    return self;
}

- (NSUInteger)timescaleForTrack:(MP42Track *)track
{
    AVAssetTrack *assetTrack = [localAsset trackWithTrackID:[track sourceId]];

    return [assetTrack naturalTimeScale];
}

- (NSSize)sizeForTrack:(MP42Track *)track
{
    MP42VideoTrack* currentTrack = (MP42VideoTrack*) track;

    return NSMakeSize([currentTrack width], [currentTrack height]);
}

- (NSData*)magicCookieForTrack:(MP42Track *)track
{
    AVAssetTrack *assetTrack = [localAsset trackWithTrackID:[track sourceId]];

    CMFormatDescriptionRef formatDescription;
    NSArray *formatDescriptions = assetTrack.formatDescriptions;
    if ([formatDescriptions count] > 0)
        formatDescription = (CMFormatDescriptionRef)[formatDescriptions objectAtIndex:0];

    FourCharCode code = CMFormatDescriptionGetMediaSubType(formatDescription);
    if ([[assetTrack mediaType] isEqualToString:AVMediaTypeVideo]) {
        if (code == kCMVideoCodecType_H264) {
            CFDictionaryRef extentions = CMFormatDescriptionGetExtensions(formatDescription);
            CFDictionaryRef atoms = CFDictionaryGetValue(extentions, kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms);
            CFDataRef avcC = CFDictionaryGetValue(atoms, @"avcC");

            return (NSData*)avcC;
        }
    }
    else if ([[assetTrack mediaType] isEqualToString:AVMediaTypeAudio]) {
        size_t cookieSizeOut;
        const void *magicCookie = CMAudioFormatDescriptionGetMagicCookie(formatDescription, &cookieSizeOut);

        // Extract DecoderSpecific info
        UInt8* buffer;
        int size;
        ReadESDSDescExt((void*)magicCookie, &buffer, &size, 0);

        return [NSData dataWithBytes:buffer length:size];
    }

    return nil;
}

- (void) fillMovieSampleBuffer: (id)sender
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	BOOL success = YES;
    OSStatus err = noErr;

    AVFTrackHelper * trackHelper=nil; 

    NSError *localError;
    AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:localAsset error:&localError];
	success = (assetReader != nil);
	if (success) {
        for (MP42Track * track in activeTracks) {
            AVAssetReaderOutput *assetReaderOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:[localAsset trackWithTrackID:track.sourceId] outputSettings:nil];
            if (! [assetReader canAddOutput: assetReaderOutput])
                NSLog(@"Unable to add the output to assetReader!");

            [assetReader addOutput:assetReaderOutput];

            track.trackDemuxerHelper = [[[AVFTrackHelper alloc] init] autorelease];

            trackHelper = track.trackDemuxerHelper;
            trackHelper->assetReaderOutput = assetReaderOutput;
        }
    }

    success = [assetReader startReading];
	if (!success)
		localError = [assetReader error];

    for (MP42Track * track in activeTracks) {
        AVAssetReaderOutput *assetReaderOutput = ((AVFTrackHelper*)track.trackDemuxerHelper)->assetReaderOutput;
        while (!isCancelled) {
            while ([samplesBuffer count] >= 200) {
                usleep(200);
            }

            CMSampleBufferRef sampleBuffer = [assetReaderOutput copyNextSampleBuffer];
            if (sampleBuffer) {
                CMItemCount samplesNum = CMSampleBufferGetNumSamples(sampleBuffer);
                if (!samplesNum)
                    continue;
                if (samplesNum == 1) {
                    // We have only a sample
                    CMTime duration = CMSampleBufferGetDuration(sampleBuffer);
                    CMTime decodeTimeStamp = CMSampleBufferGetDecodeTimeStamp(sampleBuffer);
                    CMTime presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);

                    CMBlockBufferRef buffer = CMSampleBufferGetDataBuffer(sampleBuffer);
                    size_t sampleSize = CMBlockBufferGetDataLength(buffer);
                    void *sampleData = malloc(sampleSize);
                    CMBlockBufferCopyDataBytes(buffer, 0, sampleSize, sampleData);

                    BOOL sync = 1;
                    CFArrayRef attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, NO);
                    if (attachmentsArray) {
                        for (NSDictionary *dict in (NSArray*)attachmentsArray) {
                            if ([dict valueForKey:(NSString*)kCMSampleAttachmentKey_NotSync])
                                sync = 0;
                        }
                    }
                    MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                    sample->sampleData = sampleData;
                    sample->sampleSize = sampleSize;
                    sample->sampleDuration = duration.value;
                    sample->sampleOffset = decodeTimeStamp.value - presentationTimeStamp.value;
                    sample->sampleTimestamp = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer).value;
                    sample->sampleIsSync = sync;
                    sample->sampleTrackId = track.Id;

                    @synchronized(samplesBuffer) {
                        [samplesBuffer addObject:sample];
                        [sample release];
                    }
                }
                else {
                    // A CMSampleBufferRef can contains an unknown number of samples, check how many needs to be divided to separated MP42SampleBuffers
                    // First get the array with the timings for each sample
                    CMItemCount timingArrayEntries = 0;
                    CMItemCount timingArrayEntriesNeededOut = 0;
                    err = CMSampleBufferGetOutputSampleTimingInfoArray(sampleBuffer, timingArrayEntries, NULL, &timingArrayEntriesNeededOut);
                    if (err)
                        continue;

                    CMSampleTimingInfo *timingArrayOut = malloc(sizeof(CMSampleTimingInfo) * timingArrayEntriesNeededOut);
                    timingArrayEntries = timingArrayEntriesNeededOut;
                    err = CMSampleBufferGetOutputSampleTimingInfoArray(sampleBuffer, timingArrayEntries, timingArrayOut, &timingArrayEntriesNeededOut);
                    if (err)
                        continue;
                    
                    // Then the array with the size of each sample
                    CMItemCount sizeArrayEntries = 0;
                    CMItemCount sizeArrayEntriesNeededOut = 0;
                    err = CMSampleBufferGetSampleSizeArray(sampleBuffer, sizeArrayEntries, NULL, &sizeArrayEntriesNeededOut);
                    if (err)
                        continue;

                    size_t *sizeArrayOut = malloc(sizeof(CMSampleTimingInfo) * sizeArrayEntriesNeededOut);
                    sizeArrayEntries = sizeArrayEntriesNeededOut;
                    err = CMSampleBufferGetSampleSizeArray(sampleBuffer, sizeArrayEntries, sizeArrayOut, &sizeArrayEntriesNeededOut);
                    if (err)
                        continue;

                    // Get CMBlockBufferRef to extrac the actual data later
                    CMBlockBufferRef buffer = CMSampleBufferGetDataBuffer(sampleBuffer);
                    size_t bufferSize = CMBlockBufferGetDataLength(buffer);

                    int i = 0, pos = 0;
                    for (i = 0; i < sizeArrayEntries; i++) {
                        CMSampleTimingInfo sampleTimingInfo = timingArrayOut[i];
                        if (timingArrayEntries < i +1)
                            sampleTimingInfo = timingArrayOut[0];

                        size_t sampleSize = sizeArrayOut[i];
                        if (!sampleSize)
                            continue;

                        void *sampleData = malloc(sampleSize);

                        if (pos < bufferSize) {
                            CMBlockBufferCopyDataBytes(buffer, pos, sampleSize, sampleData);
                            pos += sampleSize;
                        }

                        BOOL sync = 1;
                        CFArrayRef attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, NO);
                        if (attachmentsArray) {
                            for (NSDictionary *dict in (NSArray*)attachmentsArray) {
                                if ([dict valueForKey:(NSString*)kCMSampleAttachmentKey_NotSync])
                                    sync = 0;
                            }
                        }

                        MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                        sample->sampleData = sampleData;
                        sample->sampleSize = sampleSize;
                        sample->sampleDuration = sampleTimingInfo.duration.value;
                        //sample->sampleOffset = sampleTimingInfo.decodeTimeStamp.value - sampleTimingInfo.presentationTimeStamp.value;
                        sample->sampleTimestamp = sampleTimingInfo.presentationTimeStamp.value;
                        sample->sampleIsSync = sync;
                        sample->sampleTrackId = track.Id;

                        @synchronized(samplesBuffer) {
                            [samplesBuffer addObject:sample];
                            [sample release];
                        }
                    }

                    if(timingArrayOut)
                        free(timingArrayOut);
                    if(sizeArrayOut)
                        free(sizeArrayOut);
                }
            }
            else {
                AVAssetReaderStatus status = assetReader.status;

                if (status == AVAssetReaderStatusCompleted) {
                    NSLog(@"AVAssetReader: done");
                }

                break;
            }
        }
    }

    [assetReader release];
    readerStatus = 1;
    [pool release];
}

- (MP42SampleBuffer*)copyNextSample
{    
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

- (BOOL)cleanUp:(MP4FileHandle) fileHandle
{    
    return YES;
}

- (void) dealloc
{
    if (dataReader)
        [dataReader release];

	[file release];
    [tracksArray release];

    if (activeTracks)
        [activeTracks release];
    if (samplesBuffer)
        [samplesBuffer release];

    [localAsset release];

    [super dealloc];
}

@end
