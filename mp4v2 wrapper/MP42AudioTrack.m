//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42AudioTrack.h"
#import "AudioMuxer.h"

@implementation MP42AudioTrack

- (id) initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
    if (self = [super initWithSourcePath:source trackID:trackID fileHandle:fileHandle])
    {

    }

    return self;
}

-(id) init
{
    if (self = [super init])
    {
        name = @"Sound Track";
        language = @"Unknown";
    }

    return self;
}

- (BOOL) writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError
{
    if (!fileHandle)
        return NO;

    if (isEdited && !muxed) {
        if ([[sourcePath pathExtension] isEqualToString:@"mov"])
            Id = muxMOVAudioTrack(fileHandle, sourcePath, sourceId);
        else if ([[sourcePath pathExtension] isEqualToString:@"aac"])
            Id = muxAACAdtsStream(fileHandle, sourcePath);
        else if ([[sourcePath pathExtension] isEqualToString:@"ac3"])
            Id = muxAC3ElementaryStream(fileHandle, sourcePath);
        else
            Id = muxMP4AudioTrack(fileHandle, sourcePath, sourceId);
    }
    if (Id)
        [super writeToFile:fileHandle error:outError];

    return YES;
}

- (void) dealloc
{
    [super dealloc];
}

@end
