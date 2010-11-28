//
//  MP42Muxer.h
//  Subler
//
//  Created by Damiano Galassi on 30/06/10.
//  Copyright 2010 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "mp4v2.h"
@class MP42Track;

@interface MP42Muxer : NSObject {
    NSMutableArray *workingTracks;
    id delegate;
}
- (id)initWithDelegate:(id)del;

- (void)addTrack:(MP42Track*)track;

- (void)prepareWork:(MP4FileHandle)fileHandle;
- (void)work:(MP4FileHandle)fileHandle;
- (void)stopWork:(MP4FileHandle)fileHandle;

@end

@interface NSObject (MP42MuxerDelegateMethod)
- (void)progressStatus: (CGFloat)progress;

@end