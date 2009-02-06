//
//  MP4FileWrapper.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP4FileWrapper.h"
#include "MP4Utilities.h"

@implementation MP4FileWrapper

-(id)initWithExistingMP4File:(NSString *)mp4File
{
    if ((self = [super init]))
	{
		fileHandle = MP4Read([mp4File UTF8String], 0);

		if (!fileHandle)
			return nil;

        tracksArray = [[NSMutableArray alloc] init];
        int i, tracksCount = MP4GetNumberOfTracks( fileHandle, 0, 0);
        MP4TrackId chapterId = findChapterTrackId(fileHandle);
    
        for (i=0; i< tracksCount; i++) {
            MP4TrackId trackId = MP4FindTrackId( fileHandle, i, 0, 0);
            MP4TrackWrapper *track = [[MP4TrackWrapper alloc] initWithSourcePath:mp4File trackID: trackId];
            if(track.Id == chapterId)
                track.name = @"Chapter Track";
            [tracksArray addObject:track];
            [track release];
        }

        tracksToBeDeleted = [[NSMutableArray alloc] init];

        /*
        MP4Chapter_t *chapter_list = NULL;
        uint32_t      chapter_count;

        MP4GetChapters( fileHandle, &chapter_list, &chapter_count, 
                       MP4ChapterTypeQt );

        i = 1;
        while( i <= chapter_count )
        {
            NSLog(@"%s", chapter_list[i-1].title );
            i++;
        }
        */

	}
	return self;
}

- (NSInteger)tracksCount
{
    return [tracksArray count];
}

- (void) dealloc
{
    [tracksArray release];
    [tracksToBeDeleted release];
    [super dealloc];
}

@synthesize tracksArray;
@synthesize tracksToBeDeleted;


@end
