//
//  SBAudioConverter.m
//  Subler
//
//  Created by Damiano Galassi on 16/09/10.
//  Copyright 2010 Damiano Galassi. All rights reserved.
//

#import "SBAudioConverter.h"
#import "MP42Track.h"
#import "MP42AudioTrack.h"
#import "MP42FileImporter.h"
#import "MP42Utilities.h"

#define FIFO_DURATION (0.5f)

@interface NSString (VersionStringCompare)
- (BOOL)isVersionStringOlderThan:(NSString *)older;
@end

@implementation NSString (VersionStringCompare)
- (BOOL)isVersionStringOlderThan:(NSString *)older
{
	if([self compare:older] == NSOrderedAscending)
		return TRUE;
	if([self hasPrefix:older] && [self length] > [older length] && [self characterAtIndex:[older length]] == 'b')
		//1.0b1 < 1.0, so check for it.
		return TRUE;
	return FALSE;
}
@end

#define ComponentNameKey @"Name"
#define ComponentArchiveNameKey @"ArchiveName"
#define ComponentTypeKey @"Type"

#define BundleVersionKey @"CFBundleVersion"
#define BundleIdentifierKey @"CFBundleIdentifier"

typedef enum
{
	InstallStatusInstalledInWrongLocation = 0,
	InstallStatusNotInstalled = 1,
	InstallStatusOutdatedWithAnotherInWrongLocation = 2,
	InstallStatusOutdated = 3,
	InstallStatusInstalledInBothLocations = 4,
	InstallStatusInstalled = 5
} InstallStatus;

typedef enum
{
	ComponentTypeQuickTime,
	ComponentTypeCoreAudio,
	ComponentTypeFramework
} ComponentType;

InstallStatus currentInstallStatus(InstallStatus status)
{
	return (status | 1);
}

InstallStatus setWrongLocationInstalled(InstallStatus status)
{
	return (status & ~1);
}

@implementation SBAudioConverter

- (NSString *)installationBasePath:(BOOL)userInstallation
{
	if(userInstallation)
		return NSHomeDirectory();
	return @"/";
}

- (NSString *)quickTimeComponentDir:(BOOL)userInstallation
{
	return [[self installationBasePath:userInstallation] stringByAppendingPathComponent:@"Library/QuickTime"];
}

- (NSString *)coreAudioComponentDir:(BOOL)userInstallation
{
	return [[self installationBasePath:userInstallation] stringByAppendingPathComponent:@"Library/Audio/Plug-Ins/Components"];
}

- (NSString *)frameworkComponentDir:(BOOL)userInstallation
{
	return [[self installationBasePath:userInstallation] stringByAppendingPathComponent:@"Library/Frameworks"];
}

- (NSString *)basePathForType:(ComponentType)type user:(BOOL)userInstallation
{
	NSString *path = nil;
	
	switch(type)
	{
		case ComponentTypeCoreAudio:
			path = [self coreAudioComponentDir:userInstallation];
			break;
		case ComponentTypeQuickTime:
			path = [self quickTimeComponentDir:userInstallation];
			break;
		case ComponentTypeFramework:
			path = [self frameworkComponentDir:userInstallation];
			break;
	}
	return path;
}

- (InstallStatus)installStatusForComponent:(NSString *)component type:(ComponentType)type
{
	NSString *path = nil;
	InstallStatus ret = InstallStatusNotInstalled;

	path = [[self basePathForType:type user:YES] stringByAppendingPathComponent:component];

	NSDictionary *infoDict = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"]];
	if(infoDict != nil)
	{
		NSString *currentVersion = [infoDict objectForKey:BundleVersionKey];;
		if([currentVersion isVersionStringOlderThan:@"1.2"])
			ret = InstallStatusOutdated;
		else
			ret = InstallStatusInstalled;
	}

	/* Check other installation type */
	path = [[self basePathForType:type user:NO] stringByAppendingPathComponent:component];

	infoDict = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"]];
	if(infoDict == nil)
    /* Above result is all there is */
		return ret;

	return (ret);
}

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
    unsigned int wanted = MIN(*ioNumberDataPackets * afio->srcSizePerPacket, sfifo_used(afio->fifo));

    outNumBytes = sfifo_read(afio->fifo, afio->srcBuffer, wanted);
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

