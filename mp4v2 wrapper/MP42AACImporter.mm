//
//  MP42AacFileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 07/12/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import "MP42AACImporter.h"
#import "lang.h"
#import "MP42File.h"

@implementation MP42AACImporter

static const char*  ProgName = "Subler";
static int aacUseOldFile = 0;
static int aacProfileLevel = 4;

#define MP4AV_AAC_MAIN_PROFILE	0
#define MP4AV_AAC_LC_PROFILE	1
#define MP4AV_AAC_SSR_PROFILE	2
#define MP4AV_AAC_LTP_PROFILE	3

#include <assert.h>
#include <ctype.h> /* isdigit, isprint, isspace */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <sys/types.h>
#include "mbs.h"

#ifdef __cplusplus
extern "C" {
#endif
    
    uint8_t MP4AV_AacConfigGetAudioObjectType(uint8_t *pConfig);
    
    u_int8_t MP4AV_AacConfigGetSamplingRateIndex(
                                                 u_int8_t* pConfig);
    
    u_int32_t MP4AV_AacConfigGetSamplingRate(
                                             u_int8_t* pConfig);
    
    u_int16_t MP4AV_AacConfigGetSamplingWindow(
                                               u_int8_t* pConfig);
    
    u_int8_t MP4AV_AacConfigGetChannels(
                                        u_int8_t* pConfig);
    
    bool MP4AV_AacGetConfigurationFromAdts(
                                           u_int8_t** ppConfig,
                                           u_int32_t* pConfigLength,
                                           u_int8_t* pAdtsHdr);
    
    bool MP4AV_AacGetConfiguration(
                                   u_int8_t** ppConfig,
                                   u_int32_t* pConfigLength,
                                   u_int8_t profile,
                                   u_int32_t samplingRate,
                                   u_int8_t channels);
    
    bool MP4AV_AacGetConfiguration_SBR(
                                       u_int8_t** ppConfig,
                                       u_int32_t* pConfigLength,
                                       u_int8_t profile,
                                       u_int32_t samplingRate,
                                       u_int8_t channels);
    
    void MP4AV_LatmGetConfiguration(uint8_t **ppConfig,
                                    uint32_t *pConfigLength,
                                    const uint8_t *AudioSpecificConfig,
                                    uint32_t AudioSpecificConfigLen);
    bool MP4AV_AacGetConfiguration_LATM(u_int8_t** ppConfig,
                                        u_int32_t* pConfigLength,
                                        u_int8_t profile,
                                        u_int32_t samplingRate,
                                        u_int8_t channels);
#ifdef __cplusplus
}
#endif

#ifdef __cplusplus
extern "C" {
#endif
    
#define NUM_ADTS_SAMPLING_RATES	16
    
    extern u_int32_t AdtsSamplingRates[NUM_ADTS_SAMPLING_RATES];
    
    bool MP4AV_AdtsGetNextFrame(
                                u_int8_t* pSrc, 
                                u_int32_t srcLength,
                                u_int8_t** ppFrame, 
                                u_int32_t* pFrameSize);
    
    u_int16_t MP4AV_AdtsGetFrameSize(
                                     u_int8_t* pHdr);
    
    u_int16_t MP4AV_AdtsGetHeaderBitSize(
                                         u_int8_t* pHdr);
    
    u_int16_t MP4AV_AdtsGetHeaderByteSize(
                                          u_int8_t* pHdr);
    
    u_int8_t MP4AV_AdtsGetVersion(
                                  u_int8_t* pHdr);
    
    u_int8_t MP4AV_AdtsGetProfile(
                                  u_int8_t* pHdr);
    
    u_int8_t MP4AV_AdtsGetSamplingRateIndex(
                                            u_int8_t* pHdr);
    
    u_int8_t MP4AV_AdtsFindSamplingRateIndex(
                                             u_int32_t samplingRate);
    
    u_int32_t MP4AV_AdtsGetSamplingRate(
                                        u_int8_t* pHdr);
    
    u_int8_t MP4AV_AdtsGetChannels(
                                   u_int8_t* pHdr);
    
    bool MP4AV_AdtsMakeFrame(
                             u_int8_t* pData,
                             u_int16_t dataLength,
                             bool isMpeg2,
                             u_int8_t profile,
                             u_int32_t samplingFrequency,
                             u_int8_t channels,
                             u_int8_t** ppAdtsData,
                             u_int32_t* pAdtsDataLength);
    
    
#ifdef __cplusplus
}
#endif

