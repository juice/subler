//
//  MP4FileWrapper.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP4FileWrapper.h"
#import "MP4ChapterTrackWrapper.h"
#import "SubMuxer.h"
#import "lang.h"

#include "MP4Utilities.h"

@implementation MP4FileWrapper

- (id)initWithExistingMP4File:(NSString *)mp4File andDelegate:(id)del;
{
    if ((self = [super init]))
	{
        delegate = del;
        
		fileHandle = MP4Read([mp4File UTF8String], 0);
        filePath = mp4File;
		if (!fileHandle)
			return nil;

        tracksArray = [[NSMutableArray alloc] init];
        int i, tracksCount = MP4GetNumberOfTracks( fileHandle, 0, 0);
        MP4TrackId chapterId = findChapterTrackId(fileHandle);

        for (i=0; i< tracksCount; i++) {
            id track;
            MP4TrackId trackId = MP4FindTrackId( fileHandle, i, 0, 0);
            if (trackId == chapterId)
                track = [[MP4ChapterTrackWrapper alloc] initWithSourcePath:mp4File trackID: trackId];
            else
                track = [[MP4TrackWrapper alloc] initWithSourcePath:mp4File trackID: trackId];

            [tracksArray addObject:track];
            [track release];
        }

        tracksToBeDeleted = [[NSMutableArray alloc] init];
        metadata = [[MP4Metadata alloc] initWithSourcePath:mp4File];
        MP4Close(fileHandle);
	}
    
	return self;
}

- (NSInteger)tracksCount
{
    return [tracksArray count];
}

- (void) optimizeComplete: (id) sender;
{
    if ([delegate respondsToSelector:@selector(optimizeDidComplete)]) 
        [delegate optimizeDidComplete];
}

- (void) _optimize: (id) sender
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    BOOL noErr;
    NSString * tempPath = [NSString stringWithFormat:@"%@%@", filePath, @".tmp"];

    noErr = MP4Optimize([filePath UTF8String], [tempPath UTF8String], MP4_DETAILS_ERROR);

    if (noErr) {
        NSFileManager *fileManager = [NSFileManager defaultManager];

        [fileManager removeFileAtPath:filePath handler:nil];
        [fileManager movePath:tempPath toPath:filePath handler:nil];
    }
    
    [self performSelectorOnMainThread:@selector(optimizeComplete:) withObject:nil waitUntilDone:NO];
    [pool release];
}

- (void) optimize
{
    [NSThread detachNewThreadSelector:@selector(_optimize:) toTarget:self withObject:nil];
}

- (BOOL) writeToFile
{
    MP4TrackWrapper *track;

    for (track in tracksToBeDeleted)
        [self deleteSubtitleTrack: track];

    for (track in tracksArray)
    {
        if ([track isMemberOfClass:[MP4SubtitleTrackWrapper class]])
            if (track.hasChanged && !track.muxed)
                [self muxSubtitleTrack:(MP4SubtitleTrackWrapper *)track];

        if ([track isMemberOfClass:[MP4ChapterTrackWrapper class]])
            if (track.hasDataChanged)
                [self muxChapterTrack:(MP4ChapterTrackWrapper *)track];

        if (track.hasChanged && track.Id != 0) {
            [self updateTrackLanguage:track];
            [self updateTrackName:track];
        }
    }

    if (metadata.edited)
        [metadata writeMetadata];

    return YES;
}

- (BOOL) muxSubtitleTrack: (MP4SubtitleTrackWrapper*) track
{
    iso639_lang_t *lang = lang_for_english([track.language UTF8String]);

    fileHandle = MP4Modify([filePath UTF8String], MP4_DETAILS_ERROR, 0);
    if (fileHandle == MP4_INVALID_FILE_HANDLE) {
        printf("Error\n");
        return NO;
    }

    muxSubtitleTrack(fileHandle,
                     track.sourcePath,
                     lang->iso639_2,
                     track.height,
                     track.delay);

    MP4Close(fileHandle);

    return YES;
}

