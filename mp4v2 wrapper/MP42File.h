//
//  MP42File.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "mp4v2.h"
#import "MP42Track.h"
#import "MP42SubtitleTrack.h"
#import "MP42ChapterTrack.h"
#import "MP42Metadata.h"

@interface MP42File : NSObject {

    MP4FileHandle  fileHandle;
    NSString      *filePath;

    NSMutableArray  *tracks;
    NSMutableArray  *tracksToBeDeleted;
    MP42Metadata    *metadata;

    id delegate;
}

@property(readonly) NSMutableArray *tracks;
@property(readonly) MP42Metadata    *metadata;

- (id)   initWithExistingFile:(NSString *) path andDelegate:(id) del;
- (int)  tracksCount;
- (id)   trackAtIndex:(NSUInteger) index;
- (void) addTrack:(id) track;
- (void) removeTrackAtIndex:(NSUInteger) index;

- (BOOL) writeToFile;
- (void) optimize;

@end

@interface NSObject (MP42FileDelegateMethod)
- (void)optimizeDidComplete;

@end
