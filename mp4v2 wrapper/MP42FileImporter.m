//
//  MP42FileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import "MP42FileImporter.h"
#import "MP42MkvImporter.h"
#import "MP42Mp4Importer.h"
#import "MP42SrtImporter.h"
#import "MP42CCImporter.h"
#import "MP42AC3Importer.h"
#import "MP42AACImporter.h"
#import "MP42H264Importer.h"

#if !__LP64__
#import "MP42QTImporter.h"
#endif

#import "MP42AVFImporter.h"

@implementation MP42FileImporter

- (id)initWithDelegate:(id)del andFile:(NSURL *)URL error:(NSError **)outError
{
    [self release];
    self = nil;
    if ([[URL pathExtension] caseInsensitiveCompare: @"mkv"] == NSOrderedSame ||
        [[URL pathExtension] caseInsensitiveCompare: @"mka"] == NSOrderedSame)
        self = [[MP42MkvImporter alloc] initWithDelegate:del andFile:URL error:outError];
    else if ([[URL pathExtension] caseInsensitiveCompare: @"mp4"] == NSOrderedSame ||
             [[URL pathExtension] caseInsensitiveCompare: @"m4v"] == NSOrderedSame ||
             [[URL pathExtension] caseInsensitiveCompare: @"m4a"] == NSOrderedSame)
        self = [[MP42Mp4Importer alloc] initWithDelegate:del andFile:URL error:outError];
    else if ([[URL pathExtension] caseInsensitiveCompare: @"srt"] == NSOrderedSame)
        self = [[MP42SrtImporter alloc] initWithDelegate:del andFile:URL error:outError];
    else if ([[URL pathExtension] caseInsensitiveCompare: @"scc"] == NSOrderedSame)
        self = [[MP42CCImporter alloc] initWithDelegate:del andFile:URL error:outError];
    else if ([[URL pathExtension] caseInsensitiveCompare: @"ac3"] == NSOrderedSame)
        self = [[MP42AC3Importer alloc] initWithDelegate:del andFile:URL error:outError];
    else if ([[URL pathExtension] caseInsensitiveCompare: @"aac"] == NSOrderedSame)
        self = [[MP42AACImporter alloc] initWithDelegate:del andFile:URL error:outError];
    else if ([[URL pathExtension] caseInsensitiveCompare: @"264"] == NSOrderedSame ||
             [[URL pathExtension] caseInsensitiveCompare: @"h264"] == NSOrderedSame)
        self = [[MP42H264Importer alloc] initWithDelegate:del andFile:URL error:outError];

#if !__LP64__
    else if ([[URL pathExtension] caseInsensitiveCompare: @"mov"] == NSOrderedSame)
        self = [[MP42QTImporter alloc] initWithDelegate:del andFile:URL error:outError];
#elif __MAC_OS_X_VERSION_MAX_ALLOWED > 1060
    else if ([[URL pathExtension] caseInsensitiveCompare: @"mov"] == NSOrderedSame)
        self = [[MP42AVFImporter alloc] initWithDelegate:del andFile:URL error:outError];
#endif

    return self;
}

- (NSUInteger)timescaleForTrack:(MP42Track *)track{
    return 0;
}
- (NSSize)sizeForTrack:(MP42Track *)track{
    return NSMakeSize(0,0);
}
- (NSData*)magicCookieForTrack:(MP42Track *)track{
    return nil;
}

- (void)setActiveTrack:(MP42Track *)track
{
}

- (MP42SampleBuffer*)copyNextSample
{
    return nil;
}

- (MP42SampleBuffer*)nextSampleForTrack:(MP42Track *)track
{
    return nil;
}

- (CGFloat)progress
{
    return 0;
}

- (BOOL)cleanUp:(MP4FileHandle) fileHandle
{
    return NO;
}

- (void)cancel
{
    isCancelled = YES;
}


@synthesize metadata;
@synthesize tracksArray;

@end