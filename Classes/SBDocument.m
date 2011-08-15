//
//  SBDocument.m
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright Damiano Galassi 2009 . All rights reserved.
//

#import "SBDocument.h"
#import "MP42File.h"
#import "EmptyViewController.h"
#import "MovieViewController.h"
#import "VideoViewController.h"
#import "SoundViewController.h"
#import "ChapterViewController.h"
#import "FileImport.h"
#import "VideoFramerate.h"
#import "MetadataSearchController.h"
#import "ArtworkSelector.h"

#define SublerTableViewDataType @"SublerTableViewDataType"

@implementation SBDocument

@synthesize languages;

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
    return @"SBDocument";
}

- (void)awakeFromNib
{
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"rememberWindowSize"] integerValue]) {
        [documentWindow setFrameAutosaveName:@"documentSave"];
        [documentWindow setFrameUsingName:@"documentSave"];
        [splitView setAutosaveName:@"splitViewSave"];
    }
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];

    languages = [[NSArray arrayWithObjects:  @"Unknown", @"English", @"French", @"German" , @"Italian", @"Dutch",
				  @"Swedish" , @"Spanish" , @"Danish" , @"Portuguese", @"Norwegian", @"Hebrew",
				  @"Japanese", @"Arabic", @"Finnish", @"Greek, Modern", @"Icelandic", @"Maltese", @"Turkish",
				  @"Croatian", @"Chinese", @"Urdu", @"Hindi", @"Thai", @"Korean", @"Lithuanian", @"Polish", 
				  @"Hungarian", @"Estonian", @"Latvian", @"Northern Sami", @"Faroese", @"Persian", @"Romanian", @"Russian", 
				  @"Irish", @"Albanian", @"Bulgarian", @"Czech", @"Slovak", @"Slovenian", nil] retain];

    MovieViewController *controller = [[MovieViewController alloc] initWithNibName:@"MovieView" bundle:nil];
    [controller setFile:mp4File];
    if (controller !=nil){
        propertyView = controller;
        [[propertyView view] setAutoresizingMask:( NSViewWidthSizable | NSViewHeightSizable )];
        [[propertyView view] setFrame:[targetView bounds]];
        [targetView addSubview: [propertyView view]];
    }

    [documentWindow recalculateKeyViewLoop];

    [fileTracksTable registerForDraggedTypes:[NSArray arrayWithObjects:SublerTableViewDataType, nil]];
    [documentWindow registerForDraggedTypes:[NSArray arrayWithObjects:
                                   NSColorPboardType, NSFilenamesPboardType, nil]];

    _optimize = NO;
}

- (id)initWithType:(NSString *)typeName error:(NSError **)outError
{
    mp4File = [[MP42File alloc] initWithDelegate:self];
    return [super initWithType:typeName error:outError];
}

+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)type
{
    return NO;
}

#pragma mark Read methods

- (void) reloadFile: (id) sender
{
    if ([self fileURL]) {
        MP42File *newFile = [[MP42File alloc] initWithExistingFile:[self fileURL] andDelegate:self];
        if (newFile) {
            [mp4File autorelease];
            mp4File = newFile;
            [fileTracksTable reloadData];
            [self tableViewSelectionDidChange:nil];
        }
        else
            [self close];
    }
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    mp4File = [[MP42File alloc] initWithExistingFile:absoluteURL andDelegate:self];
    
    if ( outError != NULL && !mp4File ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
        
        return NO;
	}
    
    return YES;
}

- (BOOL)revertToContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    [mp4File release];
    mp4File = [[MP42File alloc] initWithExistingFile:absoluteURL andDelegate:self];
    
    [fileTracksTable reloadData];
    [self tableViewSelectionDidChange:nil];
    [self updateChangeCount:NSChangeCleared];
    
    if ( outError != NULL && !mp4File ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];   
        
        return NO;
	}
    return YES;
}

#pragma mark Save methods

