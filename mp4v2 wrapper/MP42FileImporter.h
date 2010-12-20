//
//  MP42FileImporter.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42Sample.h"
#import "mp4v2.h"

@class MP42Sample;
@class MP42Metadata;
@class MP42Track;

@interface MP42FileImporter : NSObject {
    NSString       *file;

    NSInteger      chapterTrackId;
    MP42Metadata   *metadata;
    NSMutableArray *tracksArray;

    id delegate;
    BOOL           isCancelled;
}

- (id)initWithDelegate:(id)del andFile:(NSString *)fileUrl;

- (NSUInteger)timescaleForTrack:(MP42Track *)track;
- (NSSize)sizeForTrack:(MP42Track *)track;
- (NSData*)magicCookieForTrack:(MP42Track *)track;
- (void)setActiveTrack:(MP42Track *)track;

- (MP42SampleBuffer*)copyNextSample;
- (CGFloat)progress;
- (void)cancel;

- (BOOL)cleanUp:(MP4FileHandle) fileHandle;

@property(readwrite, retain) MP42Metadata *metadata;
@property(readonly) NSMutableArray  *tracksArray;

@end

@interface NSObject (MP42FileImporterDelegateMethod)
- (void) fileLoaded;

@end