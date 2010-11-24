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
    if (self = [super initWithSourcePath:source trackID:trackID fileHandle:fileHandle])
    {
        MP4GetTrackFloatProperty(fileHandle, Id, "tkhd.volume", &volume);
    }

    return self;
}

-(id) init
{
    if (self = [super init])
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

    if (isEdited && !muxed) {
        if ([sourceInputType isEqualToString:MP42SourceTypeQuickTime]) {
#if !__LP64__
            Id = muxMOVAudioTrack(fileHandle, sourceFileHandle, sourceId);
#endif
        }
        else if ([sourceInputType isEqualToString:MP42SourceTypeMP4])
            Id = muxMP4AudioTrack(fileHandle, sourcePath, sourceId);

        else if ([sourceInputType isEqualToString:MP42SourceTypeMatroska])
			Id = muxMKVAudioTrack(fileHandle, sourcePath, sourceId);

        else if ([sourceInputType isEqualToString:MP42SourceTypeRaw])
        {
            if ([[sourcePath pathExtension] isEqualToString:@"aac"])
                Id = muxAACAdtsStream(fileHandle, sourcePath);

            else if ([[sourcePath pathExtension] isEqualToString:@"ac3"])
                Id = muxAC3ElementaryStream(fileHandle, sourcePath);
        }    
        muxed = YES;
        enableFirstAudioTrack(fileHandle);
    }
    if (!Id && (outError != NULL)) {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Error: couldn't mux audio track" forKey:NSLocalizedDescriptionKey];
        *outError = [NSError errorWithDomain:@"MP42Error"
                                        code:110
                                    userInfo:errorDetail];
    }
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

@end
