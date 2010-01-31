//
//  MP42MkvFileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Apple Inc. All rights reserved.
//

#import "MP42MkvImporter.h"
#import "MatroskaParser.h"
#import "MatroskaFile.h"
#import "lang.h"
#import "MP42File.h"

@interface MP42MkvImporter (Private)
    NSString* matroskaCodecIDToHumanReadableName(TrackInfo *track);
    NSString* getMatroskaTrackName(TrackInfo *track);
@end

@implementation MP42MkvImporter

- (id)initWithDelegate:(id)del andFile:(NSURL *)fileUrl
{
    if (self = [super initWithDelegate:del andFile:fileUrl]) {
        ioStream = calloc(1, sizeof(StdIoStream)); 
        matroskaFile = openMatroskaFile((char *)[[file path ]UTF8String], ioStream);
        
        NSInteger trackCount = mkv_GetNumTracks(matroskaFile);
        tracksArray = [[NSMutableArray alloc] initWithCapacity:trackCount];
        
        NSUInteger i;
        
        for (i = 0; i < trackCount; i++) {
            TrackInfo *mkvTrack = mkv_GetTrackInfo(matroskaFile, i);
            MP42Track *newTrack = nil;

            // Video
            if (mkvTrack->Type == TT_VIDEO)  {
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
                newTrack.sourcePath = [file path];
                newTrack.sourceInputType = MP42SourceTypeMatroska;

                double trackTimecodeScale = (mkvTrack->TimecodeScale.v >> 32);
                SegmentInfo *segInfo = mkv_GetFileInfo(matroskaFile);
                UInt64 scaledDuration = (UInt64)segInfo->Duration / (UInt32)segInfo->TimecodeScale * trackTimecodeScale;

                newTrack.duration = scaledDuration;
                newTrack.name = getMatroskaTrackName(mkvTrack);
                iso639_lang_t *isoLanguage = lang_for_code2(mkvTrack->Language);
                newTrack.language = [NSString stringWithUTF8String:isoLanguage->eng_name];
                [tracksArray addObject:newTrack];
                [newTrack release];
            }
        }

        if (chapterTrackId > 0) {
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
                    if (chapters->Children[xi].Display && strlen(chapters->Children[xi].Display->String))
                        [newTrack addChapter:[NSString stringWithUTF8String:chapters->Children[xi].Display->String]
                                    duration:timestamp];
                    else
                        [newTrack addChapter:[NSString stringWithFormat:@"Chapter %d", xi+1]
                                    duration:timestamp];
                }
            }
            [tracksArray addObject:newTrack];
            [newTrack release];
        }
    }

    return self;
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

- (void) dealloc
{
	[file release];
    [tracksArray release];

	/* close matroska parser */ 
	mkv_Close(matroskaFile); 

	/* close file */ 
	fclose(ioStream->fp); 

    [super dealloc];
}

@end
