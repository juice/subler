//
//  MP42AC3FileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 07/12/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import "MP42AC3Importer.h"
#import "lang.h"
#import "MP42File.h"
#include <sys/stat.h>

#define AC3_HEADER_MAX_SIZE 10 /* bytes */
#define NUM_AC3_SAMPLING_RATES 4
#define NUM_AC3_FRAMECODE_SIZES 19 * 2


@implementation MP42AC3Importer

u_int32_t Ac3SamplingRates[NUM_AC3_SAMPLING_RATES] = {
    48000, 44100, 32000, 0
};

// Format(frmsizecod) 
// Nominal bit rate (kbit/s), Words/syncframe (32 kHz), Words/syncframe (44.1 kHz), Words/syncframe (48 kHz)
u_int32_t Ac3FrameSize[NUM_AC3_FRAMECODE_SIZES][4] = {
    {32, 96, 69, 64},
    {32, 96, 70, 64},
    {40, 120, 87, 80},
    {40, 120, 88, 80},
    {48, 144, 104, 96},
    {48, 144, 105, 96},
    {56, 168, 121, 112},
    {56, 168, 122, 112},
    {64, 192, 139, 128},
    {64, 192, 140, 128},
    {80, 240, 174, 160},
    {80, 240, 175, 160},
    {96, 288, 208, 192},
    {96, 288, 209, 192},
    {112, 336, 243, 224},
    {112, 336, 244, 224},
    {128, 384, 278, 256},
    {128, 384, 279, 256},
    {160, 480, 348, 320},
    {160, 480, 349, 320},
    {192, 576, 417, 384},
    {192, 576, 418, 384},
    {224, 672, 487, 448},
    {224, 672, 488, 448},
    {256, 768, 557, 512},
    {256, 768, 558, 512},
    {320, 960, 696, 640},
    {320, 960, 697, 640},
    {384, 1152, 835, 768},
    {384, 1152, 836, 768},
    {448, 1344, 975, 896},
    {448, 1344, 976, 896},
    {512, 1536, 1114, 1024},
    {512, 1536, 1115, 1024},
    {576, 1728, 1253, 1152},
    {576, 1728, 1254, 1152},
    {640, 1920, 1393, 1280},
    {640, 1920, 1394, 1280},
};

static u_int8_t firstHeader[AC3_HEADER_MAX_SIZE];

static u_int16_t MP4AV_Ac3GetHeaderBitSize(u_int8_t* pHdr)
{
	return AC3_HEADER_MAX_SIZE * 8;
}

static u_int16_t MP4AV_Ac3GetHeaderByteSize(u_int8_t* pHdr)
{
	return AC3_HEADER_MAX_SIZE;
}

static u_int8_t MP4AV_Ac3GetSamplingRateIndex(u_int8_t* pHdr)
{
	return ((pHdr[4] & 0xC0) >> 6);
}

static u_int32_t MP4AV_Ac3GetSamplingRate(u_int8_t* pHdr)
{
	return Ac3SamplingRates[MP4AV_Ac3GetSamplingRateIndex(pHdr)];
}

static u_int8_t MP4AV_Ac3GetFrameSizeCode(u_int8_t* pHdr)
{
	return (pHdr[4] & 0x3F);
}

static u_int16_t MP4AV_Ac3GetFrameSize(u_int8_t* pHdr)
{
	u_int8_t index = MP4AV_Ac3GetSamplingRateIndex(pHdr);
	u_int8_t frmsizecod = MP4AV_Ac3GetFrameSizeCode(pHdr);
	// table returns words
	return Ac3FrameSize[frmsizecod][3 - index] * 2;
}

/* 
 * hdr must point to at least Ac3_HEADER_MAX_SIZE bytes of memory 
 */
static bool LoadNextAc3Header(FILE* inFile, u_int8_t* hdr)
{
	u_int state = 0;
	u_int dropped = 0;
	u_int hdrByteSize = AC3_HEADER_MAX_SIZE;
    
	while (1) {
		/* read a byte */
		u_int8_t b;
        
		if (fread(&b, 1, 1, inFile) == 0) {
			return false;
		}
        
		/* header is complete, return it */
		if (state == hdrByteSize - 1) {
			hdr[state] = b;
			if (dropped > 0) {
#ifdef DEBUG
                fprintf(stderr, "Warning: dropped %u input bytes at offset %u\n", dropped,
                        ftell(inFile) - dropped - state - 1);
#endif
			}
			return true;
		}
        
		/* collect requisite number of bytes, no constraints on data */
		if (state >= 2) {
			hdr[state++] = b;
		} else {
			/* have first byte, check if we have 0111 0111 */
			if (state == 1) {
				if (b == 0x77) {
					hdr[state] = b;
					state = 2;
					/* compute desired header size */
					hdrByteSize = MP4AV_Ac3GetHeaderByteSize(hdr);
				} else {
					state = 0;
					dropped ++;
				}
			}
			/* initial state, looking for 0000 1011 */
			if (state == 0) {
				if (b == 0x0B) {
					hdr[state] = b;
					state = 1;
				} else {
                    /* else drop it */ 
					dropped++;
					//					printf("%02x ", b);
				}
			}
		}
	}
}

