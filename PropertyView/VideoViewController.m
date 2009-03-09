//
//  PropertyViewController.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "VideoViewController.h"


@implementation VideoViewController

- (void) awakeFromNib
{
    [sampleWidth setStringValue: [NSString stringWithFormat:@"%d", track.width]];
    [sampleHeight setStringValue: [NSString stringWithFormat:@"%d", track.height]];
    
    [trackWidth setStringValue: [NSString stringWithFormat:@"%d", (uint16_t)track.trackWidth]];
    [trackHeight setStringValue: [NSString stringWithFormat:@"%d", (uint16_t)track.trackHeight]];
    
    [offsetX setStringValue: [NSString stringWithFormat:@"%d", track.offsetX]];
    [offsetY setStringValue: [NSString stringWithFormat:@"%d", track.offsetY]];
}

- (void) setTrack:(MP42VideoTrack *) videoTrack
{
    track = videoTrack;
}

@end