- (void) saveDidComplete: (NSError *)outError
{
    [NSApp endSheet: savingWindow];
    [savingWindow orderOut:self];

    if (outError) {
        [self presentError:outError
            modalForWindow:documentWindow
                  delegate:nil
        didPresentSelector:NULL
               contextInfo:NULL];
    }

    [self reloadFile:self];
}

- (void)saveToURL:(NSURL *)absoluteURL
		   ofType:(NSString *)typeName
 forSaveOperation:(NSSaveOperationType)saveOperation
		 delegate:(id)delegate
  didSaveSelector:(SEL)didSaveSelector
	  contextInfo:(void *)contextInfo
{
    __block NSError	 *outError;

    [optBar setIndeterminate:YES];
    [optBar startAnimation:nil];
    [saveOperationName setStringValue:@"Saving…"];
    [NSApp beginSheet:savingWindow modalForWindow:documentWindow
        modalDelegate:nil didEndSelector:NULL contextInfo:nil];

    [documentWindow setTitle:[[absoluteURL path] lastPathComponent]];

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        BOOL success = [self saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:&outError];

        [self setFileURL:absoluteURL];
        [self setFileModificationDate:[[[NSFileManager defaultManager]  
                                        attributesOfItemAtPath:[absoluteURL path] error:nil]  
                                       fileModificationDate]];
        if (success && outError)
            outError = nil;

        dispatch_async(dispatch_get_main_queue(), ^{
            [self saveDidComplete:outError];
        });
    });
}

