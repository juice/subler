#import <Foundation/Foundation.h>
#include <assert.h>
#include <pthread.h>

#include "MatroskaFile.h"
#include "MatroskaParser.h"

#include "sfifo.h"

#include <AudioToolbox/AudioToolbox.h>
#include <CoreAudio/CoreAudio.h>

enum {
	// these are atoms/extension types defined by XiphQT for their codecs
	kCookieTypeOggSerialNo = 'oCtN',

	kCookieTypeVorbisHeader = 'vCtH',
	kCookieTypeVorbisComments = 'vCt#',
	kCookieTypeVorbisCodebooks = 'vCtC',
	kCookieTypeVorbisFirstPageNo = 'vCtN',

	kCookieTypeSpeexHeader = 'sCtH',
	kCookieTypeSpeexComments = 'sCt#',
	kCookieTypeSpeexExtraHeader	= 'sCtX',

	kCookieTypeFLACStreaminfo = 'fCtS',
	kCookieTypeFLACMetadata = 'fCtM',
};

// xiph-qt expects these this sound extension to have been created from first 3 packets
// which are stored in CodecPrivate in Matroska
CFDataRef DescExt_XiphVorbis(UInt32 codecPrivateSize, void * codecPrivate)
{
	if (codecPrivateSize) {
        CFMutableDataRef sndDescExt = CFDataCreateMutable(NULL, 0);

		unsigned char *privateBuf;
		size_t privateSize;
		uint8_t numPackets;
		int offset = 1, i;
		UInt32 uid = 0;

		privateSize = codecPrivateSize;
		privateBuf = (unsigned char *) codecPrivate;
		numPackets = privateBuf[0] + 1;

		int packetSizes[numPackets];
		memset(packetSizes, 0, sizeof(packetSizes));

		// get the sizes of the packets
		packetSizes[numPackets - 1] = privateSize - 1;
		int packetNum = 0;
		for (i = 1; packetNum < numPackets - 1; i++) {
			packetSizes[packetNum] += privateBuf[i];
			if (privateBuf[i] < 255) {
				packetSizes[numPackets - 1] -= packetSizes[packetNum];
				packetNum++;
			}
			offset++;
		}
		packetSizes[numPackets - 1] -= offset - 1;

		if (offset+packetSizes[0]+packetSizes[1]+packetSizes[2] > privateSize) {
            CFRelease(sndDescExt);
			return NULL;
		}

		// first packet
		uint32_t serial_header_atoms[3+2] = { EndianU32_NtoB(3*4), 
			EndianU32_NtoB(kCookieTypeOggSerialNo), 
			EndianU32_NtoB(uid),
			EndianU32_NtoB(packetSizes[0] + 2*4), 
			EndianU32_NtoB(kCookieTypeVorbisHeader) };

        CFDataAppendBytes(sndDescExt, (UInt8 *)serial_header_atoms, sizeof(serial_header_atoms));
        CFDataAppendBytes(sndDescExt, &privateBuf[offset], packetSizes[0]);

		// second packet
		uint32_t atomhead2[2] = { EndianU32_NtoB(packetSizes[1] + sizeof(atomhead2)), 
			EndianU32_NtoB(kCookieTypeVorbisComments) };
        CFDataAppendBytes(sndDescExt, (UInt8 *)atomhead2, sizeof(atomhead2));
        CFDataAppendBytes(sndDescExt, &privateBuf[offset + packetSizes[0]], packetSizes[1]);

		// third packet
		uint32_t atomhead3[2] = { EndianU32_NtoB(packetSizes[2] + sizeof(atomhead3)), 
			EndianU32_NtoB(kCookieTypeVorbisCodebooks) };
        CFDataAppendBytes(sndDescExt, (UInt8 *)atomhead3, sizeof(atomhead3));
        CFDataAppendBytes(sndDescExt, &privateBuf[offset + packetSizes[1] + packetSizes[0]], packetSizes[2]);

        return sndDescExt;
	}
	return NULL;
}

