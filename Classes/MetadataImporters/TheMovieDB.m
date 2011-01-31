//
//  themoviedb.m
//  Subler
//
//  Created by Douglas Stebila on 2011/01/28.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import "TheMovieDB.h"
#import "MetadataSearchController.h"
#import "MP42File.h"

@implementation TheMovieDB

#pragma mark Search for matching movies

- (void) searchForResults:(NSString *)aMovieTitle callback:(MetadataSearchController *)aCallback {
    mMovieTitle = aMovieTitle;
    mCallback = aCallback;
    [NSThread detachNewThreadSelector:@selector(runSearchForResultsThread:) toTarget:self withObject:nil];
}

- (void) runSearchForResultsThread:(id)param {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:1];
    NSString *url = [NSString stringWithFormat:@"http://api.themoviedb.org/2.1/Movie.search/en/xml/b0073bafb08b4f68df101eb2325f27dc/%@", [MetadataSearchController urlEncoded:mMovieTitle]];
    NSXMLDocument *xml = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL URLWithString:url] options:0 error:NULL];
    if (xml) {
        NSError *err;
        NSArray *nodes = [xml nodesForXPath:@"./OpenSearchDescription/movies/movie" error:&err];        
        for (NSXMLElement *node in nodes) {
            MP42Metadata *metadata = [TheMovieDB metadata:nil forNode:node];
            if (metadata) [results addObject:metadata];
        }
    }
    [mCallback searchForResultsDone:[[results retain] autorelease]];
    [pool release];
}

#pragma mark Load additional metadata

- (void) loadAdditionalMetadata:(MP42Metadata *)aMetadata callback:(MetadataSearchController *) aCallback {
    mMetadata = aMetadata;
    mCallback = aCallback;
    [NSThread detachNewThreadSelector:@selector(runLoadAdditionalMetadataThread:) toTarget:self withObject:nil];
}

- (void) runLoadAdditionalMetadataThread:(id) param {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *tmdbID = [mMetadata.tagsDict valueForKey:@"TMDb ID"];
    if (tmdbID && ([tmdbID length] > 0)) {
        NSString *url = [NSString stringWithFormat:@"http://api.themoviedb.org/2.1/Movie.getInfo/en/xml/b0073bafb08b4f68df101eb2325f27dc/%@", [MetadataSearchController urlEncoded:tmdbID]];
        NSXMLDocument *xml = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL URLWithString:url] options:0 error:NULL];
        if (xml) {
            NSError *err;
            NSArray *nodes = [xml nodesForXPath:@"./OpenSearchDescription/movies/movie" error:&err];
            if ([nodes count] == 1) {
                [TheMovieDB metadata:mMetadata forNode:[nodes objectAtIndex:0]];
            }
        }
    }
    [mCallback loadAdditionalMetadataDone:[[mMetadata retain] autorelease]];
    [pool release];
}

#pragma mark Parse metadata

+ (NSString *) nodes:(NSXMLElement *)node forXPath:(NSString *)query joinedBy:(NSString *)joiner {
    NSError *err;
    NSArray *tag = [node nodesForXPath:query error:&err];
    if ([tag count]) {
        NSMutableArray *elements = [[NSMutableArray alloc] initWithCapacity:[tag count]];
        NSEnumerator *tagEnum = [tag objectEnumerator];
        NSXMLNode *element;
        while (element = [tagEnum nextObject]) {
            [elements addObject:[element stringValue]];
        }
        return [elements componentsJoinedByString:@", "];
    } else {
        return nil;
    }
}

+ (MP42Metadata *) metadata:(MP42Metadata *)aMetadata forNode:(NSXMLElement *)node {
    MP42Metadata *metadata;
    if (aMetadata == nil) {
        metadata = [[MP42Metadata alloc] init];
    } else {
        metadata = aMetadata;
    }
    metadata.mediaKind = 9; // movie
    NSArray *tag;
    NSError *err;
    // initial fields from general movie search
    tag = [node nodesForXPath:@"./name" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Name"];
    tag = [node nodesForXPath:@"./released" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Release Date"];
    tag = [node nodesForXPath:@"./overview" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Description"];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Long Description"];
    tag = [node nodesForXPath:@"./certification" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Rating"];
    tag = [node nodesForXPath:@"./images/image[@type='poster'][@size='original']/@url" error:&err];
    if ([tag count]) [metadata setArtworkURL:[NSURL URLWithString:[[tag objectAtIndex:0] stringValue]]];
    tag = [node nodesForXPath:@"./id" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"TMDb ID"];
    // additional fields from detailed movie info
    NSString *joined;
    joined = [TheMovieDB nodes:node forXPath:@"./categories/category[@type='genre']/@name" joinedBy:@","];
    if (joined) [metadata setTag:joined forKey:@"Genre"];
    joined = [TheMovieDB nodes:node forXPath:@"./cast/person[@job='Actor']/@name" joinedBy:@","];
    if (joined) [metadata setTag:joined forKey:@"Cast"];
    joined = [TheMovieDB nodes:node forXPath:@"./cast/person[@job='Director']/@name" joinedBy:@","];
    if (joined) [metadata setTag:joined forKey:@"Director"];
    joined = [TheMovieDB nodes:node forXPath:@"./cast/person[@department='Writing']/@name" joinedBy:@","];
    if (joined) [metadata setTag:joined forKey:@"Screenwriters"];
    joined = [TheMovieDB nodes:node forXPath:@"./cast/person[@department='Production']/@name" joinedBy:@","];
    if (joined) [metadata setTag:joined forKey:@"Producers"];
    joined = [TheMovieDB nodes:node forXPath:@"./studios/studio/@name" joinedBy:@","];
    if (joined) [metadata setTag:joined forKey:@"Studio"];
    // TheMovieDB does not provide the following fields normally associated with TV shows in MP42Metadata:
    // "Copyright" "Artist"
    return metadata;
}

#pragma mark Finishing up

- (void) dealloc {
    [super dealloc];
}

@end
