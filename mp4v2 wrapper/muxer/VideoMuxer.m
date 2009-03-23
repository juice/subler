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

int muxMOVVideoTrack(MP4FileHandle fileHandle, NSString* filePath, MP4TrackId srcTrackId)
{
    OSStatus err;
    QTMovie *srcFile = [[QTMovie alloc] initWithFile:filePath error:nil];
    Track track = [[[srcFile tracks] objectAtIndex:srcTrackId] quickTimeTrack];
    Media media = GetTrackMedia(track);
    MP4TrackId dstTrackId = MP4_INVALID_TRACK_ID;
    long count;

    // Get the sample description
	SampleDescriptionHandle desc = (SampleDescriptionHandle) NewHandle(0);
    GetMediaSampleDescription(media, 1, desc);

    ImageDescriptionHandle imgDesc = (ImageDescriptionHandle) desc;

    if ((*imgDesc)->cType == kH264CodecType) {
        // Get avcC atom
        Handle imgDescHandle = NewHandle(0);
        GetImageDescriptionExtension(imgDesc, &imgDescHandle, 'avcC', 1);

        MP4SetVideoProfileLevel(fileHandle, 0x7F);
        // Add video track
        dstTrackId = MP4AddH264VideoTrack(fileHandle, GetMediaTimeScale(media),
                                          MP4_INVALID_DURATION,
                                          (*imgDesc)->width, (*imgDesc)->height,
                                          (*imgDescHandle)[1],  // AVCProfileIndication
                                          (*imgDescHandle)[2],  // profile_compat
                                          (*imgDescHandle)[3],  // AVCLevelIndication
                                          (*imgDescHandle)[4]); // lengthSizeMinusOne

        // We have got a complete avcC atom, but mp4v2 wants sps and pps separately
        SInt64 i;
        int8_t spsCount = ((*imgDescHandle)[5] & 0x1f);
        uint8_t ptrPos = 6;
        for (i = 0; i < spsCount; i++) {
            uint16_t spsSize = (*imgDescHandle)[ptrPos++] << 8 & 0xff;
            spsSize = (*imgDescHandle)[ptrPos++] & 0xff;
            MP4AddH264SequenceParameterSet(fileHandle, dstTrackId,
                                           (uint8_t *)*imgDescHandle+ptrPos, spsSize);
            ptrPos += spsSize;
        }

        int8_t ppsCount = (*imgDescHandle)[ptrPos++];
        for (i = 0; i < ppsCount; i++) {
            uint16_t ppsSize = (*imgDescHandle)[ptrPos++] << 8 & 0xff;
            ppsSize = (*imgDescHandle)[ptrPos++] & 0xff;
            MP4AddH264PictureParameterSet(fileHandle, dstTrackId,
                                      (uint8_t*)*imgDescHandle+ptrPos, ppsSize);
            ptrPos += ppsSize;
        }
        DisposeHandle(imgDescHandle);
    }
    else if ((*imgDesc)->cType == kMPEG4VisualCodecType) {
        MP4SetVideoProfileLevel(fileHandle, MPEG4_SP_L3);
        // Add video track
        dstTrackId = MP4AddVideoTrack(fileHandle, GetMediaTimeScale(media),
                                      MP4_INVALID_DURATION,
                                      (*imgDesc)->width, (*imgDesc)->height,
                                      MP4_MPEG4_VIDEO_TYPE);

        // Add ES decoder specific configuration
        CountImageDescriptionExtensionType(imgDesc, 'esds',  &count);
        if (count >= 1) {
            Handle imgDescExt = NewHandle(0);
            UInt8* buffer;
            int size;

            GetImageDescriptionExtension(imgDesc, &imgDescExt, 'esds', 1);

            ReadESDSDescExt(*imgDescExt, &buffer, &size, 1);
            MP4SetTrackESConfiguration(fileHandle, dstTrackId, buffer, size);

            DisposeHandle(imgDescExt);
        }
    }
    else
        goto bail;

    // Add pixel aspect ratio and color atom
    CountImageDescriptionExtensionType(imgDesc, kPixelAspectRatioImageDescriptionExtension, &count);
    if (count > 0) {
        Handle pasp = NewHandle(0);
        GetImageDescriptionExtension(imgDesc, &pasp, kPixelAspectRatioImageDescriptionExtension, 1);
        MP4AddPixelAspectRatio(fileHandle, dstTrackId,
                               CFSwapInt32BigToHost(((PixelAspectRatioImageDescriptionExtension*)(*pasp))->hSpacing),
                               CFSwapInt32BigToHost(((PixelAspectRatioImageDescriptionExtension*)(*pasp))->vSpacing));
        DisposeHandle(pasp);
    }

    CountImageDescriptionExtensionType(imgDesc, kColorInfoImageDescriptionExtension, &count);
    if (count > 0) {
        Handle colr = NewHandle(0);
        GetImageDescriptionExtension(imgDesc, &colr, kColorInfoImageDescriptionExtension, 1);
        MP4AddColr(fileHandle, dstTrackId,
                   CFSwapInt16BigToHost(((NCLCColorInfoImageDescriptionExtension*)(*colr))->primaries),
                   CFSwapInt16BigToHost(((NCLCColorInfoImageDescriptionExtension*)(*colr))->transferFunction),
                   CFSwapInt16BigToHost(((NCLCColorInfoImageDescriptionExtension*)(*colr))->matrix));
        DisposeHandle(colr);
    }    

    // Create a QTSampleTable which cointans all the informatio of the track samples.
    TimeValue64 sampleTableStartDecodeTime = 0;
    QTMutableSampleTableRef sampleTable = NULL;
    err = CopyMediaMutableSampleTable(media,
                                      0,
                                      &sampleTableStartDecodeTime,
                                      0,
                                      0,
                                      &sampleTable);

    TimeValue64 minDisplayOffset = 0;
    err = QTSampleTableGetProperty(sampleTable,
                                   kQTPropertyClass_SampleTable,
                                   kQTSampleTablePropertyID_MinDisplayOffset,
                                   sizeof(TimeValue64),
                                   &minDisplayOffset,
                                   NULL);

    SInt64 sampleIndex, sampleCount;
    sampleCount = QTSampleTableGetNumberOfSamples(sampleTable);

    for (sampleIndex = 1; sampleIndex <= sampleCount; sampleIndex++) {
        TimeValue64 sampleDecodeTime = 0;
        ByteCount sampleDataSize = 0;
        MediaSampleFlags sampleFlags = 0;
		UInt8 *sampleData = NULL;
        TimeValue64 decodeDuration = QTSampleTableGetDecodeDuration(sampleTable, sampleIndex);
        TimeValue64 displayOffset = QTSampleTableGetDisplayOffset(sampleTable, sampleIndex);

        // Get the frame's data size and sample flags.  
        SampleNumToMediaDecodeTime( media, sampleIndex, &sampleDecodeTime, NULL);
		sampleDataSize = QTSampleTableGetDataSizePerSample(sampleTable, sampleIndex);
        sampleFlags = QTSampleTableGetSampleFlags(sampleTable, sampleIndex);

        // Load the frame.
		sampleData = malloc(sampleDataSize);
		err = GetMediaSample2(media, sampleData, sampleDataSize, NULL, sampleDecodeTime,
                              NULL, NULL, NULL, NULL, NULL, 1, NULL, NULL);

        err = MP4WriteSample(fileHandle,
                             dstTrackId,
                             sampleData,
                             sampleDataSize,
                             decodeDuration,
                             displayOffset -minDisplayOffset,
                             !sampleFlags);
        free(sampleData);
    }

    QTSampleTableRelease(sampleTable);

    TimeValue editTrackStart, editTrackDuration;
	TimeValue64 editDisplayStart, trackDuration = 0;
    Fixed editDwell;

	// Find the first edit
	// Each edit has a starting track timestamp, a duration in track time, a starting display timestamp and a rate.
	GetTrackNextInterestingTime(track, 
                                nextTimeTrackEdit | nextTimeEdgeOK,
                                0,
                                fixed1,
                                &editTrackStart,
                                &editTrackDuration);

    while (editTrackDuration > 0) {
        editDisplayStart = TrackTimeToMediaDisplayTime(editTrackStart, track);
        editTrackDuration = (editTrackDuration / (float)GetMovieTimeScale([srcFile quickTimeMovie])) * MP4GetTimeScale(fileHandle);
        editDwell = GetTrackEditRate64(track, editTrackStart);
        
        if (minDisplayOffset < 0)
            MP4AddTrackEdit(fileHandle, dstTrackId, MP4_INVALID_EDIT_ID, editDisplayStart -minDisplayOffset,
                            editTrackDuration, !Fix2X(editDwell));
        else
            MP4AddTrackEdit(fileHandle, dstTrackId, MP4_INVALID_EDIT_ID, editDisplayStart,
                            editTrackDuration, !Fix2X(editDwell));

        trackDuration += editTrackDuration;
        // Find the next edit, skipping empty edits.
		GetTrackNextInterestingTime(track, 
                                    nextTimeTrackEdit,
                                    editTrackStart,
                                    fixed1,
                                    &editTrackStart,
                                    &editTrackDuration);
    }

    MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "tkhd.duration", trackDuration);

