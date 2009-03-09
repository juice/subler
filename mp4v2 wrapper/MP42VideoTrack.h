//
//  MP42SubtitleTrack.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42Track.h"

@interface MP42VideoTrack : MP42Track {
    uint16_t width, height;
    float trackWidth, trackHeight;
    uint32_t offsetX, offsetY;
}

@property(readwrite) uint16_t width;
@property(readwrite) uint16_t height;

@property(readwrite) float trackWidth;
@property(readwrite) float trackHeight;

@property(readwrite) uint32_t offsetX;
@property(readwrite) uint32_t offsetY;

@end
