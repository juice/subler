//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42SubtitleTrack.h"
#import "MP42Utilities.h"
#import "lang.h"

@implementation MP42SubtitleTrack

- (id) initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
    if ((self = [super initWithSourcePath:source trackID:trackID fileHandle:fileHandle]))
    {
        MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.tx3g.defTextBoxBottom", &height);
        MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.tx3g.defTextBoxRight", &width);
    }

    return self;
}

-(id) init
{
    if ((self = [super init]))
    {
        name = @"Subtitle Track";
        format = @"3GPP Text";
    }

    return self;
}

- (BOOL) writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError
{
    if (isEdited && !muxed)
    {
        if (!Id && (outError != NULL)) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Error: couldn't mux subtitle track" forKey:NSLocalizedDescriptionKey];
            *outError = [NSError errorWithDomain:@"MP42Error"
                                            code:110
                                        userInfo:errorDetail];
        }
        else {
            muxed = YES;
            enableFirstSubtitleTrack(fileHandle);

            MP4GetTrackFloatProperty(fileHandle, Id, "tkhd.width", &trackWidth);
            MP4GetTrackFloatProperty(fileHandle, Id, "tkhd.height", &trackHeight);

            uint8_t *val;
            uint8_t nval[36];
            uint32_t *ptr32 = (uint32_t*) nval;
            uint32_t size;

            MP4GetTrackBytesProperty(fileHandle ,Id, "tkhd.matrix", &val, &size);
            memcpy(nval, val, size);
            offsetX = CFSwapInt32BigToHost(ptr32[6]) / 0x10000;
            offsetY = CFSwapInt32BigToHost(ptr32[7]) / 0x10000;
            free(val);

            [super writeToFile:fileHandle error:outError];
        }
        return Id;
    }
    else
        [super writeToFile:fileHandle error:outError];

    MP4SetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.tx3g.defTextBoxBottom", trackHeight);
    MP4SetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.tx3g.defTextBoxRight", trackWidth);

    return YES;
}

- (BOOL)exportToURL:(NSURL *)url error:(NSError **)error
{
	MP4FileHandle fileHandle = MP4Read([sourcePath UTF8String], 0);
	MP4TrackId srcTrackId = Id;

	MP4SampleId sampleId = 1;
	NSUInteger srtSampleNumber = 1;
	
	MP4Timestamp time = 0;

	NSMutableString *srtFile = [[[NSMutableString alloc] init] autorelease];

	while (1) {
		uint8_t *pBytes = NULL;
		uint32_t numBytes = 0;
		MP4Duration sampleDuration;
		MP4Duration renderingOffset;
		MP4Timestamp pStartTime;
		bool isSyncSample;

		if (!MP4ReadSample(fileHandle,
						   srcTrackId,
						   sampleId,
						   &pBytes, &numBytes,
						   &pStartTime, &sampleDuration, &renderingOffset,
						   &isSyncSample)) {
			break;
		}

		NSUInteger textSampleLength = (pBytes[0] << 8) & 0xff00;
		textSampleLength += pBytes[1];

		if (textSampleLength) {
			[srtFile appendFormat:@"%d\n%@ --> %@\n", srtSampleNumber++,
														SRTStringFromTime(time, 1000, ','), SRTStringFromTime(time + sampleDuration, 1000, ',')];

			NSString * sampleText = [[[NSString alloc] initWithBytes:(pBytes+2)
															  length:textSampleLength
															encoding:NSUTF8StringEncoding] autorelease];

			if ([sampleText characterAtIndex:[sampleText length] - 1] == '\n')
				sampleText = [[[NSString alloc] initWithBytes:(pBytes+2)
													   length:textSampleLength-1
													 encoding:NSUTF8StringEncoding] autorelease];

			NSLog(@"%d %@", textSampleLength, sampleText);
			[srtFile appendString:sampleText];
			[srtFile appendString:@"\n\n"];

		}

		time += sampleDuration;

		sampleId++;
	}

	return [srtFile writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:error];
}

- (void) dealloc
{
    [super dealloc];
}

@end
