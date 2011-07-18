//
//  SBVobSubConverter.m
//  Subler
//
//  Created by Damiano Galassi on 26/03/11.
//  VobSub code taken from Perian VobSubCodec.c
//  Copyright 2011 Damiano Galassi. All rights reserved.
//

#import "SBVobSubConverter.h"
#import "MP42File.h"
#import "MP42FileImporter.h"
#import "MP42Sample.h"
#import "SubUtilities.h"
#import "SBOCRWrapper.h"

#include "intreadwrite.h"

#define REGISTER_DECODER(x) { \
extern AVCodec x##_decoder; \
avcodec_register(&x##_decoder); }

void FFInitFFmpeg()
{
	/* This one is used because Global variables are initialized ONE time
     * until the application quits. Thus, we have to make sure we're initialize
     * the libavformat only once or we get an endlos loop when registering the same
     * element twice!! */
	static Boolean inited = FALSE;
	//int unlock = PerianInitEnter(&inited);
	
	/* Register the Parser of ffmpeg, needed because we do no proper setup of the libraries */
	if(!inited) {
		inited = TRUE;
		avcodec_init();
		//av_lockmgr_register(PerianLockMgrCallback);
		
		REGISTER_DECODER(dvdsub);
		
	}

	//PerianInitExit(unlock);
}

typedef struct {
	// color format is 32-bit ARGB
	UInt32  pixelColor[16];
	UInt32  duration;
} PacketControlData;

int ExtractVobSubPacket(UInt8 *dest, UInt8 *framedSrc, int srcSize, int *usedSrcBytes, int index) {
	int copiedBytes = 0;
	UInt8 *currentPacket = framedSrc;
	int packetSize = INT_MAX;
	
	while (currentPacket - framedSrc < srcSize && copiedBytes < packetSize) {
		// 3-byte start code: 0x00 00 01
		if (currentPacket[0] + currentPacket[1] != 0 || currentPacket[2] != 1) {
			//Codecprintf(NULL, "VobSub Codec: !! Unknown header: %02x %02x %02x\n", currentPacket[0], currentPacket[1], currentPacket[2]);
			return copiedBytes;
		}
		
		int packet_length;
		
		switch (currentPacket[3]) {
			case 0xba:
				// discard PS packets; nothing in them we're interested in
				// here, packet_length is the additional stuffing
				packet_length = currentPacket[13] & 0x7;
				
				currentPacket += 14 + packet_length;
				break;
				
			case 0xbe:
			case 0xbf:
				// skip padding and navigation data 
				// (navigation shouldn't be present anyway)
				packet_length = currentPacket[4];
				packet_length <<= 8;
				packet_length += currentPacket[5];
				
				currentPacket += 6 + packet_length;
				break;
				
			case 0xbd:
				// a private stream packet, contains subtitle data
				packet_length = currentPacket[4];
				packet_length <<= 8;
				packet_length += currentPacket[5];
				
				int header_data_length = currentPacket[8];
				int packetIndex = currentPacket[header_data_length + 9] & 0x1f;
				if(index == -1)
					index = packetIndex;
				if(index == packetIndex)
				{
					int blockSize = packet_length - 1 - (header_data_length + 3);
					memcpy(&dest[copiedBytes], 
						   // header's 9 bytes + extension, we don't want 1st byte of packet
						   &currentPacket[9 + header_data_length + 1], 
						   // we don't want the 1-byte stream ID, or the header
						   blockSize);
					copiedBytes += blockSize;
                    
					if(packetSize == INT_MAX)
					{
						packetSize = dest[0] << 8 | dest[1];
					}
				}
				currentPacket += packet_length + 6;
				break;
				
			default:
				// unknown packet, probably video, return for now
				//Codecprintf(NULL, "VobSubCodec - Unknown packet type %x, aborting\n", (int)currentPacket[3]);
				return copiedBytes;
		} // switch (currentPacket[3])
	} // while (currentPacket - framedSrc < srcSize)
	if(usedSrcBytes != NULL)
		*usedSrcBytes = currentPacket - framedSrc;
	
	return copiedBytes;
}

static ComponentResult ReadPacketControls(UInt8 *packet, UInt32 palette[16], PacketControlData *controlDataOut) {
	// to set whether the key sequences 0x03 - 0x06 have been seen
	UInt16 controlSeqSeen = 0;
	int i = 0;
	Boolean loop = TRUE;
	int controlOffset = (packet[2] << 8) + packet[3] + 4;
	uint8_t *controlSeq = packet + controlOffset;
	
	memset(controlDataOut, 0, sizeof(PacketControlData));
	
	while (loop) {
		switch (controlSeq[i]) {
			case 0x00:
				// subpicture identifier, we don't care
				i++;
				break;
				
			case 0x01:
				// start displaying, we don't care
				i++;
				break;
				
			case 0x03:
				// palette info
				controlDataOut->pixelColor[3] += palette[controlSeq[i+1] >> 4 ];
				controlDataOut->pixelColor[2] += palette[controlSeq[i+1] & 0xf];
				controlDataOut->pixelColor[1] += palette[controlSeq[i+2] >> 4 ];
				controlDataOut->pixelColor[0] += palette[controlSeq[i+2] & 0xf];
				
				i += 3;
				controlSeqSeen |= 0x0f;
				break;
				
			case 0x04:
				// alpha info
				controlDataOut->pixelColor[3] += (controlSeq[i + 1] & 0xf0) << 20;
				controlDataOut->pixelColor[2] += (controlSeq[i + 1] & 0x0f) << 24;
				controlDataOut->pixelColor[1] += (controlSeq[i + 2] & 0xf0) << 20;
				controlDataOut->pixelColor[0] += (controlSeq[i + 2] & 0x0f) << 24;
				
				// double the nibble
				controlDataOut->pixelColor[3] += (controlSeq[i + 1] & 0xf0) << 24;
				controlDataOut->pixelColor[2] += (controlSeq[i + 1] & 0x0f) << 28;
				controlDataOut->pixelColor[1] += (controlSeq[i + 2] & 0xf0) << 24;
				controlDataOut->pixelColor[0] += (controlSeq[i + 2] & 0x0f) << 28;
				
				i += 3;
				controlSeqSeen |= 0xf0;
				break;
				
			case 0x05:
				// coordinates of image, ffmpeg takes care of this
				i += 7;
				break;
				
			case 0x06:
				// offset of the first graphic line, and second, ffmpeg takes care of this
				i += 5;
				break;
				
			case 0xff:
				// end of control sequence
				loop = FALSE;
				break;
				
			default:
				NSLog(@"!! Unknown control sequence 0x%02x  aborting (offset %x)\n", controlSeq[i], i);
				loop = FALSE;
				break;
		}
	}
	
	// force fully transparent to transparent black; needed? for graphicsModePreBlackAlpha
	for (i = 0; i < 4; i++) {
		if ((controlDataOut->pixelColor[i] & 0xff000000) == 0)
			controlDataOut->pixelColor[i] = 0;
	}
	
	if (controlSeqSeen != 0xff)
		return -1;
	return noErr;
}

//	==============================================================
//	resizedImage
//	==============================================================
// Return a scaled copy of the image.  


CGImageRef resizedImage(CGImageRef imageRef, CGRect thumbRect)
{
	CGImageAlphaInfo	alphaInfo = CGImageGetAlphaInfo(imageRef);
	
	// There's a wierdness with kCGImageAlphaNone and CGBitmapContextCreate
	// see Supported Pixel Formats in the Quartz 2D Programming Guide
	// Creating a Bitmap Graphics Context section
	// only RGB 8 bit images with alpha of kCGImageAlphaNoneSkipFirst, kCGImageAlphaNoneSkipLast, kCGImageAlphaPremultipliedFirst,
	// and kCGImageAlphaPremultipliedLast, with a few other oddball image kinds are supported
	// The images on input here are likely to be png or jpeg files
	if (alphaInfo == kCGImageAlphaNone)
		alphaInfo = kCGImageAlphaNoneSkipLast;
    
	// Build a bitmap context that's the size of the thumbRect
	CGContextRef bitmap = CGBitmapContextCreate(
                                                NULL,
                                                thumbRect.size.width,		// width
                                                thumbRect.size.height,		// height
                                                CGImageGetBitsPerComponent(imageRef),	// really needs to always be 8
                                                4 * thumbRect.size.width,	// rowbytes
                                                CGImageGetColorSpace(imageRef),
                                                alphaInfo
                                                );
    
	// Draw into the context, this scales the image
	CGContextDrawImage(bitmap, thumbRect, imageRef);
    
	// Get an image from the context and a UIImage
	CGImageRef	ref = CGBitmapContextCreateImage(bitmap);
    
	CGContextRelease(bitmap);	// ok if NULL
	//CGImageRelease(ref);
    
	return ref;
}

@implementation SBVobSubConverter

- (void) DecoderThreadMainRoutine: (id) sender
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    encoderDone = NO;

    while(1) {
        while (![inputSamplesBuffer count] && !fileReaderDone)
            usleep(1000);

        MP42SampleBuffer* sampleBuffer = [inputSamplesBuffer objectAtIndex:0];
        UInt8 *data = (UInt8 *) sampleBuffer->sampleData;
        int ret, got_sub;

        if(sampleBuffer->sampleSize < 4)
        {
            MP42SampleBuffer* subSample = copyEmptySubtitleSample(trackId, sampleBuffer->sampleDuration);
            [outputSamplesBuffer addObject:subSample];    
            [subSample release];

            [inputSamplesBuffer removeObjectAtIndex:0];

            continue;
        }

        if (codecData == NULL) {
            codecData = av_malloc(sampleBuffer->sampleSize + 2);
            bufferSize = sampleBuffer->sampleSize + 2;
        }

        // make sure we have enough space to store the packet
        codecData = fast_realloc_with_padding(codecData, &bufferSize, sampleBuffer->sampleSize + 2);

        if (sampleBuffer->sampleIsCompressed)
        {
            DecompressZlib(&codecData, &bufferSize, sampleBuffer->sampleData, sampleBuffer->sampleSize);
            
            codecData[0] = (bufferSize >> 8) & 0xff;
            codecData[1] = bufferSize & 0xff;

            // the header of a spu PS packet starts 0x000001bd
            // if it's raw spu data, the 1st 2 bytes are the length of the data
        } else if (data[0] + data[1] == 0) {
            // remove the MPEG framing
            sampleBuffer->sampleSize = ExtractVobSubPacket(codecData, data, bufferSize, NULL, -1);
        } else {
            memcpy(codecData, sampleBuffer->sampleData, sampleBuffer->sampleSize);
        }

        AVPacket pkt;
        av_init_packet(&pkt);
        pkt.data = codecData;
        pkt.size = bufferSize;
        ret = avcodec_decode_subtitle2(avContext, &subtitle, &got_sub, &pkt);

        if (ret < 0 || !got_sub) {
            NSLog(@"Error decoding DVD subtitle %d / %ld", ret, (long)bufferSize);
            
            MP42SampleBuffer* subSample = copyEmptySubtitleSample(trackId, sampleBuffer->sampleDuration);
            [outputSamplesBuffer addObject:subSample];    
            [subSample release];
            
            [inputSamplesBuffer removeObjectAtIndex:0];

            continue;
        }

        unsigned int i, x, j, y;
        uint8_t *imageData;

        OSErr err = noErr;
        PacketControlData controlData;

        memcpy(paletteG, [srcMagicCookie bytes], sizeof(UInt32)*16);
        int ii;
        for ( ii = 0; ii <16; ii++ )
            paletteG[ii] = EndianU32_LtoN(paletteG[ii]);

        err = ReadPacketControls(codecData, paletteG, &controlData);
        int usePalette = 0;

        if (err == noErr)
            usePalette = true;

        for (i = 0; i < subtitle.num_rects; i++) {
            AVSubtitleRect *rect = subtitle.rects[i];

            imageData = malloc(sizeof(uint8_t) * rect->w * rect->h * 4);
            memset(imageData, 0, rect->w * rect->h * 4);

            uint8_t *line = (uint8_t *)imageData;
            uint8_t *sub = rect->pict.data[0];
            unsigned int w = rect->w;
            unsigned int h = rect->h;
            uint32_t *palette = (uint32_t *)rect->pict.data[1];

            if (usePalette) {
                for (j = 0; j < 4; j++)
                    palette[j] = EndianU32_BtoN(controlData.pixelColor[j]);
            }

            for (y = 0; y < h; y++) {
                uint32_t *pixel = (uint32_t *) line;
                
                for (x = 0; x < w; x++)
                    pixel[x] = palette[sub[x]];

                line += rect->w*4;
                sub += rect->pict.linesize[0];
            }

            size_t length = sizeof(uint8_t) * rect->w * rect->h * 4;
            uint8_t* imgData2 = (uint8_t*)imageData;
            for (i = 0; i < length; i +=4) {
                imgData2[i] = 255;
 
            }
            CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaFirst;
            CFDataRef imgData = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, imageData, w*h*4,kCFAllocatorNull);
            CGDataProviderRef provider = CGDataProviderCreateWithCFData(imgData);
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            CGImageRef cgImage = CGImageCreate(w,
                                               h,
                                               8,
                                               32,
                                               w*4,
                                               colorSpace,
                                               bitmapInfo,
                                               provider,
                                               NULL,
                                               NO,
                                               kCGRenderingIntentDefault);
            CGColorSpaceRelease(colorSpace);

            //NSBitmapImageRep *bitmapImage = [[NSBitmapImageRep alloc]initWithCGImage:(CGImageRef)cgImage];
            //[[bitmapImage representationUsingType:NSTIFFFileType properties:nil] writeToFile:@"/tmp/foo.tif" atomically:YES];

            NSString *text = [ocr performOCROnCGImage:cgImage];

            MP42SampleBuffer* subSample = copySubtitleSample(trackId, text, sampleBuffer->sampleDuration);
            [outputSamplesBuffer addObject:subSample];
            [subSample release];

            CGImageRelease(cgImage);
            CGDataProviderRelease(provider);
            CFRelease(imgData);

            free(imageData);
        }

        [inputSamplesBuffer removeObjectAtIndex:0];
    }

    encoderDone = YES;

    [pool drain];
    [pool release];

	return;
}

