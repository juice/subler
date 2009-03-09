//
//  MP42Track.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP42Track.h"
#import "MP42Utilities.h"


@implementation MP42Track

-(id)initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
	if ((self = [super init]))
	{
		sourcePath = [source retain];
		Id = trackID;
        isEdited = NO;
        isDataEdited = NO;
        muxed = YES;

        if (fileHandle) {
            format = getHumanReadableTrackMediaDataName(fileHandle, Id);
            name = [getTrackName(fileHandle, Id) retain];
            language = [getHumanReadableTrackLanguage(fileHandle, Id) retain];
            bitrate = MP4GetTrackBitRate(fileHandle, Id);
            duration = MP4ConvertFromTrackDuration(fileHandle, Id,
                                                   MP4GetTrackDuration(fileHandle, Id),
                                                   MP4_MSECS_TIME_SCALE);
            timescale = MP4GetTrackTimeScale(fileHandle, Id);
        }
	}

    return self;
}

-(void)readTrackType
{
    MP4FileHandle *sourceHandle = MP4Read([sourcePath UTF8String], 0);

    if (!sourceHandle)
        return;

    format = getHumanReadableTrackMediaDataName(sourceHandle, Id);
    name = [getTrackName(sourceHandle, Id) retain];
    language = [getHumanReadableTrackLanguage(sourceHandle, Id) retain];
    bitrate = MP4GetTrackBitRate(sourceHandle, Id);
    duration = MP4ConvertFromTrackDuration(sourceHandle, Id,
                                          MP4GetTrackDuration(sourceHandle, Id),
                                          MP4_MSECS_TIME_SCALE);
    timescale = MP4GetTrackTimeScale(sourceHandle, Id);
    
    MP4Close(sourceHandle);
}

- (void) dealloc
{
    [sourcePath release];
    [name release];
    [language release];
    [super dealloc];
}

- (NSString *) SMPTETimeString
{
    return SMPTEStringFromTime(duration, 1000);
}

@synthesize sourcePath;
@synthesize Id;
@synthesize format;
@synthesize name;
@synthesize language;

@synthesize timescale;
@synthesize bitrate;
@synthesize duration;
@synthesize isEdited;
@synthesize isDataEdited;
@synthesize muxed;

@end
