//
//  SBBatchController.m
//  Subler
//
//  Created by Damiano Galassi on 12/08/11.
//  Copyright 2011 Damiano Galassi. All rights reserved.
//

#import "SBBatchController.h"
#import "SBBatchItem.h"
#import "MP42File.h"
#import "MP42FileImporter.h"
#import "MetadataSearchController.h"

#define SublerBatchTableViewDataType @"SublerBatchTableViewDataType"

static SBBatchController *sharedController = nil;

@implementation SBBatchController

@synthesize status;

+ (SBBatchController*)sharedController
{
    if (sharedController == nil) {
        sharedController = [[super allocWithZone:NULL] init];
    }
    return sharedController;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [[self sharedController] retain];
}

- (id)init
{
    self = [super initWithWindowNibName:@"Batch"];
    if (self) {
        filesArray = [[NSMutableArray alloc] init];
    }

    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain
{
    return self;
}

- (NSUInteger)retainCount
{
    return NSUIntegerMax;  //denotes an object that cannot be released
}

- (oneway void)release
{
    //do nothing
}

- (id)autorelease
{
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [spinningIndicator setHidden:YES];
    [countLabel setStringValue:@"Empty queue"];

    [tableView registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, SublerBatchTableViewDataType, nil]];
}

- (void)updateUI
{
    [tableView reloadData];
    if (status != SBBatchStatusWorking) {
        [countLabel setStringValue:[NSString stringWithFormat:@"%ld files in queue.", [filesArray count]]];
    }
}

- (void)addItem:(MP42File*)mp4File;
{
    SBBatchItem *newItem = [SBBatchItem itemWithMP4:mp4File];
    [filesArray addObject:newItem];

    [self updateUI];
}

- (NSArray*)loadSubtitles:(NSURL*)url
{
    NSError *outError;
    NSMutableArray *tracksArray = [[NSMutableArray alloc] init];
    NSArray *directory = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[url URLByDeletingLastPathComponent] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsSubdirectoryDescendants | NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants error:nil];

    for (NSURL *dirUrl in directory) {
        if ([[dirUrl pathExtension] isEqualToString:@"srt"]) {
            NSComparisonResult result;
            NSString *movieFilename = [[url URLByDeletingPathExtension] lastPathComponent];
            NSString *subtitleFilename = [[dirUrl URLByDeletingPathExtension] lastPathComponent];
            NSRange range = { 0, [movieFilename length] };

            result = [subtitleFilename compare:movieFilename options:kCFCompareCaseInsensitive range:range];

            if (result == NSOrderedSame) {
                MP42FileImporter *fileImporter = [[MP42FileImporter alloc] initWithDelegate:nil
                                                                                    andFile:dirUrl
                                                                                      error:&outError];

                for (MP42Track *track in [fileImporter tracksArray]) {
                    [track setTrackImporterHelper:fileImporter];
                    [tracksArray addObject:track];                    
                }
                [fileImporter release];
            }
        }
    }

    return [tracksArray autorelease];
}

- (NSImage*)loadArtwork:(NSURL*)url
{
    NSData *artworkData = [NSData dataWithContentsOfURL:url];
    if (artworkData && [artworkData length]) {
        NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:artworkData];
        if (imageRep != nil) {
            NSImage *artwork = [[NSImage alloc] initWithSize:[imageRep size]];
            [artwork addRepresentation:imageRep];
            return [artwork autorelease];
        }
    }

    return nil;
}

- (MP42Metadata *)searchMetadataForFile:(NSURL*) url
{
    id  currentSearcher = nil;
    MP42Metadata *metadata = nil;
    // Parse FileName and search for metadata
    NSDictionary *parsed = [MetadataSearchController parseFilename:[url lastPathComponent]];
    if ([@"movie" isEqualToString:(NSString *) [parsed valueForKey:@"type"]]) {
        currentSearcher = [[TheMovieDB alloc] init];
        NSArray *results = [((TheMovieDB *) currentSearcher) searchForResults:[parsed valueForKey:@"title"]
                                            mMovieLanguage:[MetadataSearchController langCodeFor:@"English"]];
        if ([results count])
            metadata = [((TheMovieDB *) currentSearcher) loadAdditionalMetadata:[results objectAtIndex:0] mMovieLanguage:@"English"];

    } else if ([@"tv" isEqualToString:(NSString *) [parsed valueForKey:@"type"]]) {
        currentSearcher = [[TheTVDB alloc] init];
        NSArray *results = [((TheTVDB *) currentSearcher) searchForResults:[parsed valueForKey:@"seriesName"]
                                         seriesLanguage:[MetadataSearchController langCodeFor:@"English"] 
                                              seasonNum:[parsed valueForKey:@"seasonNum"]
                                             episodeNum:[parsed valueForKey:@"episodeNum"]];
        if ([results count])
            metadata = [results objectAtIndex:0];
    }

    if (metadata.artworkThumbURLs && [metadata.artworkThumbURLs count]) {
        [metadata setArtwork:[self loadArtwork:[metadata.artworkFullsizeURLs lastObject]]];
    }

    [currentSearcher release];
    return metadata;
}

