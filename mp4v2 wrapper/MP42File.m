//
//  MP42File.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP42File.h"
#import "MP42ChapterTrack.h"
#import "MP42Utilities.h"
#import "SubMuxer.h"
#import "SubUtilities.h"
#import "lang.h"


@interface MP42File (Private)

- (BOOL) muxSubtitleTrack: (MP42SubtitleTrack*) track;
- (BOOL) muxChapterTrack: (MP42ChapterTrack*) track;
- (void) removeMuxedTrack: (MP42Track *)track;
- (BOOL) updateTrackLanguage: (MP42Track*) track;
- (BOOL) updateTrackName: (MP42Track*) track;
- (BOOL) updateTrackSize: (MP42Track*) track;

@end

@implementation MP42File

- (id)initWithExistingFile:(NSString *)path andDelegate:(id)del;
{
    if (self = [super init])
	{
        delegate = del;

		fileHandle = MP4Read([path UTF8String], 0);
        filePath = path;
		if (!fileHandle)
			return nil;

        tracks = [[NSMutableArray alloc] init];
        int i, tracksCount = MP4GetNumberOfTracks(fileHandle, 0, 0);
        MP4TrackId chapterId = findChapterTrackId(fileHandle);

        for (i=0; i< tracksCount; i++) {
            id track;
            MP4TrackId trackId = MP4FindTrackId(fileHandle, i, 0, 0);
            const char* type = MP4GetTrackType(fileHandle, trackId);

            if (!strcmp(type, MP4_AUDIO_TRACK_TYPE))
                track = [MP42Track alloc];
            else if (!strcmp(type, MP4_VIDEO_TRACK_TYPE))
                track = [MP42VideoTrack alloc];
            else if (!strcmp(type, MP4_TEXT_TRACK_TYPE)) {
                if (trackId == chapterId)
                    track = [MP42ChapterTrack alloc];
                else
                    track = [MP42Track alloc];
            }
            else if (!strcmp(type, MP4_SUBTITLE_TRACK_TYPE))
                track = [MP42SubtitleTrack alloc];
            else
                track = [MP42Track alloc];

            [track initWithSourcePath:filePath trackID: trackId fileHandle:fileHandle];
            [tracks addObject:track];
            [track release];
        }

        tracksToBeDeleted = [[NSMutableArray alloc] init];
        metadata = [[MP42Metadata alloc] initWithSourcePath:filePath fileHandle:fileHandle];
        MP4Close(fileHandle);
	}

	return self;
}

- (NSInteger)tracksCount
{
    return [tracks count];
}

- (id)trackAtIndex:(NSUInteger) index
{
    return [tracks objectAtIndex:index];
}

- (void)addTrack:(id) track
{
    [tracks addObject:track];
}

- (void)removeTrackAtIndex:(NSUInteger) index
{
    MP42Track *track = [tracks objectAtIndex:index];
    if (track.muxed)
        [tracksToBeDeleted addObject:track];
    [tracks removeObjectAtIndex:index];
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
    MP42Track *track;

    fileHandle = MP4Modify([filePath UTF8String], MP4_DETAILS_ERROR, 0);
    if (fileHandle == MP4_INVALID_FILE_HANDLE) {
        NSLog(@"Fatal Error");
        return NO;
    }

    for (track in tracksToBeDeleted)
        [self removeMuxedTrack:track];

    for (track in tracks)
    {
        if ([track isMemberOfClass:[MP42SubtitleTrack class]])
            if (track.isEdited && !track.muxed)
                if (![self muxSubtitleTrack:(MP42SubtitleTrack *)track]) {
                    NSLog(@"Error writing subtitles");
                    break;
                }

        if ([track isMemberOfClass:[MP42ChapterTrack class]])
            if (track.isDataEdited)
                [self muxChapterTrack:(MP42ChapterTrack *)track];

        if (track.isEdited && track.Id) {
            if ([track isKindOfClass:[MP42VideoTrack class]])
                [self updateTrackSize:track];
            [self updateTrackLanguage:track];
            [self updateTrackName:track];
        }
    }

    if (metadata.isEdited)
        [metadata writeMetadataWithFileHandle:fileHandle];

    MP4Close(fileHandle);
    return YES;
}

- (BOOL) muxSubtitleTrack: (MP42SubtitleTrack*) track
{
    BOOL err;
    if (!fileHandle)
        return NO;

    err = muxSubtitleTrack(fileHandle,
                           track.sourcePath,
                           lang_for_english([track.language UTF8String])->iso639_2,
                           track.height,
                           track.delay);

    return err;
}

- (BOOL) muxChapterTrack: (MP42ChapterTrack*) track
{
    if (!fileHandle)
        return NO;

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

    return YES;
}

- (void) removeMuxedTrack: (MP42Track *)track
{
    if (!fileHandle)
        return;

    MP4DeleteTrack(fileHandle, track.Id);

    updateTracksCount(fileHandle);
    if ([track isMemberOfClass:[MP42SubtitleTrack class]])
        enableFirstSubtitleTrack(fileHandle);
}

- (BOOL) updateTrackLanguage: (MP42Track*) track
{
    BOOL err;
    if (!fileHandle)
        return NO;

    err = MP4SetTrackLanguage(fileHandle, track.Id, lang_for_english([track.language UTF8String])->iso639_2);

    return err;
}

- (BOOL) updateTrackName: (MP42Track*) track
{
    if (!fileHandle)
        return NO;

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

    return YES;
}

- (BOOL) updateTrackSize: (MP42VideoTrack*) track
{
    MP4SetTrackFloatProperty(fileHandle, track.Id, "tkhd.width", track.trackWidth);
    MP4SetTrackFloatProperty(fileHandle, track.Id, "tkhd.height", track.trackHeight);

    uint8_t *val;
    uint8_t nval[36];
    uint32_t *ptr32 = (uint32_t*) nval;
    uint32_t size;

    MP4GetTrackBytesProperty(fileHandle ,track.Id, "tkhd.matrix", &val, &size);
    memcpy(nval, val, size);
    ptr32[6] = CFSwapInt32HostToBig(track.offsetX * 0x10000);
    ptr32[7] = CFSwapInt32HostToBig(track.offsetY * 0x10000);
    MP4SetTrackBytesProperty(fileHandle, track.Id, "tkhd.matrix", nval, size);

    free(val);

    return YES;
}

- (void) dealloc
{   
    [tracks release];
    [tracksToBeDeleted release];
    [metadata release];
    [super dealloc];
}

@synthesize tracks;
@synthesize metadata;

@end