// xiph-qt expects these this sound extension to have been created in this way
// from the packets which are stored in the CodecPrivate element in Matroska
CFDataRef DescExt_XiphFLAC(UInt32 codecPrivateSize, void * codecPrivate)
{	
	if (codecPrivateSize) {
        CFMutableDataRef sndDescExt = CFDataCreateMutable(NULL, 0);
		UInt32 uid = 0;

		size_t privateSize = codecPrivateSize;
		UInt8 *privateBuf = (unsigned char *) codecPrivate, *privateEnd = privateBuf + privateSize;

		unsigned long serialnoatom[3] = { EndianU32_NtoB(sizeof(serialnoatom)), 
			EndianU32_NtoB(kCookieTypeOggSerialNo), 
			EndianU32_NtoB(uid) };

        CFDataAppendBytes(sndDescExt, (UInt8 *)serialnoatom, sizeof(serialnoatom));

		privateBuf += 4; // skip 'fLaC'

		while ((privateEnd - privateBuf) > 4) {
			uint32_t packetHeader = EndianU32_BtoN(*(uint32_t*)privateBuf);
			int lastPacket = packetHeader >> 31, blockType = (packetHeader >> 24) & 0x7F;
			uint32_t packetSize = (packetHeader & 0xFFFFFF) + 4;
			uint32_t xiphHeader[2] = {EndianU32_NtoB(packetSize + sizeof(xiphHeader)),
				EndianU32_NtoB(blockType ? kCookieTypeFLACMetadata : kCookieTypeFLACStreaminfo)};

			if ((privateEnd - privateBuf) < packetSize)
				break;

            CFDataAppendBytes(sndDescExt, (UInt8 *)xiphHeader, sizeof(xiphHeader));
            CFDataAppendBytes(sndDescExt, privateBuf, packetSize);

			privateBuf += packetSize;

			if (lastPacket)
				break;
		}

		return sndDescExt;	
	}
	return nil;
}

// a struct to hold info for the input data proc
struct AudioFileIO
{
    struct StdIoStream *ioStream;
	struct MatroskaFile *matroskaFile;
    unsigned int TrackMask;

	SInt64			pos;
	char *			srcBuffer;
	UInt32			srcBufferSize;
	AudioStreamBasicDescription srcFormat;
	UInt32			srcSizePerPacket;
	UInt32			numPacketsPerRead;
	AudioStreamPacketDescription * pktDescs;
} AudioFileIO;

unsigned char *buffer;
int bufferSize;
sfifo_t fifo;
AudioStreamBasicDescription inputEncoderFormat;
int readerDone;
int encoderDone;

CFURLRef outputFileURL;

OSStatus EncoderDataProc(AudioConverterRef              inAudioConverter, 
                         UInt32*                        ioNumberDataPackets,
                         AudioBufferList*				ioData,
                         AudioStreamPacketDescription**	outDataPacketDescription,
                         void*							inUserData)
{
	struct AudioFileIO* afio = (struct AudioFileIO*)inUserData;
	
	// figure out how much to read
	if (*ioNumberDataPackets > afio->numPacketsPerRead) *ioNumberDataPackets = afio->numPacketsPerRead;
    
    // read from the fifo    
	UInt32 outNumBytes;
    unsigned int wanted = MIN(*ioNumberDataPackets * afio->srcSizePerPacket, sfifo_used(&fifo)); // * 2 * 4;

    //pthread_mutex_lock(&fifoLock);
    outNumBytes = sfifo_read(&fifo, afio->srcBuffer, wanted);
    //pthread_mutex_unlock(&fifoLock);
    OSStatus err = noErr;
	if (outNumBytes < wanted) {
        *ioNumberDataPackets = 0;
		printf ("Input Proc Read error: %d (%4.4s)\n", (int)err, (char*)&err);
		return err;
	}
	
    if (*ioNumberDataPackets == 0)
		printf ("End\n");
    
    // put the data pointer into the buffer list

	ioData->mBuffers[0].mData = afio->srcBuffer;
	ioData->mBuffers[0].mDataByteSize = outNumBytes;
	ioData->mBuffers[0].mNumberChannels = afio->srcFormat.mChannelsPerFrame;
    
    *ioNumberDataPackets = ioData->mBuffers[0].mDataByteSize / afio->srcSizePerPacket;

    afio->pos += *ioNumberDataPackets;

	if (outDataPacketDescription) {
		if (afio->pktDescs)
			*outDataPacketDescription = afio->pktDescs;
		else
			*outDataPacketDescription = NULL;
	}
    
	return err;
}

