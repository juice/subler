//
//  PrefsController.m
//
//  Created by Damiano Galassi on 13/05/08.
//  Copyright 2008 Damiano Galassi. All rights reserved.
//

#import "PrefsController.h"
#import "MetadataSearchController.h"
#import "SBPresetManager.h"
#import "SBTableView.h"
#import "MP42Metadata.h"
#import "MovieViewController.h"

#define TOOLBAR_GENERAL     @"TOOLBAR_GENERAL"
#define TOOLBAR_AUDIO       @"TOOLBAR_AUDIO"
#define TOOLBAR_SETS        @"TOOLBAR_SETS"

@interface PrefsController (Private)

- (void) setPrefView: (id) sender;
- (NSToolbarItem *)toolbarItemWithIdentifier: (NSString *)identifier
                                       label: (NSString *)label
                                       image: (NSImage *)image;

@end

@implementation PrefsController

-(id) init
{
    if ((self = [super initWithWindowNibName:@"Prefs"])) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateTableView:)
                                                     name:@"SBPresetManagerUpdatedNotification" object:nil];
    }        

    return self;
}

- (void) awakeFromNib
{
    NSToolbar * toolbar = [[[NSToolbar alloc] initWithIdentifier: @"Preferences Toolbar"] autorelease];
    [toolbar setDelegate: self];
    [toolbar setAllowsUserCustomization: NO];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
    [toolbar setSizeMode: NSToolbarSizeModeRegular];
    [[self window] setToolbar: toolbar];

    [toolbar setSelectedItemIdentifier: TOOLBAR_GENERAL];
    [self setPrefView:nil];
}

- (NSToolbarItem *)toolbar: (NSToolbar *)toolbar
     itemForItemIdentifier: (NSString *)ident
 willBeInsertedIntoToolbar: (BOOL)flag
{
    if ( [ident isEqualToString:TOOLBAR_GENERAL] ) {
        return [self toolbarItemWithIdentifier:ident
                                         label:NSLocalizedString(@"General", @"Preferences General Toolbar Item")
                                         image:[NSImage imageNamed:NSImageNamePreferencesGeneral]];
    }
    else if ( [ident isEqualToString:TOOLBAR_AUDIO] ) {
        return [self toolbarItemWithIdentifier:ident
                                         label:NSLocalizedString(@"Audio", @"Preferences Audio Toolbar Item")
                                         image:[NSImage imageNamed:@"prefs-audio"]];
    }
    else if ( [ident isEqualToString:TOOLBAR_SETS] ) {
        return [self toolbarItemWithIdentifier:ident
                                         label:NSLocalizedString(@"Sets", @"Preferences Sets Toolbar Item")
                                         image:[NSImage imageNamed:NSImageNameFolderSmart]];
    }    

    return nil;
}

