//
//  SubUtilities.h
//  Subler
//
//  Created by Alexander Strange on 7/24/07.
//  Copyright 2007 Perian. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UniversalDetector.h"
#import "mp4v2.h"

@interface SBTextSample : NSObject <NSCoding> {
    MP4Duration timestamp;
    NSString *title;
}

@property(readwrite, retain) NSString *title;
@property(readwrite) MP4Duration timestamp;

@end

@interface SBSubLine : NSObject
{
@public
	NSString *line;
	unsigned begin_time, end_time;
	unsigned no; // line number, used only by SBSubSerializer
}
-(id)initWithLine:(NSString*)l start:(unsigned)s end:(unsigned)e;
@end

@interface SBSubSerializer : NSObject
{
	// input lines, sorted by 1. beginning time 2. original insertion order
	NSMutableArray *lines;
	BOOL finished;

	unsigned last_begin_time, last_end_time;
	unsigned linesInput;
}
-(void)addLine:(SBSubLine *)sline;
-(void)setFinished:(BOOL)finished;
-(SBSubLine*)getSerializedPacket;
-(BOOL)isEmpty;
@end

NSMutableString *STStandardizeStringNewlines(NSString *str);
extern NSString *STLoadFileWithUnknownEncoding(NSString *path);
int LoadSRTFromPath(NSString *path, SBSubSerializer *ss, MP4Duration *duration);
int LoadSMIFromPath(NSString *path, SBSubSerializer *ss, int subCount);

int LoadChaptersFromPath(NSString *path, NSMutableArray *ss);
int ParseSSAHeader(NSString *header);
NSString *StripSSALine(NSString *line);

@class MP42SampleBuffer;

MP42SampleBuffer* copySubtitleSample(MP4TrackId subtitleTrackId, NSString* string, MP4Duration duration, BOOL forced);
MP42SampleBuffer* copyEmptySubtitleSample(MP4TrackId subtitleTrackId, MP4Duration duration, BOOL forced);
