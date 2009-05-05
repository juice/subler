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

@interface SBSample : NSObject {
    MP4Duration timestamp;
    NSString *title;
}

@property(readwrite, retain) NSString *title;
@property(readwrite) MP4Duration timestamp;

@end

@interface SubLine : NSObject
{
@public
	NSString *line;
	unsigned begin_time, end_time;
	unsigned no; // line number, used only by SubSerializer
}
-(id)initWithLine:(NSString*)l start:(unsigned)s end:(unsigned)e;
@end

@interface SubSerializer : NSObject
{
	// input lines, sorted by 1. beginning time 2. original insertion order
	NSMutableArray *lines;
	BOOL finished;
	
	unsigned last_begin_time, last_end_time;
	unsigned linesInput;
}
-(void)addLine:(SubLine *)sline;
-(void)setFinished:(BOOL)finished;
-(SubLine*)getSerializedPacket;
-(BOOL)isEmpty;
@end

NSMutableString *STStandardizeStringNewlines(NSString *str);
extern NSString *STLoadFileWithUnknownEncoding(NSString *path);
int LoadSRTFromPath(NSString *path, SubSerializer *ss);
int LoadChaptersFromPath(NSString *path, NSMutableArray *ss);
