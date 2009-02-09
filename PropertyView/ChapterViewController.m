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

- (void) setFile: (MP4FileWrapper *)file andTrack:(MP4ChapterTrackWrapper *) chapterTrack
{
    mp4File = file;
    track = chapterTrack;
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    return [track.chapters count];
}

- (id) tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
    SBChapter * chapter = [track.chapters objectAtIndex:rowIndex];
    if ([tableColumn.identifier isEqualToString:@"time"])
        return SMPTEStringFromTime(chapter.duration, 1000);  

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

@end
