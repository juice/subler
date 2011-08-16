//
//  SBBatchController.m
//  Subler
//
//  Created by Damiano Galassi on 12/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SBBatchController.h"
#import "MP42File.h"
#import "MP42FileImporter.h"
#import "MetadataSearchController.h"

@implementation SBBatchController

@synthesize status;

- (id)init
{
    self = [super initWithWindowNibName:@"Batch"];
    if (self) {
        filesArray = [[NSMutableArray alloc] init];
    }

    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [spinningIndicator setHidden:YES];
    [countLabel setStringValue:@"Empty queue"];
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
    id  currentSearcher;
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

    return metadata;
}

- (IBAction)start:(id)sender
{
    [countLabel setStringValue:@"Working."];
    [spinningIndicator setHidden:NO];
    [spinningIndicator startAnimation:self];
    [start setEnabled:NO];
    [open setEnabled:NO];
    status = SBBatchStatusWorking;

    NSArray * urlArray = [filesArray copy];

    NSMutableDictionary * attributes = [[NSMutableDictionary alloc] init];
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"chaptersPreviewTrack"] integerValue])
        [attributes setObject:[NSNumber numberWithBool:YES] forKey:MP42CreateChaptersPreviewTrack];

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSError *outError;
        BOOL success = YES;
        for (NSURL *url in urlArray) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [countLabel setStringValue:[NSString stringWithFormat:@"Processing file %ld of %ld.",[urlArray indexOfObject:url] + 1, [urlArray count]]];
            });

            MP42File *mp4File = [[MP42File alloc] initWithDelegate:self];
            MP42FileImporter *fileImporter = [[MP42FileImporter alloc] initWithDelegate:nil
                                                                                andFile:url
                                                                                  error:&outError];

            for (MP42Track *track in [fileImporter tracksArray]) {
                if ([track.format isEqualToString:@"AC-3"] && [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioConvertAC3"] integerValue])
                    track.needConversion = YES;

                [track setTrackImporterHelper:fileImporter];
                [mp4File addTrack:track];
            }
            [fileImporter release];

            MP42Metadata *metadata = [self searchMetadataForFile:url];
            [[mp4File metadata] mergeMetadata:metadata];

            // Write the file to disk
            NSURL *newURL = [[url URLByDeletingPathExtension] URLByAppendingPathExtension:@"mp4"];
            success = [mp4File writeToUrl:newURL
                           withAttributes:attributes
                                    error:&outError];

            if (!success) {
                NSLog(@"Error: %@", [outError localizedDescription]);
            }
            [mp4File release];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [countLabel setStringValue:@"Done."];
            [spinningIndicator setHidden:YES];
            [spinningIndicator stopAnimation:self];
            [start setEnabled:YES];
            [open setEnabled:YES];
        });
    });

    [urlArray release];
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
                [filesArray addObject:url];
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
    return [[filesArray objectAtIndex:rowIndex] lastPathComponent];
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

@end
