//
//  FileImport.h
//  Subler
//
//  Created by Ryan Walklin on 10/09/09.
//  Copyright 2009 Test Toast. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MP42FileImporter;

@interface FileImport : NSWindowController {
	
	NSURL               * file;
    NSMutableArray		* importCheckArray;
    MP42FileImporter    * fileImporter;

	id delegate;
	IBOutlet NSTableView * tableView;
	IBOutlet NSButton    * addTracksButton;
    IBOutlet NSProgressIndicator *loadProgressBar;
    NSTimer *loadTimer;
}

- (id)initWithDelegate:(id)del andFile: (NSURL *)path;
- (IBAction) closeWindow: (id) sender;
- (IBAction) addTracks: (id) sender;

@end

@interface NSObject (FileImportDelegateMethod)
- (void) importDone: (NSArray*) tracksToBeImported;

@end

