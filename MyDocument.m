//
//  MyDocument.m
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright __MyCompanyName__ 2009 . All rights reserved.
//

#import "MyDocument.h"
#import "MP42File.h"
#import "EmptyViewController.h"
#import "MovieViewController.h"
#import "VideoViewController.h"
#import "ChapterViewController.h"
#import "MP4FileImport.h"
#import "MovFileImport.h"

@implementation MyDocument

- (id)init
{
    self = [super init];
    if (self) {
    
        // Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
    }
    return self;
}

- (NSString *)windowNibName
{
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];

    languages = [[NSArray arrayWithObjects:  @"Unknown", @"English", @"French", @"German" , @"Italian", @"Dutch", @"Swedish" , @"Spanish" , @"Danish" , @"Portuguese", @"Norwegian", @"Hebrew", @"Japanese", @"Arabic", @"Finnish", @"Greek", @"Icelandic", @"Maltese", @"Turkish", @"Croatian", @"Chinese", @"Urdu", @"Hindi", @"Thai", @"Korean", @"Lithuanian", @"Polish", @"Hungarian", @"Estonian", @"Latvian", @"Northern Sami", @"Faroese", @"Persian", @"Russian", @"Irish", @"Albanian", @"Czech", @"Slovak", @"Slovenian", nil] retain];

    [langSelection addItemsWithTitles:languages];
    [langSelection selectItemWithTitle:@"English"];
    
    MovieViewController *controller = [[MovieViewController alloc] initWithNibName:@"MovieView" bundle:nil];
    [controller setFile:mp4File];
    if (controller !=nil){
        propertyView = controller;
        [[propertyView view] setAutoresizingMask:( NSViewWidthSizable | NSViewHeightSizable )];
        [[propertyView view] setFrame:[targetView bounds]];
        [targetView addSubview: [propertyView view]];
    }

    [documentWindow registerForDraggedTypes:[NSArray arrayWithObjects:
                                   NSColorPboardType, NSFilenamesPboardType, nil]];
}

- (void) reloadFile: (id) sender
{
    MP42File *newFile = [[MP42File alloc] initWithExistingFile:[[self fileURL] path] andDelegate:self];
    [mp4File autorelease];
    mp4File = newFile;
    [fileTracksTable reloadData];
    [self tableViewSelectionDidChange:nil];
}

- (BOOL)writeSafelyToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName 
        forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError;
{
    BOOL success = NO;

	switch (saveOperation)
	{
		case NSSaveOperation:
		{
            // movie file already exists, so we'll just update
            // the movie resource
            success = [mp4File updateMP4File:outError];
            if (!success && outError)
                [self presentError:*outError
                    modalForWindow:documentWindow
                          delegate:nil
                didPresentSelector:NULL
                       contextInfo:NULL];
            else
                [self reloadFile:self];
            
            NSDictionary *fileAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithUnsignedInt:'M4V '], NSFileHFSTypeCode,
                                            [NSNumber numberWithUnsignedInt:0], NSFileHFSCreatorCode,
                                            nil];
            
            [[NSFileManager defaultManager] changeFileAttributes:fileAttributes atPath:[absoluteURL path]];
            [self setFileURL:absoluteURL];
            [self setFileModificationDate:[[[NSFileManager defaultManager]  
                                            fileAttributesAtPath:[absoluteURL path] traverseLink:YES]  
                                           fileModificationDate]];
		}
            break;

		case NSSaveAsOperation:
		case NSSaveToOperation:
            // not implemented
            return NO;
            break;
	}

    return success;
}

- (void) saveAndOptimize: (id)sender
{
    if ([self isDocumentEdited])
        [self saveDocument:sender];

    [optBar startAnimation:sender];

    [NSApp beginSheet:savingWindow modalForWindow:documentWindow
        modalDelegate:nil didEndSelector:NULL contextInfo:nil];

    [mp4File optimize];
}

- (void) optimizeDidComplete
{
    [self reloadFile:self];

    [self setFileURL: [self fileURL]];
    [self setFileModificationDate:[[[NSFileManager defaultManager]  
                                    fileAttributesAtPath:[[self fileURL] path] traverseLink:YES]  
                                   fileModificationDate]];

    [NSApp endSheet: savingWindow];
    [savingWindow orderOut:self];

    [optBar stopAnimation:nil];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    mp4File = [[MP42File alloc] initWithExistingFile:[absoluteURL path] andDelegate:self];

    if ( outError != NULL && !mp4File ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];

        return NO;
	}

    return YES;
}

