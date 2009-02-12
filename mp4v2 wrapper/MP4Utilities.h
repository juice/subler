/*
 *  MP4Utilities.h
 *  Subler
 *
 *  Created by Damiano Galassi on 30/01/09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */

#include "mp4v2/mp4v2.h"
#import <Cocoa/Cocoa.h>

NSString *SMPTEStringFromTime(long long time, long timeScale);
int enableFirstSubtitleTrack(MP4FileHandle fileHandle);
int updateTracksCount(MP4FileHandle fileHandle);
uint64_t findChapterTrackId(MP4FileHandle fileHandle);
MP4TrackId findFirstVideoTrack(MP4FileHandle fileHandle);
