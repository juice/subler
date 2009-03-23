//
//  FileImport.h
//  Subler
//
//  Created by Damiano Galassi on 15/03/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MP42File.h"

@interface MP4FileImport : NSWindowController {
    MP42File        *sourceFile;
    NSString        *filePath;
    NSMutableArray  *importCheckArray;

    id delegate;
}

- (id)initWithDelegate:(id)del andFile: (NSString *)path;
- (IBAction) closeWindow: (id) sender;
- (IBAction) addTracks: (id) sender;

@end

@interface NSObject (MP4FileImportDelegateMethod)
- (void) importDone: (NSArray*) tracksToBeImported;

@end
