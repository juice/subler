//
//  MovieViewController.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MP42File.h"

// Custom class for capturing return key
@interface TagsTableView : NSTableView {
}
- (void)keyDown:(NSEvent *)theEvent;
@end

@interface MovieViewController : NSViewController {
    MP42Metadata            *metadata;

    IBOutlet NSPopUpButton  *tagList;
    IBOutlet TagsTableView  *tagsTableView;

    IBOutlet NSImageView    *imageView;
    IBOutlet NSPopUpButton  *mediaKind;
    IBOutlet NSPopUpButton  *contentRating;
    IBOutlet NSButton       *hdVideo;
    IBOutlet NSButton       *gapless;

    IBOutlet NSButton       *removeTag;
    
    NSDictionary    *tags;
    NSArray         *tagsArray;
    NSArray         *tagsMenu;
    NSDictionary    *detailBoldAttr;
    
    NSTableColumn *tabCol;
    CGFloat width;
}

- (void) setFile: (MP42File *)file;
- (IBAction) addTag: (id) sender;
- (IBAction) removeTag: (id) sender;

- (IBAction) updateArtwork: (id) sender;

- (IBAction) changeMediaKind: (id) sender;
- (IBAction) changecContentRating: (id) sender;
- (IBAction) changeGapless: (id) sender;
- (IBAction) changehdVideo: (id) sender;

@end