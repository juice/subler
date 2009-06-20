//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "SubMuxer.h"
#import "MP42Utilities.h"
#import "SubUtilities.h"
#import <QTKit/QTKit.h>
#if !__LP64__
    #import <QuickTime/QuickTime.h>
#endif

// Create a subtitle track and set default value for the sample description
static MP4TrackId createSubtitleTrack(MP4FileHandle fileHandle,
                                      uint16_t videoTrackWidth,
                                      uint16_t videoTrackHeight,
                                      uint16_t subtitleHeight,
                                      uint32_t timescale)
{
    const uint8_t textColor[4] = { 255,255,255,255 };
    MP4TrackId trackId = MP4AddSubtitleTrack(fileHandle, timescale, videoTrackWidth, subtitleHeight);

    MP4SetTrackDurationPerChunk(fileHandle, trackId, timescale / 8);
    MP4SetTrackIntegerProperty(fileHandle, trackId, "tkhd.alternate_group", 2);

    MP4SetTrackIntegerProperty(fileHandle, trackId, "mdia.minf.stbl.stsd.tx3g.horizontalJustification", 1);
    MP4SetTrackIntegerProperty(fileHandle, trackId, "mdia.minf.stbl.stsd.tx3g.verticalJustification", 0);

    MP4SetTrackIntegerProperty(fileHandle, trackId, "mdia.minf.stbl.stsd.tx3g.bgColorAlpha", 255);

    MP4SetTrackIntegerProperty(fileHandle, trackId, "mdia.minf.stbl.stsd.tx3g.defTextBoxBottom", subtitleHeight);
    MP4SetTrackIntegerProperty(fileHandle, trackId, "mdia.minf.stbl.stsd.tx3g.defTextBoxRight", videoTrackWidth);

    MP4SetTrackIntegerProperty(fileHandle, trackId, "mdia.minf.stbl.stsd.tx3g.fontSize", 24);

    MP4SetTrackIntegerProperty(fileHandle, trackId, "mdia.minf.stbl.stsd.tx3g.fontColorRed", textColor[0]);
    MP4SetTrackIntegerProperty(fileHandle, trackId, "mdia.minf.stbl.stsd.tx3g.fontColorGreen", textColor[1]);
    MP4SetTrackIntegerProperty(fileHandle, trackId, "mdia.minf.stbl.stsd.tx3g.fontColorBlue", textColor[2]);
    MP4SetTrackIntegerProperty(fileHandle, trackId, "mdia.minf.stbl.stsd.tx3g.fontColorAlpha", textColor[3]);

    /* translate the track */
    uint8_t* val;
    uint8_t nval[36];
    uint32_t *ptr32 = (uint32_t*) nval;
    uint32_t size;

    MP4GetTrackBytesProperty(fileHandle, trackId, "tkhd.matrix", &val, &size);
    memcpy(nval, val, size);
    ptr32[7] = CFSwapInt32HostToBig( (videoTrackHeight - subtitleHeight) * 0x10000);

    MP4SetTrackBytesProperty(fileHandle, trackId, "tkhd.matrix", nval, size);
    free(val);

    return trackId;
}

#define STYLE_BOLD 1
#define STYLE_ITALIC 2
#define STYLE_UNDERLINED 4

static u_int8_t* createStyleRecord(u_int16_t startChar, u_int16_t endChar, u_int16_t fontID, u_int8_t flags, u_int8_t* style)
{
    style[0] = (startChar >> 8) & 0xff; // startChar
    style[1] = startChar & 0xff;
    style[2] = (endChar >> 8) & 0xff;   // endChar
    style[3] = endChar & 0xff;
    style[4] = (fontID >> 8) & 0xff;    // font-ID
    style[5] = fontID & 0xff;
    style[6] = flags;   // face-style-flags: 1 bold; 2 italic; 4 underline
    style[7] = 24;      // font-size
    style[8] = 255;     // r
    style[9] = 255;     // g
    style[10] = 255;    // b
    style[11] = 255;    // a

    return style;
}

