//
//  MP42Track.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "mp4v2.h"

@interface MP42Track : NSObject {
    MP4TrackId  Id;
	NSString    *sourcePath;
	NSString    *format;
    NSString    *name;
    NSString    *language;

    BOOL    isEdited;
    BOOL    isDataEdited;
    BOOL    muxed;

	int     samplerate; 
	double  bitrate; // kbit/sec
	double  duration;    // seconds
}

@property(readwrite, retain) NSString * sourcePath;
@property(readwrite) MP4TrackId Id;
@property(readwrite, retain) NSString *format;
@property(readwrite, retain) NSString *name;
@property(readwrite, retain) NSString *language;

@property(readonly) int samplerate;
@property(readonly) double bitrate;
@property(readonly) double duration;

@property(readwrite) BOOL isEdited;
@property(readwrite) BOOL isDataEdited;
@property(readwrite) BOOL muxed;

-(id)initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID;
-(void)readTrackType;

@end
