//
//  CCMuxer.h
//  Subler
//
//  Created by Damiano Galassi on 05/05/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "mp4v2.h"

int muxSccCCTrack(MP4FileHandle fileHandle, NSString* filePath);

#if !__LP64__
    int muxMOVCCTrack(MP4FileHandle fileHandle, NSString* filePath, MP4TrackId srcTrackId);
#endif

int muxMP4CCTrack(MP4FileHandle fileHandle, NSString* filePath, MP4TrackId srcTrackId);