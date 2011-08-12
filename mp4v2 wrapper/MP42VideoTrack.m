//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42VideoTrack.h"

@implementation MP42VideoTrack

- (id) initWithSourceURL:(NSURL *)URL trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
    if ((self = [super initWithSourceURL:URL trackID:trackID fileHandle:fileHandle]))
    {
        if ([self isMemberOfClass:[MP42VideoTrack class]]) {
            height = MP4GetTrackVideoHeight(fileHandle, Id);
            width = MP4GetTrackVideoWidth(fileHandle, Id);
        }

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
        
        if ([format isEqualToString:@"H.264"]) {
            MP4GetTrackH264ProfileLevel(fileHandle, trackID, &origProfile, &origLevel);
            newProfile = origProfile;
            newLevel = origLevel;
        }
        
    }

    return self;
}

-(id) init
{
    if ((self = [super init]))
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

    else if (Id) {
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
            
            if ([format isEqualToString:@"H.264"]) {
                if ([updatedProperty valueForKey:@"profile"]) {
                    MP4SetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.*[0].avcC.AVCProfileIndication", newProfile);
                    origProfile = newProfile;
                }
                if ([updatedProperty valueForKey:@"level"]) {
                    MP4SetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.*[0].avcC.AVCLevelIndication", newLevel);
                    origLevel = newLevel;
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


- (uint64_t) hSpacing {
    return hSpacing;
}

- (void) setHSpacing:(uint64_t)newHSpacing
{
    hSpacing = newHSpacing;
    isEdited = YES;
    [updatedProperty setValue:@"True" forKey:@"hSpacing"];
    
}

- (uint64_t) vSpacing {
    return vSpacing;
}

- (void) setVSpacing:(uint64_t)newVSpacing
{
    vSpacing = newVSpacing;
    isEdited = YES;
    [updatedProperty setValue:@"True" forKey:@"vSpacing"];
    
}

@synthesize offsetX;
@synthesize offsetY;

@synthesize origProfile;
@synthesize origLevel;

@synthesize newProfile;
@synthesize newLevel;

@end
