//
//  MetadataImportController.m
//  Subler
//
//  Created by Douglas Stebila on 2011/01/27.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import "MetadataSearchController.h"
#import "MP42File.h"
#import "SBDocument.h"
#import "ArtworkSelector.h"

@implementation MetadataSearchController

#pragma mark Initialization

- (id)initWithDelegate:(id)del
{
	if ((self = [super initWithWindowNibName:@"MetadataSearch"])) {        
		delegate = del;
        
        NSMutableParagraphStyle * ps = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
        [ps setHeadIndent: -10.0];
        [ps setAlignment:NSRightTextAlignment];
        detailBoldAttr = [[NSDictionary dictionaryWithObjectsAndKeys:
                           [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
                           ps, NSParagraphStyleAttributeName,
                           [NSColor grayColor], NSForegroundColorAttributeName,
                           nil] retain];
    }

	return self;
}

- (void)windowDidLoad {
    
    [super windowDidLoad];

    [[self window] makeFirstResponder:movieName];
    
    NSString *filename = nil;
    MP42File *mp4File = [((SBDocument *) delegate) mp4File];
    for (NSUInteger i = 0; i < [mp4File tracksCount]; i++) {
        MP42Track *track = [mp4File trackAtIndex:i];
        if ([track sourcePath]) {
            filename = [[track sourcePath] lastPathComponent];
            break;
        }
    }
    if (!filename) return;

    NSDictionary *parsed = [MetadataSearchController parseFilename:filename];
    if (!parsed) return;
    
    if ([@"movie" isEqualToString:(NSString *) [parsed valueForKey:@"type"]]) {
        [searchMode selectTabViewItemAtIndex:0];
        if ([parsed valueForKey:@"title"]) [movieName setStringValue:[parsed valueForKey:@"title"]];
    } else if ([@"tv" isEqualToString:(NSString *) [parsed valueForKey:@"type"]]) {
        [searchMode selectTabViewItemAtIndex:1];
        [[self window] makeFirstResponder:tvSeriesName];
        if ([parsed valueForKey:@"seriesName"]) [((NSTextField *) tvSeriesName) setStringValue:[parsed valueForKey:@"seriesName"]];
        if ([parsed valueForKey:@"seasonNum"]) [tvSeasonNum setStringValue:[parsed valueForKey:@"seasonNum"]];
        if ([parsed valueForKey:@"episodeNum"]) [tvEpisodeNum setStringValue:[parsed valueForKey:@"episodeNum"]];
        // just in case this is actually a movie, set the text in the movie field for the user's convenience
        [movieName setStringValue:[filename stringByDeletingPathExtension]];
    }
    [self updateSearchButtonVisibility];
    if ([searchButton isEnabled]) {
        [self searchForResults:nil];
    }
    return;
}

+ (NSDictionary *) parseFilename: (NSString *) filename
{
    NSMutableDictionary *results = nil;
    
    if (!filename || ![filename length]) {
        return results;
    }
    
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/perl"];
    
    NSMutableArray *args = [[NSMutableArray alloc] initWithCapacity:3];
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"ParseFilename" ofType:@""];
    [args addObject:[NSString stringWithFormat:@"-I%@/lib", path]];
    [args addObject:[NSString stringWithFormat:@"%@/ParseFilename.pl", path]];
    [args addObject:filename];
    [task setArguments:args];
    
    NSPipe *stdOut = [[NSPipe alloc] init];
    NSFileHandle *stdOutWrite = [stdOut fileHandleForWriting];
    [task setStandardOutput:stdOutWrite];
    
    [task launch];
    [task waitUntilExit];
    [stdOutWrite closeFile];
    
    NSData *outputData = [[stdOut fileHandleForReading] readDataToEndOfFile];
    NSString *outputString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
    NSArray *lines = [outputString componentsSeparatedByString:@"\n"];
    
    if ([lines count]) {
        if ([(NSString *) [lines objectAtIndex:0] isEqualToString:@"tv"]) {
            if ([lines count] >= 4) {
                results = [[NSMutableDictionary alloc] initWithCapacity:4];
                [results setValue:@"tv" forKey:@"type"];
                [results setValue:[lines objectAtIndex:1] forKey:@"seriesName"];
                [results setValue:[lines objectAtIndex:2] forKey:@"seasonNum"];
                [results setValue:[lines objectAtIndex:3] forKey:@"episodeNum"];
            }
        } else if ([(NSString *) [lines objectAtIndex:0] isEqualToString:@"movie"]) {
            if ([lines count] >= 2) {
                results = [[NSMutableDictionary alloc] initWithCapacity:4];
                [results setValue:@"movie" forKey:@"type"];
				NSString *newTitle=[[lines objectAtIndex:1] 
                                    stringByReplacingOccurrencesOfString:@"." 
                                    withString:@" "];
                newTitle = [newTitle stringByReplacingOccurrencesOfString:@"(" withString:@" "];
                newTitle = [newTitle stringByReplacingOccurrencesOfString:@")" withString:@" "];
                newTitle = [newTitle stringByReplacingOccurrencesOfString:@"[" withString:@" "];
                newTitle = [newTitle stringByReplacingOccurrencesOfString:@"]" withString:@" "];
                newTitle = [newTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                [results setValue:newTitle forKey:@"title"];
            }
        }
    }
    
    [outputString release];
    [stdOut release];
    [args release];
    [task release];
    
    return [results autorelease];
}

#pragma mark Search input fields

- (void)updateSearchButtonVisibility {
    if ([[[searchMode selectedTabViewItem] label] isEqualToString:@"Movie"]) {
        if ([[movieName stringValue] length] > 0) {
            [searchButton setEnabled:YES];
            return;
        }
    } else if ([[[searchMode selectedTabViewItem] label] isEqualToString:@"TV Episode"]) {
        if ([[tvSeriesName stringValue] length] > 0) {
            if (([[tvSeasonNum stringValue] length] == 0) && ([[tvEpisodeNum stringValue] length] > 0)) {
                [searchButton setEnabled:NO];
                return;
            } else {
                [searchButton setEnabled:YES];
                return;
            }
        }
    } 
    [searchButton setEnabled:NO];
}

- (void)controlTextDidChange:(NSNotification *)aNotification {
    [self updateSearchButtonVisibility];
    [addButton setKeyEquivalent:@""];
    [searchButton setKeyEquivalent:@"\r"];
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    [self updateSearchButtonVisibility];
}

- (void) searchForTVSeriesNameDone:(NSMutableArray *)seriesArray {
    tvSeriesNameSearchArray = seriesArray;
    [tvSeriesNameSearchArray sortUsingSelector:@selector(compare:)];
    [tvSeriesName noteNumberOfItemsChanged];
    [tvSeriesName reloadData];
}

#pragma mark Search for results

- (IBAction) searchForResults: (id) sender {
    if ([[[searchMode selectedTabViewItem] label] isEqualToString:@"Movie"]) {
        [progress startAnimation:self];
        [progress setHidden:NO];
        [progressText setStringValue:@"Searching TheMovieDB for movies‚Ä¶"];
        [progressText setHidden:NO];
        currentSearcher = [[TheMovieDB alloc] init];
        [((TheMovieDB *) currentSearcher) searchForResults:[movieName stringValue] callback:self];
    } else if ([[[searchMode selectedTabViewItem] label] isEqualToString:@"TV Episode"]) {
        [progress startAnimation:self];
        [progress setHidden:NO];
        [progressText setStringValue:@"Searching TheTVDB for episode information‚Ä¶"];
        [progressText setHidden:NO];
        currentSearcher = [[TheTVDB alloc] init];
        [((TheTVDB *) currentSearcher) searchForResults:[tvSeriesName stringValue]
                                              seasonNum:[tvSeasonNum stringValue]
                                             episodeNum:[tvEpisodeNum stringValue]
                                               callback:self];        
    } 
}

- (void) searchForResultsDone:(NSArray *)_resultsArray {
    [progressText setHidden:YES];
    [progress setHidden:YES];
    [progress stopAnimation:self];
    resultsArray = _resultsArray;
    selectedResult = nil;
    [resultsTable reloadData];
    [metadataTable reloadData];
    [self tableViewSelectionDidChange:[NSNotification notificationWithName:@"tableViewSelectionDidChange" object:resultsTable]];
    [[self window] makeFirstResponder:resultsTable];
}

#pragma mark Load additional metadata

- (IBAction) loadAdditionalMetadata:(id) sender {
    [addButton setEnabled:NO];
    if ([[[searchMode selectedTabViewItem] label] isEqualToString:@"Movie"]) {
        [progress startAnimation:self];
        [progress setHidden:NO];
        [progressText setStringValue:@"Downloading additional metadata from TheMovieDB‚Ä¶"];
        [progressText setHidden:NO];
        currentSearcher = [[TheMovieDB alloc] init];
        [((TheMovieDB *) currentSearcher) loadAdditionalMetadata:selectedResult callback:self];
    } else if ([[[searchMode selectedTabViewItem] label] isEqualToString:@"TV Episode"]) {
        [self loadAdditionalMetadataDone:selectedResult];
    }
}

- (void) loadAdditionalMetadataDone:(MP42Metadata *)metadata {
    [progress setHidden:YES];
    [progressText setHidden:YES];
    [progress stopAnimation:self];
    selectedResult = metadata;
    [self selectArtwork];
}

#pragma mark Select artwork

- (void) selectArtwork {
    if (selectedResult.artworkThumbURLs && [selectedResult.artworkThumbURLs count]) {
        if ([selectedResult.artworkThumbURLs count] == 1) {
            selectedResult.artworkURL = [selectedResult.artworkFullsizeURLs objectAtIndex:0];
            [self loadArtwork];
        } else {
            artworkSelectorWindow = [[ArtworkSelector alloc] initWithDelegate:self imageURLs:selectedResult.artworkThumbURLs];
            [NSApp beginSheet:[artworkSelectorWindow window] modalForWindow:[self window] modalDelegate:nil didEndSelector:NULL contextInfo:nil];
        }
    } else {
        [self addMetadata];
    }
}

- (void) selectArtworkDone:(NSURL *)url {
    NSUInteger i = [selectedResult.artworkThumbURLs indexOfObject:url];
    if (i != NSNotFound) {
        [NSApp endSheet:[artworkSelectorWindow window]];
        [[artworkSelectorWindow window] orderOut:self];
        [artworkSelectorWindow release];
        selectedResult.artworkURL = [selectedResult.artworkFullsizeURLs objectAtIndex:i];
    }
    [self loadArtwork];
}

#pragma mark Load artwork

- (void) loadArtwork {
    if (selectedResult.artworkURL) {
        [progress startAnimation:self];
        [progress setHidden:NO];
        [progressText setStringValue:@"Downloading artwork‚Ä¶"];
        [progressText setHidden:NO];
        [tvSeriesName setEnabled:NO];
        [tvSeasonNum setEnabled:NO];
        [tvEpisodeNum setEnabled:NO];
        [movieName setEnabled:NO];
        [searchButton setEnabled:NO];
        [resultsTable setEnabled:NO];
        [metadataTable setEnabled:NO];
        [NSThread detachNewThreadSelector:@selector(runLoadArtworkThread:) toTarget:self withObject:nil];
    } else {
        [self addMetadata];
    }
}

- (void) runLoadArtworkThread:(id)param {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    artworkData = [NSData dataWithContentsOfURL:selectedResult.artworkURL];
    [self loadArtworkDone];
    [pool release];
}

- (void) loadArtworkDone {
    if (artworkData && [artworkData length]) {
        NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:artworkData];
        if (imageRep != nil) {
            NSImage *artwork = [[NSImage alloc] initWithSize:[imageRep size]];
            [artwork addRepresentation:imageRep];
            selectedResult.artwork = artwork;
            [artwork release];
        }
    }
    [self addMetadata];
}

