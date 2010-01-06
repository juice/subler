//
//  MKVFileImport.m
//  Subler
//
//  Created by Ryan Walklin on 10/09/09.
//  Copyright 2009 Test Toast. All rights reserved.
//

#import "MKVFileImport.h"
#import "MatroskaParser.h"
#import "MatroskaFile.h"
#import "lang.h"
#import "MP42File.h"

@implementation MKVFileImport

- (id)initWithDelegate:(id)del andFile: (NSString *)path
{
	if (self = [super initWithWindowNibName:@"FileImport"])
	{        
		delegate = del;
        filePath = [path retain];
	}
	return self;
}
- (void)awakeFromNib
{
    ioStream = calloc(1, sizeof(StdIoStream)); 
	matroskaFile = openMatroskaFile((char *)[filePath UTF8String], ioStream);

	NSInteger i = mkv_GetNumTracks(matroskaFile);

    Chapter* chapters;
    unsigned count;
    mkv_GetChapters(matroskaFile, &chapters, &count);
    if (count) {
        chapterTrackId = i;
        i++;
    }
    else
        chapterTrackId = -1;
    
    importCheckArray = [[NSMutableArray alloc] initWithCapacity:i];
	
    while (i) {
        [importCheckArray addObject: [NSNumber numberWithBool:YES]];
        i--;
		[addTracksButton setEnabled:YES];       
    }
}

NSString* getMatroskaTrackName(TrackInfo *track)
{    
    if (!track->Name) {
        if (track->Type == TT_AUDIO)
            return NSLocalizedString(@"Sound Track", @"Sound Track");
        else if (track->Type == TT_VIDEO)
            return NSLocalizedString(@"Video Track", @"Video Track");
        else if (track->Type == TT_SUB)
            return NSLocalizedString(@"Subtitle Track", @"Subtitle Track");
        else
            return NSLocalizedString(@"Unknown Track", @"Unknown Track");
    }
    else
        return [NSString stringWithUTF8String:track->Name];
}


NSString* matroskaCodecIDToHumanReadableName(TrackInfo *track)
{
    if (track->CodecID) {
        if (!strcmp(track->CodecID, "V_MPEG4/ISO/AVC"))
            return @"H.264";
        else if (!strcmp(track->CodecID, "A_AAC"))
            return @"AAC";
        else if (!strcmp(track->CodecID, "A_AC3"))
            return @"AC-3";
        else if (!strcmp(track->CodecID, "V_MPEG4/ISO/SP"))
            return @"MPEG-4 Visual";
        else if (!strcmp(track->CodecID, "A_DTS"))
            return @"DTS";
        else if (!strcmp(track->CodecID, "A_VORBIS"))
            return @"Vorbis";
        else if (!strcmp(track->CodecID, "A_FLAC"))
            return @"Flac";
        else if (!strcmp(track->CodecID, "S_TEXT/UTF8"))
            return @"Plain Text";
        else if (!strcmp(track->CodecID, "S_TEXT/ASS"))
            return @"ASS";
        else if (!strcmp(track->CodecID, "S_TEXT/SSA"))
            return @"SSA";
        else
            return [NSString stringWithUTF8String:track->CodecID];
    }
    else {
        return @"Unknown";
    }
}


- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    if( !matroskaFile )
        return 0;
	
    if (chapterTrackId > 0)
        return mkv_GetNumTracks(matroskaFile) + 1;
    else
        return mkv_GetNumTracks(matroskaFile);
}

- (id) tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
    if (rowIndex == chapterTrackId) {
        if( [tableColumn.identifier isEqualToString: @"check"] )
            return [importCheckArray objectAtIndex: rowIndex];
        
        if ([tableColumn.identifier isEqualToString:@"trackId"])
            return [NSNumber numberWithInt:chapterTrackId +1];
        
        if ([tableColumn.identifier isEqualToString:@"trackName"])
            return @"Chapter Track";
        
        if ([tableColumn.identifier isEqualToString:@"trackInfo"])
            return @"Text";
        
        if ([tableColumn.identifier isEqualToString:@"trackDuration"])
            return nil;
        
        if ([tableColumn.identifier isEqualToString:@"trackLanguage"])
            return nil;
    }

	TrackInfo *track = mkv_GetTrackInfo(matroskaFile, rowIndex);
    
	if (!track)
        return nil;
    if( [tableColumn.identifier isEqualToString: @"check"] )
        return [importCheckArray objectAtIndex: rowIndex];
	
    if ([tableColumn.identifier isEqualToString:@"trackId"])
        return [NSString stringWithFormat:@"%d", track->Number];
	
    if ([tableColumn.identifier isEqualToString:@"trackName"])
        return getMatroskaTrackName(track);
	
    if ([tableColumn.identifier isEqualToString:@"trackInfo"])
		return matroskaCodecIDToHumanReadableName(track);
	
    if ([tableColumn.identifier isEqualToString:@"trackDuration"])
	{
		double trackTimecodeScale = (track->TimecodeScale.v >> 32);
		SegmentInfo *segInfo = mkv_GetFileInfo(matroskaFile);
		UInt64 scaledDuration = (UInt64)segInfo->Duration / (UInt32)segInfo->TimecodeScale * trackTimecodeScale;
		return SMPTEStringFromTime(scaledDuration, 1000);
	}
	
    if ([tableColumn.identifier isEqualToString:@"trackLanguage"])
	{
		iso639_lang_t *isoLanguage = lang_for_code2(track->Language);
		return [NSString stringWithUTF8String:isoLanguage->eng_name];
	}
    return nil;
}

