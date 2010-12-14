//
//  VideoFramerate.m
//  Subler
//
//  Created by Damiano Galassi on 01/04/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "VideoFramerate.h"
#import "MP42File.h"
#import "MP42FileImporter.h"

@implementation VideoFramerate

- (id)initWithDelegate:(id)del andFile: (NSString *)path
{
	if ((self = [super initWithWindowNibName:@"VideoFramerate"]))
	{        
		delegate = del;
        filePath = [path retain];
    }

	return self;
}

- (void)awakeFromNib
{
    fileImporter = [[MP42FileImporter alloc] initWithDelegate:delegate andFile:filePath];
}

- (IBAction) closeWindow: (id) sender
{
    if ([delegate respondsToSelector:@selector(importDone:)]) 
        [delegate importDone:nil];
}

uint8_t H264Info(const char *filePath, uint32_t *pic_width, uint32_t *pic_height, uint8_t *profile, uint8_t *level);

- (IBAction) addTracks: (id) sender
{   
    NSMutableArray *tracks = [[NSMutableArray alloc] init];

    for (MP42Track * track in [fileImporter tracksArray]) {
        [track setTrackImporterHelper:fileImporter];
        [track setId:[[framerateSelection selectedItem] tag]];
        [tracks addObject:track];
    }

    if ([delegate respondsToSelector:@selector(importDone:)]) 
        [delegate importDone:tracks];
    [tracks release];
}

- (void) dealloc
{
    [filePath release];
    [super dealloc];
}

@end
