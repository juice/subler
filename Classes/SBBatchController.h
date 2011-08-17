//
//  SBBatchController.h
//  Subler
//
//  Created by Damiano Galassi on 12/08/11.
//  Copyright 2011 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SBTableView.h"

@class MP42File;

enum {
    SBBatchStatusUnknown = 0,
    SBBatchStatusWorking,
    SBBatchStatusCompleted,
    SBBatchStatusFailed,
    SBBatchStatusCancelled,
};
typedef NSInteger SBBatchStatus;

@interface SBBatchController : NSWindowController<NSTableViewDelegate, NSTableViewDataSource, SBTableViewDelegate> {
    IBOutlet NSButton *start;
    IBOutlet NSButton *open;

    IBOutlet NSTextField *countLabel;
    IBOutlet NSProgressIndicator *spinningIndicator;

    IBOutlet SBTableView *tableView;
    NSMutableArray *filesArray;

    SBBatchStatus status;
}

@property (readonly) SBBatchStatus status;

+ (SBBatchController*)sharedController;

- (void)addItem:(MP42File*)mp4File;

- (IBAction)start:(id)sender;
- (IBAction)open:(id)sender;

@end
