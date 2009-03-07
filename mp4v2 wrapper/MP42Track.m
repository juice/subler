//
//  MP42Track.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP42Track.h"
#import "MP42Utilities.h"

#include "lang.h"

@implementation MP42Track

-(id)initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID
{
	if ((self = [super init]))
	{
		sourcePath = [source retain];
		Id = trackID;
        isEdited = NO;
        isDataEdited = NO;
        muxed = YES;
	}
	[self readTrackType];
	
    return self;
}

-(void)readTrackType
{
	MP4FileHandle *sourceHandle = MP4Read([sourcePath UTF8String], 0);
	
	if (sourceHandle != MP4_INVALID_FILE_HANDLE)
	{
        u_int8_t    *value;
        u_int32_t   valueSize;

        if (MP4GetTrackBytesProperty(sourceHandle, Id,
                                     "udta.name.value",
                                     &value, &valueSize)) {
            char * trackName;
            trackName = malloc(valueSize +2);
            memcpy(trackName, value, valueSize);
            trackName[valueSize] = '\0';
            name = [[NSString stringWithCString: trackName] retain];
            free(trackName);
            free(value);
        }
        else {
            const char* type = MP4GetTrackType(sourceHandle, Id);
            if (!strcmp(type, MP4_AUDIO_TRACK_TYPE))
                name = NSLocalizedString(@"Audio Track", @"Audio Track");
            else if (!strcmp(type, MP4_VIDEO_TRACK_TYPE))
                name = NSLocalizedString(@"Video Track", @"Video Track");
            else if (!strcmp(type, MP4_TEXT_TRACK_TYPE))
                name = NSLocalizedString(@"Text Track", @"Text Track");
            else if (!strcmp(type, "sbtl"))
                name = NSLocalizedString(@"Subtitle Track", @"Subtitle Track");
            else
                name = NSLocalizedString(@"Unknown Track", @"Unknown Track");
        }

        const char* dataName = MP4GetTrackMediaDataName(sourceHandle, Id);
        if (!strcmp(dataName, "avc1"))
            format = @"H.264";
        else if (!strcmp(dataName, "mp4a"))
            format = @"AAC";
        else if (!strcmp(dataName, "ac-3"))
            format = @"AC-3", @"AC-3";
        else if (!strcmp(dataName, "mp4v"))
            format = @"MPEG-4 Visual";
        else if (!strcmp(dataName, "text"))
            format = @"Text";
        else if (!strcmp(dataName, "tx3g"))
            format = @"3GPP Text";
        else
            format = NSLocalizedString(@"Unknown", @"Unknown");

		bitrate = (double)MP4GetTrackBitRate(sourceHandle, Id) / 1024;
		duration = (double)MP4ConvertFromTrackDuration(sourceHandle, Id,
                                                       MP4GetTrackDuration(sourceHandle, Id),
                                                       MP4_MSECS_TIME_SCALE);
		samplerate = MP4GetTrackTimeScale(sourceHandle, Id);

        char* lang = malloc(sizeof(char)*4);
        MP4GetTrackLanguage( sourceHandle, Id, lang);
        language = [[NSString stringWithFormat:@"%s", lang_for_code2(lang)->eng_name] retain];
        free(lang);
		MP4Close(sourceHandle);
	}
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

@synthesize samplerate;
@synthesize bitrate;
@synthesize duration;
@synthesize isEdited;
@synthesize isDataEdited;
@synthesize muxed;

@end
