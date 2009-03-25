//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
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
    Media media = [[[[srcFile tracks] objectAtIndex:srcTrackId] media] quickTimeMedia];
    MP4TrackId dstTrackId = MP4_INVALID_TRACK_ID;

    // Get the sample description
	SampleDescriptionHandle desc = (SampleDescriptionHandle) NewHandle(0);
    GetMediaSampleDescription(media, 1, desc);

    SoundDescriptionHandle sndDesc = (SoundDescriptionHandle) desc;
    
    AudioStreamBasicDescription asbd = {0};
    err = QTSoundDescriptionGetProperty(sndDesc, kQTPropertyClass_SoundDescription,
                                        kQTSoundDescriptionPropertyID_AudioStreamBasicDescription,
                                        sizeof(asbd), &asbd, NULL);

    if (asbd.mFormatID == kAudioFormatMPEG4AAC) {
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
        ReadESDSDescExt(cookie, &buffer, &size, 0);
        free(cookie);

        // Add audio track
        dstTrackId = MP4AddAudioTrack(fileHandle,
                                      asbd.mSampleRate,
                                      1024, MP4_MPEG4_AUDIO_TYPE);
        // Dunno what this does
        MP4SetAudioProfileLevel(fileHandle, 0x0F);

        // QuickTime returns a complete ESDS, but mp4v2 wants only
        // the DecoderSpecific info.
        MP4SetTrackESConfiguration(fileHandle, dstTrackId,
                                   buffer, size);
    }
    else if (asbd.mFormatID == kAudioFormatAC3 || asbd.mFormatID == 0x6D732000)
    {
        uint8_t fscod = 0;
        uint8_t bsid = 8;
        uint8_t bsmod = 0;
        uint8_t acmod = 7;
        uint8_t lfeon = 1;
        uint8_t bit_rate_code = 15;

        if (asbd.mSampleRate == 48000)
                fscod = 0;
        else if (asbd.mSampleRate == 44100)
                fscod = 1;
        else if (asbd.mSampleRate == 32000)
                fscod = 2;
        else
                fscod = 3;

        dstTrackId = MP4AddAC3AudioTrack(fileHandle, asbd.mSampleRate,
                                         fscod,
                                         bsid,
                                         bsmod,
                                         acmod,
                                         lfeon,
                                         bit_rate_code);
    }
    
    enableFirstAudioTrack(fileHandle);

    // Create a QTSampleTable which cointans all the informatio of the track samples.
    TimeValue64 sampleTableStartDecodeTime = 0;
    QTMutableSampleTableRef sampleTable = NULL;
    err = CopyMediaMutableSampleTable(media,
                                      0,
                                      &sampleTableStartDecodeTime,
                                      0,
                                      0,
                                      &sampleTable );

    SInt64 sampleIndex;
    SInt64 sampleCount = QTSampleTableGetNumberOfSamples(sampleTable);

    for (sampleIndex = 1; sampleIndex <= sampleCount; sampleIndex++) {
        TimeValue64 sampleDecodeTime = 0;
        ByteCount sampleDataSize = 0;
		UInt8 *sampleData = NULL;

        // Get the frame's data size and sample flags.  
        SampleNumToMediaDecodeTime(media, sampleIndex, &sampleDecodeTime, NULL);
		sampleDataSize = QTSampleTableGetDataSizePerSample(sampleTable, sampleIndex);

        // Load the frame.
		sampleData = malloc(sampleDataSize);
		err = GetMediaSample2(media, sampleData, sampleDataSize, NULL, sampleDecodeTime,
                              NULL, NULL, NULL, NULL, NULL, 1, NULL, NULL);

        err = MP4WriteSample(fileHandle,
                             dstTrackId,
                             sampleData,
                             sampleDataSize,
                             MP4_INVALID_DURATION,
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
    enableFirstAudioTrack(fileHandle);

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

    MP4Duration trackDuration = 0;
    uint32_t i = 1, trackEditCount = MP4GetTrackNumberOfEdits(srcFile, srcTrackId);
    while (i <= trackEditCount) {
        MP4Timestamp editMediaStart = MP4GetTrackEditMediaStart(srcFile, srcTrackId, i);
        MP4Duration editDuration = MP4ConvertFromMovieDuration(srcFile,
                                                               MP4GetTrackEditDuration(srcFile, srcTrackId, i),
                                                               MP4GetTimeScale(fileHandle));
        trackDuration += editDuration;
        int8_t editDwell = MP4GetTrackEditDwell(srcFile, srcTrackId, i);
        
        MP4AddTrackEdit(fileHandle, dstTrackId, i, editMediaStart, editDuration, editDwell);
        i++;
    }
    if (trackEditCount)
        MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "tkhd.duration", trackDuration);

    MP4Close(srcFile);

    return dstTrackId;
}
