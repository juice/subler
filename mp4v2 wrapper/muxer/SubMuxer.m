//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "SubMuxer.h"
#import "MP42Utilities.h"
#import "SubUtilities.h"
#import "lang.h"

static MP4TrackId createSubtitleTrack(MP4FileHandle file, MP4TrackId refTrackId, const char* language_iso639_2,
                               uint16_t video_width, uint16_t video_height, uint16_t subtitleHeight)
{
    const uint8_t textColor[4] = { 255,255,255,255 };
    MP4TrackId subtitle_track = MP4AddSubtitleTrack(file, refTrackId);

    MP4SetTrackLanguage(file, subtitle_track, language_iso639_2);

    MP4SetTrackFloatProperty(file,subtitle_track, "tkhd.width", video_width);
    MP4SetTrackFloatProperty(file,subtitle_track, "tkhd.height", subtitleHeight);

    MP4SetTrackIntegerProperty(file,subtitle_track, "tkhd.alternate_group", 2);

    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.horizontalJustification", 1);
    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.verticalJustification", 0);

	MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.bgColorAlpha", 255);

    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.defTextBoxBottom", subtitleHeight);
    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.defTextBoxRight", video_width);

    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.fontID", 1);
    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.fontSize", 24);

    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.fontColorRed", textColor[0]);
    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.fontColorGreen", textColor[1]);
    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.fontColorBlue", textColor[2]);
    MP4SetTrackIntegerProperty(file,subtitle_track, "mdia.minf.stbl.stsd.tx3g.fontColorAlpha", textColor[3]);

    /* translate the track */
    uint8_t* val;
    uint8_t nval[36];
    uint32_t *ptr32 = (uint32_t*) nval;
    uint32_t size;

    MP4GetTrackBytesProperty(file, subtitle_track, "tkhd.matrix", &val, &size);
    memcpy(nval, val, size);
    ptr32[7] = CFSwapInt32HostToBig( (video_height - subtitleHeight) * 0x10000);

    MP4SetTrackBytesProperty(file, subtitle_track, "tkhd.matrix", nval, size);
    free(val);

    /* set the timescale to ms */
    MP4SetTrackTimeScale(file,subtitle_track, 1000);

    enableFirstSubtitleTrack(file);

	return subtitle_track;
}

static u_int8_t* makeStyleRecord(u_int16_t startChar, u_int16_t endChar, u_int16_t fontID, u_int8_t flags, u_int8_t* style)
{
    style[0] = (startChar >> 8) & 0xff; // startChar
    style[1] = startChar & 0xff;;
    style[2] = (endChar >> 8) & 0xff;   // endChar
    style[3] = endChar & 0xff;
    style[4] = (fontID >> 8) & 0xff;   // font-ID
    style[5] = fontID & 0xff;
    style[6] = flags;   // face-style-flags: 1 bold; 2 italic; 4 underline
    style[7] = 24;      // font-size
    style[8] = 255;     // r
    style[9] = 255;     // g
    style[10] = 255;    // b
    style[11] = 255;    // a
    
    return style;
}

