//
//  ChapsUtilities.h
//  Subler
//
//  Created by Damiano Galassi on 17/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "mp4v2.h"

@interface SBChapter : NSObject {
    MP4Duration duration;
    NSString *title;
}

@property(readwrite, retain) NSString *title;
@property(readwrite) MP4Duration duration;

@end;

void LoadChaptersFromPath(NSString *path, NSMutableArray *ss);
