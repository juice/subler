//
//  MP42Track.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "mp4v2.h"

@interface MP42Track : NSObject {
    MP4TrackId  Id;
    MP4TrackId  sourceId;
	NSString    *sourcePath;
	NSString    *format;
    NSString    *name;
    NSString    *language;
    BOOL        enabled;
    uint64_t    alternate_group;

    BOOL    isEdited;
    BOOL    isDataEdited;
    BOOL    muxed;

	uint32_t    timescale; 
	uint32_t    bitrate; 
	MP4Duration duration;
}

@property(readwrite) MP4TrackId Id;
@property(readwrite) MP4TrackId sourceId;

@property(readwrite, retain) NSString *sourcePath;
@property(readwrite, retain) NSString *format;
@property(readwrite, retain) NSString *name;
@property(readwrite, retain) NSString *language;

@property(readonly) uint32_t timescale;
@property(readonly) uint32_t bitrate;
@property(readonly) MP4Duration duration;

@property(readwrite) BOOL isEdited;
@property(readwrite) BOOL isDataEdited;
@property(readwrite) BOOL muxed;

- (id) initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle;
- (BOOL) writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError;

- (NSString *) timeString;

@end
