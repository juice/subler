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

-(id)init
{
    if ((self = [super init]))
    {
        enabled = YES;
        updatedProperty = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(id)initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
	if ((self = [super init]))
	{
		sourcePath = [source retain];
		Id = trackID;
        isEdited = NO;
        muxed = YES;
        updatedProperty = [[NSMutableDictionary alloc] init];

        if (fileHandle) {
            format = [getHumanReadableTrackMediaDataName(fileHandle, Id) retain];
            name = [getTrackName(fileHandle, Id) retain];
            language = [getHumanReadableTrackLanguage(fileHandle, Id) retain];
            bitrate = MP4GetTrackBitRate(fileHandle, Id);
            duration = MP4ConvertFromTrackDuration(fileHandle, Id,
                                                   MP4GetTrackDuration(fileHandle, Id),
                                                   MP4_MSECS_TIME_SCALE);
            timescale = MP4GetTrackTimeScale(fileHandle, Id);
            startOffset = getTrackStartOffset(fileHandle, Id);

            uint64_t temp;
            MP4GetTrackIntegerProperty(fileHandle, Id, "tkhd.flags", &temp);
            if (temp & TRACK_ENABLED) enabled = YES;
            else enabled = NO;
            MP4GetTrackIntegerProperty(fileHandle, Id, "tkhd.alternate_group", &alternate_group);
        }
	}

    return self;
}

- (BOOL) writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError
{
    BOOL success = YES;
    if (!fileHandle || !Id) {
        if ( outError != NULL) {
            *outError = MP42Error(@"Failed to modify track",
                                  nil,
                                  120);
            return NO;

        }
    }

    if ([updatedProperty valueForKey:@"name"]  || !muxed)
        if (![name isEqualToString:@"Video Track"] &&
            ![name isEqualToString:@"Sound Track"] &&
            ![name isEqualToString:@"Subtitle Track"] &&
            ![name isEqualToString:@"Text Track"] &&
            ![name isEqualToString:@"Chapter Track"] &&
            ![name isEqualToString:@"Unknown Track"] &&
            name != nil) {
            const char* cString = [name cStringUsingEncoding: NSMacOSRomanStringEncoding];
            if (cString)
                MP4SetTrackName(fileHandle, Id, cString);
        }
    if ([updatedProperty valueForKey:@"alternate_group"] || !muxed)
        MP4SetTrackIntegerProperty(fileHandle, Id, "tkhd.alternate_group", alternate_group);
    if ([updatedProperty valueForKey:@"start_offset"])
        setTrackStartOffset(fileHandle, Id, startOffset);
    if ([updatedProperty valueForKey:@"language"] || !muxed)
        MP4SetTrackLanguage(fileHandle, Id, lang_for_english([language UTF8String])->iso639_2);
    if ([updatedProperty valueForKey:@"enabled"] || !muxed) {
        if (enabled) enableTrack(fileHandle, Id);
        else disableTrack(fileHandle, Id);
    }

    return success;
}

- (void) dealloc
{
    if (trackImporterHelper)
        [trackImporterHelper release];
    if (trackDemuxerHelper)
        [trackDemuxerHelper release];
    if (trackConverterHelper)
        [trackConverterHelper release];

    [updatedProperty release];
    [format release];
    [sourcePath release];
    [name release];
    [language release];
    [sourceFileHandle release];
    [super dealloc];
}

- (NSString *) timeString
{
        return SMPTEStringFromTime(duration, 1000);
}

@synthesize sourcePath;
@synthesize Id;
@synthesize sourceId;
@synthesize sourceFileHandle;

@synthesize format;
@synthesize sourceFormat;
@synthesize name;

- (NSString *) name {
    return name;
}

- (void) setName: (NSString *) newName
{
    [name autorelease];
    name = [newName retain];
    isEdited = YES;
    [updatedProperty setValue:@"True" forKey:@"name"];
}

- (NSString *) language {
    return language;
}

- (void) setLanguage: (NSString *) newLang
{
    [language autorelease];
    language = [newLang retain];
    isEdited = YES;
    [updatedProperty setValue:@"True" forKey:@"language"];
}

- (BOOL) enabled {
    return enabled;
}

- (void) setEnabled: (BOOL) newState
{
    enabled = newState;
    isEdited = YES;
    [updatedProperty setValue:@"True" forKey:@"enabled"];
}

- (uint64_t) alternate_group {
    return alternate_group;
}

- (void) setAlternate_group: (uint64_t) newGroup
{
    alternate_group = newGroup;
    isEdited = YES;
    [updatedProperty setValue:@"True" forKey:@"alternate_group"];
}

- (int64_t) startOffset {
    return startOffset;
}

- (void) setStartOffset:(int64_t)newOffset
{
    startOffset = newOffset;
    isEdited = YES;
    [updatedProperty setValue:@"True" forKey:@"start_offset"];
    
}

- (NSString *) formatSummary
{
    return [[format retain] autorelease];
}

@synthesize timescale;
@synthesize bitrate;
@synthesize duration;
@synthesize isEdited;
@synthesize muxed;
@synthesize needConversion;

@synthesize updatedProperty;

@synthesize trackImporterHelper;
@synthesize trackDemuxerHelper;
@synthesize trackConverterHelper;

@end