/*
 * ADTS Header: 
 *  MPEG-2 version 56 bits (byte aligned) 
 *  MPEG-4 version 56 bits (byte aligned) - note - changed for 0.99 version
 *
 * syncword						12 bits
 * id							1 bit
 * layer						2 bits
 * protection_absent			1 bit
 * profile						2 bits
 * sampling_frequency_index		4 bits
 * private						1 bit
 * channel_configuraton			3 bits
 * original						1 bit
 * home							1 bit
 * copyright_id					1 bit
 * copyright_id_start			1 bit
 * aac_frame_length				13 bits
 * adts_buffer_fullness			11 bits
 * num_raw_data_blocks			2 bits
 *
 * if (protection_absent == 0)
 *	crc_check					16 bits
 */

#define NUM_ADTS_SAMPLING_RATES	16

u_int32_t AdtsSamplingRates[NUM_ADTS_SAMPLING_RATES] = {
    96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 
    16000, 12000, 11025, 8000, 7350, 0, 0, 0
};

/*
 * compute ADTS frame size
 */
u_int16_t MP4AV_AdtsGetFrameSize(u_int8_t* pHdr)
{
	/* extract the necessary fields from the header */
	uint16_t frameLength;
    
	frameLength = (((u_int16_t)(pHdr[3] & 0x3)) << 11) 
    | (((u_int16_t)pHdr[4]) << 3) | (pHdr[5] >> 5); 
    
	return frameLength;
}

/*
 * Compute length of ADTS header in bits
 */
u_int16_t MP4AV_AdtsGetHeaderBitSize(u_int8_t* pHdr)
{
	u_int8_t hasCrc = !(pHdr[1] & 0x01);
	u_int16_t hdrSize;
    
	hdrSize = 56;
    
	if (hasCrc) {
		hdrSize += 16;
	}
	return hdrSize;
}

u_int16_t MP4AV_AdtsGetHeaderByteSize(u_int8_t* pHdr)
{
	return (MP4AV_AdtsGetHeaderBitSize(pHdr) + 7) / 8;
}

u_int8_t MP4AV_AdtsGetVersion(u_int8_t* pHdr)
{
	return (pHdr[1] & 0x08) >> 3;
}

u_int8_t MP4AV_AdtsGetProfile(u_int8_t* pHdr)
{
	return (pHdr[2] & 0xc0) >> 6;
}

u_int8_t MP4AV_AdtsGetSamplingRateIndex(u_int8_t* pHdr)
{
	return (pHdr[2] & 0x3c) >> 2;
}

u_int8_t MP4AV_AdtsFindSamplingRateIndex(u_int32_t samplingRate)
{
	for (u_int8_t i = 0; i < NUM_ADTS_SAMPLING_RATES; i++) {
		if (samplingRate == AdtsSamplingRates[i]) {
			return i;
		}
	}
	return NUM_ADTS_SAMPLING_RATES - 1;
}

u_int32_t MP4AV_AdtsGetSamplingRate(u_int8_t* pHdr)
{
	return AdtsSamplingRates[MP4AV_AdtsGetSamplingRateIndex(pHdr)];
}

u_int8_t MP4AV_AdtsGetChannels(u_int8_t* pHdr)
{
	return ((pHdr[2] & 0x1) << 2) | ((pHdr[3] & 0xc0) >> 6);
}


