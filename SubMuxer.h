//
//  SubMuxer.h
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SubUtilities.h"

typedef enum {  TRACK_DISABLED = 0x0,
    TRACK_ENABLED = 0x1,
    TRACK_IN_MOVIE = 0x2,
    TRACK_IN_PREVIEW = 0x4,
    TRACK_IN_POSTER = 0x8
} track_header_flags;

@interface SubMuxer : NSObject {

}

int muxSubtitleTrack(NSString* filePath, NSString* subtitlePath, const char* lang, uint16_t subtitleHeight, int16_t delay);

@end
