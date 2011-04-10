//
//  TheTVDB.h
//  Subler
//
//  Created by Douglas Stebila on 2011/01/27.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MetadataSearchController;

@interface TheTVDB : NSObject {
    NSString *seriesName;
	NSString *seriesLanguage;
    NSString *seasonNum;
    NSString *episodeNum;
    MetadataSearchController *callback;
    BOOL isCancelled;
}

#pragma mark Search for TV series name
- (void) searchForTVSeriesName:(NSString *)seriesName callback:(MetadataSearchController *) callback;
- (void) runSearchForTVSeriesNameThread:(id)param;

#pragma mark Search for episode metadata
- (void) searchForResults:(NSString *)seriesName seriesLanguage:(NSString *)_seriesLanguage seasonNum:(NSString *)seasonNum episodeNum:(NSString *)episodeNum callback:(MetadataSearchController *) callback;
- (void) runSearchForResultsThread:(id)param;

- (void) cancel;

+ (void) deleteCachedMetadata;

@end
