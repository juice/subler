//
//  MovieViewController.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MovieViewController.h"


@implementation MovieViewController

- (void) setFile: (MP4FileWrapper *)file
{
    mp4File = file;
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    NSUInteger i = [[[mp4File metadata] tagsDict] count];
    return i;
}

- (id) tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
    NSDictionary *tags = [[mp4File metadata] tagsDict];
    NSArray *tagsArray = [tags allKeys];

    if ([tableColumn.identifier isEqualToString:@"name"])
        return [tagsArray objectAtIndex:rowIndex];
    
    if ([tableColumn.identifier isEqualToString:@"value"])
        return [tags objectForKey:[tagsArray objectAtIndex:rowIndex]];
    
    return nil;
}

@end
