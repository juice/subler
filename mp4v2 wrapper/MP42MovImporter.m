//
//  MP42MkvFileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import "MP42MovImporter.h"
#import "MP42File.h"
#import <AudioToolbox/AudioToolbox.h>

#if !__LP64__
#import <QuickTime/QuickTime.h>
#endif

#include "lang.h"


extern NSString * const QTTrackLanguageAttribute;	// NSNumber (long)

@interface QTMovie(IdlingAdditions)
-(QTTime)maxTimeLoaded;
@end

@interface MP42MovImporter(Private)
    -(void) movieLoaded;
    -(NSString*)formatForTrack: (QTTrack *)track;
    -(NSString*)langForTrack: (QTTrack *)track;
@end

@interface MovTrackHelper : NSObject {
@public
    MP4SampleId     currentSampleId;
    uint64_t        totalSampleNumber;
    int64_t         minDisplayOffset;
    MP4Timestamp    currentTime;
}
@end

@implementation MovTrackHelper

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

@implementation MP42MovImporter

- (id)initWithDelegate:(id)del andFile:(NSString *)fileUrl
{
    if ((self = [super init])) {
        delegate = del;
        file = [fileUrl retain];

        sourceFile = [[QTMovie alloc] initWithFile:file error:nil];

        if ([[sourceFile attributeForKey:QTMovieLoadStateAttribute] longValue] >= QTMovieLoadStateComplete) {
            [self movieLoaded];
        }
        else {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(loadStateChanged:) 
                                                         name:QTMovieLoadStateDidChangeNotification 
                                                       object:sourceFile];
            
            //loadTimer = [NSTimer scheduledTimerWithTimeInterval:1
            //                                             target:self
            //                                           selector:@selector(updateUI:)
            //                                           userInfo:nil
            //                                            repeats:YES];
            //[[NSRunLoop currentRunLoop] addTimer:loadTimer
            //                             forMode:NSDefaultRunLoopMode];
            //[loadProgressBar setIndeterminate:NO];
            //[loadProgressBar setHidden:NO];
            //[loadProgressBar setUsesThreadedAnimation:YES];
        }
    }

    return self;
}

-(void) movieLoaded
{
    for (QTTrack *track in [sourceFile tracks])
        if ([[track attributeForKey:QTTrackIsChapterTrackAttribute] boolValue])
            chapterTrackId = [[track attributeForKey:QTTrackIDAttribute] integerValue];

    tracksArray = [[NSMutableArray alloc] init];

    NSUInteger i = 0;
    for (QTTrack *track in [sourceFile tracks]) {
        NSString* mediaType = [track attributeForKey:QTTrackMediaTypeAttribute];
        MP42Track *newTrack = nil;

        // Video
        if ([mediaType isEqualToString:QTMediaTypeVideo]) {
            if ([[self formatForTrack:track] isEqualToString:@"Text"]) {
                newTrack = [[MP42SubtitleTrack alloc] init];
                [(MP42SubtitleTrack*)newTrack setTrackWidth:60];
            }
            else {
                newTrack = [[MP42VideoTrack alloc] init];

                NSSize dimension = [track apertureModeDimensionsForMode:QTMovieApertureModeClean];
                [(MP42VideoTrack*)newTrack setTrackWidth: dimension.width];
                [(MP42VideoTrack*)newTrack setTrackHeight: dimension.height];
                [(MP42VideoTrack*)newTrack setWidth: dimension.width];
                [(MP42VideoTrack*)newTrack setHeight: dimension.height];
            }
        }
        // Audio
        else if ([mediaType isEqualToString:QTMediaTypeSound])
            newTrack = [[MP42AudioTrack alloc] init];
        // Text
        else if ([mediaType isEqualToString:QTMediaTypeText]) {
            if ([[track attributeForKey:QTTrackIDAttribute] integerValue] == chapterTrackId) {
                newTrack = [[MP42ChapterTrack alloc] init];
                NSArray *chapters = [sourceFile chapters];

                for (NSDictionary *dic in chapters) {
                    QTTimeRange time = [[dic valueForKey:QTMovieChapterStartTime] QTTimeRangeValue];
                    [(MP42ChapterTrack*)newTrack addChapter:[dic valueForKey:QTMovieChapterName]
                                                    duration:((float)time.time.timeValue / time.time.timeScale)*1000];
                }
            }
        }
        // Subtitle
        else if([mediaType isEqualToString:@"sbtl"])
            newTrack = [[MP42SubtitleTrack alloc] init];
        // Closed Caption
        else if([mediaType isEqualToString:@"clcp"])
            newTrack = [[MP42ClosedCaptionTrack alloc] init];
        else
            newTrack = [[MP42Track alloc] init];

        if (newTrack) {
            newTrack.format = [self formatForTrack:track];
            newTrack.Id = i++;
            newTrack.sourcePath = file;
            newTrack.sourceFileHandle = sourceFile;
            newTrack.name = [track attributeForKey:QTTrackDisplayNameAttribute];
            newTrack.language = [self langForTrack:track];

            [newTrack setTrackImporterHelper:self];

            [tracksArray addObject:newTrack];
            [newTrack release];
        }
    }
    //[addTracksButton setEnabled:YES];
    //[loadProgressBar setHidden:YES];
}


