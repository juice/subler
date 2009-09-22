//
//  FileImport.m
//  Subler
//
//  Created by Damiano Galassi on 15/03/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP4FileImport.h"

@implementation MP4FileImport

- (id)initWithDelegate:(id)del andFile: (NSString *)path
{
	if (self = [super initWithWindowNibName:@"FileImport"])
	{        
		delegate = del;
        filePath = path;
        sourceFile = [[MP42File alloc] initWithExistingFile:filePath andDelegate:self];
        importCheckArray = [[NSMutableArray alloc] initWithCapacity:[sourceFile tracksCount]];

        NSInteger i = [sourceFile tracksCount];
        while (i) {
            [importCheckArray addObject: [NSNumber numberWithBool:YES]];
            i--;
        }
    }

	return self;
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    if( !sourceFile )
        return 0;

    return [sourceFile tracksCount];
}

- (id) tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
    MP42Track *track = [sourceFile trackAtIndex:rowIndex];

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
    NSInteger i;

    for (i = 0; i < [sourceFile tracksCount]; i++) {
        if ([[importCheckArray objectAtIndex: i] boolValue]) {
            MP42Track* track = [sourceFile trackAtIndex:i];
            track.sourceInputType = MP42SourceTypeMP4;
            [tracks addObject:track];
        }
    }

    if ([delegate respondsToSelector:@selector(importDone:)]) 
        [delegate importDone:tracks];
    [tracks release];
}

- (void) dealloc
{
    [sourceFile release];
    [importCheckArray release];
    [super dealloc];
}

@end
