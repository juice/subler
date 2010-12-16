//
//  FileImport.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MP42FileImporter;
@class MP42Metadata;

@interface FileImport : NSWindowController {

	NSString            * file;
    NSMutableArray		* importCheckArray;
    MP42FileImporter    * fileImporter;

	id delegate;
	IBOutlet NSTableView * tableView;
	IBOutlet NSButton    * addTracksButton;
    IBOutlet NSButton    * importMetadata;
    IBOutlet NSProgressIndicator *loadProgressBar;
    NSTimer *loadTimer;
}

- (id)initWithDelegate:(id)del andFile: (NSString *)path;
- (IBAction) closeWindow: (id) sender;
- (IBAction) addTracks: (id) sender;

@end

@interface NSObject (FileImportDelegateMethod)
- (void) importDoneWithTracks: (NSArray*) tracksToBeImported andMetadata: (MP42Metadata*)metadata;

@end
