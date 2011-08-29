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
    SBQueueStatusUnknown = 0,
    SBQueueStatusWorking,
    SBQueueStatusCompleted,
    SBQueueStatusFailed,
    SBQueueStatusCancelled,
};
typedef NSInteger SBQueueStatus;

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

    NSURL *destination;
    BOOL customDestination;
    IBOutlet NSPopUpButton *destButton;

    NSImage *docImg;
    
    SBQueueStatus   status;
    BOOL            isCancelled;
    id              currentItem;
}

@property (readonly) SBQueueStatus status;

+ (SBQueueController*)sharedController;

- (void)start:(id)sender;
- (void)stop:(id)sender;

- (void)addItem:(SBQueueItem*)item;

- (BOOL)saveQueueToDisk;

- (IBAction)removeSelectedItems:(id)sender;
- (IBAction)removeCompletedItems:(id)sender;

- (IBAction)toggleStartStop:(id)sender;
- (IBAction)toggleOptions:(id)sender;

- (IBAction)open:(id)sender;
- (IBAction)chooseDestination:(id)sender;
- (IBAction)destination:(id)sender;

@end
