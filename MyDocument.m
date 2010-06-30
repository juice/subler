//
//  MyDocument.m
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright Damiano Galassi 2009 . All rights reserved.
//

#import "MyDocument.h"
#import "MP42File.h"
#import "EmptyViewController.h"
#import "MovieViewController.h"
#import "VideoViewController.h"
#import "SoundViewController.h"
#import "ChapterViewController.h"
#import "FileImport.h"
#import "VideoFramerate.h"
#import "tagChimpController.h"

#define SublerTableViewDataType @"SublerTableViewDataType"

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
    return YES;
}

#pragma mark Read methods

- (void) reloadFile: (id) sender
{
    if ([self fileURL]) {
        MP42File *newFile = [[MP42File alloc] initWithExistingFile:[[self fileURL] path] andDelegate:self];
        [mp4File autorelease];
        mp4File = newFile;
        [fileTracksTable reloadData];
        [self tableViewSelectionDidChange:nil];
    }
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

#pragma mark Save methods

// Hook into the flow to fork a thread
- (void)saveToURL:(NSURL *)absoluteURL
		   ofType:(NSString *)typeName
 forSaveOperation:(NSSaveOperationType)saveOperation
		 delegate:(id)delegate
  didSaveSelector:(SEL)didSaveSelector
	  contextInfo:(void *)contextInfo
{
    [optBar startAnimation:nil];
    [saveOperationName setStringValue:@"Saving…"];
    [NSApp beginSheet:savingWindow modalForWindow:documentWindow
        modalDelegate:nil didEndSelector:NULL contextInfo:nil];

    [NSApplication detachDrawingThread:@selector(saveDocumentToDisk:) toTarget:self
							withObject:[NSDictionary dictionaryWithObjectsAndKeys:absoluteURL, @"absoluteURL",
										typeName, @"typeName",
										[NSNumber numberWithInteger:saveOperation], @"saveOperation", nil]];
}

// Thread entry
- (void)saveDocumentToDisk:(NSDictionary *)info
{
    NSURL       *absoluteURL = [info objectForKey:@"absoluteURL"];
    NSString    *typeName = [info objectForKey:@"typeName"];
    NSSaveOperationType	saveOperation = [[info objectForKey:@"saveOperation"] integerValue];
    NSError	 *outError;

    BOOL success = [self saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:&outError];

    NSDictionary *fileAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:'M4V '], NSFileHFSTypeCode,
                                    [NSNumber numberWithUnsignedInt:0], NSFileHFSCreatorCode,
                                    nil];

    [[NSFileManager defaultManager] changeFileAttributes:fileAttributes atPath:[absoluteURL path]];
    [self setFileURL:absoluteURL];
    [self setFileModificationDate:[[[NSFileManager defaultManager]  
                                    fileAttributesAtPath:[absoluteURL path] traverseLink:YES]  
                                   fileModificationDate]];
    if (success && outError)
        outError = nil;

    [self performSelectorOnMainThread:@selector(saveDidComplete:) withObject:outError waitUntilDone: NO];
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
            if (_64bit_data) [attributes setObject:[NSNumber numberWithBool:YES] forKey:MP42Create64BitData];
            if (_64bit_time) [attributes setObject:[NSNumber numberWithBool:YES] forKey:MP42Create64BitTime];
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

- (void) saveDidComplete: (NSError *)outError
{
    [NSApp endSheet: savingWindow];
    [savingWindow orderOut:self];
    
    [optBar stopAnimation:nil];
    
    if (outError) {
        [self presentError:outError
            modalForWindow:documentWindow
                  delegate:nil
        didPresentSelector:NULL
               contextInfo:NULL];
    }
    
    [self reloadFile:self];
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
    
    return YES;
}

- (IBAction) setSaveFormat: (id) sender
{
    NSInteger index = [sender indexOfSelectedItem];
    switch (index) {
        case 0:
            [_currentSavePanel setRequiredFileType:@"m4v"];
            break;
        case 1:
            [_currentSavePanel setRequiredFileType:@"mp4"];
            break;
        case 2:
            [_currentSavePanel setRequiredFileType:@"m4a"];
            break;
        default:
            break;
    }
}

- (IBAction) set64bit_data: (id) sender
{
    _64bit_data = [sender state];
}

- (IBAction) set64bit_time: (id) sender
{
    _64bit_time = [sender state];
}

- (IBAction) cancelSaveOperation: (id) sender {
    [cancelSave setEnabled:NO];
    [mp4File stopOperation];
}

- (void) saveAndOptimize: (id)sender
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
        if (track.Id == 0)
            return @"na";
        else
            return [NSString stringWithFormat:@"%d", track.Id];
    }

    if ([tableColumn.identifier isEqualToString:@"trackName"])
        return track.name;

    if ([tableColumn.identifier isEqualToString:@"trackInfo"])
        return track.format;
    
    if ([tableColumn.identifier isEqualToString:@"trackEnabled"])
        return [NSNumber numberWithInteger:track.enabled];

    if ([tableColumn.identifier isEqualToString:@"trackDuration"])
        return [track timeString];

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
    importWindow = [[tagChimpController alloc] initWithDelegate:self];
    
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