-(void)loadStateChanged:(NSNotification *)notification
{
    long loadState = [[sourceFile attributeForKey:QTMovieLoadStateAttribute] longValue];
    
    if (loadState >= QTMovieLoadStateComplete)
    {
        [self movieLoaded];
        
        //[loadTimer invalidate];
        //loadTimer = nil;
        //[tableView reloadData];
    }
    else if (loadState == -1)
    {
        NSLog(@"Error occurred");
    }
}

-(double)_percentLoaded
{
    NSTimeInterval tMaxLoaded;
    NSTimeInterval tDuration;
    
    QTGetTimeInterval([sourceFile duration], &tDuration);
    QTGetTimeInterval([sourceFile maxTimeLoaded], &tMaxLoaded);
    
	return (double) tMaxLoaded/tDuration;
}

-(void) updateUI: (id) sender {
    //[loadProgressBar setDoubleValue:[self _percentLoaded] * 100];
}

- (NSString*)formatForTrack: (QTTrack *)track;
{
    NSString* result = @"";
#if !__LP64__
    ImageDescriptionHandle idh = (ImageDescriptionHandle) NewHandleClear(sizeof(ImageDescription));
    GetMediaSampleDescription([[track media] quickTimeMedia], 1,
                              (SampleDescriptionHandle)idh);
    
    switch ((*idh)->cType) {
        case kH264CodecType:
            result = @"H.264";
            break;
        case kMPEG4VisualCodecType:
            result = @"MPEG-4 Visual";
            break;
        case 'mp4a':
            result = @"AAC";
            break;
        case kAudioFormatAC3:
        case 'ms \0':
            result = @"AC-3";
            break;
        case kAudioFormatAMR:
            result = @"AMR Narrow Band";
            break;
        case TextMediaType:
            result = @"Text";
            break;
        case kTx3gSampleType:
            result = @"3GPP Text";
            break;
        case 'SRT ':
            result = @"Text";
            break;
        case 'SSA ':
            result = @"SSA";
            break;
        case 'c608':
            result = @"CEA-608";
            break;
        case TimeCodeMediaType:
            result = @"Timecode";
            break;
        case kJPEGCodecType:
            result = @"Photo - JPEG";
            break;
        default:
            result = @"Unknown";
            break;
    }
    DisposeHandle((Handle)idh);
#else
    result = [track attributeForKey:QTTrackFormatSummaryAttribute];
#endif
    return result;
}

- (NSString*)langForTrack: (QTTrack *)track
{
    return [NSString stringWithUTF8String:lang_for_qtcode(
                [[track attributeForKey:QTTrackLanguageAttribute] longValue])->eng_name];
}

- (NSUInteger)timescaleForTrack:(MP42Track *)track
{
    Track qtTrack = [[[sourceFile tracks] objectAtIndex:[track sourceId]] quickTimeTrack];
    Media media = GetTrackMedia(qtTrack);

    return GetMediaTimeScale(media);
}

- (NSSize)sizeForTrack:(MP42Track *)track
{
    MP42VideoTrack* currentTrack = (MP42VideoTrack*) track;

    return NSMakeSize([currentTrack width], [currentTrack height]);
}

