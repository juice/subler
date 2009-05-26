//
//  MovieViewController.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

NSString *MetadataPBoardType = @"MetadataPBoardType";

#import "MovieViewController.h"

@implementation MetaDataTableView

- (void)keyDown:(NSEvent *)event
{
    id delegate = [self delegate];

    unichar key = [[event charactersIgnoringModifiers] characterAtIndex:0];
    if (key == NSEnterCharacter || key == NSCarriageReturnCharacter)
        [self editColumn:1 row:[self selectedRow] withEvent:nil select:YES];
    else if ((key == NSDeleteCharacter) && [delegate respondsToSelector:@selector(_deleteSelectionFromTableView:)]) {
        if ([self selectedRow] == -1)
            NSBeep();
        else
            [delegate _deleteSelectionFromTableView:self];
        return;
    }
    else
        [super keyDown:event];
}

- (void)delete:(id)sender
{
    if ([self selectedRow] == -1)
        return;
    else if ([[self delegate] respondsToSelector:@selector(_deleteSelectionFromTableView:)])
        [[self delegate] _deleteSelectionFromTableView:self];
}

- (IBAction) copy:(id)sender {
    if ([self selectedRow] == -1)
        return;
    else if ([[self delegate] respondsToSelector:@selector(_copySelectionFromTableView:)])
        [[self delegate] _copySelectionFromTableView:self];
}

- (IBAction) cut:(id)sender {
    if ([self selectedRow] == -1)
        return;
    else if ([[self delegate] respondsToSelector:@selector(_cutSelectionFromTableView:)])
        [[self delegate] _cutSelectionFromTableView:self];
}

- (IBAction) paste:(id)sender {
    if ([[self delegate] respondsToSelector:@selector(_pasteToTableView:)])
        [[self delegate] _pasteToTableView:self];
}

- (BOOL)pasteboardHasSupportedType {
    // has the pasteboard got a type we support?
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSString *bestType = [pb availableTypeFromArray:_pasteboardTypes];
    return (bestType != nil);
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    id delegate = [self delegate];
    SEL action = [item action];

    if (action == @selector(delete:))
        if ([self selectedRow] == -1 || ![delegate respondsToSelector:@selector(_deleteSelectionFromTableView:)])
            return NO;

    if (action == @selector(copy:))
        if ([self selectedRow] == -1 || ![delegate respondsToSelector:@selector(_copySelectionFromTableView:)])
            return NO;

    if (action == @selector(cut:))
        if ([self selectedRow] == -1 || ![delegate respondsToSelector:@selector(_cutSelectionFromTableView:)])
            return NO;

    if (action == @selector(paste:))
        if (![self pasteboardHasSupportedType] || ![delegate respondsToSelector:@selector(_pasteToTableView:)])
            return NO;

    return YES;
}

- (void) dealloc
{
    [_pasteboardTypes release];
    [super dealloc];
}

@synthesize _pasteboardTypes;

@end

@implementation MovieViewController

static NSInteger sortFunction (id ldict, id rdict, void *context) {
    NSComparisonResult rc;

    NSInteger right = [(NSArray*) context indexOfObject:rdict];
    NSInteger left = [(NSArray*) context indexOfObject:ldict];

    if (right < left)
        rc = NSOrderedDescending;
    else
        rc = NSOrderedAscending;

    return rc;
}

- (void)awakeFromNib
{
    tagsMenu = [[metadata writableMetaData] retain];
    for (id tag in tagsMenu)
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

    tabCol = [[[tagsTableView tableColumns] objectAtIndex:1] retain];

    tagsArray = [[[tags allKeys] sortedArrayUsingFunction:sortFunction context:tagsMenu] retain];

    [tagsTableView setDoubleAction:@selector(doubleClickAction:)];
    [tagsTableView setTarget:self];
    [tagsTableView set_pasteboardTypes:[NSArray arrayWithObject:MetadataPBoardType]];
}

- (void) setFile: (MP42File *)file
{
    metadata = file.metadata;
    tags = metadata.tagsDict;
}

