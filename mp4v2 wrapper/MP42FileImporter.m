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
#import "MP42MovImporter.h"
#import "MP42SrtImporter.h"

@implementation MP42FileImporter

- (id)initWithDelegate:(id)del andFile:(NSString *)fileUrl
{
    [self release];
    self = nil;
    if ([[fileUrl pathExtension] caseInsensitiveCompare: @"mkv"] == NSOrderedSame ||
        [[fileUrl pathExtension] caseInsensitiveCompare: @"mka"] == NSOrderedSame)
        self = [[MP42MkvImporter alloc] initWithDelegate:del andFile:fileUrl];
    else if ([[fileUrl pathExtension] caseInsensitiveCompare: @"mp4"] == NSOrderedSame ||
             [[fileUrl pathExtension] caseInsensitiveCompare: @"m4v"] == NSOrderedSame ||
             [[fileUrl pathExtension] caseInsensitiveCompare: @"m4a"] == NSOrderedSame)
        self = [[MP42Mp4Importer alloc] initWithDelegate:del andFile:fileUrl];
    else if ([[fileUrl pathExtension] caseInsensitiveCompare: @"mov"] == NSOrderedSame)
        self = [[MP42MovImporter alloc] initWithDelegate:del andFile:fileUrl];
    else if ([[fileUrl pathExtension] caseInsensitiveCompare: @"srt"] == NSOrderedSame)
        self = [[MP42SrtImporter alloc] initWithDelegate:del andFile:fileUrl];

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

- (CGFloat)progress {
    return 0;
}


@synthesize tracksArray;

@end