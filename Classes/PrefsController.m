//
//  PrefsController.m
//
//  Created by Damiano Galassi on 13/05/08.
//  Copyright 2008 Damiano Galassi. All rights reserved.
//

#import "PrefsController.h"
#import "MetadataSearchController.h"

#define TOOLBAR_GENERAL     @"TOOLBAR_GENERAL"
#define TOOLBAR_AUDIO       @"TOOLBAR_AUDIO"

@interface PrefsController (Private)

- (void) setPrefView: (id) sender;
- (NSToolbarItem *)toolbarItemWithIdentifier: (NSString *)identifier
                                       label: (NSString *)label
                                       image: (NSImage *)image;

@end

@implementation PrefsController

-(id) init
{
    self = [super initWithWindowNibName:@"Prefs"];
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
    return [NSArray arrayWithObjects: TOOLBAR_GENERAL, TOOLBAR_AUDIO, nil];
}

- (IBAction) clearRecentSearches:(id) sender {
    [MetadataSearchController clearRecentSearches];
}

- (IBAction) deleteCachedMetadata:(id) sender {
    [MetadataSearchController deleteCachedMetadata];
}

@end

@implementation PrefsController (Private)

- (void) setPrefView: (id) sender
{
    NSView * view = generalView;
    if( sender ) {
        NSString * identifier = [sender itemIdentifier];
        if( [identifier isEqualToString: TOOLBAR_AUDIO] )
            view = audioView;
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