bool MP4AV_AdtsMakeFrame(
                                    u_int8_t* pData,
                                    u_int16_t dataLength,
                                    bool isMpeg2,
                                    u_int8_t profile,
                                    u_int32_t samplingFrequency,
                                    u_int8_t channels,
                                    u_int8_t** ppAdtsData,
                                    u_int32_t* pAdtsDataLength)
{
	*pAdtsDataLength = 7 + dataLength; // 56 bits only
    
	CMemoryBitstream adts;
    
	try {
		adts.AllocBytes(*pAdtsDataLength);
		*ppAdtsData = adts.GetBuffer();
        
		// build adts header
		adts.PutBits(0xFFF, 12);		// syncword
		adts.PutBits(isMpeg2, 1);		// id
		adts.PutBits(0, 2);				// layer
		adts.PutBits(1, 1);				// protection_absent
		adts.PutBits(profile, 2);		// profile
		adts.PutBits(
                     MP4AV_AdtsFindSamplingRateIndex(samplingFrequency),
                     4);							// sampling_frequency_index
		adts.PutBits(0, 1);				// private
		adts.PutBits(channels, 3);		// channel_configuration
		adts.PutBits(0, 1);				// original
		adts.PutBits(0, 1);				// home
        
		adts.PutBits(0, 1);				// copyright_id
		adts.PutBits(0, 1);				// copyright_id_start
		adts.PutBits(*pAdtsDataLength, 13);	// aac_frame_length
		adts.PutBits(0x7FF, 11);		// adts_buffer_fullness
		adts.PutBits(0, 2);				// num_raw_data_blocks
        
		// copy audio frame data
		adts.PutBytes(pData, dataLength);
	}
	catch (...) {
		return false;
	}
    
	return true;
}

/*
 * AAC Config in ES:
 *
 * AudioObjectType 			5 bits
 * samplingFrequencyIndex 	4 bits
 * if (samplingFrequencyIndex == 0xF)
 *	samplingFrequency	24 bits 
 * channelConfiguration 	4 bits
 * GA_SpecificConfig
 * 	FrameLengthFlag 		1 bit 1024 or 960
 * 	DependsOnCoreCoder		1 bit (always 0)
 * 	ExtensionFlag 			1 bit (always 0)
 */

extern "C" uint8_t MP4AV_AacConfigGetAudioObjectType (uint8_t *pConfig)
{
    return pConfig[0] >> 3;
}

extern "C" u_int8_t MP4AV_AacConfigGetSamplingRateIndex(u_int8_t* pConfig)
{
	return ((pConfig[0] << 1) | (pConfig[1] >> 7)) & 0xF;
}

extern "C" u_int32_t MP4AV_AacConfigGetSamplingRate(u_int8_t* pConfig)
{
	u_int8_t index =
    MP4AV_AacConfigGetSamplingRateIndex(pConfig);
    
	if (index == 0xF) {
		return (pConfig[1] & 0x7F) << 17
        | pConfig[2] << 9
        | pConfig[3] << 1
        | (pConfig[4] >> 7);
	}
	return AdtsSamplingRates[index];
}

extern "C" u_int16_t MP4AV_AacConfigGetSamplingWindow(u_int8_t* pConfig)
{
	u_int8_t adjust = 0;
    
	if (MP4AV_AacConfigGetSamplingRateIndex(pConfig) == 0xF) {
		adjust = 3;
	}
    
	if ((pConfig[1 + adjust] >> 2) & 0x1) {
		return 960;
	}
	return 1024;
}

extern "C" u_int8_t MP4AV_AacConfigGetChannels(u_int8_t* pConfig)
{
	u_int8_t adjust = 0;
    
	if (MP4AV_AacConfigGetSamplingRateIndex(pConfig) == 0xF) {
		adjust = 3;
	}
	return (pConfig[1 + adjust] >> 3) & 0xF;
}

extern "C" bool MP4AV_AacGetConfigurationFromAdts(
                                                  u_int8_t** ppConfig,
                                                  u_int32_t* pConfigLength,
                                                  u_int8_t* pHdr)
{
	return MP4AV_AacGetConfiguration(
                                     ppConfig,
                                     pConfigLength,
                                     MP4AV_AdtsGetProfile(pHdr),
                                     MP4AV_AdtsGetSamplingRate(pHdr),
                                     MP4AV_AdtsGetChannels(pHdr));
}

extern "C" bool MP4AV_AacGetConfiguration(
                                          u_int8_t** ppConfig,
                                          u_int32_t* pConfigLength,
                                          u_int8_t profile,
                                          u_int32_t samplingRate,
                                          u_int8_t channels)
{
	/* create the appropriate decoder config */
    
	u_int8_t* pConfig = (u_int8_t*)malloc(2);
    
	if (pConfig == NULL) {
		return false;
	}
    
	u_int8_t samplingRateIndex = 
    MP4AV_AdtsFindSamplingRateIndex(samplingRate);
    
	pConfig[0] =
    ((profile + 1) << 3) | ((samplingRateIndex & 0xe) >> 1);
	pConfig[1] =
    ((samplingRateIndex & 0x1) << 7) | (channels << 3);
    
	/* LATER this option is not currently used in MPEG4IP
     if (samplesPerFrame == 960) {
     pConfig[1] |= (1 << 2);
     }
     */
    
	*ppConfig = pConfig;
	*pConfigLength = 2;
    
	return true;
}

