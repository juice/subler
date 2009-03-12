//
//  MP42File.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP42File.h"
#import "MP42Utilities.h"

@interface MP42File (Private)

- (void) removeMuxedTrack: (MP42Track *)track;

@end

@implementation MP42File

- (id)initWithExistingFile:(NSString *)path andDelegate:(id)del;
{
    if (self = [super init])
	{
        delegate = del;

		fileHandle = MP4Read([path UTF8String], 0);
        filePath = path;
		if (!fileHandle) {
            [self release];
			return nil;
        }

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
    NSError *theError;

    fileHandle = MP4Modify([filePath UTF8String], MP4_DETAILS_ERROR, 0);
    if (fileHandle == MP4_INVALID_FILE_HANDLE) {
        NSLog(@"Fatal Error");
        return NO;
    }

    for (track in tracksToBeDeleted)
        [self removeMuxedTrack:track];

    for (track in tracks)
        if (track.isEdited)
            [track writeToFile:fileHandle error:&theError];

    if (metadata.isEdited)
        [metadata writeMetadataWithFileHandle:fileHandle];

    MP4Close(fileHandle);
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
