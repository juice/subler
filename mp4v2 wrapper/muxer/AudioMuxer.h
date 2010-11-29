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

int muxAACAdtsStream(MP4FileHandle fileHandle, NSString* filePath);

int muxAC3ElementaryStream(MP4FileHandle fileHandle, NSString* filePath);

#if !__LP64__
    int muxMOVAudioTrack(MP4FileHandle fileHandle, QTMovie* srcFile, MP4TrackId srcTrackId);
#endif
