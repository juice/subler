//
//  FileImport.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010. All rights reserved.
//

#import "FileImport.h"
#import "MP42File.h"
#import "MP42FileImporter.h"

@implementation FileImport

- (id)initWithDelegate:(id)del andFile: (NSString *)fileUrl error:(NSError **)outError
{
	if ((self = [super initWithWindowNibName:@"FileImport"]))
	{
		delegate = del;
        file = [fileUrl retain];
        
        fileImporter = [[MP42FileImporter alloc] initWithDelegate:delegate andFile:file error:outError];
        if (!fileImporter)
            return nil;
	}
	return self;
}

- (void)awakeFromNib
{

    importCheckArray = [[NSMutableArray alloc] initWithCapacity:[[fileImporter tracksArray] count]];
    actionArray = [[NSMutableArray alloc] initWithCapacity:[[fileImporter tracksArray] count]];

    for (MP42Track *track in [fileImporter tracksArray]) {
        if (isTrackMuxable(track.format))
            [importCheckArray addObject: [NSNumber numberWithBool:YES]];
        else if(trackNeedConversion(track.format))
            [importCheckArray addObject: [NSNumber numberWithBool:YES]];
        else
            [importCheckArray addObject: [NSNumber numberWithBool:NO]];
        
        if ([track.format isEqualToString:@"AC-3"] &&
            [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioConvertAC3"] integerValue])
            [actionArray addObject:[NSNumber numberWithInteger:[[[NSUserDefaults standardUserDefaults]
                                                                 valueForKey:@"SBAudioMixdown"] integerValue]]];
        else if (!trackNeedConversion(track.format))
            [actionArray addObject:[NSNumber numberWithInteger:0]];
        else 
            [actionArray addObject:[NSNumber numberWithInteger:[[[NSUserDefaults standardUserDefaults]
                                                                 valueForKey:@"SBAudioMixdown"] integerValue]]];

    }

    if ([fileImporter metadata])
        [importMetadata setEnabled:YES];
    else
        [importMetadata setEnabled:NO];
    
    [addTracksButton setEnabled:YES];
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    return [[fileImporter tracksArray] count];
}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
    NSCell *cell = nil;
    MP42Track *track = [[fileImporter tracksArray] objectAtIndex:rowIndex];

    if ([tableColumn.identifier isEqualToString:@"trackAction"]) {
        NSPopUpButtonCell *ratingCell = [[NSPopUpButtonCell alloc] init];
        [ratingCell setAutoenablesItems:NO];
        [ratingCell setFont:[NSFont systemFontOfSize:11]];
        [ratingCell setControlSize:NSSmallControlSize];
        [ratingCell setBordered:NO];

        if ([track isMemberOfClass:[MP42VideoTrack class]]) {
            NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:@"Passthru" action:NULL keyEquivalent:@""] autorelease];
            [item setTag:0];
            [item setEnabled:YES];
            [[ratingCell menu] addItem:item];
        }
        else if ([track isMemberOfClass:[MP42SubtitleTrack class]]) {
            NSInteger tag = 0;
            NSArray *formatArray = [NSArray arrayWithObjects:@"Passthru", @"3GPP Text", nil];
            for (NSString* format in formatArray) {
                NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:format action:NULL keyEquivalent:@""] autorelease];
                [item setTag:tag++];
                [item setEnabled:YES];
                [[ratingCell menu] addItem:item];
            }
        }
        else if ([track isMemberOfClass:[MP42AudioTrack class]]) {
            NSInteger tag = 0;
            NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:@"Passthru" action:NULL keyEquivalent:@""] autorelease];
            [item setTag:tag++];
            if (!trackNeedConversion(track.format))
                [item setEnabled:YES];
            else
                [item setEnabled:NO];
            [[ratingCell menu] addItem:item];

            NSArray *formatArray = [NSArray arrayWithObjects:@"AAC - Dolby Pro Logic II", @"AAC - Dolby Pro Logic", @"AAC - Stereo", @"AAC - Mono", @"AAC - Multi-channel", nil];
            for (NSString* format in formatArray) {
                item = [[[NSMenuItem alloc] initWithTitle:format action:NULL keyEquivalent:@""] autorelease];
                [item setTag:tag++];
                [item setEnabled:YES];
                [[ratingCell menu] addItem:item];
            }
        }
        else if ([track isMemberOfClass:[MP42ChapterTrack class]]) {
            NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:@"Text" action:NULL keyEquivalent:@""] autorelease];
            [item setTag:0];
            [item setEnabled:YES];
            [[ratingCell menu] addItem:item];
        }
        cell = ratingCell;

    }
    else
        cell = [tableColumn dataCell];
    
    return cell;
}

