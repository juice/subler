//
//  MyDocument.m
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright __MyCompanyName__ 2009 . All rights reserved.
//

#import "MyDocument.h"
#import "SubMuxer.h"
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
    fileHandle = MP4Read( [[absoluteURL path] UTF8String], 0);
    filePath = [absoluteURL path];

    if ( outError != NULL || !fileHandle ) {
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
            MP4TrackId trackId = MP4FindTrackId( fileHandle, [fileTracksTable selectedRow], 0, 0);
            const char* trackType = MP4GetTrackType( fileHandle, trackId);
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
    if( !fileHandle )
        return 0;
    
    return MP4GetNumberOfTracks( fileHandle, 0, 0);
}

- (id) tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
    MP4TrackId trackId = MP4FindTrackId( fileHandle, rowIndex, 0, 0);

    if( [tableColumn.identifier isEqualToString:@"trackId"] )
       return [NSString stringWithFormat:@"%d", trackId];

    if( [tableColumn.identifier isEqualToString:@"trackName"] )
    {
        const char* trackType = MP4GetTrackType( fileHandle, trackId);
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
        return [NSString stringWithFormat:@"%s", MP4GetTrackMediaDataName(fileHandle, trackId)];

    if( [tableColumn.identifier isEqualToString:@"trackDuration"] )
        return [NSString stringWithFormat:@"%ds", MP4GetTrackDuration(fileHandle, trackId) / MP4GetTrackTimeScale( fileHandle, trackId) ];

    if( [tableColumn.identifier isEqualToString:@"trackLanguage"] )
    {
        char* lang;
        NSString *language;
        lang = malloc(sizeof(char)*4);
        MP4GetTrackLanguage( fileHandle, trackId, lang);
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
    iso639_lang_t *lang = lang_for_english([[[langSelection selectedItem] title] UTF8String]);

    muxSubtitleTrack(filePath,
                     [subtitleFilePath stringValue],
                     lang->iso639_2,
                     [[trackHeight stringValue] integerValue],
                     [[delay stringValue] integerValue]
    );

    [self reloadTable:self];

    [NSApp endSheet: addSubtitleWindow];
    [addSubtitleWindow orderOut:self];
}

- (void) reloadTable: (id) sender
{
    fileHandle = MP4Read( [filePath UTF8String], 0);
    [fileTracksTable reloadData];
}

- (IBAction) deleteTrack: (id) sender
{
    MP4FileHandle fileHandle2;
    MP4TrackId maxTrackId;
    int i;

    MP4TrackId trackId = MP4FindTrackId( fileHandle, [fileTracksTable selectedRow], 0, 0);
    fileHandle2 = MP4Modify( [filePath UTF8String], MP4_DETAILS_ERROR, 0 );
    MP4DeleteTrack( fileHandle2, trackId);

    maxTrackId = 0;
    for (i = 0; i< MP4GetNumberOfTracks( fileHandle2, 0, 0); i++ )
                if (MP4FindTrackId(fileHandle2, i, 0, 0) > maxTrackId)
                    maxTrackId = MP4FindTrackId(fileHandle2, i, 0, 0);

    MP4SetIntegerProperty(fileHandle2, "moov.mvhd.nextTrackId", maxTrackId + 1);

    for(i = 0; i < MP4GetNumberOfTracks( fileHandle2, 0, 0); i++) {
        const char* trackType = MP4GetTrackType( fileHandle2, MP4FindTrackId( fileHandle2, i, 0, 0));
        
        if(!strcmp(trackType, "sbtl")) {
            MP4SetTrackIntegerProperty(fileHandle2, MP4FindTrackId( fileHandle2, i, 0, 0), "tkhd.flags", (TRACK_ENABLED | TRACK_IN_MOVIE));
            break;
        }
    }

    MP4Close(fileHandle2);
    
    [self reloadTable:sender];
}

@end
