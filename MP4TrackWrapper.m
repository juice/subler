//
//  MP4TrackWrapper.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP4TrackWrapper.h"
#include "lang.h"

@implementation MP4TrackWrapper

-(id)initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID
{
	if ((self = [super init]))
	{
		trackSourcePath = source;
		trackId = trackID;
        hasChanged = NO;
	}
	[self readTrackType];
	
    return self;
}

-(void)readTrackType
{
	// Override to read type-specific info
	MP4FileHandle *sourceHandle = MP4Read([trackSourcePath UTF8String], 0);
	
	if (sourceHandle != MP4_INVALID_FILE_HANDLE)
	{
		const char* type = MP4GetTrackType(sourceHandle, trackId);
        if (!strcmp(type, MP4_AUDIO_TRACK_TYPE))
            trackType = NSLocalizedString(@"Audio Track", @"Audio Track");
        else if (!strcmp(type, MP4_VIDEO_TRACK_TYPE))
            trackType = NSLocalizedString(@"Video Track", @"Video Track");
        else if (!strcmp(type, MP4_TEXT_TRACK_TYPE))
            trackType = NSLocalizedString(@"Text Track", @"Text Track");
        else if (!strcmp(type, "sbtl"))
            trackType = NSLocalizedString(@"Subtitle Track", @"Subtitle Track");
        else
            trackType = NSLocalizedString(@"Unknown Track", @"Unknown Track");

        trackMedia = [[NSString stringWithFormat:@"%s",
                       MP4GetTrackMediaDataName(sourceHandle, trackId)] retain];

		bitrate = (double)MP4GetTrackBitRate(sourceHandle, trackId) / 1024;
		duration = (double)MP4ConvertFromTrackDuration(sourceHandle, trackId,
                                                       MP4GetTrackDuration(sourceHandle, trackId),
                                                       MP4_MSECS_TIME_SCALE) / 1000;
		samplerate = MP4GetTrackTimeScale(sourceHandle, trackId);
        
        char* lang;
        lang = malloc(sizeof(char)*4);
        MP4GetTrackLanguage( sourceHandle, trackId, lang);
        language = [[NSString stringWithFormat:@"%s", lang_for_code2(lang)->eng_name] retain];
        free(lang);
		MP4Close(sourceHandle);
	}
}

@synthesize trackSourcePath;
@synthesize trackId;
@synthesize trackType;
@synthesize trackMedia;
@synthesize language;

@synthesize samplerate;
@synthesize bitrate;
@synthesize duration;
@synthesize hasChanged;

@end