- (MP42File*)prepareQueueItem:(NSURL*)url error:(NSError**)outError {
    MP42File *mp4File = [[MP42File alloc] initWithDelegate:self];
    MP42FileImporter *fileImporter = [[MP42FileImporter alloc] initWithDelegate:nil
                                                                        andFile:url
                                                                          error:outError];
    
    for (MP42Track *track in [fileImporter tracksArray]) {
        if ([track.format isEqualToString:@"AC-3"] && [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioConvertAC3"] integerValue])
            track.needConversion = YES;
        
        [track setTrackImporterHelper:fileImporter];
        [mp4File addTrack:track];
    }
    [fileImporter release];
    
    // Search for external subtitles files
    NSArray *subtitles = [self loadSubtitles:url];
    for (MP42SubtitleTrack *subTrack in subtitles)
        [mp4File addTrack:subTrack];
    
    // Search for metadata
    MP42Metadata *metadata = [self searchMetadataForFile:url];
    [[mp4File metadata] mergeMetadata:metadata];
    
    return [mp4File autorelease];
}

- (IBAction)start:(id)sender
{
    [countLabel setStringValue:@"Working."];
    [spinningIndicator setHidden:NO];
    [spinningIndicator startAnimation:self];
    [start setEnabled:NO];
    [open setEnabled:NO];
    status = SBBatchStatusWorking;

    NSArray * itemsArray = [filesArray copy];

    NSMutableDictionary * attributes = [[NSMutableDictionary alloc] init];
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"chaptersPreviewTrack"] integerValue])
        [attributes setObject:[NSNumber numberWithBool:YES] forKey:MP42CreateChaptersPreviewTrack];

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSError *outError;
        BOOL success = YES;
        for (SBBatchItem *item in itemsArray) {
            NSURL * url = [item URL];
            MP42File *mp4File = [item mp4File];
            [mp4File setDelegate:self];

            [item setStatus:SBBatchItemStatusWorking];

            // Update the UI
            dispatch_async(dispatch_get_main_queue(), ^{
                NSInteger itemIndex = [itemsArray indexOfObject:item];
                [countLabel setStringValue:[NSString stringWithFormat:@"Processing file %ld of %ld.",itemIndex + 1, [itemsArray count]]];
                [tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:itemIndex] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
            });
            // The file has been added directly to the queue, or is not an mp4file
            if (!mp4File) {
                mp4File = [[self prepareQueueItem:url error:&outError] retain];

            }
            // We have an existing mp4 file
            if ([mp4File hasFileRepresentation])
                success = [mp4File updateMP4FileWithAttributes:attributes error:&outError];
            else {
                // Write the file to disk
                NSURL *newURL = [[url URLByDeletingPathExtension] URLByAppendingPathExtension:@"mp4"];
                success = [mp4File writeToUrl:newURL
                                withAttributes:attributes
                                        error:&outError];
            }

            if (success)
                [mp4File optimize];

            if (!success) {
                [item setStatus:SBBatchItemhStatusFailed];
                NSLog(@"Error: %@", [outError localizedDescription]);
            }

            [mp4File release];

            [item setStatus:SBBatchItemStatusCompleted];

            // Update the UI
            dispatch_async(dispatch_get_main_queue(), ^{
                NSInteger itemIndex = [itemsArray indexOfObject:item];
                [tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:itemIndex] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
            });
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [countLabel setStringValue:@"Done."];
            [spinningIndicator setHidden:YES];
            [spinningIndicator stopAnimation:self];
            [start setEnabled:YES];
            [open setEnabled:YES];

            status = SBBatchStatusCompleted;
        });
    });
    
    [itemsArray release];
    [attributes release];
}

