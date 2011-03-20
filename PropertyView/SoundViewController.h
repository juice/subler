//
//  PropertyViewController.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MP42AudioTrack.h"


@interface SoundViewController : NSViewController {
    MP42AudioTrack *track;
    
    IBOutlet NSSlider *volume;
    IBOutlet NSPopUpButton *alternateGroup;
    IBOutlet NSPopUpButton *fallback;
}

- (void) setTrack:(MP42AudioTrack *) soundTrack;
- (IBAction) setTrackVolume: (id) sender;
- (IBAction) setAltenateGroup: (id) sender;
- (IBAction) setFallbackTrack: (id) sender;

@end
