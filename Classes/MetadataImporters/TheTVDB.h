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
    NSString *seasonNum;
    NSString *episodeNum;
    MetadataSearchController *callback;
}

#pragma mark Search for TV series name
- (void) searchForTVSeriesName:(NSString *)seriesName callback:(MetadataSearchController *) callback;
- (void) runSearchForTVSeriesNameThread:(id)param;

#pragma mark Search for episode metadata
- (void) searchForResults:(NSString *)seriesName seasonNum:(NSString *)seasonNum episodeNum:(NSString *)episodeNum callback:(MetadataSearchController *) callback;
- (void) runSearchForResultsThread:(id)param;

#pragma mark Parse metadata
+ (NSString *) cleanPeopleList:(NSString *)s;
+ (NSArray *) metadataForResults:(NSDictionary *)results;

+ (void) deleteCachedMetadata;

@end
