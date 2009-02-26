//
//  MovieViewController.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MP42File.h"


@interface MovieViewController : NSViewController {
    MP42File          *mp4File;
    IBOutlet NSPopUpButton  *tagList;
    IBOutlet NSTableView    *tagsTableView;

    IBOutlet NSImageView    *imageView;
    IBOutlet NSPopUpButton  *mediaKind;
    IBOutlet NSPopUpButton  *contentRating;
    IBOutlet NSButton       *hdVideo;
    IBOutlet NSButton       *gapless;
    
    IBOutlet NSButton       *removeTag;
    NSDictionary            *detailBoldAttr;
}

- (void) setFile: (MP42File *)file;
- (IBAction) addTag: (id) sender;
- (IBAction) removeTag: (id) sender;

- (IBAction) updateArtwork: (id) sender;

- (IBAction) changeMediaKind: (id) sender;
- (IBAction) changeGapless: (id) sender;
- (IBAction) changehdVideo: (id) sender;


@end
