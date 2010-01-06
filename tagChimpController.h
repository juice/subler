//
//  tagChimpController.h
//  Subler
//
//  Created by Damiano Galassi on 06/01/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SBTableView;

@interface tagChimpController : NSWindowController {
    NSMutableData   * receivedData;
    NSXMLDocument   * receivedXml;
    NSURLConnection * theConnection;
    id delegate;

    NSMutableArray * metadataArray;
    IBOutlet NSProgressIndicator * progress;
    IBOutlet NSSearchField       * searchField;
    
    IBOutlet NSTableView         * movieTitleTable;
    IBOutlet SBTableView         * metadataTable;
    
    NSDictionary    *tags;
    NSArray         *tagsArray;
}

- (id)initWithDelegate:(id)del;
- (IBAction) closeWindow: (id) sender;
- (IBAction) search: (id) sender;
- (void) tagChimpXmlToMP42Metadata: (NSXMLDocument *) xmlDocument;

@end

@interface NSObject (tagChimpControllerDelegateMethod)
- (void) metadataImportDone: (NSArray*) tracksToBeImported;
@end