void* EncoderThreadMainRoutine(void* data) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    encoderDone = 0;
    OSStatus err;

    // set up aac converter
    struct AudioFileIO afio2;
    AudioConverterRef converterEnc;
    AudioStreamBasicDescription inputFormat, encoderFormat;

    inputFormat = inputEncoderFormat;

    bzero( &encoderFormat, sizeof( AudioStreamBasicDescription ) );
    encoderFormat.mFormatID = kAudioFormatMPEG4AAC;
    encoderFormat.mSampleRate = ( Float64 ) inputFormat.mSampleRate;
    encoderFormat.mChannelsPerFrame = 2;    

    err = AudioConverterNew( &inputFormat, &encoderFormat, &converterEnc );
    if (err)
        NSLog(@"Boom encoder converter init failed");

    UInt32 tmp, tmpsiz = sizeof( tmp );

    // set encoder quality to maximum
    tmp = kAudioConverterQuality_Max;
    AudioConverterSetProperty( converterEnc, kAudioConverterCodecQuality,
                              sizeof( tmp ), &tmp );

    // set encoder bitrate control mode to constrained variable
    tmp = kAudioCodecBitRateControlMode_VariableConstrained;
    AudioConverterSetProperty( converterEnc, kAudioCodecPropertyBitRateControlMode,
                              sizeof( tmp ), &tmp );

    // set bitrate
    tmp = 160 * 1000;
    AudioConverterSetProperty( converterEnc, kAudioConverterEncodeBitRate,
                              sizeof( tmp ), &tmp );

    // get real input
    tmpsiz = sizeof( inputFormat );
    AudioConverterGetProperty( converterEnc,
                              kAudioConverterCurrentInputStreamDescription,
                              &tmpsiz, &inputFormat );

    // get real output
    tmpsiz = sizeof( encoderFormat );
    AudioConverterGetProperty( converterEnc,
                              kAudioConverterCurrentOutputStreamDescription,
                              &tmpsiz, &encoderFormat );
    AudioFileID outfile;
    AudioFileTypeID outputFileType = kAudioFileM4AType;
    // create the output file (this will erase an existing file)
    err = AudioFileCreateWithURL(outputFileURL, outputFileType, &encoderFormat,
                                 kAudioFileFlags_EraseFile, &outfile);
    if( err != noErr)
        NSLog(@"Boom Output file creation failed %d",err);

    // set up buffers and data proc info struct
	afio2.srcBufferSize = 32768;
	afio2.srcBuffer = (char *)malloc( afio2.srcBufferSize );
	afio2.pos = 0;
	afio2.srcFormat = inputFormat;
    afio2.srcSizePerPacket = inputFormat.mBytesPerPacket;
    afio2.numPacketsPerRead = afio2.srcBufferSize / afio2.srcSizePerPacket;
    afio2.pktDescs = NULL;

    // set up our output buffers

	int outputSizePerPacket = encoderFormat.mBytesPerPacket; // this will be non-zero if the format is CBR
    UInt32 size = sizeof(outputSizePerPacket);
    err = AudioConverterGetProperty(converterEnc, kAudioConverterPropertyMaximumOutputPacketSize,
                                    &size, &outputSizePerPacket);
    if (err)
        NSLog(@"Boom kAudioConverterPropertyMaximumOutputPacketSize");

	UInt32 theOutputBufSize = outputSizePerPacket;
	char* outputBuffer = (char*)malloc(theOutputBufSize);

    // grab the cookie from the converter and write it to the file
	UInt32 cookieSize = 0;
	err = AudioConverterGetPropertyInfo(converterEnc, kAudioConverterCompressionMagicCookie, &cookieSize, NULL);
    // if there is an error here, then the format doesn't have a cookie, so on we go
	if (!err && cookieSize) {
		char* cookie = (char *) malloc(cookieSize);

		err = AudioConverterGetProperty(converterEnc, kAudioConverterCompressionMagicCookie, &cookieSize, cookie);
		if (err) {
            NSLog(@"err Get Cookie From AudioConverter");
        }

		err = AudioFileSetProperty (outfile, kAudioFilePropertyMagicCookieData, cookieSize, cookie);
        // even though some formats have cookies, some files don't take them
        if (err) {
            NSLog(@"err Set Cookie");
        }

		free(cookie);
	}

    // loop to convert data
	SInt64 outputPos = 0;

	while (1) {
        AudioStreamPacketDescription odesc = {0};

		// set up output buffer list
		AudioBufferList fillBufList;
		fillBufList.mNumberBuffers = 1;
		fillBufList.mBuffers[0].mNumberChannels = inputFormat.mChannelsPerFrame;
		fillBufList.mBuffers[0].mDataByteSize = theOutputBufSize;
		fillBufList.mBuffers[0].mData = outputBuffer;

        while ((sfifo_used(&fifo) < (inputFormat.mBytesPerPacket * encoderFormat.mFramesPerPacket * 4)) && !readerDone)
            usleep(500);

        // convert data
		UInt32 ioOutputDataPackets = 1;
		err = AudioConverterFillComplexBuffer(converterEnc, EncoderDataProc, &afio2, &ioOutputDataPackets,
                                              &fillBufList, &odesc);
        if (err)
            NSLog(@"Error converterEnc %d", err);
        if (ioOutputDataPackets == 0) {
			// this is the EOF conditon
			break;
		}

        // write to output file
		UInt32 inNumBytes = fillBufList.mBuffers[0].mDataByteSize;
		err = AudioFileWritePackets(outfile, false, inNumBytes, &odesc, outputPos,
                                    &ioOutputDataPackets, outputBuffer);
        if (err)
            NSLog(@"Error outfile %d", err);

        // advance output file packet position
		outputPos += ioOutputDataPackets;
    }

    free(afio2.srcBuffer);
    free(afio2.pktDescs);
    free(outputBuffer);

    AudioConverterDispose(converterEnc);
    AudioFileClose(outfile);

    [pool release];

    NSLog(@"Encoder Done");
    encoderDone = 1;

    return NULL;
}