- (id) tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
    MP42Track *track = [[fileImporter tracksArray] objectAtIndex:rowIndex];

    if (!track)
        return nil;

    if( [tableColumn.identifier isEqualToString: @"check"] )
        return [importCheckArray objectAtIndex:rowIndex];

    if ([tableColumn.identifier isEqualToString:@"trackId"])
        return [NSString stringWithFormat:@"%d", track.Id];

    if ([tableColumn.identifier isEqualToString:@"trackName"])
        return track.name;

    if ([tableColumn.identifier isEqualToString:@"trackInfo"])
        return track.format;

    if ([tableColumn.identifier isEqualToString:@"trackDuration"])
        return [track timeString];

    if ([tableColumn.identifier isEqualToString:@"trackLanguage"])
        return track.language;

    if ([tableColumn.identifier isEqualToString:@"trackAction"])
        return [actionArray objectAtIndex:rowIndex];
    
    return nil;
}

- (void) tableView: (NSTableView *) tableView 
    setObjectValue: (id) anObject 
    forTableColumn: (NSTableColumn *) tableColumn 
               row: (NSInteger) rowIndex
{
    if ([tableColumn.identifier isEqualToString: @"check"])
        [importCheckArray replaceObjectAtIndex:rowIndex withObject:anObject];
    if ([tableColumn.identifier isEqualToString:@"trackAction"])
        [actionArray replaceObjectAtIndex:rowIndex withObject:anObject];
}

- (IBAction) closeWindow: (id) sender
{
    if ([delegate respondsToSelector:@selector(importDoneWithTracks:andMetadata:)]) 
        [delegate importDoneWithTracks:nil andMetadata:nil];
}

- (IBAction) addTracks: (id) sender
{
    NSMutableArray *tracks = [[NSMutableArray alloc] init];
    NSInteger i = 0;

    for (MP42Track * track in [fileImporter tracksArray]) {
        if ([[importCheckArray objectAtIndex: i] boolValue]) {
            NSUInteger conversion = [[actionArray objectAtIndex:i] integerValue];

            if ([track isMemberOfClass:[MP42AudioTrack class]]) {
                if (conversion)
                    track.needConversion = YES;

                switch(conversion) {
                    case 5:
                        [(MP42AudioTrack*) track setMixdownType:nil];
                        break;
                    case 4:
                        [(MP42AudioTrack*) track setMixdownType:SBMonoMixdown];
                        break;
                    case 3:
                        [(MP42AudioTrack*) track setMixdownType:SBStereoMixdown];
                        break;
                    case 2:
                        [(MP42AudioTrack*) track setMixdownType:SBDolbyMixdown];
                        break;
                    case 1:
                        [(MP42AudioTrack*) track setMixdownType:SBDolbyPlIIMixdown];
                        break;
                    default:
                        [(MP42AudioTrack*) track setMixdownType:SBDolbyPlIIMixdown];
                        break;
                }
            }
            else if ([track isMemberOfClass:[MP42SubtitleTrack class]]) {
                if (conversion)
                    track.needConversion = YES;
            }

            [track setTrackImporterHelper:fileImporter];
            [tracks addObject:track];
        }
        i++;
    }

    MP42Metadata *metadata = nil;
    if ([importMetadata state])
        metadata = [[[fileImporter metadata] retain] autorelease];

    if ([delegate respondsToSelector:@selector(importDoneWithTracks:andMetadata:)]) 
        [delegate importDoneWithTracks:tracks andMetadata: metadata];
    [tracks release];
}

- (void) dealloc
{
    [importCheckArray release];
    [actionArray release];
	[file release];
    [fileImporter release];

    [super dealloc];
}

@end