- (BOOL)revertToContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    [mp4File release];
    mp4File = [[MP42File alloc] initWithExistingFile:[absoluteURL path] andDelegate:self];

    [fileTracksTable reloadData];
    [self tableViewSelectionDidChange:nil];
    [self updateChangeCount:NSChangeCleared];

    if ( outError != NULL && !mp4File ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];   
        
        return NO;
	}
    return YES;
}

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem
{
    SEL action = [anItem action];

    if (action == @selector(saveDocument:))
        if ([self isDocumentEdited])
            return YES;

    if (action == @selector(revertDocumentToSaved:))
        if ([self isDocumentEdited])
            return YES;

    if (action == @selector(saveAndOptimize:))
            return YES;

    if (action == @selector(showSubititleWindow:))
            return YES;

    if (action == @selector(selectChapterFile:))
        return YES;
    
    if (action == @selector(selectMetadataFile:))
        return YES;

    if (action == @selector(selectFile:))
        return YES;

    if (action == @selector(deleteTrack:))
        return YES;

    return NO;
}

- (BOOL)validateToolbarItem: (NSToolbarItem *) toolbarItem
{
    if (toolbarItem == addTrackToolBar)
            return YES;

    else if (toolbarItem == deleteTrack)
        if ([fileTracksTable selectedRow] != -1 && [NSApp isActive])
                //[[toolbarItem view] setEnabled:NO];
                return YES;

    return NO;
}

// Tableview datasource methods
- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    if( !mp4File )
        return 0;
    
    return [mp4File tracksCount];
}

- (id) tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
    MP42Track *track = [mp4File trackAtIndex:rowIndex];

    if (!track)
        return nil;

    if ([tableColumn.identifier isEqualToString:@"trackId"]) {
        if (track.Id == 0)
            return @"na";
        else
            return [NSString stringWithFormat:@"%d", track.Id];
    }

    if ([tableColumn.identifier isEqualToString:@"trackName"])
        return track.name;

    if ([tableColumn.identifier isEqualToString:@"trackInfo"])
        return track.format;

    if ([tableColumn.identifier isEqualToString:@"trackDuration"])
        return [track SMPTETimeString];

    if ([tableColumn.identifier isEqualToString:@"trackLanguage"])
        return track.language;

    return nil;
}

- (void) tableView: (NSTableView *) tableView 
    setObjectValue: (id) anObject 
    forTableColumn: (NSTableColumn *) tableColumn 
               row: (NSInteger) rowIndex
{
    MP42Track *track = [mp4File trackAtIndex:rowIndex];
    
    if ([tableColumn.identifier isEqualToString:@"trackLanguage"]) {
        if (![track.language isEqualToString:anObject]) {
            track.language = anObject;
            track.isEdited = YES;
            [self updateChangeCount:NSChangeDone];
        }
    }
    if ([tableColumn.identifier isEqualToString:@"trackName"]) {
        if (![track.name isEqualToString:anObject]) {
            track.name = anObject;
            track.isEdited = YES;
            [self updateChangeCount:NSChangeDone];
        }
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    if ([propertyView view] != nil)
		[[propertyView view] removeFromSuperview];	// remove the current view

	if (propertyView != nil)
		[propertyView release];		// remove the current view controller

    NSInteger row = [fileTracksTable selectedRow];
    if (row == -1)
    {
        MovieViewController *controller = [[MovieViewController alloc] initWithNibName:@"MovieView" bundle:nil];
        [controller setFile:mp4File];
        if (controller !=nil)
            propertyView = controller;
    }
    else if (row != -1 && [[mp4File trackAtIndex:row] isMemberOfClass:[MP42ChapterTrack class]])
    {
        ChapterViewController *controller = [[ChapterViewController alloc] initWithNibName:@"ChapterView" bundle:nil];
        [controller setTrack:[mp4File trackAtIndex:row]];
        if (controller !=nil)
            propertyView = controller;
    }
    else if (row != -1 && [[mp4File trackAtIndex:row] isKindOfClass:[MP42VideoTrack class]])
    {
        VideoViewController *controller = [[VideoViewController alloc] initWithNibName:@"VideoView" bundle:nil];
        [controller setTrack:[mp4File trackAtIndex:row]];
        if (controller !=nil)
            propertyView = controller;
    }
    else
    {
        EmptyViewController *controller = [[EmptyViewController alloc] initWithNibName:@"EmptyView" bundle:nil];
        if (controller !=nil)
                propertyView = controller;
    }

    // embed the current view to our host view
	[targetView addSubview: [propertyView view]];

	// make sure we automatically resize the controller's view to the current window size
	[[propertyView view] setFrame: [targetView bounds]];
    [[propertyView view] setAutoresizingMask:( NSViewWidthSizable | NSViewHeightSizable )];
}

/* NSComboBoxCell dataSource */

- (NSInteger)numberOfItemsInComboBoxCell:(NSComboBoxCell *)comboBoxCell
{
    return [languages count];
}

- (id)comboBoxCell:(NSComboBoxCell *)comboBoxCell objectValueForItemAtIndex:(NSInteger)index {
    return [languages objectAtIndex:index];
}

- (NSUInteger)comboBoxCell:(NSComboBoxCell *)comboBoxCell indexOfItemWithStringValue:(NSString *)string {
    return [languages indexOfObject: string];
}

/* Select chapter file */

- (void) addChapterTrack: (NSString *) path
{
    [mp4File addTrack:[MP42ChapterTrack chapterTrackFromFile:path]];

    [fileTracksTable reloadData];
    [self updateChangeCount:NSChangeDone];
}

- (IBAction) selectChapterFile: (id) sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = YES;

    [panel beginSheetForDirectory: nil file: nil types: [NSArray arrayWithObject:@"txt"]
                   modalForWindow: documentWindow modalDelegate: self
                   didEndSelector: @selector( selectChapterFileDidEnd:returnCode:contextInfo: )
                      contextInfo: nil];                                                      
}

