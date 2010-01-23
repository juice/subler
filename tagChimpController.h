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
    NSURLConnection * artworkConnection;
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

    NSTableColumn *tabCol;
    CGFloat width;
}

- (id)initWithDelegate:(id)del;
- (IBAction) addMetadata: (id) sender;
- (IBAction) closeWindow: (id) sender;
- (IBAction) tagChimpWebSite: (id) sender;
- (IBAction) searchType: (id) sender;
- (IBAction) search: (id) sender;
- (NSArray *) tagChimpXmlToMP42Metadata: (NSXMLDocument *) xmlDocument;

@end

@interface NSObject (tagChimpControllerDelegateMethod)
- (void) metadataImportDone: (MP42Metadata *) metadataToBeImported;
@end
