//
//  TheTVDB.m
//  Subler
//
//  Created by Douglas Stebila on 2011/01/27.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import "TheTVDB.h"
#import "MetadataSearchController.h"
#import "MP42File.h"

@interface TheTVDB (Private)
#pragma mark Parse metadata
- (NSString *) cleanPeopleList:(NSString *)s;
- (NSArray *) metadataForResults:(NSDictionary *)results;
@end

@implementation TheTVDB

#pragma mark Search for TV series name

- (NSArray*) searchForTVSeriesName:(NSString *)_seriesName {
    seriesName = _seriesName;

    NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:3];
    NSURL *u = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"http://www.thetvdb.com/api/GetSeries.php?seriesname=%@", [MetadataSearchController urlEncoded:seriesName]]];
    if (u != nil) {
        NSXMLDocument *x = [[NSXMLDocument alloc] initWithContentsOfURL:u options:0 error:NULL];
        if (x != nil) {
            NSArray *nodes = [x nodesForXPath:@"./Data/Series" error:NULL];
            for (NSXMLElement *element in nodes) {
                NSArray *node = [element nodesForXPath:@"./SeriesName" error:NULL];
                if ([node count]) [results addObject:[[node objectAtIndex:0] stringValue]];
            }
        }
        [x release];
    }

    [u release];

    return [results autorelease];
}

- (void) searchForTVSeriesName:(NSString *)_seriesName callback:(MetadataSearchController *)_callback {
    callback = _callback;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSArray *results = [self searchForTVSeriesName:_seriesName];

        if (!isCancelled)
            [callback performSelectorOnMainThread:@selector(searchForTVSeriesNameDone:) withObject:results waitUntilDone:YES];

        [pool release];
    });
}

#pragma mark Search for episode metadata

- (NSArray*) searchForResults:(NSString *)_seriesName seriesLanguage:(NSString *)_seriesLanguage seasonNum:(NSString *)_seasonNum episodeNum:(NSString *)_episodeNum
{
    seriesName = _seriesName;
    seasonNum = _seasonNum;
    episodeNum = _episodeNum;
	seriesLanguage = _seriesLanguage;

    // load data from tvdb via python on command line
    NSMutableArray *args = [[NSMutableArray alloc] initWithCapacity:4];
    [args addObject:@"tvdb_main.py"];
    [args addObject:seriesName];
	[args addObject:seriesLanguage];
    if ([seasonNum length]) [args addObject:seasonNum];
    if ([episodeNum length]) [args addObject:episodeNum];
    NSPipe *outputPipe = [NSPipe pipe];
    NSTask *cmd = [[NSTask alloc] init];
    [cmd setArguments:args];
    [cmd setCurrentDirectoryPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"tvdb_py" ofType:@""]];
    [cmd setLaunchPath:@"/usr/bin/python"];
    [cmd setStandardOutput:outputPipe];
    [cmd launch];
    [cmd waitUntilExit];
    // read output into dictionary
    NSFileHandle *outputFile = [outputPipe fileHandleForReading];
    NSData *outputData = [outputFile readDataToEndOfFile];
    NSString *plistFilename = [[[[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding] autorelease] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:plistFilename];
    // construct result
    NSArray *results = [self metadataForResults:plist];
    if ([[NSFileManager defaultManager] fileExistsAtPath:plistFilename])
        [[NSFileManager defaultManager] removeItemAtPath:plistFilename error:NULL];
    // return results

    [args release];
    [cmd release];

    return results;
}

- (void) searchForResults:(NSString *)_seriesName seriesLanguage:(NSString *)_seriesLanguage seasonNum:(NSString *)_seasonNum episodeNum:(NSString *)_episodeNum callback:(MetadataSearchController *) _callback
{
    callback = _callback;

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSArray *results = [self searchForResults:_seriesName seriesLanguage:_seriesLanguage seasonNum:_seasonNum episodeNum:_episodeNum];

        // return results
        if (!isCancelled)
            [callback performSelectorOnMainThread:@selector(searchForResultsDone:) withObject:results waitUntilDone:YES];

        [pool release];
    });
}

#pragma mark Parse metadata

- (NSString *) cleanPeopleList:(NSString *)s {
    NSArray *a = [[[s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] 
                          stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"|"]] 
                         componentsSeparatedByString:@"|"];
    return [a componentsJoinedByString:@", "];
}

