//
//  PrefsController.h
//
//  Created by Damiano Galassi on 13/05/08.
//  Copyright 2008 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MAAttachedWindow.h"

@class MovieViewController;
@class SBTableView;

@interface PrefsController : NSWindowController <NSToolbarDelegate, NSWindowDelegate> {
    IBOutlet NSView         * generalView, * audioView, *setsView;

    MAAttachedWindow *attachedWindow;
    MAAttachedWindow *oldAttachedWindow;
    MovieViewController *controller;
    MovieViewController *oldController;

    IBOutlet SBTableView *tableView;
    IBOutlet NSButton    *removeSet;
}

- (id)init;
- (IBAction) clearRecentSearches:(id) sender;
- (IBAction) deleteCachedMetadata:(id) sender;
- (IBAction) toggleInfoWindow:(id) sender;

- (IBAction) deletePreset:(id) sender;

@end
