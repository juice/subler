//
//  MP42ChapterTrack.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP42ChapterTrack.h"
#import "SubUtilities.h"

@implementation MP42ChapterTrack

- (id) initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID
{
    if (self = [super initWithSourcePath:source trackID:trackID])
    {
        name = @"Chapter Track";
        format = @"Text";
        chapters = [[NSMutableArray alloc] init];

        MP4Chapter_t *chapter_list = NULL;
        uint32_t      chapter_count;

        MP4FileHandle *sourceHandle = MP4Read([sourcePath UTF8String], 0);
        MP4GetChapters(sourceHandle, &chapter_list, &chapter_count, MP4ChapterTypeQt);

        int i = 1;
        MP4Duration sum = 0;
        while (i <= chapter_count)
        {
            SBChapter *chapter = [[SBChapter alloc] init];
            chapter.title = [NSString stringWithCString:chapter_list[i-1].title encoding: NSUTF8StringEncoding];
            chapter.timestamp = sum;
            sum = chapter_list[i-1].duration + sum;
            [chapters addObject:chapter];
            [chapter release];
            i++;
        }
        MP4Free(chapter_list);
        MP4Close(sourceHandle);
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

        chapters = [[NSMutableArray alloc] init];
        LoadChaptersFromPath(filePath, chapters);        
    }

    return self;
}

+ (id) chapterTrackFromFile:(NSString *)filePath
{
    return [[[MP42ChapterTrack alloc] initWithTextFile:filePath] autorelease];
}

- (void) dealloc
{
    [chapters release];
    [super dealloc];
}

@synthesize chapters;

@end