- (void) selectChapterFileDidEnd: (NSOpenPanel *) sheet returnCode: (NSInteger)
returnCode contextInfo: (void *) contextInfo
{
    if (returnCode != NSOKButton)
        return;

    [self addChapterTrack:[sheet.filenames objectAtIndex: 0]];
}

/* Subtitle methods */

- (IBAction) showSubititleWindow: (id) sender;
{
    [NSApp beginSheet:addSubtitleWindow modalForWindow:documentWindow
        modalDelegate:nil didEndSelector:NULL contextInfo:nil];
}

- (IBAction) openBrowse: (id) sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = YES;

    [panel beginSheetForDirectory: nil file: nil types: [NSArray arrayWithObjects:@"srt", nil]
                   modalForWindow: addSubtitleWindow modalDelegate: self
                   didEndSelector: @selector( openBrowseDidEnd:returnCode:contextInfo: )
                      contextInfo: nil];                                                      
}

- (void) openBrowseDidEnd: (NSOpenPanel *) sheet returnCode: (NSInteger)
returnCode contextInfo: (void *) contextInfo
{
    if( returnCode != NSOKButton ) {
        if ([subtitleFilePath stringValue] == nil)
            [addTrack setEnabled:NO];
        return;
    }

    [subtitleFilePath setStringValue: [sheet.filenames objectAtIndex: 0]];
    [langSelection selectItemWithTitle:getFilenameLanguage((CFStringRef)[sheet.filenames objectAtIndex: 0])];
    [addTrack setEnabled:YES];
}

- (IBAction) closeSheet: (id) sender
{
    [NSApp endSheet: addSubtitleWindow];
    [addSubtitleWindow orderOut:self];
}

- (void) addSubtitleTrack:(NSString *)filePath
                    delay:(int)subDelay
                   height:(unsigned int)subHeight
                 language:(NSString *)subLanguage

{
    [mp4File addTrack:[MP42SubtitleTrack subtitleTrackFromFile:filePath
                                                         delay:subDelay
                                                        height:subHeight
                                                      language:subLanguage]];

    [fileTracksTable reloadData];
    [self updateChangeCount:NSChangeDone];

    [NSApp endSheet: addSubtitleWindow];
    [addSubtitleWindow orderOut:self];
}

- (IBAction) addSubtitleTrack: (id) sender
{
    [self addSubtitleTrack:[subtitleFilePath stringValue]
                     delay:[[delay stringValue] integerValue]
                    height:[[trackHeight stringValue] integerValue]
                  language:[[langSelection selectedItem] title]];
}

