//
//  MP42File.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42File.h"

@interface MP42File (Private)

- (void) removeMuxedTrack: (MP42Track *)track;

@end

@implementation MP42File

- (id)initWithDelegate:(id)del;
{
    if (self = [super init]) {
        delegate = del;
        hasFileRepresentation = NO;
        tracks = [[NSMutableArray alloc] init];
        tracksToBeDeleted = [[NSMutableArray alloc] init];

        metadata = [[MP42Metadata alloc] init];
    }

    return self;
}

- (id)initWithExistingFile:(NSString *)path andDelegate:(id)del;
{
    if (self = [super init])
	{
        delegate = del;

		fileHandle = MP4Read([path UTF8String], 0);
        filePath = path;
        hasFileRepresentation = YES;
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

            if (MP4_IS_AUDIO_TRACK_TYPE(type))
                track = [MP42AudioTrack alloc];
            else if (MP4_IS_VIDEO_TRACK_TYPE(type))
                track = [MP42VideoTrack alloc];
            else if (!strcmp(type, MP4_TEXT_TRACK_TYPE)) {
                if (trackId == chapterId)
                    track = [MP42ChapterTrack alloc];
                else
                    track = [MP42Track alloc];
            }
            else if (!strcmp(type, MP4_SUBTITLE_TRACK_TYPE))
                track = [MP42SubtitleTrack alloc];
            else if (!strcmp(type, MP4_CC_TRACK_TYPE))
                track = [MP42ClosedCaptionTrack alloc];
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

- (void)removeTracksAtIndexes:(NSIndexSet *)indexes
{
  unsigned index = [indexes firstIndex];
  while (index!=NSNotFound) {    
    MP42Track *track = [tracks objectAtIndex:index];
    if (track.muxed)
      [tracksToBeDeleted addObject:track];    
    index=[indexes indexGreaterThanIndex:index];
  }
  
  [tracks removeObjectsAtIndexes:indexes]; 
}

- (NSInteger)tracksCount
{
    return [tracks count];
}

- (id)trackAtIndex:(NSUInteger) index
{
    return [tracks objectAtIndex:index];
}

- (void)addTrack:(id) object
{
    MP42Track *track = (MP42Track *) object;
    track.sourceId = track.Id;
    track.Id = 0;
    track.muxed = NO;
    track.isEdited = YES;
    track.isDataEdited = YES;
    track.language = track.language;
    if ([track isMemberOfClass:[MP42ChapterTrack class]]) {
        for (id previousTrack in tracks)
            if ([previousTrack isMemberOfClass:[MP42ChapterTrack class]]) {
                [tracks removeObject:previousTrack];
                break;
        }
    }

    [tracks addObject:track];
}

- (void)removeTrackAtIndex:(NSUInteger) index
{
    MP42Track *track = [tracks objectAtIndex:index];
    if (track.muxed)
        [tracksToBeDeleted addObject:track];
    [tracks removeObjectAtIndex:index];
}

- (void) moveTrackAtIndex: (NSUInteger)index toIndex:(NSUInteger) newIndex
{
    id track = [[tracks objectAtIndex:index] retain];

    [tracks removeObjectAtIndex:index];
    if (newIndex > [tracks count] || newIndex > index)
        newIndex--;
    [tracks insertObject:track atIndex:newIndex];
    [track release];
}

- (void) optimize
{
    BOOL noErr;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString * tempPath = [NSString stringWithFormat:@"%@%@", filePath, @".tmp"];

    noErr = MP4Optimize([filePath UTF8String], [tempPath UTF8String], MP4_DETAILS_ERROR);

    if (noErr) {
        NSFileManager *fileManager = [NSFileManager defaultManager];

        [fileManager removeFileAtPath:filePath handler:nil];
        [fileManager movePath:tempPath toPath:filePath handler:nil];
    }

    [pool release];
}

- (BOOL) writeToUrl:(NSURL *)url flags:(uint64_t)flags error:(NSError **)outError
{
    filePath = [url path];
    NSString *fileExtension = [filePath pathExtension];
    char* majorBrand = "mp42";
    char* supportedBrands[4];
    u_int32_t supportedBrandsCount = 0;

    if ([fileExtension isEqualToString:@"m4v"]) {
        majorBrand = "M4V ";
        supportedBrands[0] = majorBrand;
        supportedBrands[1] = "M4A ";
        supportedBrands[2] = "mp42";
        supportedBrandsCount = 3;
    }
    else if ([fileExtension isEqualToString:@"m4a"]) {
        majorBrand = "M4A ";
        supportedBrands[0] = majorBrand;
        supportedBrands[1] = "mp42";
        supportedBrandsCount = 2;
    }
    else {
        supportedBrands[0] = majorBrand;
        supportedBrandsCount = 1;
    }

    fileHandle = MP4CreateEx([filePath UTF8String], MP4_DETAILS_ERROR,
                             flags, 1, 1,
                             majorBrand, 0,
                             supportedBrands, supportedBrandsCount);
    MP4SetTimeScale(fileHandle, 600);
    MP4Close(fileHandle);

    [self updateMP4File:outError];

    return YES;
}

- (BOOL) updateMP4File:(NSError **)outError
{
    BOOL success = YES;
    MP42Track *track;

    fileHandle = MP4Modify([filePath UTF8String], MP4_DETAILS_ERROR, 0);
    if (fileHandle == MP4_INVALID_FILE_HANDLE) {
        if ( outError != NULL) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Failed to open mp4 file" forKey:NSLocalizedDescriptionKey];
            *outError = [NSError errorWithDomain:@"MP42Error"
                                            code:100
                                        userInfo:errorDetail];
        }
        return NO;
    }

    for (track in tracksToBeDeleted)
        [self removeMuxedTrack:track];

    for (track in tracks)
        if (track.isEdited) {
            success = [track writeToFile:fileHandle error:outError];
            if (!success)
                break;
        }

    if (metadata.isEdited && success)
        [metadata writeMetadataWithFileHandle:fileHandle];

    MP4Close(fileHandle);
    return success;
}

- (void) removeMuxedTrack: (MP42Track *)track
{
    if (!fileHandle)
        return;

    if ([track isMemberOfClass:[MP42ChapterTrack class]])
        MP4DeleteChapters(fileHandle, MP4ChapterTypeAny, track.Id);
    else
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
@synthesize hasFileRepresentation;

@end
