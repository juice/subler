//
//  MP42MkvFileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import "MP42SrtImporter.h"
#import "SubUtilities.h"
#import "lang.h"
#import "MP42File.h"


@implementation MP42SrtImporter

- (id)initWithDelegate:(id)del andFile:(NSURL *)URL error:(NSError **)outError
{
    if ((self = [super init])) {
        delegate = del;
        fileURL = [URL retain];

        NSInteger trackCount =1;
        tracksArray = [[NSMutableArray alloc] initWithCapacity:trackCount];

        NSInteger success = 0;
        MP4Duration duration = 0;

        MP42SubtitleTrack *newTrack = [[MP42SubtitleTrack alloc] init];

        newTrack.format = @"3GPP Text";
        newTrack.sourceFormat = @"Srt";
        newTrack.sourceURL = fileURL;
        newTrack.alternate_group = 2;
        newTrack.trackHeight = 80;
        newTrack.language = getFilenameLanguage((CFStringRef)[fileURL path]);

        ss = [[SBSubSerializer alloc] init];
        if ([[fileURL pathExtension] caseInsensitiveCompare: @"srt"] == NSOrderedSame) {
            success = LoadSRTFromPath([fileURL path], ss, &duration);
        }
        else if ([[fileURL pathExtension] caseInsensitiveCompare: @"smi"] == NSOrderedSame) {
            success = LoadSMIFromPath([fileURL path], ss, 1);
        }

        [newTrack setDuration:duration];

        if (!success) {
            if (outError)
                *outError = MP42Error(@"The file could not be opened.", @"The file is not a srt file, or it does not contain any subtitles.", 100);
            
            [newTrack release];
            [self release];

            return nil;
        }

        [ss setFinished:YES];

        [tracksArray addObject:newTrack];
        [newTrack release];
    }

    return self;
}

- (NSUInteger)timescaleForTrack:(MP42Track *)track
{
    return 1000;
}

- (NSSize)sizeForTrack:(MP42Track *)track
{
      return NSMakeSize([(MP42SubtitleTrack*)track trackWidth], [(MP42SubtitleTrack*) track trackHeight]);
}

- (NSData*)magicCookieForTrack:(MP42Track *)track
{
    return nil;
}

- (MP42SampleBuffer*)nextSampleForTrack:(MP42Track *)track
{
    return [[self copyNextSample] autorelease];
}

- (MP42SampleBuffer*)copyNextSample {
    MP42SampleBuffer *sample;
    MP4TrackId dstTrackId = [[activeTracks lastObject] Id];

    if (![ss isEmpty]) {
        SBSubLine *sl = [ss getSerializedPacket];
        
        if ([sl->line isEqualToString:@"\n"]) {
            if ((sample = copyEmptySubtitleSample(dstTrackId, sl->end_time - sl->begin_time))) 
                return sample;
        }
        if ((sample = copySubtitleSample(dstTrackId, sl->line, sl->end_time - sl->begin_time)))
            return sample;
    }

    return nil;
}

- (void)setActiveTrack:(MP42Track *)track {
    if (!activeTracks)
        activeTracks = [[NSMutableArray alloc] init];
    
    [activeTracks addObject:track];
}

- (CGFloat)progress {
    return 100.0;
}

- (void) dealloc
{
    [ss release];
	[fileURL release];
    [tracksArray release];

    [super dealloc];
}

@end
