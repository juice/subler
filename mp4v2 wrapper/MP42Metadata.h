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
    MPAA_NR = 1,
    MPAA_G,
    MPAA_PG,
    MPAA_PG_13,
    MPAA_R,
    MPAA_NC_17,
    MPAA_UNRATED,
    US_TV_Y     = 9,
    US_TV_Y7,
    US_TV_G,
    US_TV_PG,
    US_TV_14,
    US_TV_MA,
    US_TV_UNRATED,
    UK_MOVIE_NR     = 17,
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
    UK_TV_CAUTION  = 29,
    DE_MOVIE_FSK_0 = 31,
    DE_MOVIE_FSK_6,
    DE_MOVIE_FSK_12,
    DE_MOVIE_FSK_16,
    DE_MOVIE_FSK_18,
    AU_MOVIE_G_0 = 37,
    AU_MOVIE_PG,
    AU_MOVIE_M,
    AU_MOVIE_MA_15,
    AU_MOVIE_R18,
    AU_TV_P = 43,
    AU_TV_C,
    AU_TV_G,
    AU_TV_PG,
    AU_TV_M,
    AU_TV_MA15,
    AU_TV_AV15,
    AU_TV_R18,
    FR_MOVIE_TOUT_PUBLIC = 52,
    FR_MOVIE_10,
    FR_MOVIE_12,
    FR_MOVIE_16,
    FR_MOVIE_18,
    FR_MOVIE_UNRATED,
    FR_TV_10 = 59,
    FR_TV_12,
    FR_TV_16,
    FR_TV_18,
    FR_TV_UNRATED,
    CA_MOVIE_G = 70,
    CA_MOVIE_PG,
    CA_MOVIE_14A,
    CA_MOVIE_18A,
    CA_MOVIE_R,
    CA_MOVIE_A,
    CA_TV_E = 77,
    CA_TV_C,     
    CA_TV_C8,
    CA_TV_G,
    CA_TV_PG,
    CA_TV_14,
    CA_TV_18,
    CA_TV_21,
    CH_MOVIE_0 = 86,
    CH_MOVIE_6,     
    CH_MOVIE_7,
    CH_MOVIE_10,
    CH_MOVIE_12,
    CH_MOVIE_14,
    CH_MOVIE_16,
    CH_MOVIE_18,

    R_UNKNOWN   = 95,
};

@interface MP42Metadata : NSObject <NSCoding, NSCopying> {
    NSString                *presetName;
    NSURL                   *sourceURL;
    NSMutableDictionary     *tagsDict;

    NSImage                 *artwork;
    NSURL                   *artworkURL;
    NSArray                 *artworkThumbURLs;
    NSArray                 *artworkFullsizeURLs;

    NSString *rating;

    uint8_t mediaKind;
    uint8_t contentRating;
    uint8_t hdVideo;
    uint8_t gapless;
    uint8_t podcast;
    BOOL isEdited;
    BOOL isArtworkEdited;
}

- (id) initWithSourceURL:(NSURL *)URL fileHandle:(MP4FileHandle)fileHandle;
- (NSArray *) availableMetadata;
- (NSArray *) writableMetadata;

- (NSArray *) availableRatings;
- (NSString *) ratingFromIndex: (NSInteger)index;
- (NSInteger) ratingIndexFromString: (NSString *)ratingString;

- (NSArray *) availableGenres;

- (void) removeTagForKey:(NSString *)aKey;
- (BOOL) setTag:(id)value forKey:(NSString *)key;
- (BOOL) setMediaKindFromString:(NSString *)mediaKindString;
- (BOOL) setContentRatingFromString:(NSString *)contentRatingString;
- (BOOL) setArtworkFromFilePath:(NSString *)imageFilePath;

- (BOOL) writeMetadataWithFileHandle: (MP4FileHandle *) fileHandle;

- (BOOL) mergeMetadata: (MP42Metadata *) newMetadata;

@property(readonly) NSMutableDictionary *tagsDict;

@property(readwrite, retain) NSString   *presetName;
@property(readwrite, retain) NSImage    *artwork;
@property(readwrite, retain) NSURL      *artworkURL;
@property(readwrite, retain) NSArray    *artworkThumbURLs;
@property(readwrite, retain) NSArray    *artworkFullsizeURLs;
@property(readwrite) uint8_t    mediaKind;
@property(readwrite) uint8_t    contentRating;
@property(readwrite) uint8_t    hdVideo;
@property(readwrite) uint8_t    gapless;
@property(readwrite) uint8_t    podcast;
@property(readwrite) BOOL       isEdited;
@property(readwrite) BOOL       isArtworkEdited;

@end
