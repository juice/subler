//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP42Utilities.h"
#import "SubUtilities.h"
#import <QTKit/QTKit.h>
#import <QuickTime/QuickTime.h>
#import "lang.h"

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
ComponentResult ReadESDSDescExt(void* descExt, UInt8 **buffer, int *size)
{
	UInt8 *esds = (UInt8 *) descExt;
	int tag, len;
	
	*size = 0;
	
	//esds += 4;		// version + flags
	len = readDescr(&esds, &tag);
	esds += 2;		// ID
	if (tag == MP4ESDescrTag)
		esds++;		// priority
	
	len = readDescr(&esds, &tag);
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

int muxMOVAudioTrack(MP4FileHandle fileHandle, NSString* filePath, MP4TrackId srcTrackId)
{
    OSStatus err;
    QTMovie *srcFile = [[QTMovie alloc] initWithFile:filePath error:nil];
    Media media = [[[[srcFile tracks] objectAtIndex:srcTrackId] media] quickTimeMedia];
    MP4TrackId dstTrackId = MP4_INVALID_TRACK_ID;

    // Get the sample description
	SampleDescriptionHandle desc = (SampleDescriptionHandle) NewHandle(0);
    GetMediaSampleDescription(media, 1, desc);

    SoundDescriptionHandle sndDesc = (SoundDescriptionHandle) desc;

    // Get the magic cookie
    UInt32 cookieSize;
    void* cookie;
    QTSoundDescriptionGetPropertyInfo(sndDesc,
                                      kQTPropertyClass_SoundDescription,
                                      kQTSoundDescriptionPropertyID_MagicCookie,
                                      NULL, &cookieSize, NULL);
    cookie = malloc(cookieSize);
    QTSoundDescriptionGetProperty(sndDesc,
                                  kQTPropertyClass_SoundDescription,
                                  kQTSoundDescriptionPropertyID_MagicCookie,
                                  cookieSize, cookie, &cookieSize);
    // Extract DecoderSpecific info
    UInt8* buffer;
    int size;
    ReadESDSDescExt(cookie, &buffer, &size);
    free(cookie);

    // Add audio track
    dstTrackId = MP4AddAudioTrack(fileHandle,
                                  GetMediaTimeScale(media),
                                  1024, MP4_MPEG4_AUDIO_TYPE);
    // Dunno what this does
    MP4SetAudioProfileLevel(fileHandle, 0x0F);

    // QuickTime returns a complete ESDS, but mp4v2 wants only
    // the DecoderSpecific info.
    MP4SetTrackESConfiguration(fileHandle, dstTrackId,
                               buffer, size);

    TimeValue64 sampleTableStartDecodeTime = 0;
    QTMutableSampleTableRef sampleTable = NULL;
    err = CopyMediaMutableSampleTable(media,
                                      0,
                                      &sampleTableStartDecodeTime,
                                      0,
                                      0,
                                      &sampleTable );

    SInt64 sampleIndex, sampleCount;
    sampleCount = QTSampleTableGetNumberOfSamples(sampleTable);

    for (sampleIndex = 0; sampleIndex <= sampleCount; sampleIndex++) {
        TimeValue64 sampleDecodeTime = 0;
        ByteCount sampleDataSize = 0;
        MediaSampleFlags sampleFlags = 0;
		UInt8 *sampleData = NULL;
        TimeValue64 decodeDuration = QTSampleTableGetDecodeDuration(sampleTable, sampleIndex);

        // Get the frame's data size and sample flags.  
        SampleNumToMediaDecodeTime(media, sampleIndex, &sampleDecodeTime, NULL);
		err = GetMediaSample2(media, NULL, 0, &sampleDataSize, sampleDecodeTime,
                              NULL, NULL, NULL, NULL, NULL, 1, NULL, &sampleFlags);

        // Load the frame.
		sampleData = malloc(sampleDataSize);
		err = GetMediaSample2(media, sampleData, sampleDataSize, NULL, sampleDecodeTime,
                              NULL, NULL, NULL, NULL, NULL, 1, NULL, NULL);

        err = MP4WriteSample(fileHandle,
                             dstTrackId,
                             sampleData,
                             sampleDataSize,
                             decodeDuration,
                             0, true);
        free(sampleData);
    }

    QTSampleTableRelease(sampleTable);
    [srcFile release];

    return dstTrackId;
}

int muxMP4AudioTrack(MP4FileHandle fileHandle, NSString* filePath, MP4TrackId srcTrackId)
{
    MP4FileHandle srcFile = MP4Read([filePath UTF8String], MP4_DETAILS_ERROR);
    MP4TrackId dstTrackId = MP4_INVALID_TRACK_ID;
    const char* dataName = MP4GetTrackMediaDataName(srcFile, srcTrackId);
    if (!strcmp(dataName, "ac-3")) {
        uint64_t samplerate, fscod, bsid, bsmod, acmod, lfeon, bit_rate_code;
        samplerate = MP4GetTrackTimeScale(srcFile, srcTrackId);
        MP4GetTrackIntegerProperty(srcFile, srcTrackId, "mdia.minf.stbl.stsd.ac-3.dac3.fscod", &fscod);
        MP4GetTrackIntegerProperty(srcFile, srcTrackId, "mdia.minf.stbl.stsd.ac-3.dac3.bsid", &bsid);
        MP4GetTrackIntegerProperty(srcFile, srcTrackId, "mdia.minf.stbl.stsd.ac-3.dac3.bsmod", &bsmod);
        MP4GetTrackIntegerProperty(srcFile, srcTrackId, "mdia.minf.stbl.stsd.ac-3.dac3.acmod", &acmod);
        MP4GetTrackIntegerProperty(srcFile, srcTrackId, "mdia.minf.stbl.stsd.ac-3.dac3.lfeon", &lfeon);
        MP4GetTrackIntegerProperty(srcFile, srcTrackId, "mdia.minf.stbl.stsd.ac-3.dac3.bit_rate_code", &bit_rate_code);

        dstTrackId = MP4AddAC3AudioTrack(
                            fileHandle,
                            samplerate, 
                            fscod,
                            bsid,
                            bsmod,
                            acmod,
                            lfeon,
                            bit_rate_code);
    }
    else
        dstTrackId = MP4CloneTrack(srcFile, srcTrackId, fileHandle, MP4_INVALID_TRACK_ID);

    if (dstTrackId == MP4_INVALID_TRACK_ID) {
        MP4Close(srcFile);
        return dstTrackId;
    }

    MP4SampleId sampleId = 0;
    MP4SampleId numSamples = MP4GetTrackNumberOfSamples(srcFile, srcTrackId);

    while (true) {
        MP4Duration sampleDuration = MP4_INVALID_DURATION;

        sampleId++;
        if (sampleId > numSamples)
            break;

        bool rc = false;
        rc = MP4CopySample(srcFile,
                           srcTrackId,
                           sampleId,
                           fileHandle,
                           dstTrackId,
                           sampleDuration);
        
        if (!rc) {
            MP4DeleteTrack(fileHandle, dstTrackId);
            MP4Close(srcFile);
            return MP4_INVALID_TRACK_ID;
        }
    }

    uint32_t i = 1, trackEditCount = MP4GetTrackNumberOfEdits(srcFile, srcTrackId);
    while (i <= trackEditCount) {
        MP4Timestamp editMediaStart = MP4GetTrackEditMediaStart(srcFile, srcTrackId, i);
        MP4Duration editDuration = MP4GetTrackEditDuration(srcFile, srcTrackId, i);
        int8_t editDwell = MP4GetTrackEditDwell(srcFile, srcTrackId, i);

        MP4AddTrackEdit(fileHandle, dstTrackId, i, editMediaStart, editDuration, editDwell);
        i++;
    }

    MP4Close(srcFile);

    return dstTrackId;
}
