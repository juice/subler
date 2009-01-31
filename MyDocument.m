//
//  MyDocument.m
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright __MyCompanyName__ 2009 . All rights reserved.
//

#import "MyDocument.h"
#import "SubMuxer.h"
#import "MP4Utilities.h"
#import "lang.h"

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
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to write your document to data of the specified type. If the given outError != NULL, ensure that you set *outError when returning nil.

    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.

    // For applications targeted for Panther or earlier systems, you should use the deprecated API -dataRepresentationOfType:. In this case you can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.

    if ( outError != NULL ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
	return nil;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    readOnlyFile = MP4Read( [[absoluteURL path] UTF8String], 0);
    filePath = [absoluteURL path];

    if ( outError != NULL || !readOnlyFile ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
    return YES;
}

- (BOOL)validateToolbarItem: (NSToolbarItem *) toolbarItem
{
    if (toolbarItem == addTrackToolBar)
            return YES;

    else if (toolbarItem == deleteTrack) {
        if ([fileTracksTable selectedRow] != -1 && [NSApp isActive]) {
            MP4TrackId trackId = MP4FindTrackId( readOnlyFile, [fileTracksTable selectedRow], 0, 0);
            const char* trackType = MP4GetTrackType( readOnlyFile, trackId);
            if (!strcmp(trackType, "sbtl"))
                return YES;
        }    
    }
    return NO;
}

/***********************************************************************
 * Tableview datasource methods
 **********************************************************************/
- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    if( !readOnlyFile )
        return 0;
    
    return MP4GetNumberOfTracks( readOnlyFile, 0, 0);
}

- (id) tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
    MP4TrackId trackId = MP4FindTrackId( readOnlyFile, rowIndex, 0, 0);

    if( [tableColumn.identifier isEqualToString:@"trackId"] )
       return [NSString stringWithFormat:@"%d", trackId];

    if( [tableColumn.identifier isEqualToString:@"trackName"] )
    {
        const char* trackType = MP4GetTrackType( readOnlyFile, trackId);
        if (!strcmp(trackType, MP4_AUDIO_TRACK_TYPE))
            return NSLocalizedString(@"Audio Track", @"Audio Track");
        else if (!strcmp(trackType, MP4_VIDEO_TRACK_TYPE))
            return NSLocalizedString(@"Video Track", @"Video Track");
        else if (!strcmp(trackType, MP4_TEXT_TRACK_TYPE))
            return NSLocalizedString(@"Text Track", @"Text Track");
        else if (!strcmp(trackType, "sbtl"))
            return NSLocalizedString(@"Subtitle Track", @"Subtitle Track");
        else
            return NSLocalizedString(@"Unknown Track", @"Unknown Track");
    }

    if( [tableColumn.identifier isEqualToString:@"trackInfo"] )
        return [NSString stringWithFormat:@"%s", MP4GetTrackMediaDataName(readOnlyFile, trackId)];

    if( [tableColumn.identifier isEqualToString:@"trackDuration"] )
        return [NSString stringWithFormat:@"%ds", MP4GetTrackDuration(readOnlyFile, trackId) / MP4GetTrackTimeScale( readOnlyFile, trackId) ];

    if( [tableColumn.identifier isEqualToString:@"trackLanguage"] )
    {
        char* lang;
        NSString *language;
        lang = malloc(sizeof(char)*4);
        MP4GetTrackLanguage( readOnlyFile, trackId, lang);
        language = [NSString stringWithFormat:@"%s", lang_for_code2(lang)->eng_name];
        free(lang);
        
        return language;
    }

    return nil;
}

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
    
    [panel beginSheetForDirectory: nil file: nil types: [NSArray arrayWithObject:@"srt"]
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
    [addTrack setEnabled:YES];
}

- (IBAction) closeSheet: (id) sender
{
    [NSApp endSheet: addSubtitleWindow];
    [addSubtitleWindow orderOut:self];
}

- (IBAction) startMuxing: (id) sender
{
    MP4FileHandle fileHandle;
    iso639_lang_t *lang = lang_for_english([[[langSelection selectedItem] title] UTF8String]);

    fileHandle = MP4Modify( [filePath UTF8String], MP4_DETAILS_ERROR, 0 );
    if (fileHandle == MP4_INVALID_FILE_HANDLE) {
        printf("Error\n");
        return;
    }
    
    muxSubtitleTrack(fileHandle,
                     [subtitleFilePath stringValue],
                     lang->iso639_2,
                     [[trackHeight stringValue] integerValue],
                     [[delay stringValue] integerValue]
    );
    
    MP4Close(fileHandle);

    [self reloadTable:self];

    [NSApp endSheet: addSubtitleWindow];
    [addSubtitleWindow orderOut:self];
}

- (void) reloadTable: (id) sender
{
    readOnlyFile = MP4Read( [filePath UTF8String], 0);
    [fileTracksTable reloadData];
}

- (IBAction) deleteTrack: (id) sender
{
    MP4FileHandle fileHandle;

    fileHandle = MP4Modify( [filePath UTF8String], MP4_DETAILS_ERROR, 0 );
    MP4TrackId trackId = MP4FindTrackId( readOnlyFile, [fileTracksTable selectedRow], 0, 0);
    MP4DeleteTrack( fileHandle, trackId);

    updateTracksCount(fileHandle);
    enableFirstSubtitleTrack(fileHandle);

    MP4Close(fileHandle);
    
    [self reloadTable:sender];
}

@end