/*
 * Load the next frame from the file
 * into the supplied buffer, which better be large enough!
 *
 * Note: Frames are padded to byte boundaries
 */
static bool LoadNextAc3Frame(FILE* inFile, u_int8_t* pBuf, u_int32_t* pBufSize, bool stripAc3)
{
	u_int16_t frameSize;
	u_int16_t hdrBitSize, hdrByteSize;
	u_int8_t hdrBuf[AC3_HEADER_MAX_SIZE];
    
	/* get the next Ac3 frame header, more or less */
	if (!LoadNextAc3Header(inFile, hdrBuf)) {
		return false;
	}
	
	/* get frame size from header */
	frameSize = MP4AV_Ac3GetFrameSize(hdrBuf);
	*pBufSize = frameSize;
	/* get header size in bits and bytes from header */
	hdrBitSize = MP4AV_Ac3GetHeaderBitSize(hdrBuf);
	hdrByteSize = MP4AV_Ac3GetHeaderByteSize(hdrBuf);
	
	/* adjust the frame size to what remains to be read */
	frameSize -= hdrByteSize;
    
	if (stripAc3) {
		if ((hdrBitSize % 8) == 0) {
			/* header is byte aligned, i.e. MPEG-2 Ac3 */
			/* read the frame data into the buffer */
			if (fread(pBuf, 1, frameSize, inFile) != frameSize) {
				return false;
			}
			(*pBufSize) = frameSize;
		} else {
			/* header is not byte aligned, i.e. MPEG-4 Ac3 */
			int i;
			u_int8_t newByte;
			int upShift = hdrBitSize % 8;
			int downShift = 8 - upShift;
            
			pBuf[0] = hdrBuf[hdrBitSize / 8] << upShift;
            
			for (i = 0; i < frameSize; i++) {
				if (fread(&newByte, 1, 1, inFile) != 1) {
					return false;
				}
				pBuf[i] |= (newByte >> downShift);
				pBuf[i+1] = (newByte << upShift);
			}
			(*pBufSize) = frameSize + 1;
		}
	} else { /* don't strip Ac3 headers */
		memcpy(pBuf, hdrBuf, hdrByteSize);
		if (fread(&pBuf[hdrByteSize], 1, frameSize, inFile) != frameSize) {
			return false;
		}
	}
    
	return true;
}

static bool GetFirstHeader(FILE* inFile)
{
	/* read file until we find an audio frame */
	fpos_t curPos;
    
	/* already read first header */
	if (firstHeader[0] == 0x0b) {
		return true;
	}
    
	/* remember where we are */
	fgetpos(inFile, &curPos);
	
	/* go back to start of file */
	rewind(inFile);
    
	if (!LoadNextAc3Header(inFile, firstHeader)) {
		return false;
	}
    
	/* reposition the file to where we were */
	fsetpos(inFile, &curPos);
    
	return true;
}


- (id)initWithDelegate:(id)del andFile:(NSString *)fileUrl
{
    if ((self = [super init])) {
        delegate = del;
        file = [fileUrl retain];

        tracksArray = [[NSMutableArray alloc] initWithCapacity:1];

        MP42Track *newTrack = [[MP42AudioTrack alloc] init];

        newTrack.format = @"AC-3";
        newTrack.sourceFormat = @"AC-3";
        newTrack.sourcePath = file;
        newTrack.sourceInputType = MP42SourceTypeRaw;

        if (!inFile)
            inFile = fopen([file UTF8String], "rb");

        struct stat st;
        stat([file UTF8String], &st);
        size = st.st_size * 8;

        // collect all the necessary meta information
        uint32_t fscod, frmsizecod, bsid, bsmod, acmod, lfeon;
        uint32_t lfe_offset = 4;

        if (!GetFirstHeader(inFile)) {
            fprintf(stderr,	
                    "Subler: data in file doesn't appear to be valid ac3 audio\n");
        }

        fscod = (firstHeader[4] >> 6) & 0x3;
        frmsizecod = (firstHeader[4] & 0x3f);
        bsid =  (firstHeader[5] >> 3) & 0x1f;
        bsmod = (firstHeader[5] & 0xf);
        acmod = (firstHeader[6] >> 5) & 0x7;
        if (acmod == 2)
            lfe_offset -= 2;
        else {
            if ((acmod & 1) && acmod != 1)
                lfe_offset -= 2;
            if (acmod & 4)
                lfe_offset -= 2;
        }
        lfeon = (firstHeader[6] >> lfe_offset) & 0x1;

        samplesPerSecond = MP4AV_Ac3GetSamplingRate(firstHeader);

        int channels = 0;
        switch (acmod) {
            case 0:
            case 2:
                channels = 2;
                break;
            case 1:
                channels = 1;
                break;
            case 3:
            case 4:
                channels = 3;
                break;
            case 5:
            case 6:
                channels = 4;
                break;
            case 7:
                channels = 5;
                break;
        }
        if (lfeon)
            channels++;

        [(MP42AudioTrack*) newTrack setChannels:channels];

        ac3Info = [[NSMutableData alloc] init];
        [ac3Info appendBytes:&fscod length:sizeof(uint64_t)];
        [ac3Info appendBytes:&bsid length:sizeof(uint64_t)];
        [ac3Info appendBytes:&bsmod length:sizeof(uint64_t)];
        [ac3Info appendBytes:&acmod length:sizeof(uint64_t)];
        [ac3Info appendBytes:&lfeon length:sizeof(uint64_t)];
        [ac3Info appendBytes:&frmsizecod length:sizeof(uint64_t)];

        [tracksArray addObject:newTrack];
        [newTrack release];
    }

    return self;
}