static int writeSubtitleSample(MP4FileHandle file, MP4TrackId subtitleTrackId, NSString* string, MP4Duration duration)
{
    int Err;
    u_int16_t styleCount = 0;
    u_int8_t styleBuffer[2048];
    size_t styleSize;
    memcpy(styleBuffer+4, "styl", 4);
    
    NSRange range = [string rangeOfString: @"<i>"];
    while (range.location != NSNotFound) 
    {   NSRange startRange;
        NSRange endRange;
        
        startRange = [string rangeOfString: @"<i>"];
        if (startRange.location != NSNotFound)
            string = [string stringByReplacingCharactersInRange:startRange withString:@""];
        else
            break;
        endRange = [string rangeOfString: @"</i>"];
        if (endRange.location != NSNotFound)
            string = [string stringByReplacingCharactersInRange:endRange withString:@""];
        else
            endRange.location = [string length];

        u_int8_t style[12];
        makeStyleRecord(startRange.location, endRange.location, 1, 2, style);
        memcpy(styleBuffer+10+(12*styleCount), style, 12);
        styleCount++;

        NSLog(@"%d %d", range.length, range.location);
    }

    if (styleCount)
    {
        styleSize = 10 + (styleCount * 12);
        styleBuffer[0] = 0;
        styleBuffer[1] = 0;
        styleBuffer[2] = (styleSize >> 8) & 0xff;
        styleBuffer[3] = styleSize & 0xff;
        styleBuffer[8] = (styleCount >> 8) & 0xff;
        styleBuffer[9] = styleCount & 0xff;
    }
    else
        styleSize = 0;

    const size_t stringLength = [string length]-1;
    u_int8_t buffer[2048];
    memcpy(buffer+2, [string UTF8String], stringLength);
    memcpy(buffer +2 + stringLength, styleBuffer, styleSize);
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

int muxSRTSubtitleTrack(MP4FileHandle fileHandle, NSString* subtitlePath, const char* lang, uint16_t subtitleHeight, int16_t delay) {
    BOOL success = YES;
    MP4TrackId subtitleTrackId, videoTrack;
    uint16_t videoWidth, videoHeight;

    videoTrack = findFirstVideoTrack(fileHandle);
    if (!videoTrack)
        return 0;

    videoWidth = getFixedVideoWidth(fileHandle, videoTrack);
    videoHeight = MP4GetTrackVideoHeight(fileHandle, videoTrack);

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    SubSerializer *ss = [[SubSerializer alloc] init];
    success = LoadSRTFromPath(subtitlePath, ss);
    [ss setFinished:YES];

    if (success) {
        int firstSub = 0;

        success = subtitleTrackId = createSubtitleTrack(fileHandle, videoTrack, lang, videoWidth, videoHeight, subtitleHeight);

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
        writeEmptySubtitleSample(fileHandle, subtitleTrackId, 100);
    }

    [ss release];
    [pool release];

    return success;
}

int muxMP4SubtitleTrack(MP4FileHandle fileHandle, NSString* filePath, MP4TrackId sourceTrackId)
{
    MP4FileHandle sourceFileHandle;
    MP4TrackId videoTrack;
    float width, height;
    uint16_t videoWidth, videoHeight;
    char lang[4] = "";

    videoTrack = findFirstVideoTrack(fileHandle);
    if (!videoTrack)
        return 0;

    videoWidth = getFixedVideoWidth(fileHandle, videoTrack);
    videoHeight = MP4GetTrackVideoHeight(fileHandle, videoTrack);

    sourceFileHandle = MP4Read([filePath UTF8String], MP4_DETAILS_ERROR || MP4_DETAILS_READ);

    MP4GetTrackLanguage(sourceFileHandle, sourceTrackId, lang);
    MP4GetTrackFloatProperty(sourceFileHandle, sourceTrackId, "tkhd.width", &width);
    MP4GetTrackFloatProperty(sourceFileHandle, sourceTrackId, "tkhd.height", &height);

    bool copySamples = true;  // LATER allow false => reference samples

    MP4TrackId dstTrackId = createSubtitleTrack(fileHandle, videoTrack, lang , videoWidth, videoHeight, height);
    int applyEdits = 0;
    if (dstTrackId == MP4_INVALID_TRACK_ID) {
        return dstTrackId;
    }
    
    bool viaEdits =
    applyEdits && MP4GetTrackNumberOfEdits(sourceFileHandle, sourceTrackId);
    
    MP4SampleId sampleId = 0;
    MP4SampleId numSamples =
    MP4GetTrackNumberOfSamples(sourceFileHandle, sourceTrackId);
    
    MP4Timestamp when = 0;
    MP4Duration editsDuration =
    MP4GetTrackEditTotalDuration(sourceFileHandle, sourceTrackId, MP4_INVALID_EDIT_ID);
    
    while (true) {
        MP4Duration sampleDuration = MP4_INVALID_DURATION;
        
        if (viaEdits) {
            sampleId = MP4GetSampleIdFromEditTime(
                                                  sourceFileHandle,
                                                  sourceTrackId,
                                                  when,
                                                  NULL,
                                                  &sampleDuration);
            
            // in theory, this shouldn't happen
            if (sampleId == MP4_INVALID_SAMPLE_ID) {
                MP4DeleteTrack(fileHandle, dstTrackId);
                MP4Close(sourceFileHandle);
                return MP4_INVALID_TRACK_ID;
            }
            
            when += sampleDuration;
            
            if (when >= editsDuration) {
                break;
            }
        } else {
            sampleId++;
            if (sampleId > numSamples) {
                break;
            }
        }
        
        bool rc = false;
        
        if (copySamples) {
            rc = MP4CopySample(
                               sourceFileHandle,
                               sourceTrackId,
                               sampleId,
                               fileHandle,
                               dstTrackId,
                               sampleDuration);

        } else {
            rc = MP4ReferenceSample(
                                    sourceFileHandle,
                                    sourceTrackId,
                                    sampleId,
                                    fileHandle,
                                    dstTrackId,
                                    sampleDuration);
        }
        
        if (!rc) {
            MP4DeleteTrack(fileHandle, dstTrackId);
            MP4Close(sourceFileHandle);
            return MP4_INVALID_TRACK_ID;
        }
    }

    MP4Close(sourceFileHandle);
    return dstTrackId;
}
