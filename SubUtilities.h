//
//  SubUtilities.h
//  Subler
//
//  Created by Alexander Strange on 7/24/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "UniversalDetector.h"
#import "mp4v2.h"

@interface SBChapter : NSObject {
    MP4Duration duration;
    NSString *title;
}

@property(readwrite, retain) NSString *title;
@property(readwrite) MP4Duration duration;

@end

@interface SubLine : NSObject
{
@public
	NSString *line;
	unsigned begin_time, end_time;
}
-(id)initWithLine:(NSString*)l start:(unsigned)s end:(unsigned)e;
@end

@interface SubSerializer : NSObject
{
	NSMutableArray *lines, *outpackets;
	BOOL finished, write_gap;
	unsigned last_time;
	SubLine *toReturn;
}
-(void)addLine:(SubLine *)sline;
-(void)setFinished:(BOOL)finished;
-(SubLine*)getSerializedPacket;
-(BOOL)isEmpty;
@end

NSMutableString *STStandardizeStringNewlines(NSString *str);
extern NSString *STLoadFileWithUnknownEncoding(NSString *path);
void LoadSRTFromPath(NSString *path, SubSerializer *ss);
void LoadChaptersFromPath(NSString *path, NSMutableArray *ss);
