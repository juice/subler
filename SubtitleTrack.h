//
//  SubtitleTrack.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SubtitleTrack : NSObject {
    int trackId;
    int delay;
    NSString *filePath;
    NSString *language;
}

@property (readwrite) int trackId;
@property (readwrite) int delay;
@property (readwrite, retain) NSString *filePath;
@property (readwrite, retain) NSString *language;

@end