- (BOOL)writeSafelyToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName 
        forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError;
{
    BOOL success = NO;
    NSMutableDictionary * attributes = [[NSMutableDictionary alloc] init];
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"chaptersPreviewTrack"] integerValue])
        [attributes setObject:[NSNumber numberWithBool:YES] forKey:MP42CreateChaptersPreviewTrack];

	switch (saveOperation)
	{
		case NSSaveOperation:
            // movie file already exists, so we'll just update
            // the movie resource
            success = [mp4File updateMP4FileWithAttributes:attributes error:outError];
            break;
		case NSSaveAsOperation:
            if ([_64bit_data state]) [attributes setObject:[NSNumber numberWithBool:YES] forKey:MP42Create64BitData];
            if ([_64bit_time state]) [attributes setObject:[NSNumber numberWithBool:YES] forKey:MP42Create64BitTime];
            success = [mp4File writeToUrl:absoluteURL withAttributes:attributes error:outError];
            break;
		case NSSaveToOperation:
            // not implemented
            break;
	}
    if (_optimize)
    {
        [saveOperationName setStringValue:@"Optimizing…"];
        [mp4File optimize];
        _optimize = NO;
    }
    [attributes release];
    return success;
}

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
    _currentSavePanel = savePanel;
    [savePanel setExtensionHidden:NO];
    [savePanel setAccessoryView:saveView];

    NSArray *formats = [self writableTypesForSaveOperation:NSSaveAsOperation];
    [fileFormat removeAllItems];
    for (id format in formats)
        [fileFormat addItemWithTitle:format];

    [fileFormat selectItemAtIndex:[[[NSUserDefaults standardUserDefaults] valueForKey:@"defaultSaveFormat"] integerValue]];
	if ([[NSUserDefaults standardUserDefaults] valueForKey:@"SBSaveFormat"])
		[_currentSavePanel setAllowedFileTypes:[NSArray arrayWithObject:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBSaveFormat"]]];

    NSString *filename = nil;
    for (NSUInteger i = 0; i < [mp4File tracksCount]; i++) {
        MP42Track *track = [mp4File trackAtIndex:i];
        if ([track sourceURL]) {
            filename = [[[track sourceURL] lastPathComponent] stringByDeletingPathExtension];
            break;
        }
    }
    if (filename) {
        [savePanel performSelector:@selector(setNameFieldStringValue:) withObject:filename];
    }

    return YES;
}

- (IBAction) setSaveFormat: (id) sender
{
    NSString *requiredFileType = nil;
    NSInteger index = [sender indexOfSelectedItem];
    switch (index) {
        case 0:
            requiredFileType = @"m4v";
            break;
        case 1:
            requiredFileType = @"mp4";
            break;
        case 2:
            requiredFileType = @"m4a";
            break;
        default:
            requiredFileType = @"m4v";
            break;
    }

    [_currentSavePanel setAllowedFileTypes:[NSArray arrayWithObject:requiredFileType]];
    [[NSUserDefaults standardUserDefaults] setObject:requiredFileType forKey:@"SBSaveFormat"];
}

- (IBAction) cancelSaveOperation: (id) sender {
    [cancelSave setEnabled:NO];
    [mp4File cancel];
}

- (IBAction) saveAndOptimize: (id)sender
{
    _optimize = YES;
    [self saveDocument:sender];
}

- (IBAction) sendToExternalApp: (id) sender {        
    /* send to itunes after save */
    NSAppleScript *myScript = [[NSAppleScript alloc] initWithSource: [NSString stringWithFormat: @"%@%@%@", @"tell application \"iTunes\" to open (POSIX file \"", [[self fileURL] path], @"\")"]];
    [myScript executeAndReturnError: nil];
    [myScript release];
}

#pragma mark Interface validation

- (void)progressStatus: (CGFloat)progress {
    [self performSelectorOnMainThread:@selector(updateProgressBar:)
                           withObject:[NSNumber numberWithDouble:progress] waitUntilDone: NO];

}

- (void)updateProgressBar: (NSNumber *)progress {
    [optBar setIndeterminate:NO];
    [optBar setDoubleValue:[progress doubleValue]];
}

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem
{
    SEL action = [anItem action];

    if (action == @selector(saveDocument:))
        if ([self isDocumentEdited])
            return YES;

    if (action == @selector(saveDocumentAs:))
        return YES;
    
    if (action == @selector(revertDocumentToSaved:))
        if ([self isDocumentEdited])
            return YES;

    if (action == @selector(saveAndOptimize:))
        if (![self isDocumentEdited] && [mp4File hasFileRepresentation])
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

    if (action == @selector(searchMetadata:))
        return YES;

    if (action == @selector(sendToExternalApp:))
        return YES;

    if (action == @selector(showTrackOffsetSheet:) && [fileTracksTable selectedRow] != -1)
        return YES;

    if (action == @selector(addChaptersEvery:))
        return YES;

	if (action == @selector(export:) && [fileTracksTable selectedRow] != -1)
		if ([[mp4File trackAtIndex:[fileTracksTable selectedRow]] respondsToSelector:@selector(exportToURL:error:)])
			return YES;

    return NO;
}

- (BOOL)validateToolbarItem: (NSToolbarItem *) toolbarItem
{
    if (toolbarItem == addTracks)
            return YES;

    else if (toolbarItem == deleteTrack)
        if ([fileTracksTable selectedRow] != -1 && [NSApp isActive])
                return YES;

    if (toolbarItem == searchMetadata)
        return YES;

    return NO;
}

#pragma mark table datasource

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
        if ([track Id] == 0)
            return @"na";
        else
            return [NSString stringWithFormat:@"%d", [track Id]];
    }

    if ([tableColumn.identifier isEqualToString:@"trackName"])
        return [track name];

    if ([tableColumn.identifier isEqualToString:@"trackInfo"])
        return [track formatSummary];

    if ([tableColumn.identifier isEqualToString:@"trackEnabled"])
        return [NSNumber numberWithInteger:[track enabled]];

    if ([tableColumn.identifier isEqualToString:@"trackDuration"])
        return [track timeString];

    if ([tableColumn.identifier isEqualToString:@"trackLanguage"])
        return [track language];

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
            [self updateChangeCount:NSChangeDone];
        }
    }
    else if ([tableColumn.identifier isEqualToString:@"trackName"]) {
        if (![track.name isEqualToString:anObject]) {
            track.name = anObject;
            [self updateChangeCount:NSChangeDone];
        }
    }
    else if ([tableColumn.identifier isEqualToString:@"trackEnabled"]) {
        if (!(track.enabled  == [anObject integerValue])) {
            track.enabled = [anObject integerValue];
            [self updateChangeCount:NSChangeDone];
        }
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    if ([propertyView view] != nil)
		[[propertyView view] removeFromSuperview];	// remove the current view

    [[self undoManager] removeAllActionsWithTarget:propertyView];  // remove the undo items from the dealloced view

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
    else if (row != -1 && [[mp4File trackAtIndex:row] isKindOfClass:[MP42AudioTrack class]])
    {
        SoundViewController *controller = [[SoundViewController alloc] initWithNibName:@"SoundView" bundle:nil];
        [controller setTrack:[mp4File trackAtIndex:row]];
        [controller setFile:mp4File];
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
    [documentWindow recalculateKeyViewLoop];

	// make sure we automatically resize the controller's view to the current window size
	[[propertyView view] setFrame: [targetView bounds]];
    [[propertyView view] setAutoresizingMask:( NSViewWidthSizable | NSViewHeightSizable )];
}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
    // Copy the row numbers to the pasteboard.
    if ([[mp4File trackAtIndex:[rowIndexes firstIndex]] muxed])
        return NO;

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pboard declareTypes:[NSArray arrayWithObject:SublerTableViewDataType] owner:self];
    [pboard setData:data forType:SublerTableViewDataType];
    return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv
                validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)op
{
    if (op == NSTableViewDropAbove && row < [mp4File tracksCount]) {
        if(![[mp4File trackAtIndex:row] muxed])
            return NSDragOperationEvery;
    }
    else if (op == NSTableViewDropAbove && row == [mp4File tracksCount])
        return NSDragOperationEvery;

    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
              row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard* pboard = [info draggingPasteboard];
    NSData* rowData = [pboard dataForType:SublerTableViewDataType];
    NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
    NSInteger dragRow = [rowIndexes firstIndex];
    
    [mp4File moveTrackAtIndex:dragRow toIndex:row];
    [fileTracksTable reloadData];
    return YES;
}