- (void) EncoderThreadMainRoutine:(MP42AudioTrack*) track {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    encoderDone = 0;
    OSStatus err;

    // set up aac converter
    AudioConverterRef converterEnc;
    AudioStreamBasicDescription inputFormat, encoderFormat;

    inputFormat = inputEncoderFormat;

    bzero( &encoderFormat, sizeof( AudioStreamBasicDescription ) );
    encoderFormat.mFormatID = kAudioFormatMPEG4AAC;
    encoderFormat.mSampleRate = ( Float64 ) inputFormat.mSampleRate;
    encoderFormat.mChannelsPerFrame = inputFormat.mChannelsPerFrame;    

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
    tmp = track.channels * 80 * 1000;
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

    // set up buffers and data proc info struct
	encoderData.srcBufferSize = 32768;
	encoderData.srcBuffer = (char *)malloc( encoderData.srcBufferSize );
	encoderData.pos = 0;
	encoderData.srcFormat = inputFormat;
    encoderData.srcSizePerPacket = inputFormat.mBytesPerPacket;
    encoderData.numPacketsPerRead = encoderData.srcBufferSize / encoderData.srcSizePerPacket;
    encoderData.pktDescs = NULL;
    encoderData.fifo = &fifo;

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
        UInt8* cookieBuffer;
        int size;

		err = AudioConverterGetProperty(converterEnc, kAudioConverterCompressionMagicCookie, &cookieSize, cookie);
		if (err) {
            NSLog(@"err Get Cookie From AudioConverter");
        }
        ReadESDSDescExt(cookie, &cookieBuffer, &size, 1);
        outputMagicCookie = [[NSData dataWithBytes:cookieBuffer length:size] retain];

        free(cookieBuffer);
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
		err = AudioConverterFillComplexBuffer(converterEnc, EncoderDataProc, &encoderData, &ioOutputDataPackets,
                                              &fillBufList, &odesc);
        if (err)
            NSLog(@"Error converterEnc %ld", (long)err);
        if (ioOutputDataPackets == 0) {
			// this is the EOF conditon
			break;
		}
        
        MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
        sample->sampleData = malloc(fillBufList.mBuffers[0].mDataByteSize);
        memcpy(sample->sampleData, outputBuffer, fillBufList.mBuffers[0].mDataByteSize);

        sample->sampleSize = fillBufList.mBuffers[0].mDataByteSize;
        sample->sampleDuration = 1024;
        sample->sampleOffset = 0;
        sample->sampleTimestamp = outputPos;
        sample->sampleIsSync = YES;
        sample->sampleTrackId = track.Id;
        
        @synchronized(outputSamplesBuffer) {
            [outputSamplesBuffer addObject:sample];
        }

        [sample release];

		outputPos += ioOutputDataPackets;
    }

    free(outputBuffer);
    
    AudioConverterDispose(converterEnc);

    [pool release];

    encoderDone = 1;

    return;
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
    
    if (afio->sample)
        [afio->sample release];
    
    // figure out how much to read
	if (*ioNumberDataPackets > afio->numPacketsPerRead) *ioNumberDataPackets = afio->numPacketsPerRead;
    
    // read from the buffer    
    while (![afio->inputSamplesBuffer count] && !afio->fileReaderDone)
        usleep(250);

    if (![afio->inputSamplesBuffer count] && afio->fileReaderDone) {
        *ioNumberDataPackets = 0;
        return err;
    }
    else {
        @synchronized(afio->inputSamplesBuffer) {
            afio->sample = [afio->inputSamplesBuffer objectAtIndex:0];
            [afio->sample retain];
            [afio->inputSamplesBuffer removeObjectAtIndex:0];
        }
    }

    // advance input file packet position
	afio->pos += *ioNumberDataPackets;
    
    // put the data pointer into the buffer list
	ioData->mBuffers[0].mData = afio->sample->sampleData;
	ioData->mBuffers[0].mDataByteSize = afio->sample->sampleSize;
	ioData->mBuffers[0].mNumberChannels = afio->srcFormat.mChannelsPerFrame;
    
	if (outDataPacketDescription) {
		if (afio->pktDescs) {
            afio->pktDescs->mStartOffset = 0;
            afio->pktDescs->mVariableFramesInPacket = *ioNumberDataPackets;
            afio->pktDescs->mDataByteSize = afio->sample->sampleSize;
			*outDataPacketDescription = afio->pktDescs;
        }
		else
			*outDataPacketDescription = NULL;
	}
    
	return err;
}

