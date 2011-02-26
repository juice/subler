//
//  themoviedb.h
//  Subler
//
//  Created by Douglas Stebila on 2011/01/28.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MetadataSearchController;
@class MP42Metadata;

@interface TheMovieDB : NSObject {
    NSString *mMovieTitle;
    MP42Metadata *mMetadata;
    MetadataSearchController *mCallback;
    BOOL isCancelled;
}

- (void) searchForResults:(NSString *)movieTitle callback:(MetadataSearchController *)callback;
- (void) runSearchForResultsThread:(id)param;

- (void) loadAdditionalMetadata:(MP42Metadata *)metadata callback:(MetadataSearchController *)callback;
- (void) runLoadAdditionalMetadataThread:(id)param;

- (void) cancel;

@end
