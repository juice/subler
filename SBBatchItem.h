//
//  SBBatchItem.h
//  Subler
//
//  Created by Damiano Galassi on 16/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MP42File;

enum {
    SBBatchItemtatusUnknown = 0,
    SBBatchItemStatusReady,
    SBBatchItemStatusWorking,
    SBBatchItemStatusCompleted,
    SBBatchItemStatusFailed,
    SBBatchItemStatusCancelled,
};
typedef NSInteger SBBatchItemStatus;


@interface SBBatchItem : NSObject {
    MP42File *mp4File;
    NSURL   *fileURL;

    SBBatchItemStatus status;
    BOOL humanEdited;
}

@property (readonly) NSURL *URL;
@property (readonly) MP42File *mp4File;
@property (readwrite) SBBatchItemStatus status;

- (id)initWithURL:(NSURL*)URL;
+ (id)itemWithURL:(NSURL*)URL;

- (id)initWithMP4:(MP42File*)MP4;
+ (id)itemWithMP4:(MP42File*)MP4;

@end
