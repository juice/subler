//
//  MP42Sample.h
//  Subler
//
//  Created by Damiano Galassi on 29/06/10.
//  Copyright 2010 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "mp4v2.h"

@class MP42Track;

@interface MP42SampleBuffer : NSObject {
    @public
	void         *sampleData;
    uint64_t      sampleSize;
    MP4Duration   sampleDuration;
    int64_t       sampleOffset;
    MP4Timestamp  sampleTimestamp;
    MP4TrackId    sampleTrackId;
    BOOL          sampleIsSync;
    BOOL          sampleIsCompressed;
    MP42Track    *sampleSourceTrack;
}

@property(readwrite) void         *sampleData;
@property(readwrite) uint64_t      sampleSize;
@property(readwrite) MP4Duration   sampleDuration;
@property(readwrite) int64_t   sampleOffset;
@property(readwrite) MP4Timestamp  sampleTimestamp;
@property(readwrite) MP4TrackId    sampleTrackId;
@property(readwrite) BOOL          sampleIsSync;
@property(readwrite) BOOL          sampleIsCompressed;
@property(assign)    MP42Track    *sampleSourceTrack;

@end
