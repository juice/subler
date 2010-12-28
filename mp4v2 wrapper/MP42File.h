//
//  MP42File.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "mp4v2.h"
#import "MP42Track.h"
#import "MP42VideoTrack.h"
#import "MP42AudioTrack.h"
#import "MP42SubtitleTrack.h"
#import "MP42ClosedCaptionTrack.h"
#import "MP42ChapterTrack.h"
#import "MP42Metadata.h"
#import "MP42Utilities.h"
#import "MP42Muxer.h"

extern NSString * const MP42Create64BitData;
extern NSString * const MP42Create64BitTime;
extern NSString * const MP42CreateChaptersPreviewTrack;

@interface MP42File : NSObject {
@private
    MP4FileHandle  fileHandle;
    NSString      *filePath;
    id delegate;

    NSMutableArray  *tracksToBeDeleted;
    BOOL             hasFileRepresentation;
    BOOL             isCancelled;

@protected
    NSMutableArray  *tracks;
    MP42Metadata    *metadata;
    MP42Muxer       *muxer;
}

@property(readonly) NSMutableArray  *tracks;
@property(readonly) MP42Metadata    *metadata;
@property(readonly) BOOL hasFileRepresentation;

- (id)   initWithDelegate:(id)del;
- (id)   initWithExistingFile:(NSString *)path andDelegate:(id)del;

- (NSUInteger) movieDuration;
- (MP42ChapterTrack*) chapters;

- (NSUInteger) tracksCount;
- (id)   trackAtIndex:(NSUInteger)index;

- (void) addTrack:(id)object;

- (void) removeTrackAtIndex:(NSUInteger)index;
- (void) removeTracksAtIndexes:(NSIndexSet *)indexes;
- (void) moveTrackAtIndex:(NSUInteger)index toIndex:(NSUInteger)newIndex;

- (BOOL) writeToUrl:(NSURL *)url withAttributes:(NSDictionary *)attributes error:(NSError **)outError;
- (BOOL) updateMP4FileWithAttributes:(NSDictionary *)attributes error:(NSError **)outError;
- (void) optimize;

- (void) cancel;

@end

@interface NSObject (MP42FileDelegateMethod)
- (void)progressStatus: (CGFloat)progress;

@end
