//
//  MP4FileWrapper.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "mp4v2.h"
#import "MP4TrackWrapper.h"
#import "MP4SubtitleTrackWrapper.h"
#import "MP4ChapterTrackWrapper.h"
#import "MP4Metadata.h"

@interface MP4FileWrapper : NSObject {

    MP4FileHandle fileHandle;
    NSString       *filePath;
    
    NSMutableArray  *tracksArray;
    NSMutableArray  *tracksToBeDeleted;
    MP4Metadata     *metadata;
    
    id delegate;
}

@property (readonly) NSMutableArray *tracksArray;
@property (readonly) NSMutableArray *tracksToBeDeleted;
@property (readonly) MP4Metadata    *metadata;

- (id)initWithExistingMP4File:(NSString *)mp4File andDelegate:(id)del;
- (int)tracksCount;
- (id)trackAtIndex:(NSUInteger) index;
- (BOOL) writeToFile;
- (void) optimize;
- (BOOL) muxSubtitleTrack: (MP4SubtitleTrackWrapper*) track;
- (BOOL) muxChapterTrack: (MP4ChapterTrackWrapper*) track;
- (BOOL) deleteSubtitleTrack: (MP4TrackWrapper *)track;
- (BOOL) updateTrackLanguage: (MP4TrackWrapper*) track;
- (BOOL) updateTrackName: (MP4TrackWrapper*) track;

@end

@interface NSObject (MP4FileWrapperDelegateMethod) 
- (void)optimizeDidComplete; 

@end 
