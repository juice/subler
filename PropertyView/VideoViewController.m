//
//  PropertyViewController.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
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

- (IBAction) setSize: (id) sender
{
    NSInteger i;

    if (sender == trackWidth) {
        i = [trackWidth integerValue];
        if (track.trackWidth != i) {
            track.trackWidth = i;

            [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
            track.isEdited = YES;
        }
    }
    else if (sender == trackHeight) {
        i = [trackHeight integerValue];
        if (track.trackHeight != i) {
            track.trackHeight = i;

            [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
            track.isEdited = YES;
        }
    }
    else if (sender == offsetX) {
        i = [offsetX integerValue];
        if (track.offsetX != i) {
            track.offsetX = i;

            [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
            track.isEdited = YES;
        }
    }
    else if (sender == offsetY) {
        i = [offsetY integerValue];
        if (track.offsetY != i) {
            track.offsetY = i;

            [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
            track.isEdited = YES;
        }
    }
}

@end
