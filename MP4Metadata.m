//
//  MP4Metadata.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP4Metadata.h"
#import "MP4Utilities.h"

@implementation MP4Metadata

-(id)initWithSourcePath:(NSString *)source
{
	if ((self = [super init]))
	{
		sourcePath = source;
        tagsDict = [[NSMutableDictionary alloc] init];
	}
	[self readMetaData];
	
    return self;
}

-(void) readMetaData
{
    MP4FileHandle *sourceHandle = MP4Read([sourcePath UTF8String], 0);
    const MP4Tags* tags = MP4TagsAlloc();
    MP4TagsFetch( tags, sourceHandle );

    if (tags->releaseDate)
        [tagsDict setObject:[NSString stringWithFormat:@"%s", tags->releaseDate] forKey: @"Date"];

    if (tags->artist)
        [tagsDict setObject:[NSString stringWithFormat:@"%s", tags->artist] forKey: @"Artist"];

    if (tags->name)
        [tagsDict setObject:[NSString stringWithFormat:@"%s", tags->name] forKey: @"Name"];
    
    if (tags->album)
        [tagsDict setObject:[NSString stringWithFormat:@"%s", tags->album] forKey: @"Album"];

    MP4TagsFree( tags );
}

-(void) dealloc
{
    [super dealloc];
    [tagsDict release];
}

@synthesize tagsDict;

@end
