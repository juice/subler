//
//  PropertyViewController.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "SoundViewController.h"

@implementation SoundViewController

- (void) awakeFromNib
{
    [alternateGroup selectItemAtIndex:track.alternate_group];
    [fallback selectItemAtIndex:track.fallbackTrackId];
    [volume setFloatValue:track.volume * 100];
}

- (void) setTrack:(MP42AudioTrack *) soundTrack
{
    track = soundTrack;
}

- (IBAction) setTrackVolume: (id) sender
{
    float value = [sender doubleValue] / 100;
    if (track.volume != value) {
        track.volume = value;
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
    }
}

- (IBAction) setFallbackTrack: (id) sender
{
    uint8_t tagName = [[sender selectedItem] tag];
    
    if (track.fallbackTrackId != tagName) {
        track.fallbackTrackId = tagName;
        [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
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
