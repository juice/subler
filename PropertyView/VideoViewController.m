//
//  PropertyViewController.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "VideoViewController.h"


@implementation VideoViewController

static NSString *getProfileName(uint8_t profile) {
    switch (profile) {
        case 66:
            return @"Baseline";
        case 77:
            return @"Main";
        case 88:
            return @"Extended";
        case 100:
            return @"High";
        case 110:
            return @"High 10";
        case 122:
            return @"High 4:2:2";
        case 144:
            return @"High 4:4:4";
        default:
            return @"Unknown profile";
    }
}

static NSString *getLevelName(uint8_t level) {
    switch (level) {
        case 10:
        case 20:
        case 30:
        case 40:
        case 50:
            return [NSString stringWithFormat:@"%u", level/10];
        case 11:
        case 12:
        case 13:
        case 21:
        case 22:
        case 31:
        case 32:
        case 41:
        case 42:
        case 51:
            return [NSString stringWithFormat:@"%u.%u", level/10, level % 10];
        default:
            return [NSString stringWithFormat:@"unknown level %x", level];
    }
}

- (void) awakeFromNib
{
    [sampleWidth setStringValue: [NSString stringWithFormat:@"%lld", track.width]];
    [sampleHeight setStringValue: [NSString stringWithFormat:@"%lld", track.height]];
    
    [trackWidth setStringValue: [NSString stringWithFormat:@"%d", (uint16_t)track.trackWidth]];
    [trackHeight setStringValue: [NSString stringWithFormat:@"%d", (uint16_t)track.trackHeight]];

    [hSpacing setStringValue: [NSString stringWithFormat:@"%lld", track.hSpacing]];
    [vSpacing setStringValue: [NSString stringWithFormat:@"%lld", track.vSpacing]];

    [offsetX setStringValue: [NSString stringWithFormat:@"%d", track.offsetX]];
    [offsetY setStringValue: [NSString stringWithFormat:@"%d", track.offsetY]];
    
    [alternateGroup selectItemAtIndex:track.alternate_group];

    if ([track.format isEqualToString:@"H.264"] && track.origProfile && track.origLevel) {
        [profileLevelUnchanged setTitle:[NSString stringWithFormat:@"Current profile: %@ @ %@", 
                                         getProfileName(track.origProfile), getLevelName(track.origLevel)]];
        if ((track.origProfile == track.newProfile) && (track.origLevel == track.newLevel)) {
            [videoProfile selectItemWithTag:1];
        } else {
            if ((track.newProfile == 66) && (track.newLevel == 21)) {
                [videoProfile selectItemWithTag:6621];
            } else if ((track.newProfile == 77) && (track.newLevel == 31)) {
                [videoProfile selectItemWithTag:7731];
            } else if ((track.newProfile == 100) && (track.newLevel == 31)) {
                [videoProfile selectItemWithTag:10031];
            } else if ((track.newProfile == 100) && (track.newLevel == 41)) {
                [videoProfile selectItemWithTag:10041];
            }
        }
    } else {
        [videoProfile setEnabled:NO];
    }
    
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

- (IBAction) setProfileLevel: (id) sender
{
    NSInteger tagName = [[sender selectedItem] tag];
    switch (tagName) {
        case 1:
            track.newProfile = track.origProfile;
            track.newLevel = track.origLevel;
            [track.updatedProperty setValue:nil forKey:@"profile"];
            [track.updatedProperty setValue:nil forKey:@"level"];
            return;
        case 6621:
            track.newProfile = 66;
            track.newLevel = 21;
            break;
        case 7731:
            track.newProfile = 77;
            track.newLevel = 31;
            break;
        case 10031:
            track.newProfile = 100;
            track.newLevel = 31;
            break;
        case 10041:
            track.newProfile = 100;
            track.newLevel = 41;
            break;
        default:
            return;
    }
    [[[[[self view]window] windowController] document] updateChangeCount:NSChangeDone];
    [track.updatedProperty setValue:@"True" forKey:@"profile"];
    [track.updatedProperty setValue:@"True" forKey:@"level"];
    track.isEdited = YES;
}

@end