- (BOOL)canDragRowsWithIndexes:(NSIndexSet *)rowIndexes atPoint:(NSPoint)mouseDownPoint
{
    return YES;
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

#pragma mark Various things

- (IBAction) searchMetadata: (id) sender
{
    importWindow = [[MetadataSearchController alloc] initWithDelegate:self];
    
    [NSApp beginSheet:[importWindow window] modalForWindow:documentWindow
        modalDelegate:nil didEndSelector:NULL contextInfo:nil];
}

- (IBAction) showTrackOffsetSheet: (id) sender
{
    [offset setStringValue:[NSString stringWithFormat:@"%d",
                            [[[mp4File tracks] objectAtIndex:[fileTracksTable selectedRow]] startOffset]]];

    [NSApp beginSheet:offsetWindow modalForWindow:documentWindow
        modalDelegate:nil didEndSelector:NULL contextInfo:nil];
}

- (IBAction) setTrackOffset: (id) sender
{
    MP42Track *selectedTrack = [[mp4File tracks] objectAtIndex:[fileTracksTable selectedRow]];
    [selectedTrack setStartOffset:[offset integerValue]];

    [self updateChangeCount:NSChangeDone];

    [NSApp endSheet: offsetWindow];
    [offsetWindow orderOut:self];
}

- (IBAction) closeOffsetSheet: (id) sender
{
    [NSApp endSheet: offsetWindow];
    [offsetWindow orderOut:self];
}

- (IBAction) deleteTrack: (id) sender
{
    if ([fileTracksTable selectedRow] == -1  || [fileTracksTable editedRow] != -1)
        return;

    [mp4File removeTrackAtIndex:[fileTracksTable selectedRow]];

    [fileTracksTable reloadData];
    [self updateChangeCount:NSChangeDone];
}

// Import tracks from file

- (void) addChapterTrack: (NSURL *) fileURL
{
    [mp4File addTrack:[MP42ChapterTrack chapterTrackFromFile:fileURL]];

    [fileTracksTable reloadData];
    [self tableViewSelectionDidChange:nil];
    [self updateChangeCount:NSChangeDone];
}

- (IBAction) selectFile: (id) sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"mp4", @"m4v", @"m4a", @"mov",
                                @"aac", @"h264", @"264", @"ac3",
                                @"txt", @"srt", @"smi", @"scc", @"mkv", nil]];

    [panel beginSheetModalForWindow:documentWindow completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSString *fileExtension = [[panel.URLs objectAtIndex: 0] pathExtension];

            if ([fileExtension caseInsensitiveCompare: @"txt"] == NSOrderedSame)
                [self addChapterTrack:[panel.URLs objectAtIndex: 0]];
            else
                [self performSelectorOnMainThread:@selector(showImportSheet:)
                                       withObject:[panel.URLs objectAtIndex: 0] waitUntilDone: NO];
        }
    }];
}