static size_t closeStyleAtom(u_int16_t styleCount, u_int8_t* styleAtom)
{
    size_t styleSize = 10 + (styleCount * 12);
    styleAtom[0] = 0;
    styleAtom[1] = 0;
    styleAtom[2] = (styleSize >> 8) & 0xff;
    styleAtom[3] = styleSize & 0xff;
    styleAtom[8] = (styleCount >> 8) & 0xff;
    styleAtom[9] = styleCount & 0xff;

    return styleSize;
}

static NSString* createStyleAtomForString(NSString* string, u_int8_t* buffer, size_t *size)
{
    u_int16_t styleCount = 0;
    memcpy(buffer + 4, "styl", 4);

    u_int8_t italic = 0;
    u_int8_t bold = 0;
    u_int8_t underlined = 0;

    // Parse the tags in the line, remove them and create a style record for every style change
    NSRange endRange;
    NSRange startRange = [string rangeOfString: @"<"];
    if (startRange.location != NSNotFound) {
        unichar tag = [string characterAtIndex:startRange.location + 1];
        if (tag == 'i') italic++;
        else if (tag == 'b') bold++;
        else if (tag == 'u') underlined++;
        startRange.length += 2;
        string = [string stringByReplacingCharactersInRange:startRange withString:@""];
    }

    while (startRange.location != NSNotFound) {
        endRange = [string rangeOfString: @"<"];
        if (endRange.location == NSNotFound)
            endRange.location = [string length] -1;

        u_int8_t styl = 0;
        if (italic) styl |= STYLE_ITALIC;
        if (bold) styl |= STYLE_BOLD;
        if (underlined) styl |= STYLE_UNDERLINED;

        if (styl && startRange.location != endRange.location) {
            u_int8_t styleRecord[12];
            createStyleRecord(startRange.location, endRange.location, 1, styl, styleRecord);
            memcpy(buffer + 10 + (12 * styleCount), styleRecord, 12);
            styleCount++;
        }

        endRange = [string rangeOfString: @"<"];
        if (endRange.location != NSNotFound && (endRange.location + 1) < [string length]) {
            unichar tag = [string characterAtIndex:endRange.location + 1];
            if (tag == 'i') italic++;
            else if (tag == 'b') bold++;
            else if (tag == 'u') underlined++;

            if (tag == '/' && (endRange.location + 2) < [string length]) {
                unichar tag2 = [string characterAtIndex:endRange.location + 2];
                if (tag2 == 'i') italic--;
                else if (tag2 == 'b') bold--;
                else if (tag2 == 'u') underlined--;
                if ((endRange.location + 3) < [string length])
                    endRange.length += 3;
                string = [string stringByReplacingCharactersInRange:endRange withString:@""];
            }
            else {
                if ((endRange.location + 2) < [string length])
                    endRange.length += 2;
                string = [string stringByReplacingCharactersInRange:endRange withString:@""];
            }
            startRange = endRange;
        }
        else
            break;
    }

    if (styleCount)
        *size = closeStyleAtom(styleCount, buffer);

    return string;
}

static int writeSubtitleSample(MP4FileHandle file, MP4TrackId subtitleTrackId, NSString* string, MP4Duration duration)
{
    int Err;
    u_int8_t styleAtom[2048];
    size_t styleSize = 0;

    string = createStyleAtomForString(string, styleAtom, &styleSize);

    const size_t stringLength = strlen([string UTF8String]);
    u_int8_t buffer[2048];
    memcpy(buffer+2, [string UTF8String], stringLength);
    memcpy(buffer+2+stringLength, styleAtom, styleSize);
    buffer[0] = (stringLength >> 8) & 0xff;
    buffer[1] = stringLength & 0xff;

    Err = MP4WriteSample(file,
                         subtitleTrackId,
                         buffer,
                         stringLength + styleSize + 2,
                         duration,
                         0, true);
    return Err;
}

