//
//  MP42SubtitleTrack.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MP42Track.h"

@interface MP42SubtitleTrack : MP42Track {
    int delay;
    int height;
}

@property(readwrite) int delay;
@property(readwrite) int height;

@end
