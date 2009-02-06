//
//  ChapterViewController.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MP4FileWrapper.h"
#import "MP4ChapterTrackWrapper.h"

@interface ChapterViewController : NSViewController {
    MP4FileWrapper  *mp4File;
    MP4ChapterTrackWrapper *track;
    
}

- (void) setFile: (MP4FileWrapper *)mp4File andTrack:(MP4ChapterTrackWrapper *)track;

@end