extern "C" bool MP4AV_AacGetConfiguration_SBR(
                                              u_int8_t** ppConfig,
                                              u_int32_t* pConfigLength,
                                              u_int8_t profile,
                                              u_int32_t samplingRate,
                                              u_int8_t channels)
{
    /* create the appropriate decoder config */
    
    u_int8_t* pConfig = (u_int8_t*)malloc(5);
    if (pConfig == NULL) return false;
    
    pConfig[0] = 0;
    pConfig[1] = 0;
    pConfig[2] = 0;
    pConfig[3] = 0;
    pConfig[4] = 0;
    
    if (pConfig == NULL) {
        return false;
    }
    
    u_int8_t samplingRateIndex = 
    MP4AV_AdtsFindSamplingRateIndex(samplingRate);
    
    pConfig[0] =
    ((profile + 1) << 3) | ((samplingRateIndex & 0xe) >> 1);
    pConfig[1] =
    ((samplingRateIndex & 0x1) << 7) | (channels << 3);
    
    /* pConfig[0] & pConfig[1] now contain the backward compatible
     AudioSpecificConfig
     */
    
    /* SBR stuff */
    const u_int16_t syncExtensionType = 0x2B7;
    u_int8_t extensionSamplingRateIndex = 
    MP4AV_AdtsFindSamplingRateIndex(2*samplingRate);
    
    pConfig[2] = (syncExtensionType >> 3) & 0xFF;
    pConfig[3] = ((syncExtensionType & 0x7) << 5) | 5 /* ext ot id */;
    pConfig[4] = ((1 & 0x1) << 7) | (extensionSamplingRateIndex << 3);
    
    *ppConfig = pConfig;
    *pConfigLength = 5;
    
    return true;
}

extern "C" void MP4AV_LatmGetConfiguration (uint8_t **ppConfig,
                                            uint32_t *pConfigLength,
                                            const uint8_t *AudioSpecificConfig,
                                            uint32_t AudioSpecificConfigLen)
{
    *ppConfig = NULL;
    *pConfigLength = 0;
    uint32_t ix;
    uint8_t *stream_mux_config = (uint8_t *)malloc(AudioSpecificConfigLen + 2 + 3);
    if (stream_mux_config == NULL) return;
    
    stream_mux_config[0] = 0x80;
    stream_mux_config[1] = 0;
    for (ix = 0; ix < AudioSpecificConfigLen; ix++) {
        stream_mux_config[ix + 1] |= (AudioSpecificConfig[ix] >> 7) & 0x1;
        stream_mux_config[ix + 2] = AudioSpecificConfig[ix] << 1;
    }
    stream_mux_config[ix + 2] = 0x3f;
    stream_mux_config[ix + 3] = 0xc0;
    *ppConfig = stream_mux_config;
    *pConfigLength = ix + 3;
}

extern "C" bool MP4AV_AacGetConfiguration_LATM (
                                                u_int8_t** ppConfig,
                                                u_int32_t* pConfigLength,
                                                u_int8_t profile,
                                                u_int32_t samplingRate,
                                                u_int8_t channels)
{
	/* create the appropriate config string */
    
	u_int8_t* pConfig = (u_int8_t*)malloc(6);
    
	if (pConfig == NULL) {
		return false;
	}
    
	u_int8_t samplingRateIndex = MP4AV_AdtsFindSamplingRateIndex(samplingRate);
    
    // StreamMuxConfig
    pConfig[0] = 0x40;
    pConfig[1] = ((profile+1 & 0x10) >> 5);
    
	pConfig[2] = (((profile + 1) & 0x0f) << 4) | (samplingRateIndex & 0x0f);
    
    pConfig[3] = (channels << 4);
    pConfig[4] = 0x3f;
    pConfig[5] = 0xc0;
    
    
	*ppConfig = pConfig;
	*pConfigLength = 6;
    
	return true;
}