- (void) showImportSheet: (NSURL *) fileURL
{
    NSError *error = nil;

    if ([[fileURL pathExtension] isEqualToString:@"h264"] || [[fileURL pathExtension] isEqualToString:@"264"])
        importWindow = [[VideoFramerate alloc] initWithDelegate:self andFile:fileURL];
    else
		importWindow = [[FileImport alloc] initWithDelegate:self andFile:fileURL error:&error];

    if (importWindow) {
        [NSApp beginSheet:[importWindow window] modalForWindow:documentWindow
            modalDelegate:nil didEndSelector:NULL contextInfo:nil];
    }
    else {
        //[self presentError:error];
        if (error)
            [self presentError:error modalForWindow:documentWindow delegate:nil didPresentSelector:NULL contextInfo:nil];
    }
}

- (void) importDoneWithTracks: (NSArray*) tracksToBeImported andMetadata: (MP42Metadata*) metadata
{
    if (tracksToBeImported) {
        for (id track in tracksToBeImported)
            [mp4File addTrack:track];

        [self updateChangeCount:NSChangeDone];
        [fileTracksTable reloadData];
    }
    
    if (metadata) {
        [mp4File.metadata mergeMetadata:metadata];
        [self tableViewSelectionDidChange:nil];
        [self updateChangeCount:NSChangeDone];
    }

    [NSApp endSheet:[importWindow window]];
    [[importWindow window] orderOut:self];
    [importWindow release], importWindow = nil;
}

- (void) metadataImportDone: (MP42Metadata*) metadataToBeImported
{
    if (metadataToBeImported) {
        [mp4File.metadata mergeMetadata:metadataToBeImported];
        [self tableViewSelectionDidChange:nil];
        [self updateChangeCount:NSChangeDone];
        for (MP42Track *track in mp4File.tracks)
            if ([track isKindOfClass:[MP42VideoTrack class]])
            {
                uint64_t tw = (uint64_t) [((MP42VideoTrack *) track) trackWidth];
                uint64_t th = (uint64_t) [((MP42VideoTrack *) track) trackHeight];
                if ((tw >= 1024) && (th >= 720))
                {
                    [mp4File.metadata setTag:@"YES" forKey:@"HD Video"];
                }
                [self tableViewSelectionDidChange:nil];
                [self updateChangeCount:NSChangeDone];
            }
        
    }

    [NSApp endSheet:[importWindow window]];
    [[importWindow window] orderOut:self];
    [importWindow release];
}

- (void) addMetadata: (NSURL *) URL
{
    MP42File *file = [[MP42File alloc] initWithExistingFile:URL andDelegate:self];
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
    panel.canChooseDirectories = NO;
    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"mp4", @"m4v", @"m4a", nil]];
    
    [panel beginSheetModalForWindow:documentWindow completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            [self addMetadata:[panel URL]];
        }
    }];
}

