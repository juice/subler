//
//  MP42Metadata.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "mp4v2.h"

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