#define ADTS_HEADER_MAX_SIZE 10 /* bytes */

static u_int8_t firstHeader[ADTS_HEADER_MAX_SIZE];
static u_int16_t OLD_MP4AV_AdtsGetFrameSize(u_int8_t* pHdr)
{
	/* extract the necessary fields from the header */
	u_int8_t isMpeg4 = !(pHdr[1] & 0x08);
	u_int16_t frameLength;
    
	if (isMpeg4) {
		frameLength = (((u_int16_t)pHdr[4]) << 5) | (pHdr[5] >> 3); 
	} else { /* MPEG-2 */
		frameLength = (((u_int16_t)(pHdr[3] & 0x3)) << 11) 
        | (((u_int16_t)pHdr[4]) << 3) | (pHdr[5] >> 5); 
	}
    
	return frameLength;
}
static u_int16_t OLD_MP4AV_AdtsGetHeaderBitSize(u_int8_t* pHdr)
{
	u_int8_t isMpeg4 = !(pHdr[1] & 0x08);
	u_int8_t hasCrc = !(pHdr[1] & 0x01);
	u_int16_t hdrSize;
    
	if (isMpeg4) {
		hdrSize = 58;
	} else {
		hdrSize = 56;
	}
	if (hasCrc) {
		hdrSize += 16;
	}
	return hdrSize;
}

static u_int16_t OLD_MP4AV_AdtsGetHeaderByteSize(u_int8_t* pHdr)
{
	return (OLD_MP4AV_AdtsGetHeaderBitSize(pHdr) + 7) / 8;
}

/* 
 * hdr must point to at least ADTS_HEADER_MAX_SIZE bytes of memory 
 */