- (BOOL) muxChapterTrack: (MP4ChapterTrackWrapper*) track
{
    fileHandle = MP4Modify( [filePath UTF8String], MP4_DETAILS_ERROR, 0 );
    if (fileHandle == MP4_INVALID_FILE_HANDLE) {
        printf("Error\n");
        return NO;
    }

    MP4Chapter_t * chapters = 0;
    uint32_t i, refTrackDuration, sum = 0, chapterCount = 0;

    // get the list of chapters
    MP4GetChapters(fileHandle, &chapters, &chapterCount, MP4ChapterTypeQt);

    MP4DeleteChapters(fileHandle, MP4ChapterTypeAny, track.Id);
    updateTracksCount(fileHandle);

    MP4TrackId refTrack = findFirstVideoTrack(fileHandle);
    if (!refTrack)
        refTrack = 1;

    if (chapterCount && track.muxed) {
        for (i = 0; i<chapterCount; i++)
            strcpy(chapters[i].title, [[[track.chapters objectAtIndex:i] title] UTF8String]);

        MP4AddChapterTextTrack(fileHandle, refTrack, 1000);
        MP4SetChapters(fileHandle, chapters, chapterCount, MP4ChapterTypeQt);
    }
    else {
        chapterCount = [track.chapters count];
        chapters = malloc(sizeof(MP4Chapter_t)*chapterCount);
        refTrackDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                       refTrack,
                                                       MP4GetTrackDuration(fileHandle, refTrack),
                                                       MP4_MSECS_TIME_SCALE);

        for (i = 0; i < chapterCount; i++) {
            SBChapter * chapter = [track.chapters objectAtIndex:i];
            strcpy(chapters[i].title, [[chapter title] UTF8String]);

            if (i+1 < chapterCount && sum < refTrackDuration) {
                SBChapter * nextChapter = [track.chapters objectAtIndex:i+1];
                chapters[i].duration = nextChapter.timestamp - chapter.timestamp;
                sum = nextChapter.timestamp;
            }
            else
                chapters[i].duration = refTrackDuration - chapter.timestamp;

            if (sum > refTrackDuration) {
                chapters[i].duration = refTrackDuration - chapter.timestamp;
                i++;
                break;
            }
        }

        MP4AddChapterTextTrack(fileHandle, refTrack, 1000);
        MP4SetChapters(fileHandle, chapters, i, MP4ChapterTypeQt);

        free(chapters);
    }

    track.Id = findChapterTrackId(fileHandle);
    MP4Close(fileHandle);

    return YES;
}

- (BOOL) deleteSubtitleTrack: (MP4TrackWrapper *)track
{  
    fileHandle = MP4Modify( [filePath UTF8String], MP4_DETAILS_ERROR, 0 );
    MP4TrackId trackId = track.Id;
    MP4DeleteTrack( fileHandle, trackId);

    updateTracksCount(fileHandle);
    enableFirstSubtitleTrack(fileHandle);

    MP4Close(fileHandle);

    return YES;
}

- (BOOL) updateTrackLanguage: (MP4TrackWrapper*) track
{
    iso639_lang_t *lang = lang_for_english([track.language UTF8String]);

    fileHandle = MP4Modify( [filePath UTF8String], MP4_DETAILS_ERROR, 0 );
    if (fileHandle == MP4_INVALID_FILE_HANDLE) {
        printf("Error\n");
        return NO;
    }

    MP4SetTrackLanguage(fileHandle, track.Id, lang->iso639_2);

    MP4Close(fileHandle);

    return YES;
}

- (BOOL) updateTrackName: (MP4TrackWrapper*) track
{   
    fileHandle = MP4Modify( [filePath UTF8String], MP4_DETAILS_ERROR, 0 );
    if (fileHandle == MP4_INVALID_FILE_HANDLE) {
        printf("Error\n");
        return NO;
    }

    if (![track.name isEqualToString:@"Video Track"] &&
        ![track.name isEqualToString:@"Audio Track"] &&
        ![track.name isEqualToString:@"Subtitle Track"] &&
        ![track.name isEqualToString:@"Text Track"] &&
        ![track.name isEqualToString:@"Chapter Track"] &&
        track.name != nil) {
        if (MP4HaveTrackAtom(fileHandle, track.Id, "udta.name"))
            MP4SetTrackBytesProperty(fileHandle, track.Id,
                                     "udta.name.value",
                                     (const uint8_t*) [track.name UTF8String], strlen([track.name UTF8String]));
    }

    MP4Close(fileHandle);

    return YES;
}

- (void) dealloc
{   
    [tracksArray release];
    [tracksToBeDeleted release];
    [metadata release];
    [super dealloc];
}

@synthesize tracksArray;
@synthesize tracksToBeDeleted;
@synthesize metadata;

@end
