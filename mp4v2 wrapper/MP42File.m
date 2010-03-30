//
//  MP42File.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42File.h"
#import <QTKit/QTKit.h>
#import "SubUtilities.h"

NSString * const MP42Create64BitData = @"64BitData";
NSString * const MP42Create64BitTime = @"64BitTime";
NSString * const MP42CreateChaptersPreviewTrack = @"ChaptersPreview";

@interface MP42File (Private)
- (void) removeMuxedTrack: (MP42Track *)track;
- (BOOL) createChaptersPreview;

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
        filePath = [path retain];
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

            track = [track initWithSourcePath:filePath trackID:trackId fileHandle:fileHandle];
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
    NSUInteger index = [indexes firstIndex];
    while (index != NSNotFound) {    
        MP42Track *track = [tracks objectAtIndex:index];
        if (track.muxed)
            [tracksToBeDeleted addObject:track];    
        index = [indexes indexGreaterThanIndex:index];
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
    track.name = track.name;
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

- (BOOL) writeToUrl:(NSURL *)url withAttributes:(NSDictionary *)attributes error:(NSError **)outError
{
    BOOL success = YES;
    filePath = [[url path] retain];
    NSString *fileExtension = [filePath pathExtension];
    char* majorBrand = "mp42";
    char* supportedBrands[4];
    uint32_t supportedBrandsCount = 0;
    uint32_t flags = 0;
    if ([[attributes valueForKey:MP42Create64BitData] integerValue])
        flags += 0x01;
    if ([[attributes valueForKey:MP42Create64BitTime] integerValue])
        flags += 0x02;

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
    if (fileHandle) {
        MP4SetTimeScale(fileHandle, 600);
        MP4Close(fileHandle);

        success = [self updateMP4FileWithAttributes:attributes error:outError];
    }

    return success;
}

- (BOOL) updateMP4FileWithAttributes:(NSDictionary *)attributes error:(NSError **)outError
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
        if (track.isEdited && !stopOperation) {
            success = [track writeToFile:fileHandle error:outError];
            if (!success)
                break;
        }

    if (metadata.isEdited && success)
        [metadata writeMetadataWithFileHandle:fileHandle];

    MP4Close(fileHandle);

    if ([[attributes valueForKey:@"ChaptersPreview"] integerValue])
        [self createChaptersPreview];

    return success;
}

- (void) stopOperation;
{
    stopOperation = TRUE;
}

- (void) removeMuxedTrack: (MP42Track *)track
{
    if (!fileHandle)
        return;

    // We have to handle a few special cases here.
    if ([track isMemberOfClass:[MP42ChapterTrack class]])
        MP4DeleteChapters(fileHandle, MP4ChapterTypeAny, track.Id);
    else
        MP4DeleteTrack(fileHandle, track.Id);
    
    if ([track.format isEqualToString:@"Photo - JPEG"]) {
        MP42ChapterTrack * chapterTrack = nil;
        MP4TrackId refTrack = findFirstVideoTrack(fileHandle);
        if (!refTrack)
            refTrack = 1;
        
        MP4RemoveAllTrackReferences(fileHandle, "tref.chap", refTrack);
        for (MP42Track * track in tracks)
            if ([track isMemberOfClass:[MP42ChapterTrack class]])
                chapterTrack = (MP42ChapterTrack*) track;
        
        if (chapterTrack)
            MP4AddTrackReference(fileHandle, "tref.chap", [chapterTrack Id], refTrack);
    }

    updateTracksCount(fileHandle);
    updateMoovDuration(fileHandle);
    if ([track isMemberOfClass:[MP42SubtitleTrack class]])
        enableFirstSubtitleTrack(fileHandle);
}

- (void) openQTMovieOnTheMainThread:(NSMutableDictionary*)dict {
    QTMovie * qtMovie;
    NSDictionary *movieAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [dict valueForKey:@"URL"], QTMovieURLAttribute,
                                     [NSNumber numberWithBool:NO], QTMovieAskUnresolvedDataRefsAttribute,
                                     [NSNumber numberWithBool:YES], @"QTMovieOpenForPlaybackAttribute",
                                     [NSNumber numberWithBool:NO], @"QTMovieOpenAsyncRequiredAttribute",
                                     [NSNumber numberWithBool:NO], @"QTMovieOpenAsyncOKAttribute",
                                     QTMovieApertureModeClean, QTMovieApertureModeAttribute,
                                     nil];
    qtMovie = [[QTMovie alloc] initWithAttributes:movieAttributes error:nil];
    if(!qtMovie)
        NSLog(@"QTKit error");
    else {
        //[qtMovie detachFromCurrentThread];
        [dict setObject:qtMovie forKey:@"QTMovieObject"];
    }
}

- (void) closeQTMovieOnTheMainThread:(QTMovie*)qtMovie {
    if (qtMovie) {
        //[qtMovie attachToCurrentThread];
        [qtMovie release];
    }
}