- (void) DecoderThreadMainRoutine:(MP42AudioTrack*)track;
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    AudioConverterRef converterDec;
    OSStatus    err;

    CFDataRef   magicCookie = NULL;
    NSData * srcMagicCookie = [[track trackImporterHelper] magicCookieForTrack:track];
    NSInteger sampleRate = [[track trackImporterHelper] timescaleForTrack:track];
    AudioStreamBasicDescription inputFormat, outputFormat;
    
    if (track.sourceFormat) {
        if ([track.sourceFormat isEqualToString:@"Vorbis"]) {
            bzero( &inputFormat, sizeof( AudioStreamBasicDescription ) );
            inputFormat.mSampleRate = ( Float64 ) sampleRate;
            inputFormat.mFormatID = 'XiVs';
            inputFormat.mFormatFlags = 0;
            inputFormat.mBytesPerPacket = 0;
            inputFormat.mFramesPerPacket = 0;
            inputFormat.mBytesPerFrame = 0;
            inputFormat.mChannelsPerFrame = track.channels;
            inputFormat.mBitsPerChannel = 0;
            
            magicCookie = DescExt_XiphVorbis([srcMagicCookie length], [srcMagicCookie bytes]);
        }
        if ([track.sourceFormat isEqualToString:@"Flac"]) {
            bzero( &inputFormat, sizeof( AudioStreamBasicDescription ) );
            inputFormat.mSampleRate = ( Float64 ) sampleRate;
            inputFormat.mFormatID = 'XiFL';
            inputFormat.mChannelsPerFrame = track.channels;
            
            magicCookie = DescExt_XiphFLAC([srcMagicCookie length], [srcMagicCookie bytes]);
        }
        else if ([track.sourceFormat isEqualToString:@"AC-3"]) {
            bzero( &inputFormat, sizeof( AudioStreamBasicDescription ) );
            inputFormat.mSampleRate = ( Float64 ) sampleRate;
            inputFormat.mFormatID = kAudioFormatAC3;
            inputFormat.mFramesPerPacket = 1536;
            inputFormat.mChannelsPerFrame = track.channels;
        }
        else if ([track.sourceFormat isEqualToString:@"DTS"]) {
            bzero( &inputFormat, sizeof( AudioStreamBasicDescription ) );
            inputFormat.mSampleRate = ( Float64 ) sampleRate;
            inputFormat.mFormatID = 'DTS ';
            inputFormat.mChannelsPerFrame = track.channels;
        }
        else if ([track.sourceFormat isEqualToString:@"Mp3"]) {
            bzero( &inputFormat, sizeof( AudioStreamBasicDescription ) );
            inputFormat.mSampleRate = ( Float64 ) sampleRate;
            inputFormat.mFormatID = kAudioFormatMPEGLayer3;
            inputFormat.mFramesPerPacket = 1152;
            inputFormat.mChannelsPerFrame = track.channels;
        }
    }

    bzero( &outputFormat, sizeof( AudioStreamBasicDescription ) );
	outputFormat.mSampleRate = sampleRate;
	outputFormat.mFormatID = kAudioFormatLinearPCM ;
	outputFormat.mFormatFlags =  kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    outputFormat.mBytesPerPacket = 2 * track.channels;
    outputFormat.mFramesPerPacket = 1;
	outputFormat.mBytesPerFrame = outputFormat.mBytesPerPacket * outputFormat.mFramesPerPacket;
	outputFormat.mChannelsPerFrame = track.channels;
	outputFormat.mBitsPerChannel = 16;

    // initialize the decoder
    err = AudioConverterNew( &inputFormat, &outputFormat, &converterDec );
    if ( err != noErr) {
        NSLog(@"Boom %ld",(long)err);
        readerDone = 1;
        encoderDone = 1;
        return;
    }

    if ((track.channels == 6) && ([track.sourceFormat isEqualToString:@"AC-3"])) {
        SInt32 channelMap[6] = { 2, 0, 1, 4, 5, 3 };
        AudioConverterSetProperty( converterDec, kAudioConverterChannelMap,
                                  sizeof( channelMap ), channelMap );
    }

    // set the decoder magic cookie
    if (magicCookie) {
        err = AudioConverterSetProperty( converterDec, kAudioConverterDecompressionMagicCookie,
                                        CFDataGetLength(magicCookie) , CFDataGetBytePtr(magicCookie) );
        if( err != noErr)
            NSLog(@"Boom Magic Cookie %ld",(long)err);
        CFRelease(magicCookie);
    }

    UInt32 size = sizeof(inputFormat);
	err = AudioConverterGetProperty(converterDec, kAudioConverterCurrentInputStreamDescription,
                                    &size, &inputFormat);
    if( err != noErr)
        NSLog(@"Boom kAudioConverterCurrentInputStreamDescription %ld",(long)err);

    size = sizeof(outputFormat);
	err = AudioConverterGetProperty(converterDec, kAudioConverterCurrentOutputStreamDescription,
                                    &size, &outputFormat);
    if( err != noErr)
        NSLog(@"Boom kAudioConverterCurrentOutputStreamDescription %ld",(long)err);

    // set up buffers and data proc info struct
	decoderData.srcBufferSize = 32768;
	decoderData.srcBuffer = (char *)malloc( decoderData.srcBufferSize );
	decoderData.pos = 0;
	decoderData.srcFormat = inputFormat;    
    decoderData.numPacketsPerRead = 1;
    decoderData.pktDescs = (AudioStreamPacketDescription*)malloc(decoderData.numPacketsPerRead);
    decoderData.inputSamplesBuffer = inputSamplesBuffer;
    
    // set up our output buffers
	AudioStreamPacketDescription* outputPktDescs = NULL;
	int outputSizePerPacket = outputFormat.mBytesPerPacket; // this will be non-zero if the format is CBR
	UInt32 theOutputBufSize = 32768;
	char* outputBuffer = (char*)malloc(theOutputBufSize);
    
	UInt32 numOutputPackets = theOutputBufSize / outputSizePerPacket;
    
    inputEncoderFormat = outputFormat;
    readerDone = 0;
    encoderThread = [[NSThread alloc] initWithTarget:self selector:@selector(EncoderThreadMainRoutine:) object:track];
    [encoderThread setName:@"AAC Encoder"];
    [encoderThread start];
    
    int ringbuffer_len = sampleRate * FIFO_DURATION * 4 * 23;
    sfifo_init(&fifo, ringbuffer_len );
    bufferSize = ringbuffer_len >> 1;
    buffer = (unsigned char *)malloc(bufferSize);
    
    decoderData.fifo = &fifo;
    
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
		err = AudioConverterFillComplexBuffer(converterDec, DecoderDataProc, &decoderData, &ioOutputDataPackets,
                                              &fillBufList, outputPktDescs);
        if (err)
            NSLog(@"Error converterDec %ld", (long)err);
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

    free(outputBuffer);

    AudioConverterDispose(converterDec);

    [pool drain];
    return;
}

