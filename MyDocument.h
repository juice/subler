//
//  MyDocument.h
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright Damiano Galassi 2009 . All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MP42File;
@class MP4FileImport;

@interface MyDocument : NSDocument
{
    MP42File  *mp4File;

    IBOutlet NSWindow       *documentWindow;

    IBOutlet NSTableView    *fileTracksTable;

    IBOutlet NSWindow       *savingWindow;
    IBOutlet NSTextField    *saveOperationName;

    IBOutlet NSTextField    *subtitleFilePath;
    IBOutlet NSTextField    *label;    
    IBOutlet NSWindow       *addSubtitleWindow;
    IBOutlet NSPopUpButton  *langSelection;
    IBOutlet NSTextField    *delay;
    IBOutlet NSTextField    *trackHeight;
    IBOutlet NSButton       *addTrack;

    IBOutlet NSToolbarItem  *addTrackToolBar;
    IBOutlet NSToolbarItem  *deleteTrack;

    NSMutableArray          *languages;

    NSViewController        *propertyView;
    IBOutlet NSView         *targetView;
    id                      importWindow;

    IBOutlet NSView         *saveView;
    IBOutlet NSProgressIndicator *optBar;
    
    BOOL _64bit_data;
    BOOL _64bit_time;
    BOOL _optimize;
}

- (IBAction) showSubititleWindow: (id) sender;
- (IBAction) closeSheet: (id) sender;
- (IBAction) openBrowse: (id) sender;
- (IBAction) addSubtitleTrack: (id) sender;
- (IBAction) selectChapterFile: (id) sender;
- (IBAction) selectFile: (id) sender;
- (IBAction) deleteTrack: (id) sender;

- (IBAction) set64bit_data: (id) sender;
- (IBAction) set64bit_time: (id) sender;

@end