#pragma mark Finishing up

- (void) addMetadata {
    // save TV series name in user preferences
    if ([[[searchMode selectedTabViewItem] label] isEqualToString:@"TV Episode"]) {
        NSArray *previousTVseries = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Previously used TV series"];
        NSMutableArray *newTVseries;
        NSString *formattedTVshowName = [selectedResultTags objectForKey:@"TV Show"];
        if (previousTVseries == nil) {
            newTVseries = [NSMutableArray arrayWithCapacity:1];
            [newTVseries addObject:formattedTVshowName];
            [[NSUserDefaults standardUserDefaults] setObject:newTVseries forKey:@"Previously used TV series"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        } else {
            if ([previousTVseries indexOfObject:formattedTVshowName] == NSNotFound) {
                newTVseries = [NSMutableArray arrayWithArray:previousTVseries];
                [newTVseries addObject:formattedTVshowName];
                [[NSUserDefaults standardUserDefaults] setObject:newTVseries forKey:@"Previously used TV series"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        }
    }
    if ([delegate respondsToSelector:@selector(metadataImportDone:)]) {
        [delegate performSelector:@selector(metadataImportDone:) withObject:[[selectedResult retain] autorelease]];
    }
}

- (IBAction) closeWindow: (id) sender
{
    if ([delegate respondsToSelector:@selector(metadataImportDone:)]) {
        [delegate performSelector:@selector(metadataImportDone:) withObject:nil];
    }
}

- (void) dealloc
{
    [detailBoldAttr release];
    [super dealloc];
}

#pragma mark -

#pragma mark Privacy

+ (void) clearRecentSearches {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Previously used TV series"];
}

+ (void) deleteCachedMetadata {
    [TheTVDB deleteCachedMetadata];
}

#pragma mark Miscellaneous

- (NSAttributedString *) boldString: (NSString *) string {
    return [[[NSAttributedString alloc] initWithString:string attributes:detailBoldAttr] autorelease];
}

+ (NSString *) urlEncoded:(NSString *)s {
    CFStringRef urlString = CFURLCreateStringByAddingPercentEscapes(
                                                                    NULL,
                                                                    (CFStringRef) s,
                                                                    NULL,
                                                                    (CFStringRef) @"!*'\"();:@&=+$,/?%#[]% ",
                                                                    kCFStringEncodingUTF8);
    return [(NSString *)urlString autorelease];
}

#pragma mark Logos

- (IBAction) loadTMDbWebsite:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.themoviedb.org/"]];
}

- (IBAction) loadTVDBWebsite:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://thetvdb.com/"]];
}

#pragma mark -

#pragma mark NSComboBox delegates and protocols

- (NSString *)comboBox:(NSComboBox *)comboBox completedString:(NSString *)uncompletedString {
    if (!uncompletedString || ([uncompletedString length] < 1)) return nil;
    if (comboBox == tvSeriesName) {
        NSArray *previousTVseries = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Previously used TV series"];
        if (previousTVseries == nil) return nil;
        NSEnumerator *previousTVseriesEnum = [previousTVseries objectEnumerator];
        NSString *s;
        while (s = (NSString *) [previousTVseriesEnum nextObject]) {
            if ([[s lowercaseString] hasPrefix:[uncompletedString lowercaseString]]) {
                return s;
            }
        }
        return nil;
    }
    return nil;
}

- (void)comboBoxWillPopUp:(NSNotification *)notification {
    if ([notification object] == tvSeriesName) {
        if ([[tvSeriesName stringValue] length] == 0) {
            tvSeriesNameSearchArray = [[NSMutableArray alloc] initWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"Previously used TV series"]];
            [tvSeriesNameSearchArray sortUsingSelector:@selector(compare:)];
            [tvSeriesName reloadData];
        } else if ([[tvSeriesName stringValue] length] > 3) {
            tvSeriesNameSearchArray = nil;
            tvSeriesNameSearchArray = [[NSMutableArray alloc] initWithCapacity:1];
            [tvSeriesNameSearchArray addObject:@"searching‚Ä¶"];
            [tvSeriesName reloadData];
            currentSearcher = [[TheTVDB alloc] init];
            [((TheTVDB *) currentSearcher) searchForTVSeriesName:[tvSeriesName stringValue] callback:self];
        } else {
            tvSeriesNameSearchArray = nil;
            [tvSeriesName reloadData];
        }
    }
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    // for some unknown reason, the number of items displayed won't be correct unless these member variables get accessed
    // bug to fix!
    NSLog(@"in numberOfItemsInComboBox; box numberOfVisibleItems = %d, cell numberOfVisibleItems = %d", (int) [comboBox numberOfVisibleItems], (int) [[comboBox cell] numberOfVisibleItems]);
    if (comboBox == tvSeriesName) {
        if (tvSeriesNameSearchArray != nil) {
            return [tvSeriesNameSearchArray count];
        }
    }
    return 0;
}

- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    if (comboBox == tvSeriesName) {
        if (tvSeriesNameSearchArray != nil) {
            return [tvSeriesNameSearchArray objectAtIndex:index];
        }
    }
    return nil;
}

#pragma mark -

#pragma mark NSTableView delegates and protocols

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == resultsTable) {
        if (resultsArray != nil) {
            return [resultsArray count];
        }
    } else if (tableView == (NSTableView *) metadataTable) {
        if (selectedResult != nil) {
            return [selectedResultTagsArray count];
        }
    }
    return 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex {
    if (tableView == resultsTable) {
        if (resultsArray != nil) {
            MP42Metadata *result = [resultsArray objectAtIndex:rowIndex];
            if ((result.mediaKind == 10) && ([resultsArray count] > 1)) { // TV show
                return [NSString stringWithFormat:@"%@x%@ - %@", [result.tagsDict valueForKey:@"TV Season"], [result.tagsDict valueForKey:@"TV Episode #"], [result.tagsDict valueForKey:@"Name"]];
            } else {
                return [result.tagsDict valueForKey:@"Name"];
            }
        }
    } else if (tableView == (NSTableView *) metadataTable) {
        if (selectedResult != nil) {
            if ([tableColumn.identifier isEqualToString:@"name"]) {
                return [self boldString:[selectedResultTagsArray objectAtIndex:rowIndex]];
            }
            if ([tableColumn.identifier isEqualToString:@"value"]) {
                NSString *tagName = [selectedResultTagsArray objectAtIndex:rowIndex];
                if ([tagName isEqualToString:@"Rating"]) {
                    return [selectedResult ratingFromIndex:[[selectedResultTags objectForKey:[selectedResultTagsArray objectAtIndex:rowIndex]] integerValue]];
                }
                return [selectedResultTags objectForKey:[selectedResultTagsArray objectAtIndex:rowIndex]];
            }
        }
    }
    return nil;
}

