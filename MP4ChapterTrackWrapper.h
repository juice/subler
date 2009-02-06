//
//  MP4ChapterTrackWrapper.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MP4TrackWrapper.h"

@interface MP4ChapterTrackWrapper : MP4TrackWrapper {
    NSMutableArray *chapters;
}
-(id)initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID;

@property (readonly) NSMutableArray * chapters;


@end
