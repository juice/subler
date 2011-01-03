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
    }

    return self;
}

-(id) init
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

@synthesize channels;
@synthesize mixdownType;
@synthesize channelLayoutTag;

@end
