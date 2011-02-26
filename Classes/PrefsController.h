//
//  PrefsController.h
//
//  Created by Damiano Galassi on 13/05/08.
//  Copyright 2008 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MAAttachedWindow.h"

@class SBTableView;

@interface PrefsController : NSWindowController {
    IBOutlet NSView         * generalView, * audioView, *setsView;
    
    MAAttachedWindow *attachedWindow;
    IBOutlet NSView *infoView;
    IBOutlet SBTableView *tableView;
}

- (id)init;
- (IBAction) clearRecentSearches:(id) sender;
- (IBAction) deleteCachedMetadata:(id) sender;
- (IBAction) toggleWindow:(id) sender;

@end
