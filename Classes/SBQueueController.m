//
//  SBQueueController.m
//  Subler
//
//  Created by Damiano Galassi on 12/08/11.
//  Copyright 2011 Damiano Galassi. All rights reserved.
//

#import "SBQueueController.h"
#import "SBQueueItem.h"
#import "MP42File.h"
#import "MP42FileImporter.h"
#import "MetadataSearchController.h"

#define SublerBatchTableViewDataType @"SublerBatchTableViewDataType"
#define kOptionsPanelHeight 88

static SBQueueController *sharedController = nil;

@implementation SBQueueController

@synthesize status;

+ (SBQueueController*)sharedController
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

- (NSMenuItem*)prepareDestPopupItem:(NSURL*) dest
{
    NSMenuItem *folderItem = [[NSMenuItem alloc] initWithTitle:[dest lastPathComponent] action:@selector(destination:) keyEquivalent:@""];
    [folderItem setTag:10];

    NSImage* menuItemIcon = [[NSWorkspace sharedWorkspace] iconForFile:[dest path]];
    [menuItemIcon setSize:NSMakeSize(16, 16)];

    [folderItem setImage:menuItemIcon];

    return [folderItem autorelease];
}

- (void)prepareDestPopup
{
    NSMenuItem *folderItem = nil;

    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"SBQueueDestination"])
        destination = [[NSURL fileURLWithPath:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBQueueDestination"]] retain];

    else {
        NSArray *allPaths = NSSearchPathForDirectoriesInDomains(NSMoviesDirectory,
                                                                NSUserDomainMask,
                                                                YES);
        if ([allPaths count])
            destination = [[NSURL fileURLWithPath:[allPaths lastObject]] retain];;
    }

    folderItem = [self prepareDestPopupItem:destination];

    [[destButton menu] insertItem:[NSMenuItem separatorItem] atIndex:0];
    [[destButton menu] insertItem:folderItem atIndex:0];

    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SBQueueDestinationSelected"] boolValue]) {
        [destButton selectItem:folderItem];
        customDestination = YES;
    }
}

- (IBAction)destination:(id)sender
{
    if ([sender tag] == 10) {
        customDestination = YES;
        [[NSUserDefaults standardUserDefaults] setValue:@"YES" forKey:@"SBQueueDestinationSelected"];
    }
    else {
        customDestination = NO;
        [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"SBQueueDestinationSelected"];
    }
}