bail:
    [srcFile release];

    return dstTrackId;
}

int muxMP4VideoTrack(MP4FileHandle fileHandle, NSString* filePath, MP4TrackId srcTrackId)
{
    MP4FileHandle srcFile = MP4Read([filePath UTF8String], 0);
    MP4TrackId dstTrackId = MP4CloneTrack(srcFile, srcTrackId, fileHandle, MP4_INVALID_TRACK_ID);

    if (dstTrackId == MP4_INVALID_TRACK_ID) {
        MP4Close(srcFile);
        return dstTrackId;
    }

    if (MP4HaveTrackAtom(srcFile, srcTrackId, "mdia.minf.stbl.stsd.*.pasp")) {
        uint64_t hSpacing, vSpacing;
        MP4GetTrackIntegerProperty(srcFile, srcTrackId, "mdia.minf.stbl.stsd.*.pasp.hSpacing", &hSpacing);
        MP4GetTrackIntegerProperty(srcFile, srcTrackId, "mdia.minf.stbl.stsd.*.pasp.vSpacing", &vSpacing);

        MP4AddPixelAspectRatio(fileHandle, dstTrackId, hSpacing, vSpacing);
    }

    if (MP4HaveTrackAtom(srcFile, srcTrackId, "mdia.minf.stbl.stsd.*.colr")) {
        uint64_t primariesIndex, transferFunctionIndex, matrixIndex;
        MP4GetTrackIntegerProperty(srcFile, srcTrackId, "mdia.minf.stbl.stsd.*.colr.primariesIndex", &primariesIndex);
        MP4GetTrackIntegerProperty(srcFile, srcTrackId, "mdia.minf.stbl.stsd.*.colr.transferFunctionIndex", &transferFunctionIndex);
        MP4GetTrackIntegerProperty(srcFile, srcTrackId, "mdia.minf.stbl.stsd.*.colr.matrixIndex", &matrixIndex);

        MP4AddColr(fileHandle, dstTrackId, primariesIndex, transferFunctionIndex, matrixIndex);
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