- (IBAction) updateArtwork: (id) sender
{
    metadata.artwork = [imageView image];
    metadata.isEdited = YES;
    metadata.isArtworkEdited = YES;

    [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
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

- (IBAction) changecContentRating: (id) sender
{
    uint8_t tagName = [[sender selectedItem] tag];
    
    if (metadata.contentRating != tagName) {
        metadata.contentRating = tagName;
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

- (void) updateTagsArray
{
    [tagsArray autorelease];
    tagsArray = [[[tags allKeys] sortedArrayUsingFunction:sortFunction context:tagsMenu] retain];
}

- (IBAction) addTag: (id) sender
{
    NSString *tagName = [[sender selectedItem] title];

    if (![metadata.tagsDict valueForKey:tagName]) {
        [metadata.tagsDict setObject:@"" forKey:tagName];
        [self updateTagsArray];
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
        [tagsTableView reloadData];
    }
}

- (NSArray *) allSet
{
    return [metadata writableMetaData];
}

- (NSArray *) tvShowSet
{
    return [NSArray arrayWithObjects:  @"Name", @"Artist", @"Album Artist", @"Album", @"Comments", @"Genre", @"Release Date", @"Track #", @"Disk #", @"TV Show", @"TV Episode #", @"TV Network", @"TV Episode ID", @"TV Season", @"Genre", @"Description", @"Long Description", nil];
}

- (NSArray *) movieSet
{
    return [NSArray arrayWithObjects:  @"Name", @"Artist", @"Album Artist", @"Album", @"Comments", @"Genre", @"Release Date", @"Track #", @"Disk #", @"Tempo", @"Genre", @"Description", @"Long Description", @"Lyrics", @"Copyright", nil];
}

- (IBAction) addMetadataSet: (id)sender
{
    NSArray *metadataKeys = nil;
    if ([sender tag] == 0)
        metadataKeys = [self allSet];
    else if ([sender tag] == 1)
        metadataKeys = [self movieSet];
    else if ([sender tag] == 2)
        metadataKeys = [self tvShowSet];

    for (NSString *key in metadataKeys) {
        if (![[metadata tagsDict] valueForKey:key])
            [metadata setTag:@"" forKey:key];
    }

    [self updateTagsArray];
    [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
    [tagsTableView reloadData]; 
}

/* NSTableView additions for copy & paste and more */

- (IBAction)doubleClickAction:(id)sender
{
    // make sure they clicked a real cell and not a header or empty row
    if ([sender clickedRow] != -1 && [sender clickedColumn] == 1) { 
        // edit the cell
        [sender editColumn:[sender clickedColumn] 
                       row:[sender clickedRow]
                 withEvent:nil
                    select:YES];
    }
}

- (void)_deleteSelectionFromTableView:(NSTableView *)tableView;
{
    [self removeTag:tableView];
}

- (void)_copySelectionFromTableView:(NSTableView *)tableView;
{
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSIndexSet *rowIndexes = [tableView selectedRowIndexes];
    NSUInteger current_index = [rowIndexes lastIndex];
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    NSString *string = @"";

    while (current_index != NSNotFound) {
        NSString *tagName = [tagsArray objectAtIndex:current_index];
        NSString *tagValue = [tags objectForKey:tagName];
        string = [string stringByAppendingFormat:@"%@: %@\n",tagName, tagValue];
        [data setValue:tagValue forKey:tagName];

        current_index = [rowIndexes indexLessThanIndex: current_index];
    }

    NSArray *types = [NSArray arrayWithObjects:
                      MetadataPBoardType, NSStringPboardType, nil];
    [pb declareTypes:types owner:nil];
    [pb setString:string forType: NSStringPboardType];
    [pb setData:[NSArchiver archivedDataWithRootObject:data] forType:MetadataPBoardType];
    [data release];
}

- (void)_cutSelectionFromTableView:(NSTableView *)tableView;
{
    [self _copySelectionFromTableView:tableView];
    [self removeTag:tableView];
}

- (void)_pasteToTableView:(NSTableView *)tableView
{
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSData *archivedData = [pb dataForType:MetadataPBoardType];
    NSMutableDictionary *data = [NSUnarchiver unarchiveObjectWithData:archivedData];
    NSArray *metadataKeys = [data allKeys];

    for (NSString *key in metadataKeys) {
        [metadata setTag:[data valueForKey:key] forKey:key];
    }

    [self updateTagsArray];
    [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
    [tagsTableView reloadData]; 
}

- (IBAction) removeTag: (id) sender {
    NSIndexSet *rowIndexes = [tagsTableView selectedRowIndexes];
    NSUInteger current_index = [rowIndexes lastIndex];

    while (current_index != NSNotFound) {
        if (current_index != -1 && [tagsTableView editedRow] == -1) {
            NSString *tagName = [tagsArray objectAtIndex:current_index];
            [metadata removeTagForKey:tagName];
            [self updateTagsArray];

            [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
        }
        current_index = [rowIndexes indexLessThanIndex: current_index];
    }
    [tagsTableView reloadData];
}

- (NSAttributedString *) boldString: (NSString *) string
{
    return [[[NSAttributedString alloc] initWithString:string attributes:detailBoldAttr] autorelease];
}

/* TableView delegate methods */

- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    return [[metadata tagsDict] count];
}

- (id) tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
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
    NSString *tagName = [tagsArray objectAtIndex:rowIndex];

    if ([tableColumn.identifier isEqualToString:@"value"])
        if ([metadata setTag:anObject forKey:tagName]) {
            [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];

            [tagsTableView noteHeightOfRowsWithIndexesChanged:
             [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(0, [tagsTableView numberOfRows])]];
        }
}

- (CGFloat) tableView: (NSTableView *) tableView
          heightOfRow: (NSInteger) rowIndex
{
	NSRect r = NSMakeRect(0,0,width,1000.0);
	NSTextFieldCell *cell = [tabCol dataCellForRow:rowIndex];	
	[cell setObjectValue:[tags objectForKey:[tagsArray objectAtIndex:rowIndex]]];
	CGFloat height = [cell cellSizeForBounds:r].height; // Slow
	if (height <= 0)
        height = 14.0; // Ensure miniumum height is 14.0

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
    width = [tabCol width];
    [tagsTableView noteHeightOfRowsWithIndexesChanged:
     [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(0, [tagsTableView numberOfRows])]];
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
    [tagsArray release];
    [tagsMenu release];
    [tabCol release];
    [detailBoldAttr release];
    [super dealloc];
}

@end
