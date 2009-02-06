//
//  ChapterViewController.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "ChapterViewController.h"


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
    if ([tableColumn.identifier isEqualToString:@"time"])
        return [NSString stringWithFormat:@"%d", rowIndex+1];
    
    if ([tableColumn.identifier isEqualToString:@"title"])
        return [track.chapters objectAtIndex:rowIndex];
    
    return nil;
}

@end