void LaunchEncoderThread() {
    // Create the thread using POSIX routines.
    pthread_attr_t attr;
    pthread_t	posixThreadID;
    int	returnVal;

    returnVal = pthread_attr_init(&attr);
    assert(!returnVal);
    returnVal = pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    assert(!returnVal);

    int	threadError = pthread_create(&posixThreadID, &attr, &EncoderThreadMainRoutine, NULL);

    returnVal = pthread_attr_destroy(&attr);
    assert(!returnVal);
    if (threadError != 0) {
        // Report an error.
    }
}

// decoder input data proc callback

OSStatus DecoderDataProc(AudioConverterRef              inAudioConverter, 
                         UInt32*                        ioNumberDataPackets,
                         AudioBufferList*				ioData,
                         AudioStreamPacketDescription**	outDataPacketDescription,
                         void*							inUserData)
{
    OSStatus err = noErr;
    struct AudioFileIO * afio = inUserData;

    // figure out how much to read
	if (*ioNumberDataPackets > afio->numPacketsPerRead) *ioNumberDataPackets = afio->numPacketsPerRead;

    // read from the file
    uint64_t        StartTime, EndTime, FilePos;
    uint32_t        Track, FrameSize, FrameFlags;
    
    if ( mkv_ReadFrame(afio->matroskaFile, 0, &Track, &StartTime, &EndTime, &FilePos, &FrameSize, &FrameFlags) == 0 ) {
        if (fseeko(afio->ioStream->fp, FilePos, SEEK_SET)) {
            *ioNumberDataPackets = 0;
            fprintf(stderr,"fseeko(): %s\n", strerror(errno));
            return 1;				
        }

        size_t rd = fread(afio->srcBuffer,1,FrameSize,afio->ioStream->fp);
        if (rd != FrameSize) {
            if (rd == 0) {
                if (feof(afio->ioStream->fp))
                    fprintf(stderr,"Unexpected EOF while reading frame\n");
                else
                    fprintf(stderr,"Error reading frame: %s\n",strerror(errno));
            } else
                fprintf(stderr,"Short read while reading frame\n");
        }
    }
    else {
        *ioNumberDataPackets = 0;
        FrameSize = 0;
    }

    // advance input file packet position
	afio->pos += *ioNumberDataPackets;

    // put the data pointer into the buffer list
	ioData->mBuffers[0].mData = afio->srcBuffer;
	ioData->mBuffers[0].mDataByteSize = FrameSize;
	ioData->mBuffers[0].mNumberChannels = afio->srcFormat.mChannelsPerFrame;

	if (outDataPacketDescription) {
		if (afio->pktDescs) {
            afio->pktDescs->mStartOffset = 0;
            afio->pktDescs->mVariableFramesInPacket = *ioNumberDataPackets;
            afio->pktDescs->mDataByteSize = FrameSize;
			*outDataPacketDescription = afio->pktDescs;
        }
		else
			*outDataPacketDescription = NULL;
	}

	return err;
}

