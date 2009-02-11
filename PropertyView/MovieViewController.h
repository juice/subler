//
//  MovieViewController.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MP4FileWrapper.h"


@interface MovieViewController : NSViewController {
    MP4FileWrapper          *mp4File;
    IBOutlet NSPopUpButton  *tagList;
    IBOutlet NSTableView    *tagsTableView;
    IBOutlet NSImageView    *imageView;
    
    IBOutlet NSButton       *removeTag;
    NSDictionary* detailBoldAttr;
}

- (void) setFile: (MP4FileWrapper *)file;
- (IBAction) addTag: (id) sender;
- (IBAction) removeTag: (id) sender;

@end
