//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "VideoMuxer.h"
#import "MP42Utilities.h"
#import "SubUtilities.h"
#if !__LP64__
    #import <QuickTime/QuickTime.h>
#endif
#import "MatroskaParser.h"
#import "MatroskaFile.h"
#import "lang.h"

#include "rational.h"
#include <sys/socket.h>
#import <sys/un.h>

static const framerate_t framerates[] =
{ { 2398, 24000, 1001 },
  { 24, 600, 25 },
  { 25, 600, 24 },
  { 2997, 30000, 1001 },
  { 30, 600, 20 },
  { 5994, 60000, 1001 },
  { 60, 600, 10 },
  { 0, 24000, 1001 } };

static const framerate_t framerates_thousand[] =
{ { 2398, 24000, 1001 },
	{ 2400, 600, 25 },
	{ 2500, 600, 24 },
	{ 2997, 30000, 1001 },
	{ 3000, 600, 20 },
	{ 5994, 60000, 1001 },
	{ 6000, 600, 10 },
	{ 0, 24000, 1001 } };

MP4TrackId H264Creator (MP4FileHandle mp4File, FILE* inFile, uint32_t timescale, uint32_t mp4FrameDuration, int usePipe, int pipeFD);
int write_track_to_socket(int socketFD, MatroskaFile *matroskaFile, StdIoStream *ioStream, MP4TrackId srcTrackId);
void write_nal(int socketFD, const char *data, uint32_t *pos, uint32_t data_size, uint8_t write_nal_size_size);

int muxH264ElementaryStream(MP4FileHandle fileHandle, NSString* filePath, uint32_t frameRateCode) {
    MP4TrackId dstTrackId = MP4_INVALID_TRACK_ID;
    FILE* inFile = fopen([filePath UTF8String], "rb");
    framerate_t * framerate;

    for (framerate = (framerate_t*) framerates; framerate->code; framerate++)
        if(frameRateCode == framerate->code)
            break;

    dstTrackId = H264Creator(fileHandle, inFile, framerate->timescale, framerate->duration, 0, 0);
    fclose(inFile);

    return dstTrackId;
}

