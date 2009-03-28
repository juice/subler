//
//  MP42Track.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42Track.h"
#import "MP42Utilities.h"
#import "lang.h"

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

            MP4GetTrackIntegerProperty(fileHandle, Id, "tkhd.alternate_group", &alternate_group);
        }
	}

    return self;
}

- (BOOL) writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError
{
    BOOL err;
    if (!fileHandle || !Id) {
        if ( outError != NULL) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Failed to modify track" forKey:NSLocalizedDescriptionKey];
            *outError = [NSError errorWithDomain:@"MP42Error"
                                            code:120
                                        userInfo:errorDetail];
            return NO;

        }
    }

    err = MP4SetTrackLanguage(fileHandle, Id, lang_for_english([language UTF8String])->iso639_2);

    if (![name isEqualToString:@"Video Track"] &&
        ![name isEqualToString:@"Sound Track"] &&
        ![name isEqualToString:@"Subtitle Track"] &&
        ![name isEqualToString:@"Text Track"] &&
        ![name isEqualToString:@"Chapter Track"] &&
        ![name isEqualToString:@"Unknown Track"] &&
        name != nil) {
        MP4SetTrackName(fileHandle, Id, [name cStringUsingEncoding: NSMacOSRomanStringEncoding]);
    }

    return err;
}

- (void) dealloc
{
    [sourcePath release];
    [name release];
    [language release];
    [super dealloc];
}

- (NSString *) timeString
{
        return SMPTEStringFromTime(duration, 1000);
}

@synthesize sourcePath;
@synthesize Id;
@synthesize sourceId;

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