static int writeEmptySubtitleSample(MP4FileHandle file, MP4TrackId subtitleTrackId, MP4Duration duration)
{
    int Err;
    u_int8_t empty[2] = {0,0};
    Err = MP4WriteSample(file,
                         subtitleTrackId,
                         empty,
                         2,
                         duration,
                         0, true);
    return Err;
}

int muxSRTSubtitleTrack(MP4FileHandle fileHandle, NSString* subtitlePath, uint16_t subtitleHeight, int16_t delay) {
    BOOL success = YES;
    MP4TrackId subtitleTrackId, videoTrack;
    uint16_t videoWidth, videoHeight;

    videoTrack = findFirstVideoTrack(fileHandle);
    if (videoTrack) {
        videoWidth = getFixedVideoWidth(fileHandle, videoTrack);
        videoHeight = MP4GetTrackVideoHeight(fileHandle, videoTrack);
    }
    else {
        videoWidth = 640;
        videoHeight = 480;
    }

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    SubSerializer *ss = [[SubSerializer alloc] init];
    success = LoadSRTFromPath(subtitlePath, ss);
    [ss setFinished:YES];

    if (success) {
        int firstSub = 0;

        success = subtitleTrackId = createSubtitleTrack(fileHandle, videoWidth, videoHeight, subtitleHeight, 1000);

        while (![ss isEmpty]) {
            SubLine *sl = [ss getSerializedPacket];
            if (firstSub == 0) {
                firstSub++;
                if (!writeEmptySubtitleSample(fileHandle, subtitleTrackId, sl->begin_time + delay))
                    break;
            }
            if ([sl->line isEqualToString:@"\n"]) {
                if (!writeEmptySubtitleSample(fileHandle, subtitleTrackId, sl->end_time - sl->begin_time))
                    break;
                continue;
            }
            if (!writeSubtitleSample(fileHandle, subtitleTrackId, sl->line, sl->end_time - sl->begin_time))
                break;
        }
        writeEmptySubtitleSample(fileHandle, subtitleTrackId, 10);
    }

    [ss release];
    [pool release];

    return success;
}

