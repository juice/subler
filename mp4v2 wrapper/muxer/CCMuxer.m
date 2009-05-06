//
//  CCMuxer.m
//  Subler
//
//  Created by Damiano Galassi on 05/05/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "CCMuxer.h"
#import "MP42Utilities.h"
#import "SubUtilities.h"
#import <QTKit/QTKit.h>
#import <QuickTime/QuickTime.h>
#import "RegexKitLite.h"

static unsigned ParseTimeCode(const char *time, unsigned secondScale, BOOL hasSign)
{
	unsigned hour, minute, second, frame, timeval;
	char separator;
	int sign = 1;

	if (hasSign && *time == '-') {
		sign = -1;
		time++;
	}

	if (sscanf(time,"%u:%u:%u%[,.:]%u",&hour,&minute,&second,&separator,&frame) < 5)
		return 0;

	timeval = (hour * 60 * 60 + minute * 60 + second) * 30 + frame;
	//timeval = secondScale * timeval + frame;

	return timeval * sign;
}

int ParseByte(const char *string, UInt8 *byte, Boolean hex)
{
	int err = 0;
	char chars[2];

	if (sscanf(string, "%2c", chars) == 1)
	{
		chars[0] = (char)tolower(chars[0]);
		chars[1] = (char)tolower(chars[1]);

		if (((chars[0] >= '0' && chars[0] <= '9') || (hex && (chars[0] >= 'a' && chars[0] <= 'f'))) &&
			((chars[1] >= '0' && chars[1] <= '9') || (hex && (chars[1] >= 'a' && chars[1] <= 'f'))))
		{
			*byte = 0;
			if (chars[0] >= '0' && chars[0] <= '9')
				*byte = (chars[0] - '0') * (hex ? 16 : 10);
			else if (chars[0] >= 'a' && chars[0] <= 'f')
				*byte = (chars[0] - 'a' + 10) * 16;
			
			if (chars[1] >= '0' && chars[1] <= '9')
				*byte += (chars[1] - '0');
			else if (chars[1] >= 'a' && chars[1] <= 'f')
				*byte += (chars[1] - 'a' + 10);
			
			err = 1;
		}
	}

	return err;
}

int muxSccCCTrack(MP4FileHandle fileHandle, NSString* filePath)
{
    NSString *scc = STStandardizeStringNewlines([[NSString alloc] initWithContentsOfFile:filePath usedEncoding:nil error:nil]);
    if (!scc) return 0;

    NSScanner *sc = [NSScanner scannerWithString:scc];
	NSString *res=nil;
	[sc setCharactersToBeSkipped:nil];

    [sc scanUpToString:@"\n" intoString:&res];
    if (![res isEqualToString:@"Scenarist_SCC V1.0"])
        return 0;

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

    MP4TrackId dstTrack = MP4AddCCTrack(fileHandle, 30000, videoWidth, videoHeight);

    unsigned startTime=0;
    BOOL firstSample = YES;
    NSString *splitLine  = @"\\n+";
    NSString *splitTimestamp  = @"\\t+";
    NSString *splitBytes  = @"\\s+";
    NSArray  *fileArray   = nil;
    NSUInteger i = 0;

    fileArray = [scc componentsSeparatedByRegex:splitLine];

    NSMutableArray *sampleArray = [[NSMutableArray alloc] initWithCapacity:[fileArray count]];

    for (NSString *line in fileArray) {
        NSArray *lineArray = [line componentsSeparatedByRegex:splitTimestamp];
        if ([lineArray count] < 2)
            continue;
        startTime = ParseTimeCode([[lineArray objectAtIndex:0] UTF8String], 30000, NO);
        SBSample *sample = [[SBSample alloc] init];
        sample.timestamp = startTime;
        sample.title = [lineArray lastObject];

        [sampleArray addObject:[sample autorelease]];
    }

    for (SBSample *sample in sampleArray) {
        NSArray  *bytesArray   = nil;
        MP4Duration sampleDuration = 0;
        bytesArray = [sample.title componentsSeparatedByRegex:splitBytes];

        NSUInteger byteCount = [bytesArray count] *2;
        UInt8 *bytes = malloc(sizeof(UInt8)*byteCount*2 + (sizeof(UInt8)*8));
        UInt8 *bytesPos = bytes;

        // Write out the size of the atom
        *(long*)bytesPos = EndianS32_NtoB(8 + byteCount);
        bytesPos += sizeof(long);

        // Write out the atom type
        *(OSType*)bytesPos = EndianU32_NtoB('cdat');
        bytesPos += sizeof(OSType);

        for (NSString *hexByte in bytesArray) {
            ParseByte([hexByte UTF8String], bytesPos , 1);
            ParseByte([hexByte UTF8String] + 2, bytesPos + 1, 1);
            bytesPos +=2;
        }

        if (firstSample) {
            SBSample *boh = [sampleArray objectAtIndex:1];
            sampleDuration = boh.timestamp;
            firstSample = NO;
        }
        else if (i+1 < [sampleArray count]) {
            SBSample *boh = [sampleArray objectAtIndex:i+1];
            sampleDuration = boh.timestamp - sample.timestamp;
        }
        else
            sampleDuration = 5;

        MP4WriteSample(fileHandle,
                       dstTrack,
                       bytes,
                       byteCount + 8,
                       sampleDuration *= 1001, 0, 1);
        free(bytes);
        i++;
    }

    [sampleArray release];

    return dstTrack;
}

int muxMOVCCTrack(MP4FileHandle fileHandle, NSString* filePath, MP4TrackId srcTrackId)
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

    if ((*imgDesc)->cType == 'c608') {
        // Add Closed Caption track
        dstTrackId = MP4AddCCTrack(fileHandle, GetMediaTimeScale(media), videoWidth, videoHeight);
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

        err = MP4WriteSample(fileHandle,
                             dstTrackId,
                             sampleData,
                             sampleDataSize,
                             decodeDuration,
                             0,
                             !sampleFlags);

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

int muxMP4CCTrack(MP4FileHandle fileHandle, NSString* filePath, MP4TrackId srcTrackId)
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

    MP4TrackId dstTrackId = MP4AddCCTrack(fileHandle, MP4GetTrackTimeScale(srcFile, srcTrackId), videoWidth, videoHeight);
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
