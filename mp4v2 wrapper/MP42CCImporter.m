//
//  MP42CCFileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 05/12/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import "MP42CCImporter.h"
#import "SubUtilities.h"
#import "lang.h"
#import "MP42File.h"
#import "RegexKitLite.h"


@implementation MP42CCImporter

- (id)initWithDelegate:(id)del andFile:(NSString *)fileUrl
{
    if ((self = [super init])) {
        delegate = del;
        file = [fileUrl retain];

        tracksArray = [[NSMutableArray alloc] initWithCapacity:1];

        MP42Track *newTrack = [[MP42ClosedCaptionTrack alloc] init];

        newTrack.name = @"Closed Caption Track";
        newTrack.format = @"CEA-608";
        newTrack.sourcePath = file;

        [tracksArray addObject:newTrack];
        [newTrack release];
    }

    return self;
}


- (NSUInteger)timescaleForTrack:(MP42Track *)track
{
    return 30000;
}

- (NSSize)sizeForTrack:(MP42Track *)track
{
      return NSMakeSize([(MP42SubtitleTrack*)track trackWidth], [(MP42SubtitleTrack*) track trackHeight]);
}

- (NSData*)magicCookieForTrack:(MP42Track *)track
{
    return nil;
}

static unsigned ParseTimeCode(const char *time, unsigned secondScale, BOOL hasSign, uint64_t *dropFrame)
{
	unsigned hour, minute, second, frame, timeval;
	char separator;
	int sign = 1;

	if (hasSign && *time == '-') {
		sign = -1;
		time++;
	}

	if (sscanf(time,"%u:%u:%u%[,.:;]%u",&hour,&minute,&second,&separator,&frame) < 5)
		return 0;

	timeval = (hour * 60 * 60 + minute * 60 + second) * 30 + frame;
	//timeval = secondScale * timeval + frame;

    if (separator == ';')
        *dropFrame = 1;

	return timeval * sign;
}

static int ParseByte(const char *string, UInt8 *byte, Boolean hex)
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

- (void) fillMovieSampleBuffer: (id)sender
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    MP4TrackId dstTrackId = [[activeTracks lastObject] Id];

    NSString *scc = STStandardizeStringNewlines(STLoadFileWithUnknownEncoding(file));
    if (!scc) return;

    NSScanner *sc = [NSScanner scannerWithString:scc];
	NSString *res=nil;
	[sc setCharactersToBeSkipped:nil];

    [sc scanUpToString:@"\n" intoString:&res];
    if (![res isEqualToString:@"Scenarist_SCC V1.0"])
        return;

    unsigned startTime=0;
    BOOL firstSample = YES;
    NSString *splitLine  = @"\\n+";
    NSString *splitTimestamp  = @"\\t+";
    NSString *splitBytes  = @"\\s+";
    NSArray  *fileArray   = nil;
    NSUInteger i = 0;

    fileArray = [scc componentsSeparatedByRegex:splitLine];

    NSMutableArray *sampleArray = [[NSMutableArray alloc] initWithCapacity:[fileArray count]];

	uint64_t dropFrame = 0;
    uint64_t frameDrop = 0;
    uint64_t minutesDrop = 0;

    for (NSString *line in fileArray) {
        NSArray *lineArray = [line componentsSeparatedByRegex:splitTimestamp];

        if ([lineArray count] < 2)
            continue;

        startTime = ParseTimeCode([[lineArray objectAtIndex:0] UTF8String], 30000, NO, &dropFrame);
        SBTextSample *sample = [[SBTextSample alloc] init];
        sample.timestamp = startTime;
        sample.title = [lineArray lastObject];
        
        [sampleArray addObject:[sample autorelease]];
    }

    for (SBTextSample *ccSample in sampleArray) {
        NSArray  *bytesArray   = nil;
        MP4Duration sampleDuration = 0;
        bytesArray = [ccSample.title componentsSeparatedByRegex:splitBytes];

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

        if (firstSample && ccSample.timestamp != 0 && i == 0) {
            SBTextSample *boh = [sampleArray objectAtIndex:1];
            sampleDuration = boh.timestamp - ccSample.timestamp;
            firstSample = NO;
            u_int8_t *emptyBuffer = malloc(sizeof(u_int8_t)*8);
            u_int8_t empty[8] = {0,0,0,8,'c','d','a','t'};
            memcpy(emptyBuffer, empty, sizeof(u_int8_t)*8);

            MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
            sample->sampleData = emptyBuffer;
            sample->sampleSize = 8;
            sample->sampleDuration = ccSample.timestamp *= 1001;
            sample->sampleOffset = 0;
            sample->sampleTimestamp = 0;
            sample->sampleIsSync = 1;
            sample->sampleTrackId = dstTrackId;

            @synchronized(samplesBuffer) {
                [samplesBuffer addObject:sample];
                [sample release];
            }

            frameDrop += ccSample.timestamp;
            minutesDrop += frameDrop;
        }
        else if (i+1 < [sampleArray count]) {
            SBTextSample *boh = [sampleArray objectAtIndex:i+1];
            sampleDuration = boh.timestamp - ccSample.timestamp;
            frameDrop += sampleDuration;
            minutesDrop += sampleDuration;

            if (frameDrop >= 1800 && dropFrame) {
                if (minutesDrop > 18000)
                    minutesDrop -= 16200;
                else {
                    sampleDuration -= 2;
                }

                frameDrop -= 1800;
            }
        }
        else
            sampleDuration = 6;

        MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
        sample->sampleData = bytes;
        sample->sampleSize = byteCount + 8;
        sample->sampleDuration = sampleDuration * 1001;
        sample->sampleOffset = 0;
        sample->sampleTimestamp = 0;
        sample->sampleIsSync = 1;
        sample->sampleTrackId = dstTrackId;

        @synchronized(samplesBuffer) {
            [samplesBuffer addObject:sample];
            [sample release];
        }

        i++;
    }

    [sampleArray release];
    [pool release];
    readerStatus = 1;
}

- (MP42SampleBuffer*)copyNextSample {    
    if (samplesBuffer == nil) {
        samplesBuffer = [[NSMutableArray alloc] initWithCapacity:200];
    }

    if (!dataReader && !readerStatus) {
        dataReader = [[NSThread alloc] initWithTarget:self selector:@selector(fillMovieSampleBuffer:) object:self];
        [dataReader setName:@"Closed Caption Demuxer"];
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
	[file release];
    [tracksArray release];

    [super dealloc];
}

@end
