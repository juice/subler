//
//  MP42VideoTrack.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42Track.h"

@interface MP42VideoTrack : MP42Track <NSCoding> {
    uint64_t width, height;
    float trackWidth, trackHeight;
    uint64_t hSpacing, vSpacing;

    uint32_t offsetX, offsetY;
    uint8_t origProfile, origLevel;
    uint8_t newProfile, newLevel;
}

@property(readwrite) uint64_t width;
@property(readwrite) uint64_t height;

@property(readwrite) float trackWidth;
@property(readwrite) float trackHeight;

@property(readwrite) uint64_t hSpacing;
@property(readwrite) uint64_t vSpacing;

@property(readwrite) uint32_t offsetX;
@property(readwrite) uint32_t offsetY;

@property(readwrite) uint8_t origProfile;
@property(readwrite) uint8_t origLevel;
@property(readwrite) uint8_t newProfile;
@property(readwrite) uint8_t newLevel;

@end
