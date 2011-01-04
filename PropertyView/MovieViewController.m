//
//  MovieViewController.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

NSString *MetadataPBoardType = @"MetadataPBoardType";

#import "MovieViewController.h"
#import "SBTableView.h"
#import "SBPresetManager.h"

@implementation MovieViewController

static NSInteger sortFunction (id ldict, id rdict, void *context)
{
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
    tagsMenu = [[metadata writableMetadata] retain];
    for (id tag in tagsMenu)
        [tagList addItemWithTitle:tag];

    ratingCell = [[NSPopUpButtonCell alloc] init];
    [ratingCell setAutoenablesItems:NO];
    [ratingCell setFont:[NSFont systemFontOfSize:11]];
    [ratingCell setControlSize:NSSmallControlSize];
    [ratingCell setBordered:NO];
    for (NSString *rating in [metadata availableRatings]) {
        if ([rating length]) {
            NSMenuItem *item;
            if ([rating hasPrefix:@"--"]) {
                item = [[[NSMenuItem alloc] initWithTitle:[rating substringFromIndex:3] action:NULL keyEquivalent:@""] autorelease];
                [item setEnabled:NO];
                [[ratingCell menu] addItem:item];
            }
            else {
                item = [[[NSMenuItem alloc] initWithTitle:rating action:NULL keyEquivalent:@""] autorelease];
                [item setIndentationLevel:1];
                [[ratingCell menu] addItem:item];
            }
        }
        else
            [[ratingCell menu] addItem:[NSMenuItem separatorItem]];
    }

    genreCell = [[NSComboBoxCell alloc] init];
    [genreCell setCompletes:YES];
    [genreCell setFont:[NSFont systemFontOfSize:11]];
    [genreCell setDrawsBackground:NO];
    [genreCell setBezeled:NO];
    [genreCell setButtonBordered:NO];
    [genreCell setControlSize:NSSmallControlSize];
    [genreCell setIntercellSpacing:NSMakeSize(1.0, 1.0)];
    [genreCell setEditable:YES];
    [genreCell addItemsWithObjectValues:[metadata availableGenres]];

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

    tagsArray = [[[tags allKeys] sortedArrayUsingFunction:sortFunction context:[metadata availableMetadata]] retain];

    [tagsTableView setDoubleAction:@selector(doubleClickAction:)];
    [tagsTableView setTarget:self];
    [tagsTableView set_pasteboardTypes:[NSArray arrayWithObject:MetadataPBoardType]];
    
    dct = [[NSMutableDictionary alloc] init];
}

- (void) setFile: (MP42File *)file
{
    metadata = file.metadata;
    tags = metadata.tagsDict;
}

- (void) updateTagsArray
{
    [tagsArray autorelease];
    tagsArray = [[[tags allKeys] sortedArrayUsingFunction:sortFunction context:[metadata availableMetadata]] retain];
}

- (void) add:(NSDictionary *) data
{
    NSArray *metadataKeys = [data allKeys];

    for (NSString *key in metadataKeys) {
        [metadata setTag:[data valueForKey:key] forKey:key];
    }
    NSUndoManager *undo = [[self view] undoManager];
    [[undo prepareWithInvocationTarget:self] remove:data];

    if (![undo isUndoing]) {
        [undo setActionName:@"Insert"];
    }

    [self updateTagsArray];
    [tagsTableView reloadData];
}

- (void) remove:(NSDictionary *) data
{
    NSArray *metadataKeys = [data allKeys];

    for (NSString *key in metadataKeys) {
        [metadata removeTagForKey:key];
    }
    NSUndoManager *undo = [[self view] undoManager];
    [[undo prepareWithInvocationTarget:self] add:data];

    if (![undo isUndoing]) {
        [undo setActionName:@"Delete"];
    }

    [self updateTagsArray];
    [tagsTableView reloadData];
}

- (IBAction) addTag: (id) sender
{
    NSString *tagName = [[sender selectedItem] title];

    if (![metadata.tagsDict valueForKey:tagName])
        [self add:[NSDictionary dictionaryWithObject:@"" forKey:tagName]];
}

- (IBAction) removeTag: (id) sender {
    NSIndexSet *rowIndexes = [tagsTableView selectedRowIndexes];
    NSUInteger current_index = [rowIndexes lastIndex];
    NSMutableDictionary *tagDict = [[[NSMutableDictionary alloc] init] autorelease];

    while (current_index != NSNotFound) {
        if ([tagsTableView editedRow] == -1) {
            NSString *tagName = [tagsArray objectAtIndex:current_index];
            [tagDict setObject:[metadata.tagsDict valueForKey:tagName] forKey:tagName];
        }
        current_index = [rowIndexes indexLessThanIndex: current_index];
    }
    [self remove:tagDict];
}

- (void) updateMetadata:(id)value forKey:(NSString *)key
{
    NSString *oldValue = [[[metadata tagsDict] valueForKey:key] retain];

    if ([metadata setTag:value forKey:key]) {

        [tagsTableView noteHeightOfRowsWithIndexesChanged:
            [NSIndexSet indexSetWithIndexesInRange: NSMakeRange(0, [tagsTableView numberOfRows])]];

        NSUndoManager *undo = [[self view] undoManager];
        [[undo prepareWithInvocationTarget:self] updateMetadata:oldValue
                                                      forKey:key];
        if (![undo isUndoing]) {
            [undo setActionName:@"Editing"];
        }
    }
    [oldValue release];
}

