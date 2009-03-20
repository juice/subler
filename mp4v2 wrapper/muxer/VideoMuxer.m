//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP42Utilities.h"
#import "SubUtilities.h"
#import "lang.h"

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
