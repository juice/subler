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
    NSArray *tags = [NSArray arrayWithObjects:  @" Name", @"Artist", @"Album Artist", @"Album", @"Grouping", @"Composer", @"Comments", @"Genre", @"Date", @"Track #", @"Disk #", @"TV Show", @"TV Episode", @"TV Network", @"TV Episode ID", @"TV Season", @"TV Episode", @"Genre", @"Description", @"Long Description", @"Lyrics", @"Copyright", @"Encoding Tool", @"Encoded By", @"cnID", nil];
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
    
    [imageView setImage:[mp4File.metadata artwork]];
    
    [mediaKind selectItemWithTag:[mp4File.metadata mediaKind]];
    [contentRating selectItemWithTag:[mp4File.metadata contentRating]];
    [hdVideo setState:[mp4File.metadata hdVideo]];
    [gapless setState:[mp4File.metadata gapless]];
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
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
        [tagsTableView reloadData];
    }
}

- (IBAction) changeMediaKind: (id) sender
{
    uint8_t tagName = [[sender selectedItem] tag];
    
    if (mp4File.metadata.mediaKind != tagName) {
        mp4File.metadata.mediaKind = tagName;
        mp4File.metadata.edited = YES;
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
    }
}

- (IBAction) changeGapless: (id) sender
{
    uint8_t newValue = [sender state];

    if (mp4File.metadata.gapless != newValue) {
        mp4File.metadata.gapless = newValue;
        mp4File.metadata.edited = YES;
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
    }
}

- (IBAction) changehdVideo: (id) sender
{
    uint8_t newValue = [sender state];
    
    if (mp4File.metadata.hdVideo != newValue) {
        mp4File.metadata.hdVideo = newValue;
        mp4File.metadata.edited = YES;
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
    }
}

- (IBAction) removeTag: (id) sender {
    NSInteger rowIndex = [tagsTableView selectedRow];
    if (rowIndex != -1) {
        NSDictionary *tags = [[mp4File metadata] tagsDict];
        NSArray *tagsArray = [[tags allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

        NSString *tagName = [tagsArray objectAtIndex:rowIndex];
        [mp4File.metadata.tagsDict removeObjectForKey:tagName];
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
        mp4File.metadata.edited = YES;
        [tagsTableView reloadData];
    }
}

- (NSAttributedString *) boldString: (NSString *) string
{
    return [[[NSAttributedString alloc] initWithString:string attributes:detailBoldAttr] autorelease];
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    return [[[mp4File metadata] tagsDict] count];
}

- (id) tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
    NSDictionary *tags = [[mp4File metadata] tagsDict];
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
    NSDictionary *tags = [[mp4File metadata] tagsDict];
    NSArray *tagsArray =  [[tags allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

    NSString *tagName = [tagsArray objectAtIndex:rowIndex];

    if ([tableColumn.identifier isEqualToString:@"value"]) {
        if (![[tags valueForKey:tagName] isEqualToString:anObject]) {
            [tags setValue:anObject forKey:tagName];
            mp4File.metadata.edited = YES;
            [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
        }
    }
}

- (CGFloat) tableView: (NSTableView *) tableView
          heightOfRow: (NSInteger) rowIndex
{
    NSDictionary *tags = [[mp4File metadata] tagsDict];
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