- (BOOL) createChaptersPreview {
    MP42ChapterTrack * chapterTrack = nil;
    MP4TrackId jpegTrack = 0;

    for (MP42Track * track in tracks)
        if ([track isMemberOfClass:[MP42ChapterTrack class]])
            chapterTrack = (MP42ChapterTrack*) track;

    for (MP42Track * track in tracks)
        if ([track.format isEqualToString:@"Photo - JPEG"])
            jpegTrack = track.Id;

    if (chapterTrack && !jpegTrack) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        QTMovie * qtMovie;
        NSMutableDictionary * dict = [[NSMutableDictionary dictionaryWithObject:[NSURL fileURLWithPath:filePath] forKey:@"URL"] retain];
        // QTMovie objects must always be create on the main thread.
        [self performSelectorOnMainThread:@selector(openQTMovieOnTheMainThread:)
                               withObject:dict 
                            waitUntilDone:YES];
        qtMovie = [dict valueForKey:@"QTMovieObject"];
        [dict release];
        //[QTMovie enterQTKitOnThread];
        //[qtMovie attachToCurrentThread];

        if (!qtMovie)
            return NO;

        for (QTTrack* qtTrack in [qtMovie tracksOfMediaType:@"sbtl"])
            [qtTrack setAttribute:[NSNumber numberWithBool:NO] forKey:QTTrackEnabledAttribute];

        NSMutableArray * previewImages = [NSMutableArray arrayWithCapacity:[chapterTrack chapterCount]];

        for (SBSample * chapter in [chapterTrack chapters]) {
            QTTime chapterTime = {
                [chapter timestamp] + 1500, // Add a short offset, hopefully it will get a better image
                1000,                       // if there is a fade
                0
            };

            [previewImages addObject:[qtMovie frameImageAtTime:chapterTime]];
        }

        //[qtMovie detachFromCurrentThread];
        //[QTMovie exitQTKitOnThread];
        // Release the movie, we don't want to keep it open while we are writing in it using another library.
        // I am not sure if it is safe to release a QTMovie from a background thread, let's do it on the main just to be sure.
        [self performSelectorOnMainThread:@selector(closeQTMovieOnTheMainThread:)
                               withObject:qtMovie 
                            waitUntilDone:YES];

        // Reopen the mp4v2 fileHandle
        fileHandle = MP4Modify([filePath UTF8String], MP4_DETAILS_ERROR, 0);
        if (fileHandle == MP4_INVALID_FILE_HANDLE)
            return NO;

        MP4TrackId refTrack = findFirstVideoTrack(fileHandle);
        if (!refTrack)
            refTrack = 1;

        MP4Duration refTrackDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                       refTrack,
                                                       MP4GetTrackDuration(fileHandle, refTrack),
                                                       MP4_MSECS_TIME_SCALE);

        CGFloat maxWidth = 640;
        NSSize imageSize = [[previewImages objectAtIndex:0] size];
        if (imageSize.width > maxWidth) {
            imageSize.height = maxWidth / imageSize.width * imageSize.height;
            imageSize.width = maxWidth;
        }

        jpegTrack = MP4AddMJpegVideoTrack(fileHandle, 1000, MP4_INVALID_DURATION, imageSize.width, imageSize.height);
        MP4SetTrackIntegerProperty(fileHandle, jpegTrack, "tkhd.layer", 1);
        disableTrack(fileHandle, jpegTrack);

        NSInteger i = 0;
        MP4Duration duration = 0, sumDuration = 0;

        for (SBSample *chapterT in [chapterTrack chapters]) {
            if (i < ([chapterTrack chapterCount] -1)) {
                SBSample *next = [[chapterTrack chapters] objectAtIndex:i+1];
                MP4Duration nextDuration = [next timestamp];
                duration = nextDuration - sumDuration;
                sumDuration += duration;
            }
            else
                duration = refTrackDuration - sumDuration;

            // Scale the image.
            NSRect newRect = NSMakeRect(0.0, 0.0, imageSize.width, imageSize.height);
            NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                               pixelsWide:newRect.size.width
                                                                               pixelsHigh:newRect.size.height
                                                                            bitsPerSample:8
                                                                          samplesPerPixel:4
                                                                                 hasAlpha:YES
                                                                                 isPlanar:NO
                                                                           colorSpaceName:NSCalibratedRGBColorSpace
                                                                             bitmapFormat:NSAlphaFirstBitmapFormat
                                                                              bytesPerRow:0
                                                                             bitsPerPixel:32];
            [NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
            [[previewImages objectAtIndex:0] drawInRect:newRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
            [NSGraphicsContext restoreGraphicsState];

            NSData * jpegData = [bitmap representationUsingType:NSJPEGFileType properties:nil];
            [bitmap release];

            i++;
            MP4WriteSample(fileHandle,
                           jpegTrack,
                           [jpegData bytes],
                           [jpegData length],
                           duration,
                           0,
                           true);

            [previewImages removeObjectAtIndex:0];
        }

        MP4RemoveAllTrackReferences(fileHandle, "tref.chap", refTrack);
        MP4AddTrackReference(fileHandle, "tref.chap", [chapterTrack Id], refTrack);
        MP4AddTrackReference(fileHandle, "tref.chap", jpegTrack, refTrack);
        MP4Close(fileHandle);

        [pool release];
        return YES;
    }
    else if (chapterTrack && jpegTrack) {
        // We already have all the tracks, so hook them up.
        fileHandle = MP4Modify([filePath UTF8String], MP4_DETAILS_ERROR, 0);
        if (fileHandle == MP4_INVALID_FILE_HANDLE)
            return NO;

        MP4TrackId refTrack = findFirstVideoTrack(fileHandle);
        if (!refTrack)
            refTrack = 1;
        
        MP4RemoveAllTrackReferences(fileHandle, "tref.chap", refTrack);
        MP4AddTrackReference(fileHandle, "tref.chap", [chapterTrack Id], refTrack);
        MP4AddTrackReference(fileHandle, "tref.chap", jpegTrack, refTrack);
        disableTrack(fileHandle, jpegTrack);
        MP4Close(fileHandle);
    }
    return NO;
}

@synthesize tracks;
@synthesize metadata;
@synthesize hasFileRepresentation;

- (void) dealloc
{
    [filePath release];
    [tracks release];
    [tracksToBeDeleted release];
    [metadata release];
    [super dealloc];
}

@end