- (IBAction)open:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = YES;
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = YES;
    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"mp4", @"m4v", @"m4a", @"mov",
                                @"aac", @"h264", @"264", @"ac3",
                                @"txt", @"srt", @"smi", @"scc", @"mkv", nil]];

    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            for (NSURL *url in [panel URLs]) {
                [filesArray addObject:[SBBatchItem itemWithURL:url]];
            }
            [countLabel setStringValue:[NSString stringWithFormat:@"%ld files in queue.", [filesArray count]]];
            [tableView reloadData];
        }
    }];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [filesArray count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    if ([aTableColumn.identifier isEqualToString:@"nameColumn"])
        return [[[filesArray objectAtIndex:rowIndex] URL] lastPathComponent];

    if ([aTableColumn.identifier isEqualToString:@"statusColumn"]) {
        SBBatchItemStatus batchStatus = [[filesArray objectAtIndex:rowIndex] status];
        if (batchStatus == SBBatchItemStatusCompleted)
            return [NSImage imageNamed:@"EncodeComplete"];
        else if (batchStatus == SBBatchItemStatusWorking)
            return [NSImage imageNamed:@"EncodeWorking"];
        else if (batchStatus == SBBatchItemhStatusFailed)
            return [NSImage imageNamed:@"EncodeFailed"];
        else
            return [NSImage imageNamed:NSImageNameFollowLinkFreestandingTemplate];
    }

    return nil;
}

- (void)_deleteSelectionFromTableView:(NSTableView *)aTableView
{
    NSIndexSet *rowIndexes = [aTableView selectedRowIndexes];
    NSUInteger selectedIndex = [rowIndexes lastIndex];

    [aTableView beginUpdates];
    [aTableView removeRowsAtIndexes:rowIndexes withAnimation:NSTableViewAnimationEffectFade];
    [aTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedIndex] byExtendingSelection:NO];
    [filesArray removeObjectsAtIndexes:rowIndexes];
    [aTableView endUpdates];

    if (status != SBBatchStatusWorking) {
        [countLabel setStringValue:[NSString stringWithFormat:@"%ld files in queue.", [filesArray count]]];
    }
}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
    // Copy the row numbers to the pasteboard.    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pboard declareTypes:[NSArray arrayWithObject:SublerBatchTableViewDataType] owner:self];
    [pboard setData:data forType:SublerBatchTableViewDataType];
    return YES;
}

- (NSDragOperation) tableView: (NSTableView *) view
                 validateDrop: (id <NSDraggingInfo>) info
                  proposedRow: (NSInteger) row
        proposedDropOperation: (NSTableViewDropOperation) operation
{
    if (nil == [info draggingSource]) { // From other application
        [view setDropRow: row dropOperation: NSTableViewDropAbove];
        return NSDragOperationCopy;
    }
    else if (view == [info draggingSource] && operation == NSTableViewDropAbove) { // From self
        return NSDragOperationEvery;
    }
    else { // From other documents 
        [view setDropRow: row dropOperation: NSTableViewDropAbove];
        return NSDragOperationCopy;
    }
}

- (BOOL) tableView: (NSTableView *) view
        acceptDrop: (id <NSDraggingInfo>) info
               row: (NSInteger) row
     dropOperation: (NSTableViewDropOperation) operation
{
    NSPasteboard *pboard = [info draggingPasteboard];

    if (tableView == [info draggingSource]) { // From self
        NSData* rowData = [pboard dataForType:SublerBatchTableViewDataType];
        NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
        NSInteger dragRow = [rowIndexes firstIndex];

        id object = [[filesArray objectAtIndex:dragRow] retain];

        [filesArray removeObjectAtIndex:dragRow];
        if (row > [filesArray count] || row > dragRow)
            row--;
        [filesArray insertObject:object atIndex:row];
        [object release];
        [view reloadData];

        return YES;
    }
    else { // From other documents
        if ( [[pboard types] containsObject:NSURLPboardType] ) {
            NSArray * items = [pboard readObjectsForClasses:
                               [NSArray arrayWithObject: [NSURL class]] options: nil];
            for (NSURL * url in items)
                [filesArray insertObject:[SBBatchItem itemWithURL:url] atIndex:row];
            
            [countLabel setStringValue:[NSString stringWithFormat:@"%ld files in queue.", [filesArray count]]];
            [tableView reloadData];
            
            return YES;
        }
    }

    return NO;
}

@end