- (void) tableView: (NSTableView *) tableView 
    setObjectValue: (id) anObject 
    forTableColumn: (NSTableColumn *) tableColumn 
               row: (NSInteger) rowIndex
{
    if ([tableColumn.identifier isEqualToString: @"check"])
        [importCheckArray replaceObjectAtIndex:rowIndex withObject:anObject];
}

- (IBAction) closeWindow: (id) sender
{
    if ([delegate respondsToSelector:@selector(importDone:)]) 
        [delegate importDone:nil];
}

- (IBAction) addTracks: (id) sender
{
    NSMutableArray *tracks = [[NSMutableArray alloc] init];
    NSUInteger i;
	
    for (i = 0; i < mkv_GetNumTracks(matroskaFile); i++) 
	{
        if ([[importCheckArray objectAtIndex: i] boolValue])
		{
			TrackInfo *mkvTrack = mkv_GetTrackInfo(matroskaFile, i);
            MP42Track *newTrack = nil;
			
            // Video
            if (mkvTrack->Type == TT_VIDEO) 
			{
                newTrack = [[MP42VideoTrack alloc] init];
					
                [(MP42VideoTrack*)newTrack setTrackWidth:mkvTrack->AV.Video.PixelWidth];
                [(MP42VideoTrack*)newTrack setTrackHeight:mkvTrack->AV.Video.PixelHeight];
            }
			
            // Audio
            else if (mkvTrack->Type == TT_AUDIO)
                newTrack = [[MP42AudioTrack alloc] init];
			
            // Text
            else if (mkvTrack->Type == TT_SUB)
				newTrack = [[MP42SubtitleTrack alloc] init];

            if (newTrack) {
                newTrack.format = matroskaCodecIDToHumanReadableName(mkvTrack);
                newTrack.Id = i;
                newTrack.sourcePath = filePath;
                newTrack.sourceInputType = MP42SourceTypeMatroska;

                double trackTimecodeScale = (mkvTrack->TimecodeScale.v >> 32);
                SegmentInfo *segInfo = mkv_GetFileInfo(matroskaFile);
                UInt64 scaledDuration = (UInt64)segInfo->Duration / (UInt32)segInfo->TimecodeScale * trackTimecodeScale;

                newTrack.duration = scaledDuration;
                newTrack.name = getMatroskaTrackName(mkvTrack);
				iso639_lang_t *isoLanguage = lang_for_code2(mkvTrack->Language);
				newTrack.language = [NSString stringWithUTF8String:isoLanguage->eng_name];
                [tracks addObject:newTrack];
                [newTrack release];
            }
        }
    }

    if (chapterTrackId > 0) {
        if ([[importCheckArray objectAtIndex: i] boolValue]) {
            Chapter* chapters;
            unsigned count;
            MP42ChapterTrack *newTrack = [[MP42ChapterTrack alloc] init];

            mkv_GetChapters(matroskaFile, &chapters, &count);
            if (count) {
                unsigned int xi = 0;
                for (xi = 0; xi < chapters->nChildren; xi++) {
                    uint64_t timestamp = (chapters->Children[xi].Start) / 1000000;
                    if (!xi)
                        timestamp = 0;
                    [newTrack addChapter:[NSString stringWithUTF8String:chapters->Children[xi].Display->String]
                                                duration:timestamp];
                }
            }
            [tracks addObject:newTrack];
            [newTrack release];
        }
    }

    if ([delegate respondsToSelector:@selector(importDone:)]) 
        [delegate importDone:tracks];
	
    [tracks release];
}

- (void) dealloc
{
    [importCheckArray release];
	[filePath release];
	
	/* close matroska parser */ 
	mkv_Close(matroskaFile); 
	
	/* close file */ 
	fclose(ioStream->fp); 

    [super dealloc];
}

@end
