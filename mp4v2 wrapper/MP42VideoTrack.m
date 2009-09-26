//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42VideoTrack.h"
#import "VideoMuxer.h"

@implementation MP42VideoTrack

- (id) initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
    if (self = [super initWithSourcePath:source trackID:trackID fileHandle:fileHandle])
    {
        height = MP4GetTrackVideoHeight(fileHandle, Id);
        width = MP4GetTrackVideoWidth(fileHandle, Id);

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

        if (MP4HaveTrackAtom(fileHandle, Id, "mdia.minf.stbl.stsd.*.pasp")) {
            MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.*.pasp.hSpacing", &hSpacing);
            MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.*.pasp.vSpacing", &vSpacing);
        }
        else {
            hSpacing = 1;
            vSpacing = 1;
        }
    }

    return self;
}

-(id) init
{
    if (self = [super init])
    {
        name = @"Video Track";
        language = @"Unknown";
    }

    return self;
}

- (BOOL) writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError
{
    if (!fileHandle)
        return NO;

    if (isEdited && !muxed) {
        if ([sourceInputType isEqualToString:MP42SourceTypeQuickTime]) {
#if !__LP64__
            Id = muxMOVVideoTrack(fileHandle, sourceFileHandle, sourceId);
#endif
        }
        else if ([sourceInputType isEqualToString:MP42SourceTypeMP4])
            Id = muxMP4VideoTrack(fileHandle, sourcePath, sourceId);
        else
            Id = muxH264ElementaryStream(fileHandle, sourcePath, sourceId);
    }
    if (Id) {
        [super writeToFile:fileHandle error:outError];

        if (trackWidth && trackHeight) {
            MP4SetTrackFloatProperty(fileHandle, Id, "tkhd.width", trackWidth);
            MP4SetTrackFloatProperty(fileHandle, Id, "tkhd.height", trackHeight);

            uint8_t *val;
            uint8_t nval[36];
            uint32_t *ptr32 = (uint32_t*) nval;
            uint32_t size;

            MP4GetTrackBytesProperty(fileHandle ,Id, "tkhd.matrix", &val, &size);
            memcpy(nval, val, size);
            ptr32[6] = CFSwapInt32HostToBig(offsetX * 0x10000);
            ptr32[7] = CFSwapInt32HostToBig(offsetY * 0x10000);
            MP4SetTrackBytesProperty(fileHandle, Id, "tkhd.matrix", nval, size);

            free(val);

            if (MP4HaveTrackAtom(fileHandle, Id, "mdia.minf.stbl.stsd.*.pasp")) {
                MP4SetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.*.pasp.hSpacing", hSpacing);
                MP4SetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.*.pasp.vSpacing", vSpacing);
            }
            else if(hSpacing > 1 && vSpacing > 1)
                MP4AddPixelAspectRatio(fileHandle, Id, hSpacing, vSpacing);
        }
    }

    return Id;
}

- (void) dealloc
{
    [super dealloc];
}

@synthesize width;
@synthesize height;

@synthesize trackWidth;
@synthesize trackHeight;

@synthesize hSpacing;
@synthesize vSpacing;

@synthesize offsetX;
@synthesize offsetY;

@end
