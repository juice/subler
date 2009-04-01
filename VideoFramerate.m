//
//  VideoFramerate.m
//  Subler
//
//  Created by Damiano Galassi on 01/04/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "VideoFramerate.h"
#import "MP42File.h"

@implementation VideoFramerate

- (id)initWithDelegate:(id)del andFile: (NSString *)path
{
	if (self = [super initWithWindowNibName:@"VideoFramerate"])
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

- (IBAction) addTracks: (id) sender
{   
    NSMutableArray *tracks = [[NSMutableArray alloc] init];

    MP42VideoTrack *newTrack = [[MP42VideoTrack alloc] init];
    newTrack.Id = [[framerateSelection selectedItem] tag];
    newTrack.sourcePath = filePath;

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
