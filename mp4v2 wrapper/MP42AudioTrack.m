//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42AudioTrack.h"
#import "MP42Utilities.h"

extern u_int8_t MP4AV_AacConfigGetChannels(u_int8_t* pConfig);

@implementation MP42AudioTrack

- (id) initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
    if ((self = [super initWithSourcePath:source trackID:trackID fileHandle:fileHandle])) {
        MP4GetTrackFloatProperty(fileHandle, Id, "tkhd.volume", &volume);

        u_int8_t audioType = 
		MP4GetTrackEsdsObjectTypeId(fileHandle, Id);

        if (audioType != MP4_INVALID_AUDIO_TYPE) {
            if (MP4_IS_AAC_AUDIO_TYPE(audioType)) {
                u_int8_t* pAacConfig = NULL;
                u_int32_t aacConfigLength;

                if (MP4GetTrackESConfiguration(fileHandle, 
                                               Id,
                                               &pAacConfig,
                                               &aacConfigLength) == true)
                    if (pAacConfig != NULL || aacConfigLength >= 2) {
                        channels = MP4AV_AacConfigGetChannels(pAacConfig);
                        free(pAacConfig);
                    }
            } else if ((audioType == MP4_PCM16_LITTLE_ENDIAN_AUDIO_TYPE) ||
                       (audioType == MP4_PCM16_BIG_ENDIAN_AUDIO_TYPE)) {
                u_int32_t samplesPerFrame =
                MP4GetSampleSize(fileHandle, Id, 1) / 2;

                MP4Duration frameDuration =
                MP4GetSampleDuration(fileHandle, Id, 1);

                if (frameDuration != 0) {
                    // assumes track time scale == sampling rate
                    channels = samplesPerFrame / frameDuration;
                }
            }
        }
        else if (MP4HaveTrackAtom(fileHandle, Id, "mdia.minf.stbl.stsd.ac-3.dac3")) {
            uint64_t acmod, lfeon;

            MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.ac-3.dac3.acmod", &acmod);
            MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.ac-3.dac3.lfeon", &lfeon);

            readAC3Config(acmod, lfeon, &channels, &channelLayoutTag);
        }
        if (MP4HaveTrackAtom(fileHandle, Id, "tref.fall")) {
            uint64_t fallbackId = 0;
            MP4GetTrackIntegerProperty(fileHandle, Id, "tref.fall.entries.trackId", &fallbackId);
            fallbackTrackId = (MP4TrackId) fallbackId;
        }
    }

    return self;
}

- (id) init
{
    if ((self = [super init]))
    {
        name = @"Sound Track";
        language = @"Unknown";
        volume = 1;
        mixdownType = SBDolbyPlIIMixdown;
    }

    return self;
}

- (BOOL) writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError
{
    if (!fileHandle)
        return NO;

    if (Id)
        [super writeToFile:fileHandle error:outError];

    if ([updatedProperty valueForKey:@"volume"])
        MP4SetTrackFloatProperty(fileHandle, Id, "tkhd.volume", volume);
    if ([updatedProperty valueForKey:@"fallback"]) {
        if (MP4HaveTrackAtom(fileHandle, Id, "tref.fall") && (fallbackTrackId == 0)) {
            MP4RemoveAllTrackReferences(fileHandle, "tref.fall", Id);
        }
        else if (MP4HaveTrackAtom(fileHandle, Id, "tref.fall") && (fallbackTrackId)) {
            MP4SetTrackIntegerProperty(fileHandle, Id, "tref.fall.entries.trackId", fallbackTrackId);
        }
        else if (fallbackTrackId)
            MP4AddTrackReference(fileHandle, "tref.fall", fallbackTrackId, Id);
    }

    return Id;
}

- (void) dealloc
{
    [super dealloc];
}

- (void) setVolume: (float) newVolume
{
    volume = newVolume;
    isEdited = YES;
    [updatedProperty setValue:@"True" forKey:@"volume"];
}

- (float) volume
{
    return volume;
}

- (void) setFallbackTrackId: (MP4TrackId) newFallbackTrackId
{
    fallbackTrackId = newFallbackTrackId;
    isEdited = YES;
    [updatedProperty setValue:@"True" forKey:@"fallback"];
}

- (MP4TrackId) fallbackTrackId
{
    return fallbackTrackId;
}

- (NSString *)formatSummary
{
    return [NSString stringWithFormat:@"%@, %d ch", format, channels];
}

- (NSString *)description {
    return [[super description] stringByAppendingFormat:@" %@, %d ch", format, channels];
}

@synthesize channels;
@synthesize mixdownType;
@synthesize channelLayoutTag;

@end
