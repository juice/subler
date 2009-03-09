//
//  PropertyViewController.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MP42VideoTrack.h"


@interface VideoViewController : NSViewController {
    MP42VideoTrack *track;
    
    IBOutlet NSTextField *sampleWidth;
    IBOutlet NSTextField *sampleHeight;
    
    IBOutlet NSTextField *trackWidth;
    IBOutlet NSTextField *trackHeight;
    
    IBOutlet NSTextField *offsetX;
    IBOutlet NSTextField *offsetY;
}

- (void) setTrack:(MP42VideoTrack *) videoTrack;

@end