#if !__LP64__
int muxMOVVideoTrack(MP4FileHandle fileHandle, QTMovie* srcFile, MP4TrackId srcTrackId)
{
    OSStatus err = noErr;
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

        MP4SetVideoProfileLevel(fileHandle, 0x15);
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
            uint16_t spsSize = ((*imgDescHandle)[ptrPos++] << 8) & 0xff00;
            spsSize += (*imgDescHandle)[ptrPos++] & 0xff;
            MP4AddH264SequenceParameterSet(fileHandle, dstTrackId,
                                           (uint8_t *)*imgDescHandle+ptrPos, spsSize);
            ptrPos += spsSize;
        }

        int8_t ppsCount = (*imgDescHandle)[ptrPos++];
        for (i = 0; i < ppsCount; i++) {
            uint16_t ppsSize = ((*imgDescHandle)[ptrPos++] << 8) & 0xff00;
            ppsSize += (*imgDescHandle)[ptrPos++] & 0xff;
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

    MP4SetTrackDurationPerChunk(fileHandle, dstTrackId, GetMediaTimeScale(media) / 8);

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

    // Create a QTSampleTable which contains all the informatio of the track samples.
    TimeValue64 sampleTableStartDecodeTime = 0;
    QTMutableSampleTableRef sampleTable = NULL;
    err = CopyMediaMutableSampleTable(media,
                                      0,
                                      &sampleTableStartDecodeTime,
                                      0,
                                      0,
                                      &sampleTable);
    require_noerr(err, bail);

    TimeValue64 minDisplayOffset = 0;
    err = QTSampleTableGetProperty(sampleTable,
                                   kQTPropertyClass_SampleTable,
                                   kQTSampleTablePropertyID_MinDisplayOffset,
                                   sizeof(TimeValue64),
                                   &minDisplayOffset,
                                   NULL);
    require_noerr(err, bail);

    SInt64 sampleIndex, sampleCount;
    sampleCount = QTSampleTableGetNumberOfSamples(sampleTable);

    for (sampleIndex = 1; sampleIndex <= sampleCount; sampleIndex++) {
        TimeValue64 sampleDecodeTime = 0;
        ByteCount sampleDataSize = 0;
        MediaSampleFlags sampleFlags = 0;
		UInt8 *sampleData = NULL;
        TimeValue64 decodeDuration = QTSampleTableGetDecodeDuration(sampleTable, sampleIndex);
        TimeValue64 displayOffset = QTSampleTableGetDisplayOffset(sampleTable, sampleIndex);
        uint32_t dflags = 0;

        // Get the frame's data size and sample flags.  
        SampleNumToMediaDecodeTime( media, sampleIndex, &sampleDecodeTime, NULL);
		sampleDataSize = QTSampleTableGetDataSizePerSample(sampleTable, sampleIndex);
        sampleFlags = QTSampleTableGetSampleFlags(sampleTable, sampleIndex);
        dflags |= (sampleFlags & mediaSampleHasRedundantCoding) ? MP4_SDT_HAS_REDUNDANT_CODING : 0;
        dflags |= (sampleFlags & mediaSampleHasNoRedundantCoding) ? MP4_SDT_HAS_NO_REDUNDANT_CODING : 0;
        dflags |= (sampleFlags & mediaSampleIsDependedOnByOthers) ? MP4_SDT_HAS_DEPENDENTS : 0;
        dflags |= (sampleFlags & mediaSampleIsNotDependedOnByOthers) ? MP4_SDT_HAS_NO_DEPENDENTS : 0;
        dflags |= (sampleFlags & mediaSampleDependsOnOthers) ? MP4_SDT_IS_DEPENDENT : 0;
        dflags |= (sampleFlags & mediaSampleDoesNotDependOnOthers) ? MP4_SDT_IS_INDEPENDENT : 0;
        dflags |= (sampleFlags & mediaSampleEarlierDisplayTimesAllowed) ? MP4_SDT_EARLIER_DISPLAY_TIMES_ALLOWED : 0;

        // Load the frame.
		sampleData = malloc(sampleDataSize);
		GetMediaSample2(media, sampleData, sampleDataSize, NULL, sampleDecodeTime,
                        NULL, NULL, NULL, NULL, NULL, 1, NULL, NULL);

        err = MP4WriteSampleDependency(fileHandle,
                                       dstTrackId,
                                       sampleData,
                                       sampleDataSize,
                                       decodeDuration,
                                       displayOffset -minDisplayOffset,
                                       !(sampleFlags & mediaSampleNotSync),
                                       dflags);
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
        
        if (minDisplayOffset < 0 && editDisplayStart != -1)
            MP4AddTrackEdit(fileHandle, dstTrackId, MP4_INVALID_EDIT_ID, editDisplayStart -minDisplayOffset,
                            editTrackDuration, !Fix2X(editDwell));
        else
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

    return dstTrackId;
}
#endif

int muxMP4VideoTrack(MP4FileHandle fileHandle, NSString* filePath, MP4TrackId srcTrackId)
{
    MP4FileHandle srcFile = MP4Read([filePath UTF8String], 0);
    MP4TrackId dstTrackId = MP4CloneTrack(srcFile, srcTrackId, fileHandle, MP4_INVALID_TRACK_ID);

    if (dstTrackId == MP4_INVALID_TRACK_ID) {
        MP4Close(srcFile);
        return dstTrackId;
    }

    MP4SetTrackDurationPerChunk(fileHandle, dstTrackId, MP4GetTrackTimeScale(srcFile, srcTrackId) / 8);

    if (MP4HaveTrackAtom(srcFile, srcTrackId, "mdia.minf.stbl.stsd.*.pasp")) {
        uint64_t hSpacing, vSpacing;
        MP4GetTrackIntegerProperty(srcFile, srcTrackId, "mdia.minf.stbl.stsd.*.pasp.hSpacing", &hSpacing);
        MP4GetTrackIntegerProperty(srcFile, srcTrackId, "mdia.minf.stbl.stsd.*.pasp.vSpacing", &vSpacing);

        if ( hSpacing >= 1 && vSpacing >= 1)
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
    else {
        uint32_t firstFrameOffset = MP4GetSampleRenderingOffset(fileHandle, dstTrackId, 1);
        MP4Duration editDuration = MP4ConvertFromTrackDuration(srcFile,
                                                               srcTrackId,
                                                               MP4GetTrackDuration(srcFile, srcTrackId),
                                                               MP4GetTimeScale(fileHandle));
        MP4AddTrackEdit(fileHandle, dstTrackId, MP4_INVALID_EDIT_ID, firstFrameOffset,
                        editDuration, 0);
    }
        

    MP4Close(srcFile);

    return dstTrackId;
}

@implementation SBMatroskaSample
@synthesize startTime;
@synthesize endTime;
@synthesize filePos;
@synthesize frameSize;
@synthesize frameFlags;

@end

int muxMKVVideoTrack(MP4FileHandle fileHandle, NSString* filePath, MP4TrackId srcTrackId)
{
    MP4TrackId dstTrackId = MP4_INVALID_TRACK_ID;
#ifdef H264Mux
    StdIoStream *ioStream;
	
	ioStream = calloc(1, sizeof(StdIoStream)); 
    MatroskaFile *matroskaFile = openMatroskaFile((char *)[filePath UTF8String], ioStream);
	
	TrackInfo *trackInfo = mkv_GetTrackInfo(matroskaFile, srcTrackId);
	double fr1 = 1.0f / trackInfo->DefaultDuration;
	double fr2 = fr1 * 1000 * 1000 * 1000 * 100; // nanoseconds
	
	uint32_t frameRateCode = lround(fr2);
	
	framerate_t * framerate;
	
    for (framerate = (framerate_t*) framerates_thousand; framerate->code; framerate++)
        if(frameRateCode == framerate->code)
            break;
	
	MP4SetVideoProfileLevel(fileHandle, 0x15);
	
	int parserSocketFD[2];
	socketpair(AF_UNIX, SOCK_STREAM, 0, parserSocketFD);
    
	dispatch_async(dispatch_get_global_queue(0, 0), ^{
		write_track_to_socket(parserSocketFD[1], matroskaFile, ioStream, srcTrackId);
		
		close(parserSocketFD[1]);
		close(parserSocketFD[0]);
		mkv_Close(matroskaFile);
		fclose(ioStream->fp);
	});
	
	H264Creator(fileHandle, NULL, framerate->timescale, framerate->duration, 1, parserSocketFD[0]);
#else
	StdIoStream *ioStream = calloc(1, sizeof(StdIoStream));

    MatroskaFile *matroskaFile = openMatroskaFile((char *)[filePath UTF8String], ioStream);
	TrackInfo *trackInfo = mkv_GetTrackInfo(matroskaFile, srcTrackId);
    uint64_t timeScale = mkv_GetFileInfo(matroskaFile)->TimecodeScale / mkv_TruncFloat(trackInfo->TimecodeScale) * 1000;

    if (!strcmp(trackInfo->CodecID, "V_MPEG4/ISO/AVC")) {
        // Get avcC atom
        uint8_t* avcCAtom = (uint8_t *)malloc(trackInfo->CodecPrivateSize); // mkv stores h.264 avcC in CodecPrivate
        memcpy(avcCAtom, trackInfo->CodecPrivate, trackInfo->CodecPrivateSize);

        dstTrackId = MP4AddH264VideoTrack(fileHandle, 90000,
                                          MP4_INVALID_DURATION,
                                          trackInfo->AV.Video.PixelWidth, trackInfo->AV.Video.PixelHeight,
                                          avcCAtom[1],  // AVCProfileIndication
                                          avcCAtom[2],  // profile_compat
                                          avcCAtom[3],  // AVCLevelIndication
                                          avcCAtom[4]); // lengthSizeMinusOne

        SInt64 i;
        int8_t spsCount = (avcCAtom[5] & 0x1f);
        uint8_t ptrPos = 6;
        for (i = 0; i < spsCount; i++) {
            uint16_t spsSize = (avcCAtom[ptrPos++] << 8) & 0xff00;
            spsSize += avcCAtom[ptrPos++] & 0xff;
            MP4AddH264SequenceParameterSet(fileHandle, dstTrackId,
                                           avcCAtom+ptrPos, spsSize);
            ptrPos += spsSize;
        }

        int8_t ppsCount = avcCAtom[ptrPos++];
        for (i = 0; i < ppsCount; i++) {
            uint16_t ppsSize = (avcCAtom[ptrPos++] << 8) & 0xff00;
            ppsSize += avcCAtom[ptrPos++] & 0xff;
            MP4AddH264PictureParameterSet(fileHandle, dstTrackId,
                                      avcCAtom+ptrPos, ppsSize);
            ptrPos += ppsSize;
        }

        MP4SetVideoProfileLevel(fileHandle, 0x15);
    }
    else
        return MP4_INVALID_TRACK_ID;

    AVRational dar, invPixelSize, sar;
	dar			   = (AVRational){trackInfo->AV.Video.DisplayWidth, trackInfo->AV.Video.DisplayHeight};
	invPixelSize   = (AVRational){trackInfo->AV.Video.PixelHeight, trackInfo->AV.Video.PixelWidth};
	sar = av_mul_q(dar, invPixelSize);    

    av_reduce(&sar.num, &sar.den, sar.num, sar.den, fixed1);
    MP4AddPixelAspectRatio(fileHandle, dstTrackId, sar.num, sar.den);

    MP4SetTrackDurationPerChunk(fileHandle, dstTrackId, MP4GetTrackTimeScale(fileHandle, dstTrackId) / 8);

	/* mask other tracks because we don't need them */
	mkv_SetTrackMask(matroskaFile, ~(1 << srcTrackId));

    NSMutableArray *queue = [[NSMutableArray alloc] init];
    NSMutableArray *offsetsArray = [[NSMutableArray alloc] init];
    SBMatroskaSample *frameSample = nil, *currentSample = nil;
	uint64_t        StartTime, EndTime, FilePos, current_time = 0;
    int64_t         offset, minOffset = 0, duration, next_duration;
	uint32_t        rt, FrameSize, FrameFlags, fb = 0;
	void            *frame = NULL;

    unsigned int buffer = 0, samplesWritten = 0, bufferFlush = 0;
    const unsigned int bufferSize = 20;
    int success = 0;

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    /* read frames from file */
    while ((success = mkv_ReadFrame(matroskaFile, 0, &rt, &StartTime, &EndTime, &FilePos, &FrameSize, &FrameFlags)) >=-1) {
        if (success == 0) {
            frameSample = [[SBMatroskaSample alloc] init];
            frameSample->startTime = StartTime;
            frameSample->endTime = EndTime;
            frameSample->filePos = FilePos;
            frameSample->frameSize = FrameSize;
            frameSample->frameFlags = FrameFlags;
            [queue addObject:frameSample];
            [frameSample release];
        }
        else if (success == -1 && bufferFlush == 1) {
            // add a last sample to get the duration for the last frame
            SBMatroskaSample *lastSample = [queue lastObject];
            for (SBMatroskaSample *sample in queue) {
                if (sample->startTime > lastSample->startTime)
                    lastSample = sample;
            }
            frameSample = [[SBMatroskaSample alloc] init];
            frameSample->startTime = [lastSample endTime];
            [queue addObject:frameSample];
            [frameSample release];
        }
        if ([queue count] < bufferSize && success == 0)
            continue;
        else {
            currentSample = [queue objectAtIndex:buffer];

            // matroska stores only the start and end time, so we need to recreate
            // the frame duration and the offset from the start time, the end time is useless
            // duration calculation
            duration = [[queue lastObject] startTime] - currentSample->startTime;

            for (SBMatroskaSample *sample in queue)
                if (sample != currentSample && (sample->startTime >= currentSample->startTime))
                    if ((next_duration = (sample->startTime - currentSample->startTime)) < duration)
                        duration = next_duration;

            // offset calculation
            offset = currentSample->startTime - current_time;
            // save the minimum offset, used later to keep the all the offset values positive
            if (offset < minOffset)
                minOffset = offset;
            [offsetsArray addObject:[NSNumber numberWithLongLong:offset]];

            current_time += duration;

            if (fseeko(ioStream->fp, currentSample->filePos, SEEK_SET)) {
                fprintf(stderr,"fseeko(): %s\n", strerror(errno));
                [offsetsArray release];
                [queue release];
                return MP4_INVALID_TRACK_ID;				
            } 

            if (fb < currentSample->frameSize) {
                fb = currentSample->frameSize;
                frame = realloc(frame, fb);
                if (frame == NULL) {
                    fprintf(stderr,"Out of memory\n");
                    [offsetsArray release];
                    [queue release];
                    return MP4_INVALID_TRACK_ID;		
                }
            }

            size_t rd = fread(frame,1,currentSample->frameSize,ioStream->fp);
            if (rd != currentSample->frameSize) {
                if (rd == 0) {
                    if (feof(ioStream->fp))
                        fprintf(stderr,"Unexpected EOF while reading frame\n");
                    else
                        fprintf(stderr,"Error reading frame: %s\n",strerror(errno));
                } else
                    fprintf(stderr,"Short read while reading frame\n");
                break;
            }

            MP4WriteSample(fileHandle,
                           dstTrackId,
                           frame,
                           currentSample->frameSize,
                           duration / (timeScale / 90000.f),
                           0,
                           (currentSample->frameFlags & FRAME_KF));

            samplesWritten++;
            
            if (buffer >= bufferSize)
                [queue removeObjectAtIndex:0];
            if (buffer < bufferSize && success == 0)
                buffer++;

            if (success == -1) {
                bufferFlush++;
                if (bufferFlush >= bufferSize-1)
                    break;
            }
        }
    }

    if (minOffset != 0) {
        uint32_t ix = 0;
        for (NSNumber *frameOffset in offsetsArray) {
            const uint32_t sample_offset = ([frameOffset longLongValue] - minOffset) / (timeScale / 90000.f);
            MP4SetSampleRenderingOffset(fileHandle, dstTrackId, 1 + ix++, sample_offset);
        }

        MP4Duration editDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                               dstTrackId,
                                                               MP4GetTrackDuration(fileHandle, dstTrackId),
                                                               MP4GetTimeScale(fileHandle));
        MP4AddTrackEdit(fileHandle, dstTrackId, MP4_INVALID_EDIT_ID, -minOffset / (timeScale / 90000.f),
                        editDuration, 0);
    }

    [pool release];
    [offsetsArray release];
    [queue release];
    mkv_Close(matroskaFile);
    fclose(ioStream->fp);
#endif
    return dstTrackId;
}

int write_track_to_socket(int socketFD, MatroskaFile *matroskaFile, StdIoStream *ioStream, MP4TrackId srcTrackId)
{
	
	TrackInfo *trackInfo = mkv_GetTrackInfo(matroskaFile, srcTrackId);
	
	// Get avcC atom
	char avcCAtom[512]; // mkv stores h.264 avcC in CodecPrivate
	bzero(&avcCAtom, 512);
	memcpy(&avcCAtom, trackInfo->CodecPrivate, trackInfo->CodecPrivateSize);
		
	// regenerate SPS / PPS NALs from CodecPrivate
	int codecPrivateSize = trackInfo->CodecPrivateSize;
	uint8_t m_nal_size_size = 1 + (avcCAtom[4] & 3);
	int numsps = avcCAtom[5] & 0x1f;
	
	for (int i=0; i < 2; i++) // write SPS/PPS twice to simulate file rewind
	{
		uint32_t pos = 6;
		int i;
		for (i = 0; (i < numsps) && (codecPrivateSize > pos); ++i)
			write_nal(socketFD, avcCAtom, &pos, codecPrivateSize, 2);
		
		if (codecPrivateSize <= pos) return MP4_INVALID_TRACK_ID;
		
		int numpps = avcCAtom[pos++];
		
		for (i = 0; (i < numpps) && (codecPrivateSize > pos); ++i)
			write_nal(socketFD, avcCAtom, &pos, codecPrivateSize, 2);
	}
	
	// stream raw track to reader
	/* mask other tracks because we don't need them */ 
	mkv_SetTrackMask(matroskaFile, ~(1 << srcTrackId)); 
	
	uint64_t              StartTime, EndTime, FilePos; 
	uint32_t              rt, FrameSize, FrameFlags; 
	uint32_t              fb = 0; 
	void              *frame = NULL; 
	CompressedStream *cs = NULL;
	
	
	/* init zlib decompressor if needed */ 
	if (trackInfo->CompEnabled) 
	{ 
		char err_msg[512];
		cs = cs_Create(matroskaFile, srcTrackId, err_msg, sizeof(err_msg)); 
		if (cs == NULL) { 
			NSLog(@"Can't create decompressor: %s",err_msg); 
			
			return MP4_INVALID_TRACK_ID;
		} 
	} 
	
	/* read frames from file */ 
	while (mkv_ReadFrame(matroskaFile, 0, &rt, &StartTime, &EndTime, &FilePos, &FrameSize, &FrameFlags) == 0) 
	{ 
        printf("StartTime: %llu EndTime: %llu\n", StartTime, EndTime);
		if (cs) { 
			char buffer[1024]; 
			
			cs_NextFrame(cs,FilePos,FrameSize); 
			for (;;) { 
				int rd = cs_ReadData(cs,buffer,sizeof(buffer)); 
				if (rd < 0) { 
					fprintf(stderr,"Error decompressing data: %s\n",cs_GetLastError(cs)); 
					return MP4_INVALID_TRACK_ID;
				} 
				if (rd == 0) 
					break; 
				int pos = 0;
				
				while (rd > pos)
					write_nal(socketFD, buffer, &pos, rd, m_nal_size_size);
				
			} 
		} 
		else 
		{ 
			size_t          rd; 
			
			if (fseeko(ioStream->fp, FilePos, SEEK_SET)) 
			{ 
				fprintf(stderr,"fseeko(): %s\n", strerror(errno)); 
				
				return MP4_INVALID_TRACK_ID;				
			} 
			
			if (fb < FrameSize) { 
				fb = FrameSize; 
				frame = realloc(frame, fb); 
				if (frame == NULL) { 
					fprintf(stderr,"Out of memory\n"); 
					
					return MP4_INVALID_TRACK_ID;				
				} 
			} 
			
			rd = fread(frame,1,FrameSize,ioStream->fp); 
			if (rd != FrameSize) { 
				if (rd == 0) { 
					if (feof(ioStream->fp)) 
						fprintf(stderr,"Unexpected EOF while reading frame\n"); 
					else 
						fprintf(stderr,"Error reading frame: %s\n",strerror(errno)); 
				} else 
					fprintf(stderr,"Short read while reading frame\n"); 
				break;
			}
			uint32_t pos = 0;
			
			while (FrameSize > pos)
				write_nal(socketFD, frame, &pos, FrameSize, m_nal_size_size);
		} 
	} 
	
	return srcTrackId;	
}
						   

void write_nal(int socketFD,
			   const char *data,
                     uint32_t *pos,
                     uint32_t data_size,
                     uint8_t write_nal_size_size)
{
	uint8_t s_start_code[4] = { 0x00, 0x00, 0x00, 0x01 }; // stream start code

	int i;
	uint32_t nal_size = 0;
	
	for (i = 0; i < write_nal_size_size; ++i)
	{
		nal_size <<= 8;
		nal_size |= (uint8_t)data[(*pos)++];
	}
		

	
	if ((*pos + nal_size) > data_size)
		fprintf(stderr, "Track: NAL too big\n");
	
	// buffer startcode and NAL
	uint32_t writebuffersize = 4 + nal_size;
	uint8_t *writebuffer = malloc(writebuffersize); 
	memcpy(writebuffer, s_start_code, 4);
	memcpy(writebuffer+4, data + *pos, nal_size);
	
	// write to socket
	uint32_t bytes_written = 0; 
	uint32_t bytes_to_go = writebuffersize; 
	uint32_t bytes_written_this_time = 0;
	while (bytes_to_go)
	{
		bytes_written_this_time = write(socketFD, writebuffer+bytes_written, bytes_to_go);
		if (bytes_written_this_time == -1)
		{
			bytes_written_this_time = 0;
			if (errno != EAGAIN) 
			{
				fprintf(stderr, "error %i", errno);
				break;
			}
		}
		bytes_written += bytes_written_this_time;
		bytes_to_go -= bytes_written_this_time;
	}
	if (bytes_written < writebuffersize)
	{
		printf("Short socket write");
	}
	
	*pos += nal_size;
	free(writebuffer);
}