- (NSUInteger)timescaleForTrack:(MP42Track *)track
{
    return samplesPerSecond;
}

- (NSSize)sizeForTrack:(MP42Track *)track
{
      return NSMakeSize([(MP42SubtitleTrack*)track trackWidth], [(MP42SubtitleTrack*) track trackHeight]);
}

- (NSData*)magicCookieForTrack:(MP42Track *)track
{
    
    return ac3Info;
}

- (void) fillMovieSampleBuffer: (id)sender
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    if (!inFile)
        inFile = fopen([file UTF8String], "rb");

    MP42Track *track = [activeTracks lastObject];
    MP4TrackId dstTrackId = [track Id];

    // parse the Ac3 frames, and write the MP4 samples
    u_int8_t sampleBuffer[8 * 1024];
    u_int32_t sampleSize = sizeof(sampleBuffer);
    MP4SampleId sampleId = 1;

    int64_t currentSize = 0;

    while (LoadNextAc3Frame(inFile, sampleBuffer, &sampleSize, false)) {
        while ([samplesBuffer count] >= 200) {
            usleep(200);
        }

        MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];

        void * sampleDataBuffer = malloc(sampleSize);
        memcpy(sampleDataBuffer, sampleBuffer, sampleSize);

        sample->sampleData = sampleDataBuffer;
        sample->sampleSize = sampleSize;
        sample->sampleDuration = MP4_INVALID_DURATION;
        sample->sampleOffset = 0;
        sample->sampleTimestamp = 0;
        sample->sampleIsSync = 1;
        sample->sampleTrackId = dstTrackId;
        if(track.needConversion)
            sample->sampleSourceTrack = track;

        @synchronized(samplesBuffer) {
            [samplesBuffer addObject:sample];
            [sample release];
        }

        sampleId++;
        sampleSize = sizeof(sampleBuffer);

        currentSize += sampleSize;
        progress = (currentSize / (CGFloat) size) * 100;
    }

    [pool release];
    readerStatus = 1;
}

- (MP42SampleBuffer*)copyNextSample {    
    if (samplesBuffer == nil) {
        samplesBuffer = [[NSMutableArray alloc] initWithCapacity:200];
    }

    if (!dataReader && !readerStatus) {
        dataReader = [[NSThread alloc] initWithTarget:self selector:@selector(fillMovieSampleBuffer:) object:self];
        [dataReader setName:@"AC-3 Demuxer"];
        [dataReader start];
    }

    while (![samplesBuffer count] && !readerStatus)
        usleep(2000);

    if (readerStatus)
        if ([samplesBuffer count] == 0) {
            readerStatus = 0;
            [dataReader release];
            dataReader = nil;
            return nil;
        }

    MP42SampleBuffer* sample;

    @synchronized(samplesBuffer) {
        sample = [samplesBuffer objectAtIndex:0];
        [sample retain];
        [samplesBuffer removeObjectAtIndex:0];
    }

    return sample;
}

- (void)setActiveTrack:(MP42Track *)track {
    if (!activeTracks)
        activeTracks = [[NSMutableArray alloc] init];
    
    [activeTracks addObject:track];
}

- (CGFloat)progress
{
    return progress;
}

- (void) dealloc
{
    if (dataReader)
        [dataReader release];
    if (samplesBuffer)
        [samplesBuffer release];

    fclose(inFile);

    [ac3Info release];
	[file release];
    [tracksArray release];
    [activeTracks release];

    [super dealloc];
}

@end
