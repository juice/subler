//
//  MetadataImportController.h
//  Subler
//
//  Created by Douglas Stebila on 2011/01/27.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SBTableView;
@class MP42Metadata;

#import "TheMovieDB.h"
#import "TheTVDB.h"

@interface MetadataSearchController : NSWindowController<NSTableViewDelegate> {
    id                            delegate;
    NSDictionary                 *detailBoldAttr;

    IBOutlet NSTabView           *searchMode;
    
    IBOutlet NSTextField         *movieName;
    IBOutlet NSPopUpButton       *movieLanguage;
    
    IBOutlet NSComboBox          *tvSeriesName;
    NSMutableArray               *tvSeriesNameSearchArray;
    IBOutlet NSTextField         *tvSeasonNum;
    IBOutlet NSTextField         *tvEpisodeNum;
    IBOutlet NSPopUpButton       *tvLanguage;
    
    IBOutlet NSButton            *searchButton;
    id                            currentSearcher;

    NSArray                      *resultsArray;
    IBOutlet NSTableView         *resultsTable;
    MP42Metadata                 *selectedResult;
    NSDictionary                 *selectedResultTags;
    NSArray                      *selectedResultTagsArray;
    IBOutlet SBTableView         *metadataTable;

    IBOutlet NSButton            *addButton;

    NSData                       *artworkData;
    id                           artworkSelectorWindow;

    IBOutlet NSProgressIndicator *progress;
    IBOutlet NSTextField         *progressText;
    
}

#pragma mark Initialization
- (id)initWithDelegate:(id)del;
+ (NSDictionary *) parseFilename: (NSString *) filename;
+ (NSString *)langCodeFor:(NSString *)language;

#pragma mark Search input fields
- (void) updateSearchButtonVisibility;
- (void) searchForTVSeriesNameDone:(NSMutableArray *)seriesArray;

#pragma mark Search for metadata
- (IBAction) searchForResults:(id)sender;
- (void) searchForResultsDone:(NSArray *)metadataArray;

#pragma mark Load additional metadata
- (IBAction) loadAdditionalMetadata:(id)sender;
- (void) loadAdditionalMetadataDone:(MP42Metadata *)metadata;

#pragma mark Select artwork
- (void) selectArtwork;
- (void) selectArtworkDone:(NSURL *)url;

#pragma mark Load artwork
- (void) loadArtwork;
- (void) runLoadArtworkThread:(id)param;
- (void) loadArtworkDone;

#pragma mark Finishing up
- (void) addMetadata;
- (IBAction) closeWindow: (id) sender;

#pragma mark Miscellaneous
- (NSAttributedString *) boldString: (NSString *) string;
+ (NSString *) urlEncoded:(NSString *)s;

#pragma mark Logos
- (IBAction) loadTMDbWebsite:(id)sender;
- (IBAction) loadTVDBWebsite:(id)sender;

#pragma mark Static methods
+ (void) clearRecentSearches;
+ (void) deleteCachedMetadata;

@end