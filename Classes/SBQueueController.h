//
//  SBQueueController.h
//  Subler
//
//  Created by Damiano Galassi on 12/08/11.
//  Copyright 2011 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SBTableView.h"

@class MP42File;
@class SBQueueItem;
enum {
    SBBatchStatusUnknown = 0,
    SBBatchStatusWorking,
    SBBatchStatusCompleted,
    SBBatchStatusFailed,
    SBBatchStatusCancelled,
};
typedef NSInteger SBBatchStatus;

@interface SBQueueController : NSWindowController<NSTableViewDelegate, NSTableViewDataSource, SBTableViewDelegate> {
    IBOutlet NSButton *start;
    IBOutlet NSButton *open;

    IBOutlet NSTextField *countLabel;
    IBOutlet NSProgressIndicator *spinningIndicator;

    IBOutlet NSButton *OptimizeOption;
    IBOutlet NSButton *MetadataOption;
    IBOutlet NSButton *AutoStartOption;
    IBOutlet NSBox    *optionsBox;
    BOOL optionsStatus;

    IBOutlet NSScrollView   *tableScrollView;
    IBOutlet SBTableView    *tableView;
    NSMutableArray *filesArray;

    SBBatchStatus status;
}

@property (readonly) SBBatchStatus status;

+ (SBQueueController*)sharedController;

- (void)start:(id)sender;
- (void)stop:(id)sender;

- (void)addItem:(SBQueueItem*)item;

- (IBAction)toggleStartStop:(id)sender;
- (IBAction)toggleOptions:(id)sender;

- (IBAction)open:(id)sender;

@end
