//
//  MP42Metadata.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "mp4v2.h"

enum {
    MPAA_G      = 0,
    MPAA_PG     = 1,
    MPAA_PG_13  = 2,
    MPAA_R      = 3,
    MPAA_NC_17  = 4,
    US_TV_Y     = 6,
    US_TV_Y7    = 7,
    US_TV_G     = 8,
    US_TV_PG    = 9,
    US_TV_14    = 10,
    US_TV_MA    = 11,
} rating_type;

@interface MP42Metadata : NSObject {
    NSString                *sourcePath;
    NSMutableDictionary     *tagsDict;
    NSImage                 *artwork;

    uint8_t mediaKind;
    uint8_t contentRating;
    uint8_t hdVideo;
    uint8_t gapless;
    BOOL isEdited;
    BOOL isArtworkEdited;
}

- (id) initWithSourcePath:(NSString *)source fileHandle:(MP4FileHandle)fileHandle;
- (NSArray *) availableMetadata;
- (NSArray *) writableMetadata;

- (NSArray *) availableRatings;

- (void) removeTagForKey:(id)aKey;
- (BOOL) setTag:(id)value forKey:(NSString *)key;

- (BOOL) writeMetadataWithFileHandle: (MP4FileHandle *) fileHandle;

- (BOOL) mergeMetadata: (MP42Metadata *) newMetadata;

@property(readonly) NSMutableDictionary *tagsDict;
@property(readwrite, retain) NSImage    *artwork;
@property(readwrite) uint8_t    mediaKind;
@property(readwrite) uint8_t    contentRating;
@property(readwrite) uint8_t    hdVideo;
@property(readwrite) uint8_t    gapless;
@property(readwrite) BOOL       isEdited;
@property(readwrite) BOOL       isArtworkEdited;

@end
