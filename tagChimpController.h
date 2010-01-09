//
//  tagChimpController.h
//  Subler
//
//  Created by Damiano Galassi on 06/01/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SBTableView;
@class MP42Metadata;

@interface tagChimpController : NSWindowController {
    NSMutableData   * receivedData;
    NSXMLDocument   * receivedXml;
    NSURLConnection * theConnection;
    id delegate;
    
    NSMutableArray * metadataArray;
    IBOutlet NSProgressIndicator * progress;
    IBOutlet NSSearchField       * searchField;
    IBOutlet NSMenu              * searchFieldMenu;

    IBOutlet NSTableView         * movieTitleTable;
    IBOutlet SBTableView         * metadataTable;
    
    IBOutlet NSButton            * addButton;
    
    MP42Metadata        * currentMetadata;
    NSDictionary        * tags;
    NSArray             * tagsArray;
    NSDictionary        * detailBoldAttr;
    NSInteger             videoKind;
}

- (id)initWithDelegate:(id)del;
- (IBAction) addMetadata: (id) sender;
- (IBAction) closeWindow: (id) sender;
- (IBAction) searchType: (id) sender;
- (IBAction) search: (id) sender;
- (void) tagChimpXmlToMP42Metadata: (NSXMLDocument *) xmlDocument;

@end

@interface NSObject (tagChimpControllerDelegateMethod)
- (void) metadataImportDone: (MP42Metadata *) metadataToBeImported;
@end
