//
//  MP42MkvFileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "MP42MovImporter.h"
#if !__LP64__
#import <QuickTime/QuickTime.h>
#endif
#include "lang.h"
#import "MP42File.h"

extern NSString * const QTTrackLanguageAttribute;	// NSNumber (long)

@interface QTMovie(IdlingAdditions)
-(QTTime)maxTimeLoaded;
@end

@interface MP42MovImporter(Private)
    -(void) movieLoaded;
    -(NSString*)formatForTrack: (QTTrack *)track;
    -(NSString*)langForTrack: (QTTrack *)track;
@end

@implementation MP42MovImporter

- (id)initWithDelegate:(id)del andFile:(NSString *)fileUrl
{
    if (self = [super init]) {
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

#if !__LP64__
#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_6
    if([sourceFile hasChapters]) {
        long    myCount;
        long    myTrackCount = GetMovieTrackCount([sourceFile quickTimeMovie]);
        Track   myTrack = NULL;
        Track   myChapTrack = NULL;
        
        for (myCount = 1; myCount <= myTrackCount; myCount++) {
            myTrack = GetMovieIndTrack([sourceFile quickTimeMovie], myCount);
            if (GetTrackEnabled(myTrack))
                myChapTrack = GetTrackReference(myTrack, kTrackReferenceChapterList, 1);
            if (myChapTrack != NULL)
                chapterTrackId = GetTrackID(myChapTrack);
            break;
        }
    }
#endif
#endif

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
            newTrack.sourceInputType = MP42SourceTypeQuickTime;
            newTrack.name = [track attributeForKey:QTTrackDisplayNameAttribute];
            newTrack.language = [self langForTrack:track];
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

- (void) dealloc
{
	[file release];
    [tracksArray release];

    [super dealloc];
}

@end
