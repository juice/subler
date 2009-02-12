//
//  ChapterViewController.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "ChapterViewController.h"
#import "MP4Utilities.h"

@implementation ChapterViewController

- (void) awakeFromNib
{
    NSMutableParagraphStyle * ps = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [ps setHeadIndent: -10.0];
    [ps setAlignment:NSRightTextAlignment];
    
    detailBoldAttr = [[NSDictionary dictionaryWithObjectsAndKeys:
                       [NSFont boldSystemFontOfSize:11.0], NSFontAttributeName,
                       ps, NSParagraphStyleAttributeName,
                       [NSColor grayColor], NSForegroundColorAttributeName,
                       nil] retain];
}

- (void) setFile: (MP4FileWrapper *)file andTrack:(MP4ChapterTrackWrapper *) chapterTrack
{
    mp4File = file;
    track = chapterTrack;
}

- (NSAttributedString *) boldString: (NSString *) string
{
    return [[[NSAttributedString alloc] initWithString:string attributes:detailBoldAttr] autorelease];
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    return [track.chapters count];
}

- (id)              tableView: (NSTableView *) tableView 
    objectValueForTableColumn: (NSTableColumn *) tableColumn 
                          row: (NSInteger) rowIndex
{
    SBChapter * chapter = [track.chapters objectAtIndex:rowIndex];
    if ([tableColumn.identifier isEqualToString:@"time"])
        return [self boldString:SMPTEStringFromTime(chapter.duration, 1000)];  

    if ([tableColumn.identifier isEqualToString:@"title"])
        return chapter.title;
    
    return nil;
}

- (void) tableView: (NSTableView *) tableView 
    setObjectValue: (id) anObject 
    forTableColumn: (NSTableColumn *) tableColumn 
               row: (NSInteger) rowIndex
{
    SBChapter * chapter = [track.chapters objectAtIndex:rowIndex];

    if ([tableColumn.identifier isEqualToString:@"title"]) {
        if (![chapter.title isEqualToString:anObject]) {
            chapter.title = anObject;
            track.hasDataChanged = YES;
            [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
        }
    }
}

- (void) dealloc
{
    [detailBoldAttr release];
    [super dealloc];
}

@end
