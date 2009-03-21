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

int muxMOVAudioTrack(MP4FileHandle fileHandle, NSString* filePath, MP4TrackId srcTrackId)
{
    OSStatus err;
    QTMovie *srcFile = [[QTMovie alloc] initWithFile:filePath error:nil];
    MP4TrackId dstTrackId = MP4_INVALID_TRACK_ID;
    Track track = [[[srcFile tracks] objectAtIndex:srcTrackId] quickTimeTrack];
    Media media = GetTrackMedia(track);
    SInt64 sampleIndex;
    SInt64 sampleCount = GetMediaSampleCount(media);
    TimeScale timeScale = GetMediaTimeScale(media);

    // Get the sample description
	SampleDescriptionHandle desc = (SampleDescriptionHandle) NewHandle(0);
    GetMediaSampleDescription(media, 1, desc);

    SoundDescriptionHandle sndDesc = (SoundDescriptionHandle) desc;

    // get magic cookie (elementary stream descriptor)
    UInt32 cookieSize;
    void* cookie;
    QTSoundDescriptionGetPropertyInfo(sndDesc,
                                      kQTPropertyClass_SoundDescription,
                                      kQTSoundDescriptionPropertyID_MagicCookie,
                                      NULL, &cookieSize, NULL );
    cookie = malloc(cookieSize);
    QTSoundDescriptionGetProperty(sndDesc,
                                  kQTPropertyClass_SoundDescription,
                                  kQTSoundDescriptionPropertyID_MagicCookie,
                                  cookieSize, cookie, &cookieSize );

    dstTrackId = MP4AddAudioTrack(fileHandle,
                                  timeScale,
                                  1024, MP4_MPEG4_AUDIO_TYPE );
    // Dunno what this does
    MP4SetAudioProfileLevel(fileHandle, 0x0F);
    // QuickTime returns a complete ESDS, but mp4v2 wants only
    // the DecoderSpecific info.
    MP4SetTrackESConfiguration(fileHandle, dstTrackId,
                               cookie + 31, 2 );

    
    TimeValue64 sampleTableStartDecodeTime = 0;
    QTMutableSampleTableRef sampleTable = NULL;
    err = CopyMediaMutableSampleTable(media,
                                      0,
                                      &sampleTableStartDecodeTime,
                                      0,
                                      0,
                                      &sampleTable );

    for (sampleIndex = 0; sampleIndex <= sampleCount; sampleIndex++) {
        TimeValue64 sampleDecodeTime = 0;
        ByteCount sampleDataSize = 0;
        MediaSampleFlags sampleFlags = 0;
		UInt8 *sampleData = NULL;
        TimeValue64 decodeDuration = QTSampleTableGetDecodeDuration( sampleTable, sampleIndex );
        //TimeValue64 displayOffset = QTSampleTableGetDisplayOffset( sampleTable, sampleIndex );

        // Get the frame's data size and sample flags.  
        SampleNumToMediaDecodeTime( media, sampleIndex, &sampleDecodeTime, NULL );
		err = GetMediaSample2( media, NULL, 0, &sampleDataSize, sampleDecodeTime,
                              NULL, NULL, NULL, NULL, NULL, 1, NULL, &sampleFlags );
        
        // Load the frame.
		sampleData = malloc( sampleDataSize );
		err = GetMediaSample2( media, sampleData, sampleDataSize, NULL, sampleDecodeTime,
                              NULL, NULL, NULL, NULL, NULL, 1, NULL, NULL );

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
    return NO;
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
