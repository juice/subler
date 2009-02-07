//
//  MP4ChapterTrackWrapper.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP4ChapterTrackWrapper.h"

@implementation SBChapter

-(void) dealloc
{
    [super dealloc];
    [title release];
}

@synthesize duration;
@synthesize title;

@end

@implementation MP4ChapterTrackWrapper

-(id)initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID
{
    if ((self = [super initWithSourcePath:source trackID:trackID]))
    {
        name = @"Chapter Track";
        chapters = [[NSMutableArray alloc] init];
        

        MP4Chapter_t *chapter_list = NULL;
        uint32_t      chapter_count;
         
        MP4FileHandle *sourceHandle = MP4Read([sourcePath UTF8String], 0);
        MP4GetChapters( sourceHandle, &chapter_list, &chapter_count, 
                       MP4ChapterTypeQt );
         
        int i = 1;
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        MP4Duration sum = 0;
        while (i <= chapter_count)
        {
            SBChapter *chapter = [[SBChapter alloc] init];
            chapter.title = [NSString stringWithCString:chapter_list[i-1].title encoding: NSUTF8StringEncoding];
            chapter.duration = sum;
            sum = chapter_list[i-1].duration + sum;
            [chapters addObject:chapter];
            [chapter release];
            i++;
        }
        [pool release];
        MP4Free(chapter_list);
        MP4Close(sourceHandle);
    }
    
    return self;
}

-(void) dealloc
{
    [super dealloc];
    [chapters release];
}

@synthesize chapters;

@end
