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

extern NSString * const SBMonoMixdown;
extern NSString * const SBStereoMixdown;
extern NSString * const SBDolbyMixdown;
extern NSString * const SBDolbyPlIIMixdown;

typedef enum {  TRACK_DISABLED = 0x0,
    TRACK_ENABLED = 0x1,
    TRACK_IN_MOVIE = 0x2,
    TRACK_IN_PREVIEW = 0x4,
    TRACK_IN_POSTER = 0x8
} track_header_flags;

NSString* SMPTEStringFromTime(long long time, long timeScale);
MP4Duration TimeFromSMPTEString( NSString* SMPTE_string, MP4Duration timeScale );

int enableTrack(MP4FileHandle fileHandle, MP4TrackId trackId);
int disableTrack(MP4FileHandle fileHandle, MP4TrackId trackId);

int enableFirstSubtitleTrack(MP4FileHandle fileHandle);
int enableFirstAudioTrack(MP4FileHandle fileHandle);
int updateTracksCount(MP4FileHandle fileHandle);
void updateMoovDuration(MP4FileHandle fileHandle);

MP4TrackId findChapterTrackId(MP4FileHandle fileHandle);
void removeAllChapterTrackReferences(MP4FileHandle fileHandle);
MP4TrackId findFirstVideoTrack(MP4FileHandle fileHandle);

uint16_t getFixedVideoWidth(MP4FileHandle fileHandle, MP4TrackId videoTrack);

NSString* getTrackName(MP4FileHandle fileHandle, MP4TrackId videoTrack);
NSString* getHumanReadableTrackMediaDataName(MP4FileHandle fileHandle, MP4TrackId videoTrack);
NSString* getHumanReadableTrackLanguage(MP4FileHandle fileHandle, MP4TrackId videoTrack);
NSString* getFilenameLanguage(CFStringRef filename);

ComponentResult ReadESDSDescExt(void* descExt, UInt8 **buffer, int *size, int versionFlags);
CFDataRef DescExt_XiphVorbis(UInt32 codecPrivateSize, const void * codecPrivate);
CFDataRef DescExt_XiphFLAC(UInt32 codecPrivateSize, const void * codecPrivate);

BOOL isTrackMuxable(NSString * formatName);
BOOL trackNeedConversion(NSString * formatName);

int64_t getTrackStartOffset(MP4FileHandle fileHandle, MP4TrackId Id);
void setTrackStartOffset(MP4FileHandle fileHandle, MP4TrackId Id, int64_t offset);
int copyTrackEditLists (MP4FileHandle fileHandle, MP4TrackId srcTrackId, MP4TrackId dstTrackId);