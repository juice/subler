//
//  MP4SubtitleTrackWrapper.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MP4TrackWrapper.h"

@interface MP4SubtitleTrackWrapper : MP4TrackWrapper {
    int delay;
    int height;
}

@property(readwrite) int delay;
@property(readwrite) int height;

@end
