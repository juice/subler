//
//  FileImport.m
//  Subler
//
//  Created by Damiano Galassi on 15/03/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MovFileImport.h"
#if !__LP64__
    #import <QuickTime/QuickTime.h>
#endif
#include "lang.h"

extern NSString * const QTTrackLanguageAttribute;	// NSNumber (long)

@interface QTMovie(IdlingAdditions)
 -(QTTime)maxTimeLoaded;
@end

@implementation MovFileImport

-(void) movieLoaded
{
    NSArray *tracks = [sourceFile tracks];
    importCheckArray = [[NSMutableArray alloc] initWithCapacity:[tracks count]];

    NSInteger i;
    for (i = 0; i < [tracks count]; i++) {
        [importCheckArray addObject: [NSNumber numberWithBool:YES]];
        QTTrack *track = [tracks objectAtIndex:i];
        if ([[track attributeForKey:QTTrackIsChapterTrackAttribute] boolValue])
            chapterTrackId = [[track attributeForKey:QTTrackIDAttribute] integerValue];
    }

    [addTracksButton setEnabled:YES];
    [loadProgressBar setHidden:YES];
}

- (id)initWithDelegate:(id)del andFile: (NSString *)path
{
	if (self = [super initWithWindowNibName:@"FileImport"]) {   
        delegate = del;
        filePath = [path retain];
    }
	return self;
}

- (void)awakeFromNib 
{
    NSURL *movieUrl = [NSURL fileURLWithPath:filePath];
    sourceFile = [[QTMovie alloc] initWithURL:movieUrl error:nil];
    
    if ([[sourceFile attributeForKey:QTMovieLoadStateAttribute] longValue] >= QTMovieLoadStateComplete) {
        [self movieLoaded];
    }
    else {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(loadStateChanged:) 
                                                     name:QTMovieLoadStateDidChangeNotification 
                                                   object:sourceFile];
        
        loadTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                     target:self
                                                   selector:@selector(updateUI:)
                                                   userInfo:nil
                                                    repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:loadTimer
                                     forMode:NSDefaultRunLoopMode];
        [loadProgressBar setIndeterminate:NO];
        [loadProgressBar setHidden:NO];
    }
}

-(void)loadStateChanged:(NSNotification *)notification
{
    long loadState = [[sourceFile attributeForKey:QTMovieLoadStateAttribute] longValue];

    if (loadState >= QTMovieLoadStateComplete)
    {
        [self movieLoaded];

        [loadTimer invalidate];
        [tableView reloadData];
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
    [loadProgressBar setDoubleValue:[self _percentLoaded] *100];
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

- (NSString*)langForTrack: (QTTrack *)track;
{
    return [NSString stringWithUTF8String:lang_for_qtcode(
                            [[track attributeForKey:QTTrackLanguageAttribute] longValue])->eng_name];
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    if( !sourceFile || ([[sourceFile attributeForKey:QTMovieLoadStateAttribute] longValue] < QTMovieLoadStateComplete))
        return 0;

    return [[sourceFile tracks] count];
}

- (id) tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
    QTTrack *track = [[sourceFile tracks] objectAtIndex:rowIndex];

    if (!track)
        return nil;
    
    if ([tableColumn.identifier isEqualToString: @"check"] )
        return [importCheckArray objectAtIndex: rowIndex];
    
    if ([tableColumn.identifier isEqualToString:@"trackId"])
        return [track attributeForKey:QTTrackIDAttribute];
    
    if ([tableColumn.identifier isEqualToString:@"trackName"])
        if ([[track attributeForKey:QTTrackIDAttribute] integerValue] == chapterTrackId)
            return @"Chapter Track";
        else
            return [track attributeForKey:QTTrackDisplayNameAttribute];
    
    if ([tableColumn.identifier isEqualToString:@"trackInfo"])
        return [self formatForTrack:track];
    
    if ([tableColumn.identifier isEqualToString:@"trackDuration"])
        return QTStringFromTime([[track attributeForKey:QTTrackRangeAttribute] QTTimeRangeValue].duration);
    
    if ([tableColumn.identifier isEqualToString:@"trackLanguage"])
        return [self langForTrack:track];

    return nil;
}

- (void) tableView: (NSTableView *) tableView 
    setObjectValue: (id) anObject 
    forTableColumn: (NSTableColumn *) tableColumn 
               row: (NSInteger) rowIndex
{
    if ([tableColumn.identifier isEqualToString: @"check"])
        [importCheckArray replaceObjectAtIndex:rowIndex withObject:anObject];
}

- (IBAction) closeWindow: (id) sender
{
    if (loadTimer)
        [loadTimer invalidate];
    [sourceFile release];
    sourceFile = nil;
    if ([delegate respondsToSelector:@selector(importDone:)]) 
        [delegate importDone:nil];
}

- (IBAction) addTracks: (id) sender
{
    NSMutableArray *tracks = [[NSMutableArray alloc] init];
    NSInteger i;

    for (i = 0; i < [[sourceFile tracks] count]; i++) {
        if ([[importCheckArray objectAtIndex: i] boolValue]) {
            QTTrack *track = [[sourceFile tracks] objectAtIndex:i];
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

                    NSSize dimesion = [track apertureModeDimensionsForMode:QTMovieApertureModeClean];
                    [(MP42VideoTrack*)newTrack setTrackWidth: dimesion.width];
                    [(MP42VideoTrack*)newTrack setTrackHeight: dimesion.height];
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

            if (newTrack) {
                newTrack.format = [self formatForTrack:track];
                newTrack.Id = i;
                newTrack.sourcePath = filePath;
                newTrack.sourceFileHandle = sourceFile;
                newTrack.sourceInputType = MP42SourceTypeQuickTime;
                newTrack.name = [track attributeForKey:QTTrackDisplayNameAttribute];
                newTrack.language = [self langForTrack:track];
                [tracks addObject:newTrack];
                [newTrack release];
            }
        }
    }

    if ([delegate respondsToSelector:@selector(importDone:)]) 
        [delegate importDone:tracks];

    [tracks release];
}

- (void) dealloc
{
    [sourceFile release];
    [importCheckArray release];
    [filePath release];
    [super dealloc];
}

@end
