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

    [hSpacing setStringValue: [NSString stringWithFormat:@"%d", track.hSpacing]];
    [vSpacing setStringValue: [NSString stringWithFormat:@"%d", track.vSpacing]];

    [offsetX setStringValue: [NSString stringWithFormat:@"%d", track.offsetX]];
    [offsetY setStringValue: [NSString stringWithFormat:@"%d", track.offsetY]];
    
    [alternateGroup selectItemAtIndex:track.alternate_group];
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
            if ([preserveAspectRatio state] == NSOnState) {
                track.trackHeight = (track.trackHeight / track.trackWidth) * i;
                [trackHeight setIntegerValue:track.trackHeight];
            }
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

- (IBAction) setPixelAspect: (id) sender
{
    NSInteger i;
    
    if (sender == hSpacing) {
        i = [hSpacing integerValue];
        if (track.hSpacing != i) {
            track.hSpacing = i;
            
            [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
            track.isEdited = YES;
        }
    }
    else if (sender == vSpacing) {
        i = [vSpacing integerValue];
        if (track.vSpacing != i) {
            track.vSpacing = i;
            
            [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
            track.isEdited = YES;
        }
    }
}


- (IBAction) setAltenateGroup: (id) sender
{
    uint8_t tagName = [[sender selectedItem] tag];
    
    if (track.alternate_group != tagName) {
        track.alternate_group = tagName;
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
    }
}

@end
