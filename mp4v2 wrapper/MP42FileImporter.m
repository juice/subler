//
//  MP42FileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "MP42FileImporter.h"
#import "MP42MkvImporter.h"
#import "MP42Mp4Importer.h"
#import "MP42MovImporter.h"

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

    return self;
}

@synthesize tracksArray;

@end