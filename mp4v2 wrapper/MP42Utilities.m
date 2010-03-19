/*
 *  MP42Utilities.c
 *  Subler
 *
 *  Created by Damiano Galassi on 30/01/09.
 *  Copyright 2009 Damiano Galassi. All rights reserved.
 *
 */

#import "MP42Utilities.h"
#import <string.h>
#include "lang.h"

NSString *SMPTEStringFromTime( long long time, long timeScale )
{
    NSString *SMPTE_string;
    long long hour, minute, second, frame;
    long long result;

    result = time / timeScale; // second
    frame = (time % timeScale) / 10;

    second = result % 60;

    result = result / 60; // minute
    minute = result % 60;

    result = result / 60; // hour
    hour = result % 24;

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
    unsigned int i, firstTrack = 0;
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

int enableFirstAudioTrack(MP4FileHandle fileHandle)
{
    unsigned int i, firstTrack = 0;
    for (i = 0; i < MP4GetNumberOfTracks( fileHandle, 0, 0); i++) {
        const char* trackType = MP4GetTrackType( fileHandle, MP4FindTrackId( fileHandle, i, 0, 0));
        
        if (!strcmp(trackType, MP4_AUDIO_TRACK_TYPE)) {
            MP4SetTrackIntegerProperty(fileHandle, MP4FindTrackId( fileHandle, i, 0, 0), "tkhd.alternate_group", 1);
            if (firstTrack++ == 0)
                enableTrack(fileHandle, MP4FindTrackId( fileHandle, i, 0, 0));
            else
                disableTrack(fileHandle, MP4FindTrackId( fileHandle, i, 0, 0));
        }
    }
    return 0;
}

int updateTracksCount(MP4FileHandle fileHandle)
{
    MP4TrackId maxTrackId = 0;
    unsigned int i;
    for (i = 0; i< MP4GetNumberOfTracks( fileHandle, 0, 0); i++ )
        if (MP4FindTrackId(fileHandle, i, 0, 0) > maxTrackId)
            maxTrackId = MP4FindTrackId(fileHandle, i, 0, 0);

    return MP4SetIntegerProperty(fileHandle, "moov.mvhd.nextTrackId", maxTrackId + 1);
}

void updateMoovDuration(MP4FileHandle fileHandle) {
    MP4TrackId trackId = 0;
    MP4Duration maxTrackDuration = 0, trackDuration = 0;
    unsigned int i;
    for (i = 0; i< MP4GetNumberOfTracks( fileHandle, 0, 0); i++ ) {
        trackId = MP4FindTrackId(fileHandle, i, 0, 0);
        MP4GetTrackIntegerProperty(fileHandle, trackId, "tkhd.duration", &trackDuration);
        if (maxTrackDuration < trackDuration)
            maxTrackDuration = trackDuration;
    }
    MP4SetIntegerProperty(fileHandle, "moov.mvhd.duration", maxTrackDuration);
}

MP4TrackId findChapterTrackId(MP4FileHandle fileHandle)
{
    MP4TrackId trackId = 0;
    uint64_t trackRef;
    unsigned int i;
    for (i = 0; i< MP4GetNumberOfTracks( fileHandle, 0, 0); i++ ) {
        trackId = MP4FindTrackId(fileHandle, i, 0, 0);
        if (MP4HaveTrackAtom(fileHandle, trackId, "tref.chap")) {
            MP4GetTrackIntegerProperty(fileHandle, trackId, "tref.chap.entries.trackId", &trackRef);
            return (MP4TrackId) trackRef;
        }
    }
    return 0;
}

MP4TrackId findFirstVideoTrack(MP4FileHandle fileHandle)
{
    MP4TrackId videoTrack = 0;
    int i, trackNumber = MP4GetNumberOfTracks( fileHandle, 0, 0);
    if (!trackNumber)
        return 0;
    for (i = 0; i <= trackNumber; i++) {
        videoTrack = MP4FindTrackId( fileHandle, i, 0, 0);
        const char* trackType = MP4GetTrackType(fileHandle, videoTrack);
        if (trackType)
            if (!strcmp(trackType, MP4_VIDEO_TRACK_TYPE))
                return videoTrack;
    }
    return 0;
}

uint16_t getFixedVideoWidth(MP4FileHandle fileHandle, MP4TrackId Id)
{
    uint16_t videoWidth = MP4GetTrackVideoWidth(fileHandle, Id);

    if (MP4HaveTrackAtom(fileHandle, Id, "mdia.minf.stbl.stsd.*.pasp")) {
        uint64_t hSpacing, vSpacing;
        MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.*.pasp.hSpacing", &hSpacing);
        MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.*.pasp.vSpacing", &vSpacing);
        if( hSpacing > 0 && vSpacing > 0)
            return  (uint16_t) (videoWidth / (float) vSpacing * (float) hSpacing);
        else
            return videoWidth;
    }

    return videoWidth;
}

NSString* getTrackName(MP4FileHandle fileHandle, MP4TrackId Id)
{
    char *trackName;

    if (MP4GetTrackName(fileHandle, Id, &trackName)) {
        NSString * name = [NSString stringWithUTF8String: trackName];
        free(trackName);
        return name;
    }

    const char* type = MP4GetTrackType(fileHandle, Id);
    if (!strcmp(type, MP4_AUDIO_TRACK_TYPE))
        return NSLocalizedString(@"Sound Track", @"Sound Track");
    else if (!strcmp(type, MP4_VIDEO_TRACK_TYPE))
        return NSLocalizedString(@"Video Track", @"Video Track");
    else if (!strcmp(type, MP4_TEXT_TRACK_TYPE))
        return NSLocalizedString(@"Text Track", @"Text Track");
    else if (!strcmp(type, MP4_SUBTITLE_TRACK_TYPE))
        return NSLocalizedString(@"Subtitle Track", @"Subtitle Track");
    else if (!strcmp(type, "clcp"))
        return NSLocalizedString(@"Closed Caption Track", @"Closed Caption Track");
    else if (!strcmp(type, MP4_OD_TRACK_TYPE))
        return NSLocalizedString(@"MPEG-4 ODSM Track", @"MPEG-4 ODSM Track");
    else if (!strcmp(type, MP4_SCENE_TRACK_TYPE))
        return NSLocalizedString(@"MPEG-4 SDSM Track", @"MPEG-4 SDSM Track");
    else
        return NSLocalizedString(@"Unknown Track", @"Unknown Track");
}

NSString* getHumanReadableTrackMediaDataName(MP4FileHandle fileHandle, MP4TrackId Id)
{
    const char* dataName = MP4GetTrackMediaDataName(fileHandle, Id);
    if (dataName) {
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
        else if (!strcmp(dataName, "c608"))
            return @"CEA-608";
        else if (!strcmp(dataName, "c708"))
            return @"CEA-708";
        else if (!strcmp(dataName, "samr"))
            return @"AMR Narrow Band";
        else if (!strcmp(dataName, "jpeg"))
            return @"M-JPEG";
        else if (!strcmp(dataName, "rtp "))
            return @"Hint";
        else if (!strcmp(dataName, "drms"))
            return @"FairPlay Sound";
        else if (!strcmp(dataName, "drmi"))
            return @"FairPlay Video";

        else
            return [NSString stringWithUTF8String:dataName];
    }
    else {
        return @"Unknown";
    }

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

#define MP4ESDescrTag                   0x03
#define MP4DecConfigDescrTag            0x04
#define MP4DecSpecificDescrTag          0x05

// from perian
// based off of mov_mp4_read_descr_len from mov.c in ffmpeg's libavformat
static int readDescrLen(UInt8 **buffer)
{
	int len = 0;
	int count = 4;
	while (count--) {
		int c = *(*buffer)++;
		len = (len << 7) | (c & 0x7f);
		if (!(c & 0x80))
			break;
	}
	return len;
}

// based off of mov_mp4_read_descr from mov.c in ffmpeg's libavformat
static int readDescr(UInt8 **buffer, int *tag)
{
	*tag = *(*buffer)++;
	return readDescrLen(buffer);
}

// based off of mov_read_esds from mov.c in ffmpeg's libavformat
ComponentResult ReadESDSDescExt(void* descExt, UInt8 **buffer, int *size, int versionFlags)
{
	UInt8 *esds = (UInt8 *) descExt;
	int tag, len;
	*size = 0;

    if (versionFlags)
        esds += 4;		// version + flags
	readDescr(&esds, &tag);
	esds += 2;		// ID
	if (tag == MP4ESDescrTag)
		esds++;		// priority

	readDescr(&esds, &tag);
	if (tag == MP4DecConfigDescrTag) {
		esds++;		// object type id
		esds++;		// stream type
		esds += 3;	// buffer size db
		esds += 4;	// max bitrate
		esds += 4;	// average bitrate

		len = readDescr(&esds, &tag);
		if (tag == MP4DecSpecificDescrTag) {
			*buffer = calloc(1, len + 8);
			if (*buffer) {
				memcpy(*buffer, esds, len);
				*size = len;
			}
		}
	}

	return noErr;
}

BOOL isTrackMuxable(NSString * formatName)
{
    NSArray* supportedFormats = [NSArray arrayWithObjects:@"H.264", @"AAC", @"AC-3", @"3GPP Text", @"Text", @"Plain Text", @"ASS", @"SSA",
                                 @"CEA-608", nil];
    
    for (NSString* type in supportedFormats)
        if ([formatName isEqualToString:type])
            return YES;

    return NO;
}

int64_t getTrackStartOffset(MP4FileHandle fileHandle, MP4TrackId Id)
{
    MP4Duration trackDuration = 0;
    uint32_t i = 1, trackEditCount = MP4GetTrackNumberOfEdits(fileHandle, Id);

    while (i <= trackEditCount) {
        //MP4Timestamp editMediaStart = MP4GetTrackEditMediaStart(fileHandle, Id, i);
        MP4Duration editDuration = MP4GetTrackEditDuration(fileHandle, Id, i);

        //MP4Timestamp test = (uint32_t)-1;
        //if (editMediaStart == ((uint32_t)-1))
        //    NSLog(@"Edit media start = -1");

        trackDuration += editDuration;

        //int8_t editDwell = MP4GetTrackEditDwell(fileHandle, Id, i);

        //NSLog(@"Track %d, Edit Media Start = %lld, Edit duration: %qu Dwell:%d", Id, editMediaStart, editDuration, editDwell);

        i++;
    }

    return 1;
}

void setTrackStartOffset(MP4FileHandle fileHandle, MP4TrackId Id, int64_t offset)
{
    uint32_t trackEditsCount = MP4GetTrackNumberOfEdits(fileHandle, Id);

    // If there is no existing edit list, just add some new ones at the start and do the usual stuff.
    if (offset && !trackEditsCount) {
        MP4Duration editDuration, totalDuration;

        editDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                   Id,
                                                   MP4GetTrackDuration(fileHandle, Id),
                                                   MP4GetTimeScale(fileHandle));
        if (offset > 0) {
            MP4Duration delayDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                                    Id,
                                                                    offset,
                                                                    MP4GetTimeScale(fileHandle));

            MP4AddTrackEdit(fileHandle, Id, MP4_INVALID_EDIT_ID, -1, delayDuration, 0);
            MP4AddTrackEdit(fileHandle, Id, MP4_INVALID_EDIT_ID, 0, editDuration, 0);

            totalDuration = editDuration + delayDuration;
        }
        else if (offset < 0) {
            MP4Duration delayDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                                    Id,
                                                                    -offset,
                                                                    MP4GetTimeScale(fileHandle));

            MP4AddTrackEdit(fileHandle, Id, MP4_INVALID_EDIT_ID, -offset, editDuration - delayDuration, 0);
            totalDuration = editDuration - delayDuration;
        }

        // Update the duration in tkhd, the value must be the sum of the durations of all track's edits.
        MP4SetTrackIntegerProperty(fileHandle, Id, "tkhd.duration", totalDuration);

        // Update the duration in mvhd.
        updateMoovDuration(fileHandle);
    }
    // If the mp4 contains already some edits list, try to reuse them
    else if (offset && trackEditsCount) {
        if (offset > 0) {
            
        }
        else if (offset < 0) {
            
        }

        NSLog(@"Not implemented");
    }
}