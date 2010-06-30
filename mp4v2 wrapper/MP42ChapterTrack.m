//
//  MP42ChapterTrack.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42ChapterTrack.h"
#import "SubUtilities.h"
#import "MP42Utilities.h"

@implementation MP42ChapterTrack

- (id) init
{
    if (self = [super init])
    {
        name = @"Chapter Track";
        format = @"Text";
        language = @"English";
        isEdited = YES;
        isDataEdited = YES;
        muxed = NO;
        enabled = NO;

        chapters = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void) addChapter:(NSString *)title duration:(uint64_t)timestamp
{
    SBTextSample *newChapter = [[SBTextSample alloc] init];
    newChapter.title = title;
    newChapter.timestamp = timestamp;

    [chapters addObject:newChapter];
    [newChapter release];
}

- (id)initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
    if (self = [super initWithSourcePath:source trackID:trackID fileHandle:fileHandle])
    {
        if (!name || [name isEqualToString:@"Text Track"])
            name = @"Chapter Track";
        if (!format)
            format = @"Text";
        chapters = [[NSMutableArray alloc] init];

        MP4Chapter_t *chapter_list = NULL;
        uint32_t      chapter_count;

        MP4GetChapters(fileHandle, &chapter_list, &chapter_count, MP4ChapterTypeQt);

        unsigned int i = 1;
        MP4Duration sum = 0;
        while (i <= chapter_count)
        {
            SBTextSample *chapter = [[SBTextSample alloc] init];
            chapter.title = [NSString stringWithCString:chapter_list[i-1].title encoding: NSUTF8StringEncoding];
            chapter.timestamp = sum;
            sum = chapter_list[i-1].duration + sum;
            [chapters addObject:chapter];
            [chapter release];
            i++;
        }
        MP4Free(chapter_list);
    }

    return self;
}

- (id) initWithTextFile:(NSString *)filePath
{
    if (self = [super init])
    {
        name = @"Chapter Track";
        format = @"Text";
        sourcePath = [filePath retain];
        language = @"English";
        isEdited = YES;
        isDataEdited = YES;
        muxed = NO;
        enabled = NO;

        chapters = [[NSMutableArray alloc] init];
        LoadChaptersFromPath(filePath, chapters);        
    }

    return self;
}

+ (id) chapterTrackFromFile:(NSString *)filePath
{
    return [[[MP42ChapterTrack alloc] initWithTextFile:filePath] autorelease];
}

- (BOOL) writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError
{
    BOOL success = YES;

    if (isDataEdited) {
        MP4Chapter_t * fileChapters = 0;
        uint32_t i, refTrackDuration, chapterCount = 0;
        uint64_t sum = 0;

        // get the list of chapters
        MP4GetChapters(fileHandle, &fileChapters, &chapterCount, MP4ChapterTypeQt);

        MP4DeleteChapters(fileHandle, MP4ChapterTypeAny, Id);
        updateTracksCount(fileHandle);

        MP4TrackId refTrack = findFirstVideoTrack(fileHandle);
        if (!refTrack)
            refTrack = 1;

        if (chapterCount && muxed) {
            for (i = 0; i<chapterCount; i++)
                strcpy(fileChapters[i].title, [[[chapters objectAtIndex:i] title] UTF8String]);

            MP4SetChapters(fileHandle, fileChapters, chapterCount, MP4ChapterTypeAny);
        }
        else {
            chapterCount = [chapters count];
            fileChapters = malloc(sizeof(MP4Chapter_t)*chapterCount);
            refTrackDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                           refTrack,
                                                           MP4GetTrackDuration(fileHandle, refTrack),
                                                           MP4_MSECS_TIME_SCALE);

            for (i = 0; i < chapterCount; i++) {
                SBTextSample * chapter = [chapters objectAtIndex:i];
                strcpy(fileChapters[i].title, [[chapter title] UTF8String]);
                
                if (i+1 < chapterCount && sum < refTrackDuration) {
                    SBTextSample * nextChapter = [chapters objectAtIndex:i+1];
                    fileChapters[i].duration = nextChapter.timestamp - chapter.timestamp;
                    sum = nextChapter.timestamp;
                }
                else
                    fileChapters[i].duration = refTrackDuration - chapter.timestamp;

                if (sum > refTrackDuration) {
                    fileChapters[i].duration = refTrackDuration - chapter.timestamp;
                    i++;
                    break;
                }
            }

            MP4SetChapters(fileHandle, fileChapters, i, MP4ChapterTypeAny);
        }

        free(fileChapters);
        success = Id = findChapterTrackId(fileHandle);
    }
    if (!success) {
        if ( outError != NULL) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Failed to mux chapters into mp4 file" forKey:NSLocalizedDescriptionKey];
            *outError = [NSError errorWithDomain:@"MP42Error"
                                            code:120
                                        userInfo:errorDetail];
        }
        return success;
    }
    else if (Id)
        success = [super writeToFile:fileHandle error:outError];

    return success;
}


- (NSInteger)chapterCount
{
  return [chapters count];
}

- (void) dealloc
{
    [chapters release];
    [super dealloc];
}

@synthesize chapters;

@end
