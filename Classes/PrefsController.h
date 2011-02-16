//
//  PrefsController.h
//
//  Created by Damiano Galassi on 13/05/08.
//  Copyright 2008 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PrefsController : NSWindowController {
    IBOutlet NSView         * generalView, * audioView, *setsView;
}

- (id)init;
- (IBAction) clearRecentSearches:(id) sender;
- (IBAction) deleteCachedMetadata:(id) sender;

@end
