//
//  MovieViewController.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MovieViewController.h"


@implementation MovieViewController

- (void) awakeFromNib
{
    NSArray *tags = [NSArray arrayWithObjects:  @"Name", @"Artist", @"Album", @"Date", @"Genre", @"Composer", @"Grouping", @"Comments" , @"Description", nil];
    id tag;
    for (tag in tags)
        [tagList addItemWithTitle:tag];
}

- (void) setFile: (MP4FileWrapper *)file
{
    mp4File = file;
}

- (IBAction) addTag: (id) sender
{
    NSString *tagName = [[sender selectedItem] title];

    if (![mp4File.metadata.tagsDict valueForKey:tagName]) {
        [mp4File.metadata.tagsDict setObject:@"Empty" forKey:tagName];
        [tableView reloadData];
    }
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

- (void) tableView: (NSTableView *) tableView 
    setObjectValue: (id) anObject 
    forTableColumn: (NSTableColumn *) tableColumn 
               row: (NSInteger) rowIndex
{
    NSDictionary *tags = [[mp4File metadata] tagsDict];
    NSArray *tagsArray = [tags allKeys];
    
    NSString *tagName = [tagsArray objectAtIndex:rowIndex];
    
    if ([tableColumn.identifier isEqualToString:@"value"]) {
        if (![[tags valueForKey:tagName] isEqualToString:anObject]) {
            [tags setValue:anObject forKey:tagName];
            //[self updateChangeCount:NSChangeDone];
        }
    }
}

@end
