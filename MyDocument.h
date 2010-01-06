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

    NSSavePanel                     *_currentSavePanel;
    IBOutlet NSView                 *saveView;
    IBOutlet NSPopUpButton          *fileFormat;
    IBOutlet NSProgressIndicator    *optBar;

    IBOutlet NSToolbarItem  *addTracks;
    IBOutlet NSToolbarItem  *deleteTrack;
    IBOutlet NSToolbarItem  *searchMetadata;

    NSMutableArray          *languages;

    NSViewController        *propertyView;
    IBOutlet NSView         *targetView;
    id                      importWindow;

    IBOutlet NSWindow       *addSubtitleWindow;
    IBOutlet NSPopUpButton  *langSelection;
    IBOutlet NSTextField    *delay;
    IBOutlet NSTextField    *trackHeight;
    NSString                *subtitleFilePath;
    
    
    IBOutlet NSButton *cancelSave;
    BOOL _64bit_data;
    BOOL _64bit_time;
    BOOL _optimize;
}

- (IBAction) closeSheet: (id) sender;
- (IBAction) addSubtitleTrack: (id) sender;
- (IBAction) selectFile: (id) sender;
- (IBAction) deleteTrack: (id) sender;
- (IBAction) searchMetadata: (id) sender;

- (IBAction) setSaveFormat: (id) sender;
- (IBAction) set64bit_data: (id) sender;
- (IBAction) set64bit_time: (id) sender;
- (IBAction) cancelSaveOperation: (id) sender;

@end
