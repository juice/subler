//
//  PropertyViewController.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MP42VideoTrack.h"
#import "MP42SubtitleTrack.h"


@interface VideoViewController : NSViewController {
    MP42VideoTrack *track;

    IBOutlet NSTextField *sampleWidth;
    IBOutlet NSTextField *sampleHeight;

    IBOutlet NSTextField *trackWidth;
    IBOutlet NSTextField *trackHeight;

    IBOutlet NSTextField *hSpacing;
    IBOutlet NSTextField *vSpacing;

    IBOutlet NSTextField *offsetX;
    IBOutlet NSTextField *offsetY;

    IBOutlet NSPopUpButton *alternateGroup;

    IBOutlet NSPopUpButton *videoProfile;
    IBOutlet NSTextField *videoProfileLabel;
    IBOutlet NSTextField *videoProfileDescription;

    IBOutlet NSPopUpButton *forcedSubs;
    IBOutlet NSTextField *forcedSubsLabel;

    IBOutlet NSButton *preserveAspectRatio;
    
    IBOutlet NSMenuItem *profileLevelUnchanged;
}

- (void) setTrack:(MP42VideoTrack *) videoTrack;
- (IBAction) setSize: (id) sender;
- (IBAction) setPixelAspect: (id) sender;
- (IBAction) setAltenateGroup: (id) sender;
- (IBAction) setProfileLevel: (id) sender;
- (IBAction) setForcedSubtitles: (id) sender;

@end