- (id) initWithTrack: (MP42AudioTrack*) track
{
    if ((self = [super init]))
    {
        InstallStatus installStatus = [self installStatusForComponent:@"Perian.component" type:ComponentTypeQuickTime];

        if(currentInstallStatus(installStatus) == InstallStatusNotInstalled) {
            [self release];
            return nil;
        }

        outputSamplesBuffer = [[NSMutableArray alloc] init];
        inputSamplesBuffer = [[NSMutableArray alloc] init];

        decoderThread = [[NSThread alloc] initWithTarget:self selector:@selector(DecoderThreadMainRoutine:) object:track];
        [decoderThread setName:@"Audio Decoder"];
        [decoderThread start];        
    }
    
    return self;
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
    fileReaderDone = status;
    decoderData.fileReaderDone = status;
    encoderData.fileReaderDone = status;
}

- (BOOL) encoderDone
{
    return encoderDone;
}

- (NSData*) magicCookie
{
    return outputMagicCookie;
}

- (void) dealloc
{
    sfifo_close(&fifo);

    free(decoderData.srcBuffer);
    free(decoderData.pktDescs);

    free(encoderData.srcBuffer);
    free(encoderData.pktDescs);
    
    [outputMagicCookie release];

    [decoderThread release];
    [encoderThread release];

    [outputSamplesBuffer release];
    [inputSamplesBuffer release];
    [super dealloc];
}

@end
