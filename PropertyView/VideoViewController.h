//
//  PropertyViewController.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface VideoViewController : NSViewController {
    IBOutlet NSTextField *sampleWidth;
    IBOutlet NSTextField *sampleHeight;
    
    IBOutlet NSTextField *trackWidth;
    IBOutlet NSTextField *trackHeight;
    
    IBOutlet NSTextField *offsetX;
    IBOutlet NSTextField *offsetY;
}

@end
