//
//  MP42Metadata.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "mp4v2.h"

enum rating_type {
    MPAA_NR = 0,
    MPAA_G,
    MPAA_PG,
    MPAA_PG_13,
    MPAA_R,
    MPAA_NC_17,
    MPAA_UNRATED,
    US_TV_Y     = 8,
    US_TV_Y7,
    US_TV_G,
    US_TV_PG,
    US_TV_14,
    US_TV_MA,
    US_TV_UNRATED,
    UK_MOVIE_NR     = 16,
    UK_MOVIE_U,
    UK_MOVIE_Uc,
    UK_MOVIE_PG,
    UK_MOVIE_12,
    UK_MOVIE_12A,
    UK_MOVIE_15,
    UK_MOVIE_18,
    UK_MOVIE_R18,
    UK_MOVIE_E,
    UK_MOVIE_UNRATED,
    UK_TV_CAUTION  = 28,
    DE_MOVIE_FSK_0 = 30,
    DE_MOVIE_FSK_6,
    DE_MOVIE_FSK_12,
    DE_MOVIE_FSK_16,
    DE_MOVIE_FSK_18,
    R_UNKNOWN   = 36,
};

@interface MP42Metadata : NSObject {
    NSString                *sourcePath;
    NSMutableDictionary     *tagsDict;
    NSImage                 *artwork;
    NSURL                   *artworkURL;

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
- (NSString *) ratingFromIndex: (NSInteger)index;
- (NSInteger) ratingIndexFromString: (NSString *)ratingString;

- (void) removeTagForKey:(NSString *)aKey;
- (BOOL) setTag:(id)value forKey:(NSString *)key;
- (BOOL) setMediaKindFromString:(NSString *)mediaKindString;
- (BOOL) setContentRatingFromString:(NSString *)contentRatingString;
- (BOOL) setArtworkFromFilePath:(NSString *)imageFilePath;

- (BOOL) writeMetadataWithFileHandle: (MP4FileHandle *) fileHandle;

- (BOOL) mergeMetadata: (MP42Metadata *) newMetadata;

@property(readonly) NSMutableDictionary *tagsDict;
@property(readwrite, retain) NSImage    *artwork;
@property(readwrite, retain) NSURL    *artworkURL;
@property(readwrite) uint8_t    mediaKind;
@property(readwrite) uint8_t    contentRating;
@property(readwrite) uint8_t    hdVideo;
@property(readwrite) uint8_t    gapless;
@property(readwrite) BOOL       isEdited;
@property(readwrite) BOOL       isArtworkEdited;

@end
