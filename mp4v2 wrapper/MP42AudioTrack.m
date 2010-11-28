//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42AudioTrack.h"
#import "AudioMuxer.h"
#import "MP42Utilities.h"

@implementation MP42AudioTrack

- (id) initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
    if ((self = [super initWithSourcePath:source trackID:trackID fileHandle:fileHandle]))
    {
        MP4GetTrackFloatProperty(fileHandle, Id, "tkhd.volume", &volume);
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
    }

    return self;
}

- (BOOL) writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError
{
    if (!fileHandle)
        return NO;

    if (Id)
        [super writeToFile:fileHandle error:outError];

    if ([updatedProperty valueForKey:@"volume"] || !muxed)
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

@end
