/*
 *  MP42Utilities.h
 *  Subler
 *
 *  Created by Damiano Galassi on 30/01/09.
 *  Copyright 2009 Damiano Galassi. All rights reserved.
 *
 */

#import <Foundation/Foundation.h>
#include "mp4v2.h"

typedef enum {  TRACK_DISABLED = 0x0,
    TRACK_ENABLED = 0x1,
    TRACK_IN_MOVIE = 0x2,
    TRACK_IN_PREVIEW = 0x4,
    TRACK_IN_POSTER = 0x8
} track_header_flags;

NSString* SMPTEStringFromTime(long long time, long timeScale);

int enableTrack(MP4FileHandle fileHandle, MP4TrackId trackId);
int disableTrack(MP4FileHandle fileHandle, MP4TrackId trackId);

int enableFirstSubtitleTrack(MP4FileHandle fileHandle);
int enableFirstAudioTrack(MP4FileHandle fileHandle);
int updateTracksCount(MP4FileHandle fileHandle);
void updateMoovDuration(MP4FileHandle fileHandle);

MP4TrackId findChapterTrackId(MP4FileHandle fileHandle);
MP4TrackId findFirstVideoTrack(MP4FileHandle fileHandle);

uint16_t getFixedVideoWidth(MP4FileHandle fileHandle, MP4TrackId videoTrack);

NSString* getTrackName(MP4FileHandle fileHandle, MP4TrackId videoTrack);
NSString* getHumanReadableTrackMediaDataName(MP4FileHandle fileHandle, MP4TrackId videoTrack);
NSString* getHumanReadableTrackLanguage(MP4FileHandle fileHandle, MP4TrackId videoTrack);
NSString* getFilenameLanguage(CFStringRef filename);

ComponentResult ReadESDSDescExt(void* descExt, UInt8 **buffer, int *size, int versionFlags);
BOOL isMuxableTrack(NSString * formatName);