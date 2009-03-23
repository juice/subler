//
//  ChapterViewController.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MP42File.h"
#import "MP42ChapterTrack.h"

@interface ChapterViewController : NSViewController {
    MP42ChapterTrack *track;
    
    NSDictionary* detailBoldAttr;
}

- (void) setTrack:(MP42ChapterTrack *)track;

@end
