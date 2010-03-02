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

		else if ([sourceInputType isEqualToString:MP42SourceTypeMatroska])
			Id = muxMKVVideoTrack(fileHandle, sourcePath, sourceId);

        else if ([sourceInputType isEqualToString:MP42SourceTypeRaw])
            Id = muxH264ElementaryStream(fileHandle, sourcePath, sourceId);
    }

    if (!Id && (outError != NULL)) {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Error: couldn't mux video track" forKey:NSLocalizedDescriptionKey];
        *outError = [NSError errorWithDomain:@"MP42Error"
                                        code:110
                                    userInfo:errorDetail];
    }
    else if (Id) {
        [super writeToFile:fileHandle error:outError];

        if (trackWidth && trackHeight) {
            if (hSpacing & vSpacing && !muxed)
                MP4SetTrackFloatProperty(fileHandle, Id, "tkhd.width", trackWidth * hSpacing / vSpacing);
            else
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

            if ([updatedProperty valueForKey:@"hSpacing"] || [updatedProperty valueForKey:@"vSpacing"]) {
                if (hSpacing >= 1 && vSpacing >= 1) {
                    if (MP4HaveTrackAtom(fileHandle, Id, "mdia.minf.stbl.stsd.*.pasp")) {
                        MP4SetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.*.pasp.hSpacing", hSpacing);
                        MP4SetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.*.pasp.vSpacing", vSpacing);
                    }
                    else
                        MP4AddPixelAspectRatio(fileHandle, Id, hSpacing, vSpacing);
                }
            }
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
- (void) setHSpacing: (uint64_t) newValue
{
    hSpacing = newValue;
    isEdited = YES;
    [updatedProperty setValue:@"True" forKey:@"hSpacing"];
}

@synthesize vSpacing;
- (void) setVSpacing: (uint64_t) newValue
{
    vSpacing = newValue;
    isEdited = YES;
    [updatedProperty setValue:@"True" forKey:@"vSpacing"];
}

@synthesize offsetX;
@synthesize offsetY;

@end