void print_help()
{
    printf("usage:\n");
    printf("\t\t-i set mkv input file\n");
    printf("\t\t-n set the track to convert\n");
    printf("\t\t-o set m4a outputfile\n");
}

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    char* input_file = NULL;
    char* output_file = NULL;
    UInt32 trackNumber = 0;

    if (argc == 1) {
        print_help();
        exit(-1);
    }

    char opt_char=0;
    while ((opt_char = getopt(argc, (char * const*)argv, "i:n:o:h")) != -1) {
        switch(opt_char) {
            case 'h':
                print_help();
                exit(-1);
                break;
            case 'i':
                input_file = optarg;
                break;
            case 'o':
                output_file = optarg;
                break;
            case 'n':
                trackNumber = atoi(optarg);
                break;
            default:
                print_help();
                exit(-1);
                break;
        }
    }

    AudioConverterRef converterDec;
    OSStatus    err;
    UInt32      codecPrivateSize = 0; 
    void *      codecPrivate = NULL;
    CFDataRef   magicCookie = NULL;

	outputFileURL = CFURLCreateFromFileSystemRepresentation (kCFAllocatorDefault, (const UInt8 *)output_file,
                                                             strlen(output_file), false);
    if (!outputFileURL)
		printf ("* * Bad input file path\n");

    if (!input_file || !outputFileURL)
        return -1;

    struct AudioFileIO afio;
	afio.ioStream = (StdIoStream*) calloc(1, sizeof(StdIoStream));
    afio.matroskaFile = openMatroskaFile(input_file, afio.ioStream);
    TrackInfo *trackInfo = mkv_GetTrackInfo(afio.matroskaFile, trackNumber);

    afio.TrackMask = ~0;
    afio.TrackMask &= ~(1 << trackNumber);
    mkv_SetTrackMask(afio.matroskaFile, afio.TrackMask);

    codecPrivateSize = trackInfo->CodecPrivateSize;
    if (codecPrivateSize)
        codecPrivate = trackInfo->CodecPrivate;

    AudioStreamBasicDescription inputFormat, outputFormat;

    if (trackInfo->CodecID) {
        if (!strcmp(trackInfo->CodecID, "A_VORBIS")) {
            bzero( &inputFormat, sizeof( AudioStreamBasicDescription ) );
            inputFormat.mSampleRate = ( Float64 ) mkv_TruncFloat(trackInfo->AV.Audio.SamplingFreq);
            inputFormat.mFormatID = 'XiVs';
            inputFormat.mFormatFlags = 0;
            inputFormat.mBytesPerPacket = 0;
            inputFormat.mFramesPerPacket = 0;
            inputFormat.mBytesPerFrame = 0;
            inputFormat.mChannelsPerFrame = trackInfo->AV.Audio.Channels;
            inputFormat.mBitsPerChannel = 0;

            magicCookie = DescExt_XiphVorbis(codecPrivateSize, codecPrivate);
        }
        if (!strcmp(trackInfo->CodecID, "A_FLAC")) {
            bzero( &inputFormat, sizeof( AudioStreamBasicDescription ) );
            inputFormat.mSampleRate = ( Float64 ) mkv_TruncFloat(trackInfo->AV.Audio.SamplingFreq);
            inputFormat.mFormatID = 'XiFL';
            inputFormat.mChannelsPerFrame = trackInfo->AV.Audio.Channels;

            magicCookie = DescExt_XiphFLAC(codecPrivateSize, codecPrivate);
        }
        else if (!strcmp(trackInfo->CodecID, "A_AC3")) {
            bzero( &inputFormat, sizeof( AudioStreamBasicDescription ) );
            inputFormat.mSampleRate = ( Float64 ) mkv_TruncFloat(trackInfo->AV.Audio.SamplingFreq);
            inputFormat.mFormatID = kAudioFormatAC3;
            inputFormat.mFramesPerPacket = 1536;
            inputFormat.mChannelsPerFrame = trackInfo->AV.Audio.Channels;
        }
        else if (!strcmp(trackInfo->CodecID, "A_DTS")) {
            bzero( &inputFormat, sizeof( AudioStreamBasicDescription ) );
            inputFormat.mSampleRate = ( Float64 ) mkv_TruncFloat(trackInfo->AV.Audio.SamplingFreq);
            inputFormat.mFormatID = 'DTS ';
            inputFormat.mChannelsPerFrame = trackInfo->AV.Audio.Channels;
        }
    }

    bzero( &outputFormat, sizeof( AudioStreamBasicDescription ) );
	outputFormat.mSampleRate = mkv_TruncFloat(trackInfo->AV.Audio.SamplingFreq);
	outputFormat.mFormatID = kAudioFormatLinearPCM ;
	outputFormat.mFormatFlags =  kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    outputFormat.mBytesPerPacket = 4;
    outputFormat.mFramesPerPacket = 1;
	outputFormat.mBytesPerFrame = 4;
	outputFormat.mChannelsPerFrame = 2;
	outputFormat.mBitsPerChannel = 16;

    // initialize the decoder
    err = AudioConverterNew( &inputFormat, &outputFormat, &converterDec );
    if( err != noErr) {
        NSLog(@"Boom %d",err);
        return 0;
    }

    // set the decoder magic cookie
    if (magicCookie) {
        err = AudioConverterSetProperty( converterDec, kAudioConverterDecompressionMagicCookie,
                                        CFDataGetLength(magicCookie) , CFDataGetBytePtr(magicCookie) );
        if( err != noErr)
            NSLog(@"Boom Magic Cookie %d",err);
        CFRelease(magicCookie);
    }

    UInt32 size = sizeof(inputFormat);
	err = AudioConverterGetProperty(converterDec, kAudioConverterCurrentInputStreamDescription,
                                    &size, &inputFormat);
    if( err != noErr)
        NSLog(@"Boom kAudioConverterCurrentInputStreamDescription %d",err);

    size = sizeof(outputFormat);
	err = AudioConverterGetProperty(converterDec, kAudioConverterCurrentOutputStreamDescription,
                                    &size, &outputFormat);
    if( err != noErr)
        NSLog(@"Boom kAudioConverterCurrentOutputStreamDescription %d",err);

    // set up buffers and data proc info struct
	afio.srcBufferSize = 32768;
	afio.srcBuffer = (char *)malloc( afio.srcBufferSize );
	afio.pos = 0;
	afio.srcFormat = inputFormat;    
    afio.numPacketsPerRead = 1;
    afio.pktDescs = (AudioStreamPacketDescription*)malloc(afio.numPacketsPerRead);

    // set up our output buffers
	AudioStreamPacketDescription* outputPktDescs = NULL;
	int outputSizePerPacket = outputFormat.mBytesPerPacket; // this will be non-zero if the format is CBR
	UInt32 theOutputBufSize = 32768;
	char* outputBuffer = (char*)malloc(theOutputBufSize);

	UInt32 numOutputPackets = theOutputBufSize / outputSizePerPacket;

    inputEncoderFormat = outputFormat;
    readerDone = 0;
    LaunchEncoderThread();
    
    #define FIFO_DURATION (0.5f)
    int ringbuffer_len = mkv_TruncFloat(trackInfo->AV.Audio.SamplingFreq) * FIFO_DURATION * 4 * 23;
    sfifo_init(&fifo, ringbuffer_len );
    bufferSize = ringbuffer_len >> 1;
    buffer = (unsigned char *)malloc(bufferSize);

    // loop to convert data
	SInt64 outputPos = 0;

	while (1) {
		// set up output buffer list
		AudioBufferList fillBufList;
		fillBufList.mNumberBuffers = 1;
		fillBufList.mBuffers[0].mNumberChannels = inputFormat.mChannelsPerFrame;
		fillBufList.mBuffers[0].mDataByteSize = theOutputBufSize;
		fillBufList.mBuffers[0].mData = outputBuffer;

        // convert data
		UInt32 ioOutputDataPackets = numOutputPackets;
		err = AudioConverterFillComplexBuffer(converterDec, DecoderDataProc, &afio, &ioOutputDataPackets,
                                              &fillBufList, outputPktDescs);
        if (err)
            NSLog(@"Error converterDec %d", err);
        if (ioOutputDataPackets == 0) {
			// this is the EOF conditon
			break;
		}

        // write to output file
		UInt32 inNumBytes = fillBufList.mBuffers[0].mDataByteSize;

        while (sfifo_space(&fifo) < inNumBytes)
            usleep(5000);

        sfifo_write(&fifo, outputBuffer, inNumBytes);

        // advance output file packet position
		outputPos += ioOutputDataPackets;
    }

    readerDone = 1;
    NSLog(@"Reader Done");

    while (!encoderDone)
        usleep(5000);

    free(afio.srcBuffer);
    free(afio.pktDescs);
    free(outputBuffer);

    sfifo_close(&fifo);

    AudioConverterDispose(converterDec);

    // close matroska parser */ 
	mkv_Close(afio.matroskaFile);
	// close file
	fclose(afio.ioStream->fp);

    [pool drain];
    return 0;
}