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
        muxed = YES;
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
        u_int8_t    *value;
        u_int32_t   valueSize;
    
        if (MP4GetTrackBytesProperty(sourceHandle, trackId,
                                     "udta.name.value",
                                     &value, &valueSize)) {
            char * name;
            name = malloc(valueSize + 2);
            memcpy(name, value, valueSize);
            trackName = [[NSString stringWithCString: name encoding:NSUTF8StringEncoding] retain];
            free(name);
        }
        else {
            const char* name = MP4GetTrackType(sourceHandle, trackId);
            if (!strcmp(name, MP4_AUDIO_TRACK_TYPE))
                trackName = NSLocalizedString(@"Audio Track", @"Audio Track");
            else if (!strcmp(name, MP4_VIDEO_TRACK_TYPE))
                trackName = NSLocalizedString(@"Video Track", @"Video Track");
            else if (!strcmp(name, MP4_TEXT_TRACK_TYPE))
                trackName = NSLocalizedString(@"Text Track", @"Text Track");
            else if (!strcmp(name, "sbtl"))
                trackName = NSLocalizedString(@"Subtitle Track", @"Subtitle Track");
            else
                trackName = NSLocalizedString(@"Unknown Track", @"Unknown Track");
        }
        
        const char* dataName = MP4GetTrackMediaDataName(sourceHandle, trackId);
        if (!strcmp(dataName, "avc1"))
            trackFormat = @"H.264";
        else if (!strcmp(dataName, "mp4a"))
            trackFormat = @"AAC";
        else if (!strcmp(dataName, "ac-3"))
            trackFormat = @"AC-3", @"AC-3";
        else if (!strcmp(dataName, "mp4v"))
            trackFormat = @"MPEG-4 Visual";
        else if (!strcmp(dataName, "text"))
            trackFormat = @"Text";
        else if (!strcmp(dataName, "tx3g"))
            trackFormat = @"3GPP Text";
        else
            trackFormat = NSLocalizedString(@"Unknown", @"Unknown");

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

- (void) dellaoc
{
    [trackMedia release];
    [trackName release];
    [language release];
}

@synthesize trackSourcePath;
@synthesize trackId;
@synthesize trackFormat;
@synthesize trackName;
@synthesize trackMedia;
@synthesize language;

@synthesize samplerate;
@synthesize bitrate;
@synthesize duration;
@synthesize hasChanged;
@synthesize muxed;

@end
