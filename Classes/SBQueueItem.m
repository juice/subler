//
//  SBQueueItem.m
//  Subler
//
//  Created by Damiano Galassi on 16/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SBQueueItem.h"
#import "MP42File.h"

@implementation SBQueueItem

@synthesize attributes;
@synthesize URL = fileURL;
@synthesize mp4File;
@synthesize status;
- (id)init
{
    self = [super init];
    if (self) {

    }

    return self;
}

- (id)initWithURL:(NSURL*)URL {
    self = [super init];
    if (self) {
        fileURL = [URL retain];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        unsigned long long originalFileSize = [[[fileManager attributesOfItemAtPath:[fileURL path] error:nil] valueForKey:NSFileSize] unsignedLongLongValue];
        if (originalFileSize > 4257218560) {
            attributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithBool:YES], MP42Create64BitData, nil];
        }
    }

    return self;
}

+ (id)itemWithURL:(NSURL*)URL
{
    return [[[SBQueueItem alloc] initWithURL:URL] autorelease];
}

- (id)initWithMP4:(MP42File*)MP4 {
    self = [super init];
    if (self) {
        mp4File = [MP4 retain];

        if ([MP4 URL])
            fileURL = [[MP4 URL] retain];
        else {
            for (NSUInteger i = 0; i < [mp4File tracksCount]; i++) {
                MP42Track *track = [mp4File trackAtIndex:i];
                if ([track sourceURL]) {
                    fileURL = [[track sourceURL] retain];
                    break;
                }
            }
        }

        status = SBQueueItemStatusReady;
    }

    return self;
}

+ (id)itemWithMP4:(MP42File*)MP4
{
    return [[[SBQueueItem alloc] initWithMP4:MP4] autorelease];
}

- (id)initWithMP4:(MP42File*)MP4 url:(NSURL*)URL attributes:(NSDictionary*)dict
{
    if (self = [super init])
    {
        mp4File = [MP4 retain];
        fileURL = [URL retain];
        attributes = [dict retain];

        status = SBQueueItemStatusReady;
    }

    return self;
}

+ (id)itemWithMP4:(MP42File*)MP4 url:(NSURL*)URL attributes:(NSDictionary*)dict
{
    return [[[SBQueueItem alloc] initWithMP4:MP4 url:URL attributes:dict] autorelease];
}

- (void)dealloc
{
    [attributes release];
    [fileURL release];
    [mp4File release];
}

@end
