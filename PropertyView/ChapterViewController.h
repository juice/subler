//
//  ChapterViewController.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MP42File.h"
#import "MP42ChapterTrack.h"

@interface ChapterViewController : NSViewController {
    MP42File  *mp4File;
    MP42ChapterTrack *track;
    
    NSDictionary* detailBoldAttr;
}

- (void) setFile: (MP42File *)file andTrack:(MP42ChapterTrack *)track;

@end
