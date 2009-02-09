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
	edited = NO;
    
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

    if (tags->grouping)
        [tagsDict setObject:[NSString stringWithFormat:@"%s", tags->grouping] forKey: @"Grouping"];

    if (tags->composer)
        [tagsDict setObject:[NSString stringWithFormat:@"%s", tags->composer] forKey: @"Composer"];

    if (tags->comments)
        [tagsDict setObject:[NSString stringWithFormat:@"%s", tags->comments] forKey: @"Comments"];
    
    if (tags->genre)
        [tagsDict setObject:[NSString stringWithFormat:@"%s", tags->genre] forKey: @"Genre"];
    
    if (tags->description)
        [tagsDict setObject:[NSString stringWithFormat:@"%s", tags->description] forKey: @"Description"];

    if (tags->name)
        [tagsDict setObject:[NSString stringWithFormat:@"%s", tags->name] forKey: @"Name"];

    if (tags->album)
        [tagsDict setObject:[NSString stringWithFormat:@"%s", tags->album] forKey: @"Album"];

    MP4TagsFree( tags );
    MP4Close(sourceHandle);
}

- (BOOL) writeMetadata
{
    MP4FileHandle *fileHandle = MP4Modify( [sourcePath UTF8String], MP4_DETAILS_ERROR, 0 );
    const MP4Tags* tags = MP4TagsAlloc();
    MP4TagsFetch( tags, fileHandle );
    
    if ([tagsDict valueForKey:@"Name"])
        MP4TagsSetName( tags, [[tagsDict valueForKey:@"Name"] UTF8String] );

    if ([tagsDict valueForKey:@"Artist"])
        MP4TagsSetArtist( tags, [[tagsDict valueForKey:@"Artist"] UTF8String] );

    if ([tagsDict valueForKey:@"Album"])
        MP4TagsSetAlbum( tags, [[tagsDict valueForKey:@"Album"] UTF8String] );

    if ([tagsDict valueForKey:@"Date"])
        MP4TagsSetReleaseDate( tags, [[tagsDict valueForKey:@"Date"] UTF8String] );

    if ([tagsDict valueForKey:@"Comments"])
        MP4TagsSetComments( tags, [[tagsDict valueForKey:@"Comments"] UTF8String] );

    if ([tagsDict valueForKey:@"Description"])
        MP4TagsSetDescription( tags, [[tagsDict valueForKey:@"Description"] UTF8String] );

    if ([tagsDict valueForKey:@"Genre"])
        MP4TagsSetGenre( tags, [[tagsDict valueForKey:@"Genre"] UTF8String] );

    if ([tagsDict valueForKey:@"Composer"])
        MP4TagsSetComposer( tags, [[tagsDict valueForKey:@"Composer"] UTF8String] );

    MP4TagsStore( tags, fileHandle );
    MP4TagsFree( tags );
    MP4Close( fileHandle );
    
    return YES;
}

@synthesize edited;

-(void) dealloc
{
    [super dealloc];
    [tagsDict release];
}

@synthesize tagsDict;

@end
