//
//  MyDocument.h
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright __MyCompanyName__ 2009 . All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MP42File;
@class FileImport;

@interface MyDocument : NSDocument
{
    MP42File  *mp4File;

    IBOutlet NSTextField    *subtitleFilePath;
    IBOutlet NSTextField    *label;

    IBOutlet NSTableView    *fileTracksTable;
    IBOutlet NSWindow       *addSubtitleWindow;
    IBOutlet NSWindow       *savingWindow;
    IBOutlet NSWindow       *documentWindow;

    IBOutlet NSPopUpButton  *langSelection;
    IBOutlet NSTextField    *delay;
    IBOutlet NSTextField    *trackHeight;
    IBOutlet NSButton       *addTrack;

    IBOutlet NSToolbarItem  *addTrackToolBar;
    IBOutlet NSToolbarItem  *deleteTrack;

    NSMutableArray          *languages;

    NSViewController        *propertyView;
    IBOutlet NSView         *targetView;
    FileImport              *importWindow;

    IBOutlet NSProgressIndicator *optBar;
}

- (IBAction) showSubititleWindow: (id) sender;
- (IBAction) closeSheet: (id) sender;
- (IBAction) openBrowse: (id) sender;
- (IBAction) addSubtitleTrack: (id) sender;
- (IBAction) selectChapterFile: (id) sender;
- (IBAction) selectFile: (id) sender;
- (IBAction) deleteTrack: (id) sender;

@end