- (IBAction) export: (id) sender
{
    NSInteger row = [fileTracksTable selectedRow];
    NSSavePanel * panel = [NSSavePanel savePanel];
    NSString *filename = [[[[self fileURL] path] stringByDeletingPathExtension] lastPathComponent];

    if (row != -1 && [[mp4File trackAtIndex:row] isKindOfClass:[MP42SubtitleTrack class]]) {
        [panel setAllowedFileTypes:[NSArray arrayWithObject: @"srt"]];
        filename = [filename stringByAppendingString:@" - Subtitles"];
    }
	else if (row != -1 ) {
        filename = [filename stringByAppendingString:@" - Chapters"];
		[panel setAllowedFileTypes:[NSArray arrayWithObject: @"txt"]];
    }

    [panel setCanSelectHiddenExtension: YES];
    [panel setNameFieldStringValue:filename];
    
    [panel beginSheetModalForWindow:documentWindow completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            id track = [mp4File trackAtIndex:[fileTracksTable selectedRow]];
            
            if (![track exportToURL: [panel URL] error: nil]) {
                NSAlert * alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle: NSLocalizedString(@"OK", "Export alert panel -> button")];
                [alert setMessageText: NSLocalizedString(@"File Could Not Be Saved", "Export alert panel -> title")];
                [alert setInformativeText: [NSString stringWithFormat:
                                            NSLocalizedString(@"There was a problem creating the file \"%@\".",
                                                              "Export alert panel -> message"), [[[panel URL] path] lastPathComponent]]];
                [alert setAlertStyle: NSWarningAlertStyle];
                
                [alert runModal];
                [alert release];
            }

        }
    }];
}

- (IBAction) addChaptersEvery: (id) sender
{
    MP42ChapterTrack * chapterTrack = [mp4File chapters];
    NSInteger minutes = [sender tag] * 60 * 1000;
    NSInteger i, y;

    if (!chapterTrack) {
        chapterTrack = [[MP42ChapterTrack alloc] init];
        [chapterTrack setDuration:[mp4File movieDuration]];
        [mp4File addTrack:chapterTrack];
        [chapterTrack release];
    }

    for (i = 0, y = 1; i < [mp4File movieDuration]; i += minutes, y++) {
        [chapterTrack addChapter:[NSString stringWithFormat:@"Chapter %d", y]
                        duration:i];
    }

    [fileTracksTable reloadData];
    [self tableViewSelectionDidChange:nil];
    [self updateChangeCount:NSChangeDone];
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

    if ( [[pboard types] containsObject:NSURLPboardType] ) {
        NSArray * items = [pboard readObjectsForClasses:
                           [NSArray arrayWithObject: [NSURL class]] options: nil];
        for (NSURL * file in items)
        {
            if ([[file pathExtension] caseInsensitiveCompare: @"txt"] == NSOrderedSame)
                [self addChapterTrack:file];
            else if ([[file pathExtension] caseInsensitiveCompare: @"scc"] == NSOrderedSame)
                [self showImportSheet:file];
            else if ([[file pathExtension] caseInsensitiveCompare: @"srt"] == NSOrderedSame ||
                     [[file pathExtension] caseInsensitiveCompare: @"smi"] == NSOrderedSame)
                [self showImportSheet:file];
            else if ([[file pathExtension] caseInsensitiveCompare: @"m4v"] == NSOrderedSame ||
                     [[file pathExtension] caseInsensitiveCompare: @"mp4"] == NSOrderedSame ||
                     [[file pathExtension] caseInsensitiveCompare: @"m4a"] == NSOrderedSame ||
                     [[file pathExtension] caseInsensitiveCompare: @"mov"] == NSOrderedSame ||
                     [[file pathExtension] caseInsensitiveCompare: @"mkv"] == NSOrderedSame ||
                     [[file pathExtension] caseInsensitiveCompare: @"mka"] == NSOrderedSame ||
                     [[file pathExtension] caseInsensitiveCompare: @"h264"] == NSOrderedSame ||
                     [[file pathExtension] caseInsensitiveCompare: @"264"] == NSOrderedSame)
                [self showImportSheet:file];

            else if ([[file pathExtension] caseInsensitiveCompare: @"aac"] == NSOrderedSame ||
                     [[file pathExtension] caseInsensitiveCompare: @"ac3"] == NSOrderedSame)
                [self showImportSheet:file];
            break;

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

-(MP42File *) mp4File {
    return mp4File;
}

@end