static NSInteger sortFunction (id ldict, id rdict, void *context) {
    NSComparisonResult rc;
    
    NSInteger right = [(NSArray*) context indexOfObject:rdict];
    NSInteger left = [(NSArray*) context indexOfObject:ldict];
    
    if (right < left)
        rc = NSOrderedDescending;
    else
        rc = NSOrderedAscending;
    
    return rc;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    if ([aNotification object] == resultsTable) {
        if (resultsArray && [resultsArray count] > 0) {
            selectedResult = [resultsArray objectAtIndex:[resultsTable selectedRow]];
            selectedResultTags = selectedResult.tagsDict;
            if (selectedResultTagsArray) [selectedResultTagsArray release];
            selectedResultTagsArray = [[[selectedResultTags allKeys] sortedArrayUsingFunction:sortFunction context:[selectedResult availableMetadata]] retain];
            [metadataTable reloadData];
            [addButton setEnabled:YES];
            [addButton setKeyEquivalent:@"\r"];
            [searchButton setKeyEquivalent:@""];
        }
    } else {
        [addButton setEnabled:NO];
        [addButton setKeyEquivalent:@""];
        [searchButton setKeyEquivalent:@"\r"];
    }
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    if (tableView != (NSTableView *) metadataTable) return [tableView rowHeight];
    
    // It is important to use a constant value when calculating the height. Querying the tableColumn width will not work, since it dynamically changes as the user resizes -- however, we don't get a notification that the user "did resize" it until after the mouse is let go. We use the latter as a hook for telling the table that the heights changed. We must return the same height from this method every time, until we tell the table the heights have changed. Not doing so will quicly cause drawing problems.
    NSTableColumn *tableColumnToWrap = (NSTableColumn *) [[tableView tableColumns] objectAtIndex:1];
    NSInteger columnToWrap = [tableView.tableColumns indexOfObject:tableColumnToWrap];
    
    // Grab the fully prepared cell with our content filled in. Note that in IB the cell's Layout is set to Wraps.
    NSCell *cell = [tableView preparedCellAtColumn:columnToWrap row:row];
    
    // See how tall it naturally would want to be if given a restricted with, but unbound height
    NSRect constrainedBounds = NSMakeRect(0, 0, [tableColumnToWrap width], CGFLOAT_MAX);
    NSSize naturalSize = [cell cellSizeForBounds:constrainedBounds];
    
    // Make sure we have a minimum height -- use the table's set height as the minimum.
    if (naturalSize.height > [tableView rowHeight]) {
        return naturalSize.height;
    } else {
        return [tableView rowHeight];
    }
}

@end
