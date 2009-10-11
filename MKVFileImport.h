//
//  MKVFileImport.h
//  Subler
//
//  Created by Ryan Walklin on 10/09/09.
//  Copyright 2009 Test Toast. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MKVFileImport : NSWindowController {
	
	struct MatroskaFile	*matroskaFile;
	struct StdIoStream  *ioStream;

	NSString			*filePath;
    NSMutableArray		*importCheckArray;

    NSInteger chapterTrackId;

	id delegate;
	IBOutlet NSTableView *tableView;
	IBOutlet NSButton    *addTracksButton;

}

- (id)initWithDelegate:(id)del andFile: (NSString *)path;
- (IBAction) closeWindow: (id) sender;
- (IBAction) addTracks: (id) sender;

@end

@interface NSObject (MKVFileImportDelegateMethod)
- (void) importDone: (NSArray*) tracksToBeImported;

@end