#if !__LP64__
int muxMOVSubtitleTrack(MP4FileHandle fileHandle, NSString* filePath, MP4TrackId srcTrackId)
{
    OSStatus err = noErr;
    QTMovie *srcFile = [[QTMovie alloc] initWithFile:filePath error:nil];
    Track track = [[[srcFile tracks] objectAtIndex:srcTrackId] quickTimeTrack];
    Media media = GetTrackMedia(track);
    MP4TrackId dstTrackId = MP4_INVALID_TRACK_ID;

    uint16_t videoWidth, videoHeight;
    MP4TrackId videoTrack = findFirstVideoTrack(fileHandle);
    if (videoTrack) {
        videoWidth = getFixedVideoWidth(fileHandle, videoTrack);
        videoHeight = MP4GetTrackVideoHeight(fileHandle, videoTrack);
    }
    else {
        videoWidth = 640;
        videoHeight = 480;
    }

    // Get the sample description
	SampleDescriptionHandle desc = (SampleDescriptionHandle) NewHandle(0);
    GetMediaSampleDescription(media, 1, desc);

    ImageDescriptionHandle imgDesc = (ImageDescriptionHandle) desc;

    if ((*imgDesc)->cType == 'SRT ' || /* (*imgDesc)->cType == 'SSA ' ||*/ (*imgDesc)->cType == 'tx3g') {
        // Add video track
        dstTrackId = createSubtitleTrack(fileHandle, videoWidth, videoHeight, 60, GetMediaTimeScale(media));
        
    }
    else
        goto bail;

    // Create a QTSampleTable which cointans all the informations of the track samples.
    TimeValue64 sampleTableStartDecodeTime = 0;
    QTMutableSampleTableRef sampleTable = NULL;
    err = CopyMediaMutableSampleTable(media,
                                      0,
                                      &sampleTableStartDecodeTime,
                                      0,
                                      0,
                                      &sampleTable);
    require_noerr(err, bail);

    SInt64 sampleIndex, sampleCount;
    sampleCount = QTSampleTableGetNumberOfSamples(sampleTable);

    for (sampleIndex = 1; sampleIndex <= sampleCount; sampleIndex++) {
        TimeValue64 sampleDecodeTime = 0;
        ByteCount sampleDataSize = 0;
        MediaSampleFlags sampleFlags = 0;
		UInt8 *sampleData = NULL;
        TimeValue64 decodeDuration = QTSampleTableGetDecodeDuration(sampleTable, sampleIndex);

        // Get the frame's data size and sample flags.  
        SampleNumToMediaDecodeTime( media, sampleIndex, &sampleDecodeTime, NULL);
		sampleDataSize = QTSampleTableGetDataSizePerSample(sampleTable, sampleIndex);
        sampleFlags = QTSampleTableGetSampleFlags(sampleTable, sampleIndex);

        // Load the frame.
		sampleData = malloc(sampleDataSize);
		GetMediaSample2(media, sampleData, sampleDataSize, NULL, sampleDecodeTime,
                        NULL, NULL, NULL, NULL, NULL, 1, NULL, NULL);

        if ((*imgDesc)->cType != 'tx3g') {
            if (sampleDataSize == 1) {
                if (*sampleData == 0xA)
                    err= writeEmptySubtitleSample(fileHandle, dstTrackId, decodeDuration);
            }
            else {
                NSString * string = [NSString stringWithCString:(char *)sampleData encoding:NSUTF8StringEncoding];
                err = writeSubtitleSample(fileHandle, dstTrackId, string, decodeDuration);
            }
        }
        else {
            err = MP4WriteSample(fileHandle,
                                 dstTrackId,
                                 sampleData,
                                 sampleDataSize,
                                 decodeDuration,
                                 0,
                                 !sampleFlags);
        }
        free(sampleData);
        if(!err) goto bail;
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
        
        MP4AddTrackEdit(fileHandle, dstTrackId, MP4_INVALID_EDIT_ID, editDisplayStart,
                        editTrackDuration, !Fix2X(editDwell));

        trackDuration += editTrackDuration;
        // Find the next edit
		GetTrackNextInterestingTime(track,
                                    nextTimeTrackEdit,
                                    editTrackStart,
                                    fixed1,
                                    &editTrackStart,
                                    &editTrackDuration);
    }

    MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "tkhd.duration", trackDuration);

bail:
    DisposeHandle((Handle) desc);
    [srcFile release];

    return dstTrackId;
}
#endif

int muxMP4SubtitleTrack(MP4FileHandle fileHandle, NSString* filePath, MP4TrackId srcTrackId)
{
    MP4FileHandle srcFile = MP4Read([filePath UTF8String], MP4_DETAILS_ERROR || MP4_DETAILS_READ);
    MP4TrackId videoTrack;
    float subtitleHeight;
    uint16_t videoWidth, videoHeight;
    
    videoTrack = findFirstVideoTrack(fileHandle);
    if (videoTrack) {
        videoWidth = getFixedVideoWidth(fileHandle, videoTrack);
        videoHeight = MP4GetTrackVideoHeight(fileHandle, videoTrack);
    }
    else {
        videoWidth = 640;
        videoHeight = 480;
    }

    MP4GetTrackFloatProperty(srcFile, srcTrackId, "tkhd.height", &subtitleHeight);

    MP4TrackId dstTrackId = createSubtitleTrack(fileHandle, videoWidth, videoHeight, subtitleHeight,
                                                MP4GetTrackTimeScale(srcFile, srcTrackId));
    if (dstTrackId == MP4_INVALID_TRACK_ID) {
        MP4Close(srcFile);
        return dstTrackId;
    }

    MP4SampleId sampleId = 0;
    MP4SampleId numSamples = MP4GetTrackNumberOfSamples(srcFile, srcTrackId);

    while (true) {
        sampleId++;
        if (sampleId > numSamples)
            break;

        bool rc = false;
        rc = MP4CopySample(srcFile,
                           srcTrackId,
                           sampleId,
                           fileHandle,
                           dstTrackId,
                           MP4_INVALID_DURATION);
        
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