static bool LoadNextAdtsHeader(FILE* inFile, u_int8_t* hdr)
{
	u_int state = 0;
	u_int dropped = 0;
	u_int hdrByteSize = ADTS_HEADER_MAX_SIZE;
    
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
			/* have first byte, check if we have 1111X00X */
			if (state == 1) {
				if ((b & 0xF6) == 0xF0) {
					hdr[state] = b;
					state = 2;
					/* compute desired header size */
					if (aacUseOldFile) {
                        hdrByteSize = OLD_MP4AV_AdtsGetHeaderByteSize(hdr);
					} else {
                        hdrByteSize = MP4AV_AdtsGetHeaderByteSize(hdr);
					}
				} else {
					state = 0;
					dropped ++;
				}
			}
			/* initial state, looking for 11111111 */
			if (state == 0) {
				if (b == 0xFF) {
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
static bool LoadNextAacFrame(FILE* inFile, u_int8_t* pBuf, u_int32_t* pBufSize, bool stripAdts)
{
	u_int16_t frameSize;
	u_int16_t hdrBitSize, hdrByteSize;
	u_int8_t hdrBuf[ADTS_HEADER_MAX_SIZE];
    
	/* get the next AAC frame header, more or less */
	if (!LoadNextAdtsHeader(inFile, hdrBuf)) {
		return false;
	}
	
	/* get frame size from header */
	if (aacUseOldFile) {
        frameSize = OLD_MP4AV_AdtsGetFrameSize(hdrBuf);
        /* get header size in bits and bytes from header */
        hdrBitSize = OLD_MP4AV_AdtsGetHeaderBitSize(hdrBuf);
        hdrByteSize = OLD_MP4AV_AdtsGetHeaderByteSize(hdrBuf);
	} else {
        frameSize = MP4AV_AdtsGetFrameSize(hdrBuf);
        /* get header size in bits and bytes from header */
        hdrBitSize = MP4AV_AdtsGetHeaderBitSize(hdrBuf);
        hdrByteSize = MP4AV_AdtsGetHeaderByteSize(hdrBuf);
	}
    
	
	/* adjust the frame size to what remains to be read */
	frameSize -= hdrByteSize;
    
	if (stripAdts) {
		if ((hdrBitSize % 8) == 0) {
			/* header is byte aligned, i.e. MPEG-2 ADTS */
			/* read the frame data into the buffer */
			if (fread(pBuf, 1, frameSize, inFile) != frameSize) {
				return false;
			}
			(*pBufSize) = frameSize;
		} else {
			/* header is not byte aligned, i.e. MPEG-4 ADTS */
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
	} else { /* don't strip ADTS headers */
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
	if (firstHeader[0] == 0xff) {
		return true;
	}
    
	/* remember where we are */
	fgetpos(inFile, &curPos);
	
	/* go back to start of file */
	rewind(inFile);
    
	if (!LoadNextAdtsHeader(inFile, firstHeader)) {
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

        newTrack.format = @"AAC";
        newTrack.sourceFormat = @"AAC";
        newTrack.sourcePath = file;
        newTrack.sourceInputType = MP42SourceTypeRaw;

        if (!inFile)
            inFile = fopen([file UTF8String], "rb");

        // collect all the necessary meta information
        u_int8_t mpegVersion;
        u_int8_t profile;
        u_int8_t channelConfig;
        
        if (!GetFirstHeader(inFile)) {
            fprintf(stderr,	
                    "%s: data in file doesn't appear to be valid audio\n",
                    ProgName);
            return MP4_INVALID_TRACK_ID;
        }
        
        samplesPerSecond = MP4AV_AdtsGetSamplingRate(firstHeader);
        mpegVersion = MP4AV_AdtsGetVersion(firstHeader);
        profile = MP4AV_AdtsGetProfile(firstHeader);
        if (aacProfileLevel == 2) {
            if (profile > MP4_MPEG4_AAC_SSR_AUDIO_TYPE) {
                fprintf(stderr, "Can't convert profile to mpeg2\nDo not contact project creators for help\n");
                return MP4_INVALID_TRACK_ID;
            }
            mpegVersion = 1;
        } else if (aacProfileLevel == 4) {
            mpegVersion = 0;
        }
        channelConfig = MP4AV_AdtsGetChannels(firstHeader);
        
        u_int8_t audioType = MP4_INVALID_AUDIO_TYPE;
        switch (mpegVersion) {
            case 0:
                audioType = MP4_MPEG4_AUDIO_TYPE;
                break;
            case 1:
                switch (profile) {
                    case 0:
                        audioType = MP4_MPEG2_AAC_MAIN_AUDIO_TYPE;
                        break;
                    case 1:
                        audioType = MP4_MPEG2_AAC_LC_AUDIO_TYPE;
                        break;
                    case 2:
                        audioType = MP4_MPEG2_AAC_SSR_AUDIO_TYPE;
                        break;
                    case 3:
                        fprintf(stderr,	
                                "%s: data in file doesn't appear to be valid audio\n",
                                ProgName);
                        return MP4_INVALID_TRACK_ID;
                    default:
                        break;
                        //ASSERT(false);
                }
                break;
            default:
                break;
                //ASSERT(false);
        }

        u_int8_t* pConfig = NULL;
        u_int32_t configLength = 0;
        
        MP4AV_AacGetConfiguration(
                                  &pConfig,
                                  &configLength,
                                  profile,
                                  samplesPerSecond,
                                  channelConfig);

        [(MP42AudioTrack*) newTrack setChannels:channelConfig];
        aacInfo = [[NSMutableData alloc] init];
        [aacInfo appendBytes:pConfig length:configLength];

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
    
    return aacInfo;
}

- (void) fillMovieSampleBuffer: (id)sender
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    if (!inFile)
        inFile = fopen([file UTF8String], "rb");

    MP42Track *track = [activeTracks lastObject];
    MP4TrackId dstTrackId = [track Id];

    // parse the ADTS frames, and write the MP4 samples
    u_int8_t sampleBuffer[8 * 1024];
    u_int32_t sampleSize = sizeof(sampleBuffer);
    MP4SampleId sampleId = 1;

    while (LoadNextAacFrame(inFile, sampleBuffer, &sampleSize, true)) {
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
        [dataReader setName:@"AAC Demuxer"];
        [dataReader start];
    }

    while (![samplesBuffer count] && !readerStatus)
        usleep(2000);

    if (readerStatus)
        if ([samplesBuffer count] == 0) {
            readerStatus = 0;
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

- (CGFloat)progress {
    return 100.0;
}

- (void) dealloc
{
    fclose(inFile);
    [aacInfo release];
	[file release];
    [tracksArray release];

    [super dealloc];
}

@end
