//
//  VideoFramerate.m
//  Subler
//
//  Created by Damiano Galassi on 01/04/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "VideoFramerate.h"
#import "MP42File.h"
#import "h264.h"

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

- (IBAction) closeWindow: (id) sender
{
    if ([delegate respondsToSelector:@selector(importDone:)]) 
        [delegate importDone:nil];
}

uint8_t H264Info(const char *filePath, uint32_t *pic_width, uint32_t *pic_height, uint8_t *profile, uint8_t *level);

- (IBAction) addTracks: (id) sender
{   
    NSMutableArray *tracks = [[NSMutableArray alloc] init];

    MP42VideoTrack *newTrack = [[MP42VideoTrack alloc] init];
    newTrack.Id = [[framerateSelection selectedItem] tag];
    newTrack.sourcePath = filePath;
    newTrack.format = @"H.264";
    newTrack.sourceInputType = MP42SourceTypeRaw;
    
    uint32_t tw, th;
    uint8_t profile, level;
    if (H264Info([filePath cStringUsingEncoding:NSASCIIStringEncoding], &tw, &th, &profile, &level)) {
        newTrack.width = newTrack.trackWidth = tw;
        newTrack.height = newTrack.trackHeight = th;
        newTrack.hSpacing = newTrack.vSpacing = 1;
        newTrack.origProfile = newTrack.newProfile = profile;
        newTrack.origLevel = newTrack.newLevel = level;
    }

    [tracks addObject:newTrack];
    [newTrack release];

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
