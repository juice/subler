//
//  SBAudioConverter.h
//  Subler
//
//  Created by Damiano Galassi on 16/09/10.
//  Copyright 2010 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "sfifo.h"

#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudio.h>

@class MP42SampleBuffer;
@class MP42AudioTrack;

// a struct to hold info for the data proc
struct AudioFileIO
{    
    sfifo_t          *fifo;
    
	SInt64          pos;
	char *			srcBuffer;
	UInt32			srcBufferSize;
	UInt32			srcSizePerPacket;
	UInt32			numPacketsPerRead;
    AudioStreamBasicDescription     srcFormat;
	AudioStreamPacketDescription    *pktDescs;
    
    NSMutableArray * inputSamplesBuffer;
    NSMutableArray * outputSamplesBuffer;
    
    MP42SampleBuffer      *sample;
    int                   fileReaderDone;
} AudioFileIO;

@interface SBAudioConverter : NSObject {
    NSThread *decoderThread;
    NSThread *encoderThread;

    unsigned char *buffer;
    int bufferSize;
    sfifo_t fifo;

    AudioStreamBasicDescription inputEncoderFormat;
    int readerDone;
    int encoderDone;
    int fileReaderDone;
    NSMutableArray * inputSamplesBuffer;
    NSMutableArray * outputSamplesBuffer;
    NSData * outputMagicCookie;

    struct AudioFileIO decoderData;
    struct AudioFileIO encoderData;
}

- (id) initWithTrack: (MP42AudioTrack*) track;

- (void) addSample:(MP42SampleBuffer*)sample;
- (MP42SampleBuffer*) copyEncodedSample;

- (NSData*) magicCookie;
- (BOOL) needMoreSample;

- (BOOL) encoderDone;
- (void) setDone:(BOOL)status;

@end