- (NSData*)magicCookieForTrack:(MP42Track *)track
{      
    OSStatus err = noErr;

    QTTrack * qtTrack = [[sourceFile tracks] objectAtIndex:[track sourceId]];
    NSString* mediaType = [qtTrack attributeForKey:QTTrackMediaTypeAttribute];
    Track qtcTrack = [[[sourceFile tracks] objectAtIndex:[track sourceId]] quickTimeTrack];
    Media media = GetTrackMedia(qtcTrack);
    NSMutableData * magicCookie;

    // Get the sample description
    SampleDescriptionHandle desc = (SampleDescriptionHandle) NewHandle(0);
    GetMediaSampleDescription(media, 1, desc);

    if ([mediaType isEqualToString:QTMediaTypeVideo]) {
        ImageDescriptionHandle imgDesc = (ImageDescriptionHandle) desc;

        if ((*imgDesc)->cType == kH264CodecType) {
            // Get avcC atom
            Handle imgDescHandle = NewHandle(0);
            GetImageDescriptionExtension(imgDesc, &imgDescHandle, 'avcC', 1);
            
            magicCookie = [NSData dataWithBytes:*imgDescHandle length:GetHandleSize(imgDescHandle)];

            DisposeHandle(imgDescHandle);

            return [magicCookie autorelease];
        }
        else if ((*imgDesc)->cType == kMPEG4VisualCodecType) {
            long count;
            // Add ES decoder specific configuration
            CountImageDescriptionExtensionType(imgDesc, 'esds',  &count);
            if (count >= 1) {
                Handle imgDescExt = NewHandle(0);
                UInt8* buffer;
                int size;

                GetImageDescriptionExtension(imgDesc, &imgDescExt, 'esds', 1);

                ReadESDSDescExt(*imgDescExt, &buffer, &size, 1);
                magicCookie = [NSData dataWithBytes:buffer length:size];

                DisposeHandle(imgDescExt);
                
                return [magicCookie autorelease];
            }
        }
    }
    else if ([mediaType isEqualToString:QTMediaTypeSound]) {
        SoundDescriptionHandle sndDesc = (SoundDescriptionHandle) desc;
        
        AudioStreamBasicDescription asbd = {0};
        err = QTSoundDescriptionGetProperty(sndDesc, kQTPropertyClass_SoundDescription,
                                            kQTSoundDescriptionPropertyID_AudioStreamBasicDescription,
                                            sizeof(asbd), &asbd, NULL);
        require_noerr(err, bail);
        
        if (asbd.mFormatID == kAudioFormatMPEG4AAC) {
            // Get the magic cookie
            UInt32 cookieSize;
            void* cookie;
            QTSoundDescriptionGetPropertyInfo(sndDesc,
                                              kQTPropertyClass_SoundDescription,
                                              kQTSoundDescriptionPropertyID_MagicCookie,
                                              NULL, &cookieSize, NULL);
            cookie = malloc(cookieSize);
            QTSoundDescriptionGetProperty(sndDesc,
                                          kQTPropertyClass_SoundDescription,
                                          kQTSoundDescriptionPropertyID_MagicCookie,
                                          cookieSize, cookie, &cookieSize);
            // Extract DecoderSpecific info
            UInt8* buffer;
            int size;
            ReadESDSDescExt(cookie, &buffer, &size, 0);
            magicCookie = [NSData dataWithBytes:buffer length:size];

            free(cookie);
            free(buffer);

            return [magicCookie autorelease];

        }
        else if (asbd.mFormatID == kAudioFormatAC3 || asbd.mFormatID == 0x6D732000)
        {
            ByteCount           channelLayoutSize;
            AudioChannelLayout* channelLayout = NULL;
            err = QTSoundDescriptionGetPropertyInfo(sndDesc, kQTPropertyClass_SoundDescription,
                                                    kQTSoundDescriptionPropertyID_AudioChannelLayout,
                                                    NULL, &channelLayoutSize, NULL);
            require_noerr(err, bail);

            channelLayout = (AudioChannelLayout*)malloc(channelLayoutSize);

            err = QTSoundDescriptionGetProperty(sndDesc, kQTPropertyClass_SoundDescription,
                                                kQTSoundDescriptionPropertyID_AudioChannelLayout,
                                                channelLayoutSize, channelLayout, NULL);
            require_noerr(err, bail);

            UInt32 bitmapSize = sizeof(AudioChannelLayoutTag);
            UInt32 channelBitmap;
            AudioFormatGetProperty(kAudioFormatProperty_BitmapForLayoutTag,
                                   sizeof(AudioChannelLayoutTag), &channelLayout->mChannelLayoutTag,
                                   &bitmapSize, &channelBitmap);
            uint8_t fscod = 0;
            uint8_t bsid = 8;
            uint8_t bsmod = 0;
            uint8_t acmod = 7;
            uint8_t lfeon = (channelBitmap & kAudioChannelBit_LFEScreen) ? 1 : 0;
            uint8_t bit_rate_code = 15;

            switch (AudioChannelLayoutTag_GetNumberOfChannels(channelLayout->mChannelLayoutTag) - lfeon) {
                case 1:
                    acmod = 1;
                    break;
                case 2:
                    acmod = 2;
                    break;
                case 3:
                    if (channelBitmap & kAudioChannelBit_CenterSurround) acmod = 3;
                    else acmod = 4;
                    break;
                case 4:
                    if (channelBitmap & kAudioChannelBit_CenterSurround) acmod = 5;
                    else acmod = 6;
                    break;
                case 5:
                    acmod = 7;
                    break;
                default:
                    break;
            }

            if (asbd.mSampleRate == 48000) fscod = 0;
            else if (asbd.mSampleRate == 44100) fscod = 1;
            else if (asbd.mSampleRate == 32000) fscod = 2;
            else fscod = 3;

            NSMutableData *ac3Info = [[NSMutableData alloc] init];
            [ac3Info appendBytes:&fscod length:sizeof(uint64_t)];
            [ac3Info appendBytes:&bsid length:sizeof(uint64_t)];
            [ac3Info appendBytes:&bsmod length:sizeof(uint64_t)];
            [ac3Info appendBytes:&acmod length:sizeof(uint64_t)];
            [ac3Info appendBytes:&lfeon length:sizeof(uint64_t)];
            [ac3Info appendBytes:&bit_rate_code length:sizeof(uint64_t)];

            free(channelLayout);

            return [ac3Info autorelease];
        }
    }

bail:
    return nil;
}