- (void) addChapterTrack: (NSString *) path
{
    [mp4File addTrack:[MP42ChapterTrack chapterTrackFromFile:path]];

    [fileTracksTable reloadData];
    [self tableViewSelectionDidChange:nil];
    [self updateChangeCount:NSChangeDone];
}

- (void) addCCTrack: (NSString *) path
{
    [mp4File addTrack:[MP42ClosedCaptionTrack ccTrackFromFile:path]];
    
    [fileTracksTable reloadData];
    [self updateChangeCount:NSChangeDone];
}

- (IBAction) showSubititleWindow: (NSString *) path;
{
    [langSelection selectItemWithTitle:getFilenameLanguage((CFStringRef)path)];
    subtitleFilePath = [path retain];

    [NSApp beginSheet:addSubtitleWindow modalForWindow:documentWindow
        modalDelegate:nil didEndSelector:NULL contextInfo:nil];
}

- (IBAction) closeSheet: (id) sender
{
    [subtitleFilePath release];
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

- (IBAction) addSubtitleTrack: (id)sender
{
    [self addSubtitleTrack:subtitleFilePath
                     delay:[[delay stringValue] integerValue]
                    height:[[trackHeight stringValue] integerValue]
                  language:[[langSelection selectedItem] title]];
    [subtitleFilePath release];
}

- (void) addAudioTrack: (NSString *)path
{
    MP42AudioTrack *newTrack = [[MP42AudioTrack alloc] init];
    newTrack.sourceId = 0;
    newTrack.sourcePath = path;
    newTrack.sourceInputType = MP42SourceTypeRaw;
    if ([[path pathExtension] isEqualToString:@"ac3"])
        newTrack.format = @"AC-3";
    else
        newTrack.format = @"AAC";

    [mp4File addTrack:newTrack];
    [fileTracksTable reloadData];
    [self updateChangeCount:NSChangeDone];
    
    [newTrack release];
}

- (IBAction) selectFile: (id) sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = YES;

    [panel beginSheetForDirectory: nil file: nil types: [NSArray arrayWithObjects:@"mp4", @"m4v", @"m4a", @"mov",
                                                                                    @"aac", @"h264", @"264", @"ac3",
                                                                                    @"txt", @"srt", @"smi", @"scc", @"mkv", nil]
                   modalForWindow: documentWindow modalDelegate: self
                   didEndSelector: @selector( selectFileDidEnd:returnCode:contextInfo: )
                      contextInfo: nil];                                                      
}

- (void) selectFileDidEnd: (NSOpenPanel *) sheet returnCode: (NSInteger)
returnCode contextInfo: (void *) contextInfo
{
    if (returnCode != NSOKButton)
        return;

    NSString *fileExtension = [[sheet.filenames objectAtIndex: 0] pathExtension];

    if ([fileExtension isEqualToString:@"aac"] ||
        [fileExtension isEqualToString:@"ac3"])
        [self addAudioTrack:[sheet.filenames objectAtIndex: 0]];

    else if ([fileExtension caseInsensitiveCompare: @"srt"] == NSOrderedSame ||
             [fileExtension caseInsensitiveCompare: @"smi"] == NSOrderedSame)
        [self performSelectorOnMainThread:@selector(showSubititleWindow:)
                               withObject:[sheet.filenames objectAtIndex: 0] waitUntilDone: NO];

    else if ([fileExtension caseInsensitiveCompare: @"txt"] == NSOrderedSame)
         [self addChapterTrack:[sheet.filenames objectAtIndex: 0]];

    else if ([fileExtension caseInsensitiveCompare: @"scc"] == NSOrderedSame)
        [self addCCTrack:[sheet.filenames objectAtIndex: 0]];

    else
        [self performSelectorOnMainThread:@selector(showImportSheet:)
                               withObject:[sheet.filenames objectAtIndex: 0] waitUntilDone: NO];
}

- (void) showImportSheet: (NSString *) filePath
{
    if ([[filePath pathExtension] isEqualToString:@"h264"] || [[filePath pathExtension] isEqualToString:@"264"])
        importWindow = [[VideoFramerate alloc] initWithDelegate:self andFile:filePath];
    else
		importWindow = [[FileImport alloc] initWithDelegate:self andFile:filePath];

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

- (void) metadataImportDone: (MP42Metadata*) metadataToBeImported
{
    if (metadataToBeImported) {
        [mp4File.metadata mergeMetadata:metadataToBeImported];
        [self tableViewSelectionDidChange:nil];
        [self updateChangeCount:NSChangeDone];
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
            else if ([[file pathExtension] caseInsensitiveCompare: @"scc"] == NSOrderedSame)
                [self addCCTrack:file];
            else if ([[file pathExtension] caseInsensitiveCompare: @"srt"] == NSOrderedSame ||
                     [[file pathExtension] caseInsensitiveCompare: @"smi"] == NSOrderedSame)
                [self addSubtitleTrack:file
                                 delay:0
                                height:60
                              language:getFilenameLanguage((CFStringRef)file)];
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
                [self addAudioTrack:file];

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
