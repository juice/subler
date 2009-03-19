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
#include "lang.h"

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
        
        if (!strcmp(trackType, MP4_SUBTITLE_TRACK_TYPE))
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

uint16_t getFixedVideoWidth(MP4FileHandle fileHandle, MP4TrackId Id)
{
    uint16_t videoWidth;
    uint64_t hSpacing, vSpacing;

    videoWidth = MP4GetTrackVideoWidth(fileHandle, Id);

    if (MP4HaveTrackAtom(fileHandle, Id, "mdia.minf.stbl.stsd.avc1.pasp")) {
        MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.avc1.pasp.hSpacing", &hSpacing);
        MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.avc1.pasp.vSpacing", &vSpacing);
        return (float) videoWidth / vSpacing * hSpacing;
    }
    else if (MP4HaveTrackAtom(fileHandle, Id, "mdia.minf.stbl.stsd.mp4v.pasp")) {
        MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.mp4v.pasp.hSpacing", &hSpacing);
        MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.mp4v.pasp.vSpacing", &vSpacing);
        return (float) videoWidth / vSpacing * hSpacing;
    }
    
    return videoWidth;
}

NSString* getTrackName(MP4FileHandle fileHandle, MP4TrackId Id)
{
    char *trackName;

    if (MP4GetTrackName(fileHandle, Id, &trackName)) {
        NSString * name = [NSString stringWithCString: trackName];
        free(trackName);
        return name;
    }

    const char* type = MP4GetTrackType(fileHandle, Id);
    if (!strcmp(type, MP4_AUDIO_TRACK_TYPE))
        return NSLocalizedString(@"Audio Track", @"Audio Track");
    else if (!strcmp(type, MP4_VIDEO_TRACK_TYPE))
        return NSLocalizedString(@"Video Track", @"Video Track");
    else if (!strcmp(type, MP4_TEXT_TRACK_TYPE))
        return NSLocalizedString(@"Text Track", @"Text Track");
    else if (!strcmp(type, MP4_SUBTITLE_TRACK_TYPE))
        return NSLocalizedString(@"Subtitle Track", @"Subtitle Track");
    else
        return NSLocalizedString(@"Unknown Track", @"Unknown Track");
}

NSString* getHumanReadableTrackMediaDataName(MP4FileHandle fileHandle, MP4TrackId Id)
{
    const char* dataName = MP4GetTrackMediaDataName(fileHandle, Id);
    if (!strcmp(dataName, "avc1"))
        return @"H.264";
    else if (!strcmp(dataName, "mp4a"))
        return @"AAC";
    else if (!strcmp(dataName, "ac-3"))
        return @"AC-3";
    else if (!strcmp(dataName, "mp4v"))
        return @"MPEG-4 Visual";
    else if (!strcmp(dataName, "text"))
        return @"Text";
    else if (!strcmp(dataName, "tx3g"))
        return @"3GPP Text";
    else if (!strcmp(dataName, "samr"))
        return @"AMR Narrow Band";
    else if (!strcmp(dataName, "rtp "))
        return @"Hint";

    else
        return NSLocalizedString(@"Unknown", @"Unknown");
}

NSString* getHumanReadableTrackLanguage(MP4FileHandle fileHandle, MP4TrackId Id)
{
    NSString *language;
    char lang[4] = "";
    MP4GetTrackLanguage(fileHandle, Id, lang);
    language = [NSString stringWithFormat:@"%s", lang_for_code2(lang)->eng_name];

    return language;
}

// if the subtitle filename is something like title.en.srt or movie.fre.srt
// this function detects it and returns the subtitle language
NSString* getFilenameLanguage(CFStringRef filename)
{
	CFRange findResult;
	CFStringRef baseName = NULL;
	CFStringRef langStr = NULL;
	NSString *lang = @"English";

	// find and strip the extension
	findResult = CFStringFind(filename, CFSTR("."), kCFCompareBackwards);
	findResult.length = findResult.location;
	findResult.location = 0;
	baseName = CFStringCreateWithSubstring(NULL, filename, findResult);

	// then find the previous period
	findResult = CFStringFind(baseName, CFSTR("."), kCFCompareBackwards);
	findResult.location++;
	findResult.length = CFStringGetLength(baseName) - findResult.location;

	// check for 3 char language code
	if (findResult.length == 3) {
		char langCStr[4] = "";

		langStr = CFStringCreateWithSubstring(NULL, baseName, findResult);
		CFStringGetCString(langStr, langCStr, 4, kCFStringEncodingASCII);
        lang = [NSString stringWithFormat:@"%s", lang_for_code2(langCStr)->eng_name];

		CFRelease(langStr);

		// and for a 2 char language code
	} else if (findResult.length == 2) {
		char langCStr[3] = "";

		langStr = CFStringCreateWithSubstring(NULL, baseName, findResult);
		CFStringGetCString(langStr, langCStr, 3, kCFStringEncodingASCII);
        lang = [NSString stringWithFormat:@"%s", lang_for_code2(langCStr)->eng_name];

		CFRelease(langStr);
	}

	CFRelease(baseName);
	return lang;
}