- (NSArray *) toolbarSelectableItemIdentifiers: (NSToolbar *) toolbar
{
    return [self toolbarDefaultItemIdentifiers: toolbar];
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar
{
    return [self toolbarAllowedItemIdentifiers: toolbar];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar
{
    return [NSArray arrayWithObjects: TOOLBAR_GENERAL, TOOLBAR_SETS, TOOLBAR_AUDIO, nil];
}

- (IBAction) clearRecentSearches:(id) sender {
    [MetadataSearchController clearRecentSearches];
}

- (IBAction) deleteCachedMetadata:(id) sender {
    [MetadataSearchController deleteCachedMetadata];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    SBPresetManager *presetManager = [SBPresetManager sharedManager];
    return [[presetManager presets] count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex {
    SBPresetManager *presetManager = [SBPresetManager sharedManager];
    
    return [[[presetManager presets] objectAtIndex:rowIndex] presetName];
}

- (IBAction) deletePreset:(id) sender
{
    NSInteger rowIndex = [tableView selectedRow];
    SBPresetManager *presetManager = [SBPresetManager sharedManager];
    [presetManager removePresetAtIndex:rowIndex];
    [tableView reloadData];
}

- (IBAction)hideInfoWindow:(id)sender
{
    if(attachedWindow) {
        [[self window] removeChildWindow:attachedWindow];
        [attachedWindow orderOut:self];
        [attachedWindow release];
        attachedWindow = nil;
        [controller release];
        controller = nil;
    }
}

- (IBAction)toggleInfoWindow:(id)sender
{
    if (attachedWindow) {
        [self hideInfoWindow:sender];
    }
    if (!attachedWindow) {
        SBPresetManager *presetManager = [SBPresetManager sharedManager];

        NSInteger row = [tableView selectedRow]; 

        NSRect cellFrame = [tableView frameOfCellAtColumn:1 row:row];
        NSRect tableFrame = [[[tableView superview] superview]frame];

        NSPoint windowPoint = NSMakePoint(NSMidX(cellFrame),
                                          NSHeight(tableFrame) + tableFrame.origin.y - cellFrame.origin.y - (cellFrame.size.height / 2));        

        controller = [[MovieViewController alloc] initWithNibName:@"MovieView" bundle:nil];
        [controller setMetadata:[[presetManager presets] objectAtIndex:row]];

        attachedWindow = [[MAAttachedWindow alloc] initWithView:[controller view] 
                                                attachedToPoint:windowPoint 
                                                       inWindow:[self window] 
                                                         onSide:MAPositionRightBottom 
                                                     atDistance:11
                                                       delegate:self];

        [attachedWindow setBackgroundColor:[NSColor colorWithCalibratedRed:0.98 green:0.98 blue:1 alpha:1]];
        [attachedWindow setDelegate:self];
        [attachedWindow setCornerRadius:15];

        [[self window] addChildWindow:attachedWindow ordered:NSWindowAbove];

        [attachedWindow setAlphaValue:0.0];

        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:0.1];  
        [attachedWindow makeKeyAndOrderFront:self];
        [[attachedWindow animator] setAlphaValue:1.0];
        [NSAnimationContext endGrouping];
    }
    else {
        [[self window] removeChildWindow:attachedWindow];
        [attachedWindow orderOut:self];
        [attachedWindow release];
        attachedWindow = nil;
        [controller release];
        controller = nil;
    }

}

- (void)updateTableView:(id)sender
{
    [tableView reloadData];
}

/*- (void)_deleteSelectionFromTableView:(NSTableView *)tableView {
    NSLog(@"Hello!");
}*/

/*- (void)windowDidResignKey:(NSNotification *)notification
{
    [self performSelectorOnMainThread:@selector(hideInfoWindow:) withObject:self waitUntilDone:NO];
}*/

@end

@implementation PrefsController (Private)

- (void) setPrefView: (id) sender
{
    NSView * view = generalView;
    if( sender ) {
        NSString * identifier = [sender itemIdentifier];
        if( [identifier isEqualToString: TOOLBAR_AUDIO] )
            view = audioView;
        else if( [identifier isEqualToString: TOOLBAR_SETS] )
            view = setsView;
        else;
    }

    NSWindow * window = [self window];
    if( [window contentView] == view )
        return;

    NSRect windowRect = [window frame];
    CGFloat difference = ( [view frame].size.height - [[window contentView] frame].size.height ) * [window userSpaceScaleFactor];
    windowRect.origin.y -= difference;
    windowRect.size.height += difference;

    [view setHidden: YES];
    [window setContentView: view];
    [window setFrame: windowRect display: YES animate: YES];
    [view setHidden: NO];

    //set title label
    if( sender )
        [window setTitle: [sender label]];
    else {
        NSToolbar * toolbar = [window toolbar];
        NSString * itemIdentifier = [toolbar selectedItemIdentifier];
        for( NSToolbarItem * item in [toolbar items] )
            if( [[item itemIdentifier] isEqualToString: itemIdentifier] ) {
                [window setTitle: [item label]];
                break;
            }
    }
}

- (NSToolbarItem *)toolbarItemWithIdentifier: (NSString *)identifier
                                       label: (NSString *)label
                                       image: (NSImage *)image
{
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
    [item setLabel:label];
    [item setImage:image];
    [item setAction:@selector(setPrefView:)];
    [item setAutovalidates:NO];
    return [item autorelease];
}

@end