- (void)awakeFromNib
{
    [spinningIndicator setHidden:YES];
    [countLabel setStringValue:@"Empty"];

    NSRect frame = [[self window] frame];
    frame.size.height -= kOptionsPanelHeight;
    frame.origin.y += kOptionsPanelHeight;

    [tableScrollView setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
    [optionsBox setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];

    [[self window] setFrame:frame display:YES animate:NO];

    [tableScrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [optionsBox setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];

    docImg = [[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode('MOOV')] retain];
    [docImg setSize:NSMakeSize(16, 16)];
    
    [self prepareDestPopup];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [tableView registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, SublerBatchTableViewDataType, nil]];
}

- (void)updateDockTile
{
    NSInteger count = 0;
    for (SBQueueItem *item in filesArray)
        if ([item status] != SBQueueItemStatusCompleted)
            count++;

    if (count)
        [[NSApp dockTile] setBadgeLabel:[NSString stringWithFormat:@"%ld", count]];
    else
        [[NSApp dockTile] setBadgeLabel:nil];
}

- (void)updateUI
{
    [tableView reloadData];
    if (status != SBQueueStatusWorking) {
        [countLabel setStringValue:[NSString stringWithFormat:@"%ld files in queue.", [filesArray count]]];
        [self updateDockTile];
    }
}

- (void)addItem:(SBQueueItem*)item
{
    [filesArray addObject:item];

    [self updateUI];

    if ([AutoStartOption state])
        [self start:self];
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
    NSString *type;
    MP42File *mp4File = nil;

    [url getResourceValue:&type forKey:NSURLTypeIdentifierKey error:outError];

    if ([type isEqualToString:@"com.apple.m4a-audio"] || [type isEqualToString:@"com.apple.m4v-video"] || [type isEqualToString:@"public.mpeg-4"]) {
        mp4File = [[MP42File alloc] initWithExistingFile:url andDelegate:self];
    }
    else {
        mp4File = [[MP42File alloc] initWithDelegate:self];
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
    }

    // Search for external subtitles files
    NSArray *subtitles = [self loadSubtitles:url];
    for (MP42SubtitleTrack *subTrack in subtitles)
        [mp4File addTrack:subTrack];

    // Search for metadata
    if ([MetadataOption state]) {
        MP42Metadata *metadata = [self searchMetadataForFile:url];

        for (MP42Track *track in mp4File.tracks)
            if ([track isKindOfClass:[MP42VideoTrack class]]) {
                uint64_t tw = (uint64_t) [((MP42VideoTrack *) track) trackWidth];
                uint64_t th = (uint64_t) [((MP42VideoTrack *) track) trackHeight];
                if ((tw >= 1024) && (th >= 720))
                    [metadata setTag:@"YES" forKey:@"HD Video"];
            }

        [[mp4File metadata] mergeMetadata:metadata];
    }

    return [mp4File autorelease];
}

- (SBQueueItem*)firstItemInQueue
{
    for (SBQueueItem *item in filesArray)
        if ([item status] != SBQueueItemStatusCompleted)
            return item;
    return nil;
}

- (void)start:(id)sender
{
    if (status == SBQueueStatusWorking)
        return;

    status = SBQueueStatusWorking;

    [start setTitle:@"Stop"];
    [countLabel setStringValue:@"Working."];
    [spinningIndicator setHidden:NO];
    [spinningIndicator startAnimation:self];
    [open setEnabled:NO];

    NSMutableDictionary * attributes = [[NSMutableDictionary alloc] init];
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"chaptersPreviewTrack"] integerValue])
        [attributes setObject:[NSNumber numberWithBool:YES] forKey:MP42CreateChaptersPreviewTrack];

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSError *outError = nil;
        BOOL success = NO;
        for (;;) {
            SBQueueItem *item = [self firstItemInQueue];
            if (item == nil)
                break;

            NSURL * url = [item URL];
            NSURL * destURL = nil;
            MP42File *mp4File = [[item mp4File] retain];
            [mp4File setDelegate:self];

            [item setStatus:SBQueueItemStatusWorking];

            // Update the UI
            dispatch_async(dispatch_get_main_queue(), ^{
                NSInteger itemIndex = [filesArray indexOfObject:item];
                [countLabel setStringValue:[NSString stringWithFormat:@"Processing file %ld of %ld.",itemIndex + 1, [filesArray count]]];
                [[NSApp dockTile] setBadgeLabel:[NSString stringWithFormat:@"%ld", [filesArray count] - itemIndex]];
                [tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:itemIndex] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
            });

            if (!mp4File && destination && customDestination) {
                destURL = [[[destination URLByAppendingPathComponent:[url lastPathComponent]] URLByDeletingPathExtension] URLByAppendingPathExtension:@"mp4"];
            }
            else
                destURL = [[url URLByDeletingPathExtension] URLByAppendingPathExtension:@"mp4"];

            // The file has been added directly to the queue
            if (!mp4File && url) {
                mp4File = [[self prepareQueueItem:url error:&outError] retain];
            }

            currentItem = mp4File;

            // We have an existing mp4 file
            if ([mp4File hasFileRepresentation] && !isCancelled)
                success = [mp4File updateMP4FileWithAttributes:attributes error:&outError];
            else if (mp4File) {
                // Write the file to disk
                if (destURL)
                    [attributes addEntriesFromDictionary:[item attributes]];
                    success = [mp4File writeToUrl:destURL
                                   withAttributes:attributes
                                            error:&outError];
            }

            if (isCancelled) {
                [item setStatus:SBQueueItemStatusCancelled];
                status = SBQueueStatusCancelled;
            }
            else if (success) {
                if ([OptimizeOption state])
                    [mp4File optimize];
                [item setStatus:SBQueueItemStatusCompleted];
            }
            else {
                [item setStatus:SBQueueItemStatusFailed];
                if (outError)
                    NSLog(@"Error: %@", [outError localizedDescription]);
            }

            [mp4File release];

            // Update the UI
            dispatch_async(dispatch_get_main_queue(), ^{
                NSInteger itemIndex = [filesArray indexOfObject:item];
                [tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:itemIndex] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
            });
            
            if (status == SBQueueStatusCancelled)
                break;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            currentItem = nil;

            if (status == SBQueueStatusCancelled) {
                [countLabel setStringValue:@"Cancelled."];
                status = SBQueueStatusCancelled;
                isCancelled = NO;
            }
            else {
                [countLabel setStringValue:@"Done."];
                status = SBQueueStatusCompleted;
            }

            [spinningIndicator setHidden:YES];
            [spinningIndicator stopAnimation:self];
            [start setTitle:@"Start"];
            [open setEnabled:YES];

            [self updateDockTile];
        });
    });

    [attributes release];
}

- (void)stop:(id)sender
{
    isCancelled = YES;
    [currentItem cancel];
}

- (IBAction)toggleStartStop:(id)sender
{
    if (status == SBQueueStatusWorking) {
        [self stop:sender];
    }
    else {
        [self start:sender];
    }
}