- (NSArray *) allSet
{
    return [metadata writableMetadata];
}

- (NSArray *) tvShowSet
{
    return [NSArray arrayWithObjects:  @"Name", @"Artist", @"Album", @"Release Date", @"Track #", @"Disk #", @"TV Show", @"TV Episode #", @"TV Network", @"TV Episode ID", @"TV Season", @"Genre", @"Description", @"Long Description", nil];
}

- (NSArray *) movieSet
{
    return [NSArray arrayWithObjects:  @"Name", @"Artist", @"Album", @"Genre", @"Release Date", @"Track #", @"Disk #", @"Cast", @"Director", @"Screenwriters", @"Genre", @"Description", @"Long Description", @"Rating", @"Copyright", nil];
}

- (IBAction) addMetadataSet: (id)sender
{
    NSArray *metadataKeys = nil;
    if ([sender tag] == 0)
        metadataKeys = [self allSet];
    else if ([sender tag] == 1) {
        metadataKeys = [self movieSet];
        metadata.mediaKind = 9;
        [mediaKind selectItemWithTag:metadata.mediaKind];
    }
    else if ([sender tag] == 2) {
        metadataKeys = [self tvShowSet];
        metadata.mediaKind = 10;
        [mediaKind selectItemWithTag:metadata.mediaKind];
    }

    NSMutableDictionary *tagDict = [[[NSMutableDictionary alloc] init] autorelease];
    for (NSString *key in metadataKeys) {
        if (![[metadata tagsDict] valueForKey:key])
            [tagDict setValue:@"" forKey:key];
    }

    [self add:tagDict];
}

- (IBAction) saveSet: (id)sender
{
    SBPresetManager *presetManager = [SBPresetManager sharedManager];
    [presetManager newSetFromExistingMetadata: metadata];

    NSLog(@"lalala");
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

    [self add:data];
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

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSCell *cell = nil;
    NSString *tagName = nil;
    if (tableColumn != nil)
        tagName= [tagsArray objectAtIndex:row];

    if ([tableColumn.identifier isEqualToString:@"name"]) {
        cell = [tableColumn dataCell];
    }
    else if ([tableColumn.identifier isEqualToString:@"value"]) {
        if ([tagName isEqualToString:@"Rating"]) {
            cell = ratingCell;
        }
        else if ([tagName isEqualToString:@"Genre"]) {
            cell = genreCell;
        }
        else
            cell = [tableColumn dataCell];
    }
    else
        cell = nil;

    return cell;
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
    [dct removeAllObjects];

    if ([tableColumn.identifier isEqualToString:@"value"])
        [self updateMetadata:anObject forKey:tagName];
}

- (CGFloat) tableView: (NSTableView *) tableView
          heightOfRow: (NSInteger) rowIndex
{
    NSString *key = [tagsArray objectAtIndex:rowIndex];
    NSNumber *height;

    if (!(height = [dct objectForKey:key])) {
        //calculate new row height
        NSRect r = NSMakeRect(0,0,width,1000.0);
        NSTextFieldCell *cell = [tabCol dataCellForRow:rowIndex];	
        [cell setObjectValue:[tags objectForKey:[tagsArray objectAtIndex:rowIndex]]];
        height = [NSNumber numberWithDouble:[cell cellSizeForBounds:r].height]; // Slow, but we cache it.
        //if (height <= 0)
        //    height = 14.0; // Ensure miniumum height is 14.0
        [dct setObject:height forKey:key];
    }

	return [height doubleValue];
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
    [dct removeAllObjects];
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
    uint8_t newValue;
    if (sender == gapless)
        newValue = [sender state];
    else {
        newValue = ![gapless state];
        [gapless setState:newValue];
    }
    
    if (metadata.gapless != newValue) {
        metadata.gapless = newValue;
        metadata.isEdited = YES;
    }
    
    NSUndoManager *undo = [[self view] undoManager];
    [[undo prepareWithInvocationTarget:self] changeGapless: self];
    
    if (![undo isUndoing]) {
        [undo setActionName:@"Check Gapless"];
    }
}

- (IBAction) changehdVideo: (id) sender
{
    uint8_t newValue;
    if (sender == hdVideo)
        newValue = [sender state];
    else {
        newValue = ![hdVideo state];
        [hdVideo setState:newValue];
    }

    if (metadata.hdVideo != newValue) {
        metadata.hdVideo = newValue;
        metadata.isEdited = YES;
    }

    NSUndoManager *undo = [[self view] undoManager];
    [[undo prepareWithInvocationTarget:self] changehdVideo: self];

    if (![undo isUndoing]) {
        [undo setActionName:@"Check HD Video"];
    }
}

- (void) dealloc
{
    [tagsArray release];
    [tagsMenu release];
    [tabCol release];
    [detailBoldAttr release];
    [ratingCell release];
    [genreCell release];
    [dct release];
    [super dealloc];
}

@end
