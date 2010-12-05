//
//  CCMuxer.h
//  Subler
//
//  Created by Damiano Galassi on 05/05/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "mp4v2.h"
#import <QTKit/QTKit.h>

#if !__LP64__
    int muxMOVCCTrack(MP4FileHandle fileHandle, QTMovie* srcFile, MP4TrackId srcTrackId);
#endif