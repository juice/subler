//
//  MP4ChapterTrackWrapper.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP4ChapterTrackWrapper.h"


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
        while( i <= chapter_count )
        {
            [chapters addObject:[NSString stringWithFormat:@"%s", chapter_list[i-1].title]];
            i++;
        }
        
        MP4Close(sourceHandle);
    }
    
    return self;
}

@synthesize chapters;

@end