- (void) fillMovieSampleBuffer: (id)sender
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    OSStatus err = noErr;

    NSInteger tracksNumber = [activeTracks count];
    NSInteger tracksDone = 0;

    MovTrackHelper * trackHelper;

    for (MP42Track * track in activeTracks) {
        if (track.trackDemuxerHelper == nil) {
            track.trackDemuxerHelper = [[MovTrackHelper alloc] init];
            
            Track qtcTrack = [[[sourceFile tracks] objectAtIndex:[track sourceId]] quickTimeTrack];
            Media media = GetTrackMedia(qtcTrack);
            
            trackHelper = track.trackDemuxerHelper;
            trackHelper->totalSampleNumber = GetMediaSampleCount(media);
        }
    }

    for (MP42Track * track in activeTracks) {
        Track qtcTrack = [[[sourceFile tracks] objectAtIndex:[track sourceId]] quickTimeTrack];
        Media media = GetTrackMedia(qtcTrack);

        // Create a QTSampleTable which contains all the informatio of the track samples.
        TimeValue64 sampleTableStartDecodeTime = 0;
        QTMutableSampleTableRef sampleTable = NULL;
        err = CopyMediaMutableSampleTable(media,
                                          0,
                                          &sampleTableStartDecodeTime,
                                          0,
                                          0,
                                          &sampleTable);
        require_noerr(err, bail);

        TimeValue64 minDisplayOffset = 0;
        err = QTSampleTableGetProperty(sampleTable,
                                       kQTPropertyClass_SampleTable,
                                       kQTSampleTablePropertyID_MinDisplayOffset,
                                       sizeof(TimeValue64),
                                       &minDisplayOffset,
                                       NULL);
        require_noerr(err, bail);

        trackHelper->minDisplayOffset = minDisplayOffset;

        SInt64 sampleIndex, sampleCount;
        sampleCount = QTSampleTableGetNumberOfSamples(sampleTable);

        for (sampleIndex = 1; sampleIndex <= sampleCount; sampleIndex++) {
            while ([samplesBuffer count] >= 200) {
                usleep(200);
            }

            TimeValue64 sampleDecodeTime = 0;
            ByteCount sampleDataSize = 0;
            MediaSampleFlags sampleFlags = 0;
            UInt8 *sampleData = NULL;
            TimeValue64 decodeDuration = QTSampleTableGetDecodeDuration(sampleTable, sampleIndex);
            TimeValue64 displayOffset = QTSampleTableGetDisplayOffset(sampleTable, sampleIndex);
            uint32_t dflags = 0;

            // Get the frame's data size and sample flags.  
            SampleNumToMediaDecodeTime( media, sampleIndex, &sampleDecodeTime, NULL);
            sampleDataSize = QTSampleTableGetDataSizePerSample(sampleTable, sampleIndex);
            sampleFlags = QTSampleTableGetSampleFlags(sampleTable, sampleIndex);
            dflags |= (sampleFlags & mediaSampleHasRedundantCoding) ? MP4_SDT_HAS_REDUNDANT_CODING : 0;
            dflags |= (sampleFlags & mediaSampleHasNoRedundantCoding) ? MP4_SDT_HAS_NO_REDUNDANT_CODING : 0;
            dflags |= (sampleFlags & mediaSampleIsDependedOnByOthers) ? MP4_SDT_HAS_DEPENDENTS : 0;
            dflags |= (sampleFlags & mediaSampleIsNotDependedOnByOthers) ? MP4_SDT_HAS_NO_DEPENDENTS : 0;
            dflags |= (sampleFlags & mediaSampleDependsOnOthers) ? MP4_SDT_IS_DEPENDENT : 0;
            dflags |= (sampleFlags & mediaSampleDoesNotDependOnOthers) ? MP4_SDT_IS_INDEPENDENT : 0;
            dflags |= (sampleFlags & mediaSampleEarlierDisplayTimesAllowed) ? MP4_SDT_EARLIER_DISPLAY_TIMES_ALLOWED : 0;

            // Load the frame.
            sampleData = malloc(sampleDataSize);
            GetMediaSample2(media, sampleData, sampleDataSize, NULL, sampleDecodeTime,
                            NULL, NULL, NULL, NULL, NULL, 1, NULL, NULL);

            trackHelper = track.trackDemuxerHelper;
            trackHelper->currentSampleId = trackHelper->currentSampleId + 1;
            trackHelper->currentTime = trackHelper->currentTime + decodeDuration;

            MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
            sample->sampleData = sampleData;
            sample->sampleSize = sampleDataSize;
            sample->sampleDuration = decodeDuration;
            sample->sampleOffset = displayOffset -minDisplayOffset;
            sample->sampleTimestamp = trackHelper->currentTime;
            sample->sampleIsSync = !(sampleFlags & mediaSampleNotSync);
            sample->sampleTrackId = track.Id;

            @synchronized(samplesBuffer) {
                [samplesBuffer addObject:sample];
                [sample release];
            }

            progress = ((trackHelper->currentSampleId / (CGFloat) trackHelper->totalSampleNumber ) * 100 / tracksNumber) +
            (tracksDone / (CGFloat) tracksNumber * 100);
        }

        tracksDone++;

        bail:
        QTSampleTableRelease(sampleTable);
    }

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
    for (MP42Track * track in activeTracks) {
        Track qtcTrack = [[[sourceFile tracks] objectAtIndex:[track sourceId]] quickTimeTrack];

        TimeValue editTrackStart, editTrackDuration;
        TimeValue64 editDisplayStart, trackDuration = 0;
        Fixed editDwell;

        MovTrackHelper * trackHelper;
        trackHelper = track.trackDemuxerHelper;

        // Find the first edit
        // Each edit has a starting track timestamp, a duration in track time, a starting display timestamp and a rate.
        GetTrackNextInterestingTime(qtcTrack, 
                                    nextTimeTrackEdit | nextTimeEdgeOK,
                                    0,
                                    fixed1,
                                    &editTrackStart,
                                    &editTrackDuration);

        while (editTrackDuration > 0) {
            editDisplayStart = TrackTimeToMediaDisplayTime(editTrackStart, qtcTrack);
            editTrackDuration = (editTrackDuration / (float)GetMovieTimeScale([sourceFile quickTimeMovie])) * MP4GetTimeScale(fileHandle);
            editDwell = GetTrackEditRate64(qtcTrack, editTrackStart);
            
            if (trackHelper->minDisplayOffset < 0 && editDisplayStart != -1)
                MP4AddTrackEdit(fileHandle, [track Id], MP4_INVALID_EDIT_ID, editDisplayStart -trackHelper->minDisplayOffset,
                                editTrackDuration, !Fix2X(editDwell));
            else
                MP4AddTrackEdit(fileHandle, [track Id], MP4_INVALID_EDIT_ID, editDisplayStart,
                                editTrackDuration, !Fix2X(editDwell));
            
            trackDuration += editTrackDuration;
            // Find the next edit
            GetTrackNextInterestingTime(qtcTrack,
                                        nextTimeTrackEdit,
                                        editTrackStart,
                                        fixed1,
                                        &editTrackStart,
                                        &editTrackDuration);
        }
        
        MP4SetTrackIntegerProperty(fileHandle, [track Id], "tkhd.duration", trackDuration);
    }
    
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

    [sourceFile release];

    [super dealloc];
}

@end
