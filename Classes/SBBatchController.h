//
//  SBBatchController.h
//  Subler
//
//  Created by Damiano Galassi on 12/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SBBatchController : NSWindowController<NSTableViewDelegate, NSTableViewDataSource> {
    IBOutlet NSButton *start;
    IBOutlet NSButton *open;
    
    IBOutlet NSTextField *countLabel;
    IBOutlet NSProgressIndicator *spinningIndicator;
    
    IBOutlet NSTableView *tableView;
    NSMutableArray *filesArray;
}

- (IBAction)start:(id)sender;
- (IBAction)open:(id)sender;

@end
