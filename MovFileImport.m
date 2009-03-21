//
//  FileImport.m
//  Subler
//
//  Created by Damiano Galassi on 15/03/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MovFileImport.h"
#import <QuickTime/QuickTime.h>

@implementation MovFileImport

- (id)initWithDelegate:(id)del andFile: (NSString *)path
{
	if (self = [super initWithWindowNibName:@"FileImport"])
	{        
		delegate = del;
        filePath = path;
        sourceFile = [[QTMovie alloc] initWithFile:filePath error:nil];
        NSInteger i = [[sourceFile tracks] count];
        importCheckArray = [[NSMutableArray alloc] initWithCapacity:i];

        while (i) {
            [importCheckArray addObject: [NSNumber numberWithBool:YES]];
            i--;
        }
    }

	return self;
}

- (NSString*)summaryForTrack: (QTTrack *)track;
{
    NSString* result = @"";
    
    ImageDescriptionHandle idh;
    idh = (ImageDescriptionHandle)NewHandleClear(sizeof(ImageDescription));
    GetMediaSampleDescription([[track media] quickTimeMedia], 1,
                              (SampleDescriptionHandle)idh);
    
    NSString* mediaType = [track attributeForKey:QTTrackMediaTypeAttribute];
    if ([mediaType isEqualToString:QTMediaTypeVideo]) {
        CFStringRef s;
        if (noErr == ICMImageDescriptionGetProperty(idh,
                                                    kQTPropertyClass_ImageDescription,
                                                    kICMImageDescriptionPropertyID_SummaryString,
                                                    sizeof(CFStringRef), &s, 0)) {
            result = [NSString stringWithString:(NSString*)s];
            CFRelease(s);
        }
    }
    if ([mediaType isEqualToString:QTMediaTypeText]) {
        CFStringRef s;
        if (noErr == ICMImageDescriptionGetProperty(idh,
                                                    kQTPropertyClass_ImageDescription,
                                                    kICMImageDescriptionPropertyID_SummaryString,
                                                    sizeof(CFStringRef), &s, 0)) {
            result = [NSString stringWithString:(NSString*)s];
            CFRelease(s);
        }
    }
    else if ([mediaType isEqualToString:QTMediaTypeMPEG]) {
        NSRect rc = [[track attributeForKey:QTTrackBoundsAttribute] rectValue];
        NSString* name = [track attributeForKey:QTTrackDisplayNameAttribute];
        result = [NSString stringWithFormat:@"%@, %g x %g",
                  /*FIXME*/name, rc.size.width, rc.size.height];
    }
    else if ([mediaType isEqualToString:QTMediaTypeSound]) {
        // temporary impl. : how to get audio properties?
        CFStringRef s;
        if (noErr == ICMImageDescriptionGetProperty(idh,
                                                    kQTPropertyClass_ImageDescription,
                                                    kICMImageDescriptionPropertyID_SummaryString,
                                                    sizeof(CFStringRef), &s, 0)) {
            // remove strange contents after codec name.
            //NSRange range = [(NSString*)s rangeOfString:@", "];
            //result = [(NSString*)s substringToIndex:range.location];
            result = [NSString stringWithString:(NSString*)s];
            CFRelease(s);
        }
    }
    DisposeHandle((Handle)idh);
    return result;
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    if( !sourceFile )
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
    
    if( [tableColumn.identifier isEqualToString: @"check"] )
        return [importCheckArray objectAtIndex: rowIndex];

    if ([tableColumn.identifier isEqualToString:@"trackId"]) {
        return [track attributeForKey:QTTrackIDAttribute];
    }

    if ([tableColumn.identifier isEqualToString:@"trackName"])
        return [track attributeForKey:QTTrackDisplayNameAttribute];

    if ([tableColumn.identifier isEqualToString:@"trackInfo"]) {
        NSString *info = [track attributeForKey:QTTrackFormatSummaryAttribute];
        return [info substringToIndex: [info rangeOfString:@", "].location];
        //return [self summaryForTrack:track];
    }

    if ([tableColumn.identifier isEqualToString:@"trackDuration"]) {
        return QTStringFromTime([[track attributeForKey:QTTrackRangeAttribute] QTTimeRangeValue].duration);
    }
    if ([tableColumn.identifier isEqualToString:@"trackLanguage"])
        return nil; //track.language;

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
            MP42Track *newTrack;

            if ([mediaType isEqualToString:QTMediaTypeVideo])
                newTrack = [[MP42VideoTrack alloc] init];
            else if ([mediaType isEqualToString:QTMediaTypeSound])
                newTrack = [[MP42AudioTrack alloc] init];

            NSString *info = [track attributeForKey:QTTrackFormatSummaryAttribute];
            newTrack.format = [info substringToIndex: [info rangeOfString:@", "].location];
            newTrack.Id = i;//[[track attributeForKey:QTTrackIDAttribute] integerValue];
            newTrack.sourcePath = filePath;
            newTrack.name = [track attributeForKey:QTTrackDisplayNameAttribute];
            [tracks addObject:newTrack];
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
    [super dealloc];
}

@end