- (NSArray *) metadataForResults:(NSDictionary *)dict {
    NSMutableArray *returnArray = [[NSMutableArray alloc] initWithCapacity:1];
    NSArray *episodesList = [dict valueForKey:@"episodes"];
    NSEnumerator *episodesEnum = [episodesList objectEnumerator];
    NSDictionary *episodeDict;
    while ((episodeDict = (NSDictionary *) [episodesEnum nextObject])) {
        MP42Metadata *metadata = [[MP42Metadata alloc] init];
        metadata.mediaKind = 10; // TV show
        [metadata setTag:[dict valueForKey:@"seriesname"] forKey:@"TV Show"];
        [metadata setTag:[episodeDict valueForKey:@"seasonnumber"] forKey:@"TV Season"];
        [metadata setTag:[episodeDict valueForKey:@"episodenumber"] forKey:@"TV Episode #"];
        [metadata setTag:[episodeDict valueForKey:@"productioncode"] forKey:@"TV Episode ID"];
        [metadata setTag:[episodeDict valueForKey:@"seasonnumber"] forKey:@"TV Season"];
        [metadata setTag:[episodeDict valueForKey:@"episodename"] forKey:@"Name"];
        [metadata setTag:[episodeDict valueForKey:@"firstaired"] forKey:@"Release Date"];
        [metadata setTag:[episodeDict valueForKey:@"overview"] forKey:@"Description"];
        [metadata setTag:[episodeDict valueForKey:@"overview"] forKey:@"Long Description"];
        [metadata setTag:[self cleanPeopleList:[episodeDict valueForKey:@"director"]] forKey:@"Director"];
        [metadata setTag:[self cleanPeopleList:[episodeDict valueForKey:@"writer"]] forKey:@"Screenwriters"];
        [metadata setTag:[episodeDict valueForKey:@"episodenumber"] forKey:@"Track #"];
        // artwork
        NSMutableArray *artworkThumbURLs = [[NSMutableArray alloc] initWithCapacity:10];
        NSMutableArray *artworkFullsizeURLs = [[NSMutableArray alloc] initWithCapacity:10];
        NSURL *u;
        if ([episodeDict valueForKey:@"filename"]) {
            u = [NSURL URLWithString:[episodeDict valueForKey:@"filename"]];
            [artworkThumbURLs addObject:u];
            [artworkFullsizeURLs addObject:u];
        }
        if ([dict valueForKey:@"artwork_season"]) {
            NSString *s;
            NSEnumerator *e = [((NSArray *) [dict valueForKey:@"artwork_season"]) objectEnumerator];
            while ((s = (NSString *) [e nextObject])) {
                u = [NSURL URLWithString:s];
                [artworkThumbURLs addObject:u];
                [artworkFullsizeURLs addObject:u];
            }
        }
        if ([dict valueForKey:@"artwork_posters"]) {
            NSString *s;
            NSEnumerator *e = [((NSArray *) [dict valueForKey:@"artwork_posters"]) objectEnumerator];
            while ((s = (NSString *) [e nextObject])) {
                u = [NSURL URLWithString:s];
                [artworkThumbURLs addObject:u];
                [artworkFullsizeURLs addObject:u];
            }
        }
        [metadata setArtworkThumbURLs: artworkThumbURLs];
        [metadata setArtworkFullsizeURLs: artworkFullsizeURLs];
        
        [artworkThumbURLs release];
        [artworkFullsizeURLs release];

        // cast
        NSString *actors = [((NSArray *) [dict valueForKey:@"actors"]) componentsJoinedByString:@", "];
        NSString *gueststars = [self cleanPeopleList:[episodeDict valueForKey:@"gueststars"]];
        if ([actors length]) {
            if ([gueststars length]) {
                [metadata setTag:[NSString stringWithFormat:@"%@, %@", actors, gueststars] forKey:@"Cast"];
            } else {
                [metadata setTag:actors forKey:@"Cast"];
            }
        } else {
            if ([gueststars length]) {
                [metadata setTag:gueststars forKey:@"Cast"];
            }
        }
        // TheTVDB does not provide the following fields normally associated with TV shows in MP42Metadata:
        // "TV Network", "Genre", "Copyright", "Comments", "Rating", "Producers", "Artist"
        [returnArray addObject:metadata];
        [metadata release];
    }
    return [returnArray autorelease];
}

#pragma mark Finishing up

- (void) dealloc {
    callback = nil;

    [super dealloc];
}

- (void)cancel
{
    @synchronized(self) {
        isCancelled = YES;
    }
}

#pragma mark Privacy

+ (void) deleteCachedMetadata {
    NSMutableArray *args = [[NSMutableArray alloc] initWithCapacity:4];
    [args addObject:@"-c"];
    [args addObject:@"import tempfile\nprint tempfile.gettempdir()"];
    NSPipe *outputPipe = [NSPipe pipe];
    NSTask *cmd = [[NSTask alloc] init];
    [cmd setArguments:args];
    [cmd setLaunchPath:@"/usr/bin/python"];
    [cmd setStandardOutput:outputPipe];
    [cmd launch];
    [cmd waitUntilExit];
    // read output into dictionary
    NSFileHandle *outputFile = [outputPipe fileHandleForReading];
    NSData *outputData = [outputFile readDataToEndOfFile];
    NSString *output = [[[[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding] autorelease] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [[NSFileManager defaultManager] removeItemAtPath:[output stringByAppendingPathComponent:@"tvdb_api"] error:NULL];

    [cmd release];
    [args release];
}

@end
