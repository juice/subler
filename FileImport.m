//
//  FileImport.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010. All rights reserved.
//

#import "FileImport.h"
#import "MP42File.h"
#import "MP42MkvImporter.h"
#import "MP42Mp4Importer.h"
#import "MP42MovImporter.h"

@implementation FileImport

- (id)initWithDelegate:(id)del andFile: (NSString *)fileUrl
{
	if (self = [super initWithWindowNibName:@"FileImport"])
	{        
		delegate = del;
        file = [fileUrl retain];
	}
	return self;
}

- (void)awakeFromNib
{
    if ([[file pathExtension] caseInsensitiveCompare: @"mkv"] == NSOrderedSame ||
        [[file pathExtension] caseInsensitiveCompare: @"mka"] == NSOrderedSame)
        fileImporter = [[MP42MkvImporter alloc] initWithDelegate:delegate andFile:file];
    else if ([[file pathExtension] caseInsensitiveCompare: @"mp4"] == NSOrderedSame ||
             [[file pathExtension] caseInsensitiveCompare: @"m4v"] == NSOrderedSame ||
             [[file pathExtension] caseInsensitiveCompare: @"m4a"] == NSOrderedSame)
        fileImporter = [[MP42Mp4Importer alloc] initWithDelegate:delegate andFile:file];
    else if ([[file pathExtension] caseInsensitiveCompare: @"mov"] == NSOrderedSame)
        fileImporter = [[MP42MovImporter alloc] initWithDelegate:delegate andFile:file];

    importCheckArray = [[NSMutableArray alloc] initWithCapacity:[[fileImporter tracksArray] count]];

    for (MP42Track *track in [fileImporter tracksArray])
        if (isTrackMuxable(track.format))
            [importCheckArray addObject: [NSNumber numberWithBool:YES]];
        else
            [importCheckArray addObject: [NSNumber numberWithBool:NO]];

    [addTracksButton setEnabled:YES];
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    return [[fileImporter tracksArray] count];
}

- (id) tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
    MP42Track *track = [[fileImporter tracksArray] objectAtIndex:rowIndex];

    if (!track)
        return nil;

    if( [tableColumn.identifier isEqualToString: @"check"] )
        return [importCheckArray objectAtIndex: rowIndex];

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

    return nil;
}

- (void) tableView: (NSTableView *) tableView 
    setObjectValue: (id) anObject 
    forTableColumn: (NSTableColumn *) tableColumn 
               row: (NSInteger) rowIndex
{
    if ([tableColumn.identifier isEqualToString: @"check"])
        [importCheckArray replaceObjectAtIndex:rowIndex withObject:anObject];
}

- (IBAction) closeWindow: (id) sender
{
    if ([delegate respondsToSelector:@selector(importDone:)]) 
        [delegate importDone:nil];
}

- (IBAction) addTracks: (id) sender
{
    NSMutableArray *tracks = [[NSMutableArray alloc] init];
    NSInteger i = 0;

    for (MP42Track * track in [fileImporter tracksArray])
        if ([[importCheckArray objectAtIndex: i++] boolValue])
            [tracks addObject:track];

    if ([delegate respondsToSelector:@selector(importDone:)]) 
        [delegate importDone:tracks];
    [tracks release];
}

- (void) dealloc
{
    [importCheckArray release];
	[file release];
    [fileImporter release];

    [super dealloc];
}

@end
