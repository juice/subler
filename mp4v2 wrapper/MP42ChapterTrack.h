//
//  MP42ChapterTrack.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42Track.h"

@interface MP42ChapterTrack : MP42Track {
    NSMutableArray *chapters;
}
- (id) initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID;
+ (id) chapterTrackFromFile:(NSString *)filePath;

@property (readwrite, retain) NSMutableArray * chapters;

@end
