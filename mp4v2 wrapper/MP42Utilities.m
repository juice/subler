/*
 *  MP42Utilities.c
 *  Subler
 *
 *  Created by Damiano Galassi on 30/01/09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */

#import "MP42Utilities.h"
#import <string.h>

typedef enum {  TRACK_DISABLED = 0x0,
                TRACK_ENABLED = 0x1,
                TRACK_IN_MOVIE = 0x2,
                TRACK_IN_PREVIEW = 0x4,
                TRACK_IN_POSTER = 0x8
} track_header_flags;

NSString *SMPTEStringFromTime( long long time, long timeScale )
{
    NSString *SMPTE_string;
    int days, hour, minute, second, frame;
    long long result;

    // timeScale is fps * 100
    result = time / timeScale; // second
    frame = (time % timeScale) / 10;

    second = result % 60;

    result = result / 60; // minute
    minute = result % 60;

    result = result / 60; // hour
    hour = result % 24;

    days = result;

    SMPTE_string = [NSString stringWithFormat:@"%d:%02d:%02d:%02d", hour, minute, second, frame]; // h:mm:ss:ff

    return SMPTE_string;
}

int enableTrack(MP4FileHandle fileHandle, MP4TrackId trackId)
{
    return MP4SetTrackIntegerProperty(fileHandle, trackId, "tkhd.flags", (TRACK_ENABLED | TRACK_IN_MOVIE));
}

int disableTrack(MP4FileHandle fileHandle, MP4TrackId trackId)
{
    return MP4SetTrackIntegerProperty(fileHandle, trackId, "tkhd.flags", (TRACK_DISABLED | TRACK_IN_MOVIE));
}

int enableFirstSubtitleTrack(MP4FileHandle fileHandle)
{
    int i, firstTrack = 0;
    for (i = 0; i < MP4GetNumberOfTracks( fileHandle, 0, 0); i++) {
        const char* trackType = MP4GetTrackType( fileHandle, MP4FindTrackId( fileHandle, i, 0, 0));
        
        if (!strcmp(trackType, "sbtl"))
            if (firstTrack++ == 0)
                enableTrack(fileHandle, MP4FindTrackId( fileHandle, i, 0, 0));
            else
                disableTrack(fileHandle, MP4FindTrackId( fileHandle, i, 0, 0));
    }
        return 0;
}

int updateTracksCount(MP4FileHandle fileHandle)
{
    MP4TrackId maxTrackId = 0;
    int i;
    for (i = 0; i< MP4GetNumberOfTracks( fileHandle, 0, 0); i++ )
        if (MP4FindTrackId(fileHandle, i, 0, 0) > maxTrackId)
            maxTrackId = MP4FindTrackId(fileHandle, i, 0, 0);

    return MP4SetIntegerProperty(fileHandle, "moov.mvhd.nextTrackId", maxTrackId + 1);
}

uint64_t findChapterTrackId(MP4FileHandle fileHandle)
{
    MP4TrackId trackId = 0;
    uint64_t trackRef;
    int i;
    for (i = 0; i< MP4GetNumberOfTracks( fileHandle, 0, 0); i++ ) {
        trackId = MP4FindTrackId(fileHandle, i, 0, 0);
        if (MP4HaveTrackAtom(fileHandle, trackId, "tref.chap")) {
            MP4GetTrackIntegerProperty(fileHandle, trackId, "tref.chap.entries.trackId", &trackRef);
            return trackRef;
        }
    }
    return 0;
}

MP4TrackId findFirstVideoTrack(MP4FileHandle fileHandle)
{
    MP4TrackId videoTrack = 0;
    int i, trackNumber = MP4GetNumberOfTracks( fileHandle, 0, 0);
    for (i = 0; i <= trackNumber; i++) {
        videoTrack = MP4FindTrackId( fileHandle, i, 0, 0);
        const char* trackType = MP4GetTrackType( fileHandle, videoTrack);
        if (!strcmp(trackType, MP4_VIDEO_TRACK_TYPE))
            return videoTrack;
    }
    return 0;
}
