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
    NSArray *tags = [NSArray arrayWithObjects:  @" Name", @"Artist", @"Album Artist", @"Album", @"Grouping", @"Composer", @"Comments", @"Genre", @"Release Date", @"Track #", @"Disk #", @"Tempo", @"TV Show", @"TV Episode #", @"TV Network", @"TV Episode ID", @"TV Season", @"TV Episode", @"Genre", @"Description", @"Long Description", @"Lyrics", @"Copyright", @"Encoding Tool", @"Encoded By", @"cnID", nil];
    id tag;
    for (tag in tags)
        [tagList addItemWithTitle:tag];

    NSMutableParagraphStyle * ps = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [ps setHeadIndent: -10.0];
    [ps setAlignment:NSRightTextAlignment];
    
    detailBoldAttr = [[NSDictionary dictionaryWithObjectsAndKeys:
                      [NSFont boldSystemFontOfSize:11.0], NSFontAttributeName,
                      ps, NSParagraphStyleAttributeName,
                      [NSColor grayColor], NSForegroundColorAttributeName,
                       nil] retain];

    [imageView setImage:[metadata artwork]];

    [mediaKind selectItemWithTag:metadata.mediaKind];
    [contentRating selectItemWithTag:metadata.contentRating];
    [hdVideo setState:metadata.hdVideo];
    [gapless setState:metadata.gapless];
}

- (void) setFile: (MP42File *)file
{
    metadata = file.metadata;
}

- (IBAction) addTag: (id) sender
{
    NSString *tagName = [[sender selectedItem] title];

    if (![metadata.tagsDict valueForKey:tagName]) {
        [metadata.tagsDict setObject:@"Empty" forKey:tagName];
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
        [tagsTableView reloadData];
    }
}

- (IBAction) updateArtwork: (id) sender
{
    metadata.artwork = [imageView image];
    [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
    metadata.isEdited = YES;
    metadata.isArtworkEdited = YES;

}

- (IBAction) changeMediaKind: (id) sender
{
    uint8_t tagName = [[sender selectedItem] tag];

    if (metadata.mediaKind != tagName) {
        metadata.mediaKind = tagName;
        metadata.isEdited = YES;
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
    }
}

- (IBAction) changeGapless: (id) sender
{
    uint8_t newValue = [sender state];

    if (metadata.gapless != newValue) {
        metadata.gapless = newValue;
        metadata.isEdited = YES;
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
    }
}

- (IBAction) changehdVideo: (id) sender
{
    uint8_t newValue = [sender state];

    if (metadata.hdVideo != newValue) {
        metadata.hdVideo = newValue;
        metadata.isEdited = YES;
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
    }
}

- (IBAction) removeTag: (id) sender {
    NSInteger rowIndex = [tagsTableView selectedRow];
    if (rowIndex != -1) {
        NSDictionary *tags = [metadata tagsDict];
        NSArray *tagsArray = [[tags allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

        NSString *tagName = [tagsArray objectAtIndex:rowIndex];
        [metadata.tagsDict removeObjectForKey:tagName];
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
        metadata.isEdited = YES;
        [tagsTableView reloadData];
    }
}

- (NSAttributedString *) boldString: (NSString *) string
{
    return [[[NSAttributedString alloc] initWithString:string attributes:detailBoldAttr] autorelease];
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    return [[metadata tagsDict] count];
}

- (id) tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
    NSDictionary *tags = [metadata tagsDict];
    NSArray *tagsArray = [[tags allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

    if ([tableColumn.identifier isEqualToString:@"name"])
        return [self boldString:[tagsArray objectAtIndex:rowIndex]];

    if ([tableColumn.identifier isEqualToString:@"value"])
        return [tags objectForKey:[tagsArray objectAtIndex:rowIndex]];

    return nil;
}

- (void) tableView: (NSTableView *) tableView 
    setObjectValue: (id) anObject 
    forTableColumn: (NSTableColumn *) tableColumn 
               row: (NSInteger) rowIndex
{
    NSDictionary *tags = [metadata tagsDict];
    NSArray *tagsArray =  [[tags allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

    NSString *tagName = [tagsArray objectAtIndex:rowIndex];

    if ([tableColumn.identifier isEqualToString:@"value"]) {
        if (![[tags valueForKey:tagName] isEqualToString:anObject]) {
            [tags setValue:anObject forKey:tagName];
            metadata.isEdited = YES;
            [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
        }
    }
}

- (CGFloat) tableView: (NSTableView *) tableView
          heightOfRow: (NSInteger) rowIndex
{
    NSDictionary *tags = [metadata tagsDict];
    NSArray *tagsArray = [[tags allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

	// Get column you want - first in this case:
	NSTableColumn *tabCol = [[tableView tableColumns] objectAtIndex:1];
	CGFloat width = [tabCol width];
	NSRect r = NSMakeRect(0,0,width,1000.0);
	NSCell *cell = [tabCol dataCellForRow:rowIndex];	
	NSString *content = [tags objectForKey:[tagsArray objectAtIndex:rowIndex]];	// or however you want to get the string
	[cell setObjectValue:content];
	CGFloat height = [cell cellSizeForBounds:r].height;
	if (height <= 0) height = 14.0;	// Ensure miniumum height is 14.0
    
	return height;
}

- (NSString *) tableView: (NSTableView *) aTableView 
          toolTipForCell: (NSCell *) aCell 
                    rect: (NSRectPointer) rect 
             tableColumn: (NSTableColumn *) aTableColumn
                     row: (NSInteger) row
           mouseLocation: (NSPoint) mouseLocation
{
    return nil;
}

- (void)tableViewColumnDidResize: (NSNotification* )notification
{
    [tagsTableView reloadData];
}

- (void)textDidEndEditing:(NSNotification *)aNotification
{
    NSLog(@"lalala");
    [tagsTableView reloadData];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    if ([tagsTableView selectedRow] != -1)
        [removeTag setEnabled:YES];
    else
        [removeTag setEnabled:NO];
}

- (void) dealloc
{
    [detailBoldAttr release];
    [super dealloc];
}

@end
