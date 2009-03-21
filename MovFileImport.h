//
//  FileImport.h
//  Subler
//
//  Created by Damiano Galassi on 15/03/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MP42File.h"
#import <QTKit/QTKit.h>

@interface MovFileImport : NSWindowController {
    //MP42File        *sourceFile;
    QTMovie         *sourceFile;
    NSString        *filePath;
    NSMutableArray  *importCheckArray;

    id delegate;
}

- (id)initWithDelegate:(id)del andFile: (NSString *)path;
- (IBAction) closeWindow: (id) sender;
- (IBAction) addTracks: (id) sender;

@end

@interface NSObject (MovFileImportDelegateMethod)
- (void) importDone: (NSArray*) tracksToBeImported;

@end