- (IBAction) deleteTrack: (id) sender
{
    if ([fileTracksTable selectedRow] == -1)
        return;

    [mp4File removeTrackAtIndex:[fileTracksTable selectedRow]];

    [fileTracksTable reloadData];
    [self updateChangeCount:NSChangeDone];
}

// Import tracks from mp4 file

- (IBAction) selectFile: (id) sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = YES;

    [panel beginSheetForDirectory: nil file: nil types: [NSArray arrayWithObjects:@"mp4", @"m4v", @"m4a", @"mov", nil]
                   modalForWindow: documentWindow modalDelegate: self
                   didEndSelector: @selector( selectFileDidEnd:returnCode:contextInfo: )
                      contextInfo: nil];                                                      
}

- (void) selectFileDidEnd: (NSOpenPanel *) sheet returnCode: (NSInteger)
returnCode contextInfo: (void *) contextInfo
{
    if (returnCode != NSOKButton)
        return;

    [self performSelectorOnMainThread:@selector(showImportSheet:) withObject:[sheet.filenames objectAtIndex: 0] waitUntilDone: NO];
}

- (void) showImportSheet: (NSString *) filePath
{
    if ([[filePath pathExtension] isEqualToString:@"mov"])
        importWindow = [[MovFileImport alloc] initWithDelegate:self andFile:filePath];
    else
        importWindow = [[MP4FileImport alloc] initWithDelegate:self andFile:filePath];

    [NSApp beginSheet:[importWindow window] modalForWindow:documentWindow
        modalDelegate:nil didEndSelector:NULL contextInfo:nil];
}

- (void) importDone: (NSArray*) tracksToBeImported
{
    if (tracksToBeImported) {
        for (id track in tracksToBeImported)
            [mp4File addTrack:track];

        [self updateChangeCount:NSChangeDone];
        [fileTracksTable reloadData];
    }

    [NSApp endSheet:[importWindow window]];
    [[importWindow window] orderOut:self];
    [importWindow release];
}

- (void) addMetadata: (NSString *) path
{
    MP42File *file = [[MP42File alloc] initWithExistingFile:path andDelegate:self];
    [mp4File.metadata mergeMetadata:file.metadata];

    [self tableViewSelectionDidChange:nil];
    [self updateChangeCount:NSChangeDone];
    [file release];
}

- (IBAction) selectMetadataFile: (id) sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = YES;
    
    [panel beginSheetForDirectory: nil file: nil types: [NSArray arrayWithObjects:@"mp4", @"m4v", @"m4a", nil]
                   modalForWindow: documentWindow modalDelegate: self
                   didEndSelector: @selector( selectMetadataFileDidEnd:returnCode:contextInfo: )
                      contextInfo: nil];                                                      
}

- (void) selectMetadataFileDidEnd: (NSOpenPanel *) sheet returnCode: (NSInteger)
returnCode contextInfo: (void *) contextInfo
{
    if (returnCode != NSOKButton)
        return;
    
    [self addMetadata:[sheet.filenames objectAtIndex: 0]];

}
// Drag & Drop

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];

    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
         if (sourceDragMask & NSDragOperationCopy) {
            return NSDragOperationCopy;
         }
    }
    return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];

    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        for (NSString * file in files)
        {
            if ([[file pathExtension] caseInsensitiveCompare: @"txt"] == NSOrderedSame)
                [self addChapterTrack:file];
            else if ([[file pathExtension] caseInsensitiveCompare: @"srt"] == NSOrderedSame)
                [self addSubtitleTrack:file
                                 delay:0
                                height:60
                              language:getFilenameLanguage((CFStringRef)file)];
            else if ([[file pathExtension] caseInsensitiveCompare: @"m4v"] == NSOrderedSame ||
                     [[file pathExtension] caseInsensitiveCompare: @"mp4"] == NSOrderedSame ||
                     [[file pathExtension] caseInsensitiveCompare: @"m4a"] == NSOrderedSame ||
                     [[file pathExtension] caseInsensitiveCompare: @"mov"] == NSOrderedSame)
                [self showImportSheet:file];
        }
        return YES;
    }
    return NO;
}

-(void) dealloc
{
    [propertyView release];
    [mp4File release];
    [languages release];
    [super dealloc];
}

@end
