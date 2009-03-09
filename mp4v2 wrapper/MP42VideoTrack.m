//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP42VideoTrack.h"

@implementation MP42VideoTrack

- (id)initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
    if (self = [super initWithSourcePath:source trackID:trackID fileHandle:fileHandle])
    {
        height = MP4GetTrackVideoHeight(fileHandle, Id);
        width = MP4GetTrackVideoWidth(fileHandle, Id);

        MP4GetTrackFloatProperty(fileHandle, Id, "tkhd.width", &trackWidth);
        MP4GetTrackFloatProperty(fileHandle, Id, "tkhd.height", &trackHeight);

        uint8_t* val;
        uint8_t nval[36];
        uint32_t *ptr32 = (uint32_t*) nval;
        uint32_t size;

        MP4GetTrackBytesProperty(fileHandle ,Id, "tkhd.matrix", &val, &size);
        memcpy(nval, val, size);
        offsetX = CFSwapInt32HostToBig(ptr32[6]) / 0x10000;
        offsetY = CFSwapInt32HostToBig(ptr32[7]) / 0x10000;

        free(val);
    }

    return self;
}

-(id) init
{
    if (self = [super init])
    {
        name = @"Video Track";
    }

    return self;
}

- (void) dealloc
{
    [super dealloc];
}

@synthesize width;
@synthesize height;

@synthesize trackWidth;
@synthesize trackHeight;

@synthesize offsetX;
@synthesize offsetY;

@end
