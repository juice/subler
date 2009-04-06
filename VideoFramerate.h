//
//  VideoFramerate.h
//  Subler
//
//  Created by Damiano Galassi on 01/04/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface VideoFramerate : NSWindowController {
    NSString    *filePath;
    IBOutlet NSPopUpButton  *framerateSelection;

    id delegate;
}

- (id)initWithDelegate:(id)del andFile: (NSString *)path;
- (IBAction) closeWindow: (id) sender;
- (IBAction) addTracks: (id) sender;

@end

@interface NSObject (VideoFramerateDelegateMethod)
- (void) importDone: (NSArray*) tracksToBeImported;

@end
