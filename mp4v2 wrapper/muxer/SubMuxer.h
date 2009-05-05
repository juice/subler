//
//  MP42SubtitleTrack.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "mp4v2.h"

int muxSRTSubtitleTrack(MP4FileHandle fileHandle, NSString* subtitlePath, uint16_t subtitleHeight, int16_t delay);

int muxMOVSubtitleTrack(MP4FileHandle fileHandle, NSString* filePath, MP4TrackId srcTrackId);

int muxMP4SubtitleTrack(MP4FileHandle fileHandle, NSString* filePath, MP4TrackId srcTrackId);
