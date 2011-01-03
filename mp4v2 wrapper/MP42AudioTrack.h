//
//  MP42SubtitleTrack.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42Track.h"

@interface MP42AudioTrack : MP42Track {
    float volume;
    UInt32 channels;
    UInt32 channelLayoutTag;

    NSString * mixdownType;
}

@property float volume;
@property UInt32 channels;
@property UInt32 channelLayoutTag;

@property(readwrite, retain) NSString *mixdownType;

@end