- (id) initWithTrack: (MP42SubtitleTrack*) track error:(NSError **)outError
{
    if ((self = [super init])) {
        if (!avCodec) {
            FFInitFFmpeg();

            avCodec = avcodec_find_decoder(CODEC_ID_DVD_SUBTITLE);
            avContext = avcodec_alloc_context();

            if (avcodec_open(avContext, avCodec)) {
                NSLog(@"Error opening DVD subtitle decoder");
                return nil;
            }
        }

        outputSamplesBuffer = [[NSMutableArray alloc] init];
        inputSamplesBuffer = [[NSMutableArray alloc] init];

        srcMagicCookie = [[track trackImporterHelper] magicCookieForTrack:track];

        ocr = [[SBOCRWrapper alloc] initWithLanguage:[track language]];
        
        // Launch the decoder thread.
        decoderThread = [[NSThread alloc] initWithTarget:self selector:@selector(DecoderThreadMainRoutine:) object:self];
        [decoderThread setName:@"Audio Decoder"];
        [decoderThread start];
    }

    return self;
}

- (void) setOutputTrack: (NSUInteger) outputTrackId {
    trackId = outputTrackId;
}

- (void) addSample:(MP42SampleBuffer*)sample
{
    @synchronized(inputSamplesBuffer) {
        [inputSamplesBuffer addObject:sample];
    }
}