- (IBAction)toggleOptions:(id)sender
{
    NSInteger value = 0;
    if (optionsStatus) {
        value = -kOptionsPanelHeight;
        optionsStatus = NO;
    }
    else {
        value = kOptionsPanelHeight;
        optionsStatus = YES;
    }

    NSRect frame = [[self window] frame];
    frame.size.height += value;
    frame.origin.y -= value;

    [tableScrollView setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
    [optionsBox setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];

    [[self window] setFrame:frame display:YES animate:YES];

    [tableScrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [optionsBox setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
}

#pragma mark Open methods

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
                [filesArray addObject:[SBQueueItem itemWithURL:url]];
            }
            [self updateUI];
            
            if ([AutoStartOption state])
                [self start:self];
        }
    }];
}

- (IBAction)chooseDestination:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.canCreateDirectories = YES;

    [panel setPrompt:@"Select"];
    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            destination = [[panel URL] retain];

            NSMenuItem *folderItem = [self prepareDestPopupItem:[panel URL]];

            [[destButton menu] removeItemAtIndex:0];
            [[destButton menu] insertItem:folderItem atIndex:0];

            [destButton selectItem:folderItem];
            customDestination = YES;

            [[NSUserDefaults standardUserDefaults] setValue:[[panel URL] path] forKey:@"SBQueueDestination"];
            [[NSUserDefaults standardUserDefaults] setValue:@"YES" forKey:@"SBQueueDestinationSelected"];
        }
        else
            [destButton selectItemAtIndex:2];
    }];
}

#pragma mark TableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [filesArray count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    if ([aTableColumn.identifier isEqualToString:@"nameColumn"])
        return [[[filesArray objectAtIndex:rowIndex] URL] lastPathComponent];

    if ([aTableColumn.identifier isEqualToString:@"statusColumn"]) {
        SBQueueItemStatus batchStatus = [[filesArray objectAtIndex:rowIndex] status];
        if (batchStatus == SBQueueItemStatusCompleted)
            return [NSImage imageNamed:@"EncodeComplete"];
        else if (batchStatus == SBQueueItemStatusWorking)
            return [NSImage imageNamed:@"EncodeWorking"];
        else if (batchStatus == SBQueueItemStatusFailed)
            return [NSImage imageNamed:@"EncodeCanceled"];
        else
            return docImg;
    }

    return nil;
}

- (void)_deleteSelectionFromTableView:(NSTableView *)aTableView
{
    NSMutableIndexSet *rowIndexes = [[aTableView selectedRowIndexes] mutableCopy];
    NSUInteger selectedIndex = [rowIndexes firstIndex];

    NSArray *array = [filesArray objectsAtIndexes:rowIndexes];

    // A item with a status of SBQueueItemStatusWorking can not be removed
    for (SBQueueItem *item in array)
        if ([item status] == SBQueueItemStatusWorking)
            [rowIndexes removeIndex:[filesArray indexOfObject:item]];

    if ([rowIndexes count]) {
        if ([NSTableView instancesRespondToSelector:@selector(beginUpdates)]) {
            #if __MAC_OS_X_VERSION_MAX_ALLOWED > 1060
            [aTableView beginUpdates];
            [aTableView removeRowsAtIndexes:rowIndexes withAnimation:NSTableViewAnimationEffectFade];
            [aTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedIndex] byExtendingSelection:NO];
            [filesArray removeObjectsAtIndexes:rowIndexes];
            [aTableView endUpdates];
            #endif
        }
        else {
            [filesArray removeObjectsAtIndexes:rowIndexes];
            [aTableView reloadData];
            [aTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedIndex] byExtendingSelection:NO];
        }

        if (status != SBQueueStatusWorking) {
            [countLabel setStringValue:[NSString stringWithFormat:@"%ld files in queue.", [filesArray count]]];
            [self updateDockTile];
        }
    }
}

- (IBAction)removeSelectedItems:(id)sender
{
    [self _deleteSelectionFromTableView:tableView];
}

#pragma mark Drag & Drop

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
    else
        return NSDragOperationNone;
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

        NSArray *objects = [filesArray objectsAtIndexes:rowIndexes];
        [filesArray removeObjectsAtIndexes:rowIndexes];

        for (id object in [objects reverseObjectEnumerator]) {
            if (row > [filesArray count] || row > dragRow)
                row--;
            [filesArray insertObject:object atIndex:row];
        }

        NSIndexSet *selectionSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row, [rowIndexes count])];

        [view reloadData];
        [view selectRowIndexes:selectionSet byExtendingSelection:NO];

        return YES;
    }
    else { // From other documents
        if ( [[pboard types] containsObject:NSURLPboardType] ) {
            NSArray * items = [pboard readObjectsForClasses:
                               [NSArray arrayWithObject: [NSURL class]] options: nil];
            for (NSURL * url in [items reverseObjectEnumerator])
                [filesArray insertObject:[SBQueueItem itemWithURL:url] atIndex:row];

            [self updateUI];

            if ([AutoStartOption state])
                [self start:self];

            return YES;
        }
    }

    return NO;
}

@end
