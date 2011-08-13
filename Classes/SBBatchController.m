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

@implementation SBBatchController

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

- (IBAction)start:(id)sender
{
    [countLabel setStringValue:@"Working."];
    [spinningIndicator setHidden:NO];
    [spinningIndicator startAnimation:self];
    [start setEnabled:NO];
    [open setEnabled:NO];

    NSMutableDictionary * attributes = [[NSMutableDictionary alloc] init];
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"chaptersPreviewTrack"] integerValue])
        [attributes setObject:[NSNumber numberWithBool:YES] forKey:MP42CreateChaptersPreviewTrack];

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSError *outError;
        BOOL success = YES;
        for (NSURL *url in filesArray) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [countLabel setStringValue:[NSString stringWithFormat:@"Processing file %ld of %ld.",[filesArray indexOfObject:url] + 1, [filesArray count]]];
            });

            MP42File *mp4File = [[MP42File alloc] initWithDelegate:self];
            MP42FileImporter *fileImporter = [[MP42FileImporter alloc] initWithDelegate:nil
                                                                                andFile:url
                                                                                  error:&outError];

            for (MP42Track *track in [fileImporter tracksArray]) {            
                [track setTrackImporterHelper:fileImporter];
                [mp4File addTrack:track];
            }
            [fileImporter release];

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

@end