- (MP42SampleBuffer*) copyEncodedSample
{
    MP42SampleBuffer *sample;
    if (![outputSamplesBuffer count]) {
        return nil;
    }
    @synchronized(outputSamplesBuffer) {
        sample = [outputSamplesBuffer objectAtIndex:0];
        [sample retain];
        [outputSamplesBuffer removeObjectAtIndex:0];
    }
    
    return sample;
}

- (BOOL) needMoreSample
{
    if ([inputSamplesBuffer count])
        return NO;

    return YES;
}

- (void) setDone:(BOOL)status
{
    fileReaderDone = YES;
}

- (BOOL) encoderDone
{
    return encoderDone;
}

- (void) dealloc
{
    int i;

    if (codecData) {
        av_freep(codecData);
    }
    if (avCodec) {
        avcodec_close(avContext);
    }
    if (avContext) {
        av_freep(&avContext);
    }
    if (subtitle.rects) {
        for (i = 0; i < subtitle.num_rects; i++) {
            av_freep(&subtitle.rects[i]->pict.data[0]);
            av_freep(&subtitle.rects[i]->pict.data[1]);
            av_freep(&subtitle.rects[i]);
        }
        av_freep(&subtitle.rects);
    }

    [ocr release];
    [super dealloc];
}

@end
