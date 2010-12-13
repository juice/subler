//
//  MP42SubtitleTrack.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "mp4v2.h"
#import <QTKit/QTKit.h>

typedef struct framerate_t {
    uint32_t code;
    uint32_t timescale;
    uint32_t duration;
} framerate_t;

int muxH264ElementaryStream(MP4FileHandle fileHandle, NSString* filePath, uint32_t frameRateCode);
