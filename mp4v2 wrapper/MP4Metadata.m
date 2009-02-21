//
//  MP4Metadata.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP4Metadata.h"
#import "MP4Utilities.h"

@implementation MP4Metadata

-(id)initWithSourcePath:(NSString *)source
{
	if ((self = [super init]))
	{
		sourcePath = source;
        tagsDict = [[NSMutableDictionary alloc] init];
	}
	[self readMetaData];
	edited = NO;

    return self;
}

-(void) readMetaData
{
    MP4FileHandle *sourceHandle = MP4Read([sourcePath UTF8String], 0);
    const MP4Tags* tags = MP4TagsAlloc();
    MP4TagsFetch( tags, sourceHandle );

    if (tags->name)
        [tagsDict setObject:[NSString stringWithCString:tags->name encoding: NSUTF8StringEncoding]
                     forKey:@" Name"];

    if (tags->artist)
        [tagsDict setObject:[NSString stringWithCString:tags->artist encoding: NSUTF8StringEncoding]
                     forKey:@"Artist"];

    if (tags->albumArtist)
        [tagsDict setObject:[NSString stringWithCString:tags->albumArtist encoding: NSUTF8StringEncoding]
                     forKey:@"Album Artist"];

    if (tags->album)
        [tagsDict setObject:[NSString stringWithCString:tags->album encoding: NSUTF8StringEncoding]
                     forKey:@"Album"];

    if (tags->grouping)
        [tagsDict setObject:[NSString stringWithCString:tags->grouping encoding: NSUTF8StringEncoding]
                     forKey:@"Grouping"];

    if (tags->composer)
        [tagsDict setObject:[NSString stringWithCString:tags->composer encoding: NSUTF8StringEncoding]
                     forKey:@"Composer"];

    if (tags->comments)
        [tagsDict setObject:[NSString stringWithCString:tags->comments encoding: NSUTF8StringEncoding]
                     forKey:@"Comments"];

    if (tags->genre)
        [tagsDict setObject:[NSString stringWithCString:tags->genre encoding: NSUTF8StringEncoding]
                     forKey:@"Genre"];

    if (tags->releaseDate)
        [tagsDict setObject:[NSString stringWithCString:tags->releaseDate encoding: NSUTF8StringEncoding]
                     forKey:@"Date"];

    if (tags->track)
        [tagsDict setObject:[NSString stringWithFormat:@"%d/%d", tags->track->index, tags->track->total]
                     forKey:@"Track #"];
    
    if (tags->disk)
        [tagsDict setObject:[NSString stringWithFormat:@"%d/%d", tags->disk->index, tags->disk->total]
                     forKey:@"Disk #"];

    if (tags->tvShow)
        [tagsDict setObject:[NSString stringWithCString:tags->tvShow encoding: NSUTF8StringEncoding]
                     forKey:@"TV Show"];

    if (tags->tvEpisodeID)
        [tagsDict setObject:[NSString stringWithCString:tags->tvEpisodeID encoding: NSUTF8StringEncoding]
                     forKey:@"TV Episode ID"];

    if (tags->tvSeason)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->tvSeason]
                     forKey:@"TV Season"];

    if (tags->tvEpisode)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->tvEpisode]
                     forKey:@"TV Episode"];

    if (tags->tvNetwork)
        [tagsDict setObject:[NSString stringWithCString:tags->tvNetwork encoding: NSUTF8StringEncoding]
                     forKey:@"TV Network"];

    if (tags->description)
        [tagsDict setObject:[NSString stringWithCString:tags->description encoding: NSUTF8StringEncoding]
                     forKey:@"Description"];

    if (tags->longDescription)
        [tagsDict setObject:[NSString stringWithCString:tags->longDescription encoding: NSUTF8StringEncoding]
                     forKey:@"Long Description"];

    if (tags->lyrics)
        [tagsDict setObject:[NSString stringWithCString:tags->lyrics encoding: NSUTF8StringEncoding]
                     forKey:@"Lyrics"];

    if (tags->copyright)
        [tagsDict setObject:[NSString stringWithCString:tags->copyright encoding: NSUTF8StringEncoding]
                     forKey:@"Copyright"];

    if (tags->encodingTool)
        [tagsDict setObject:[NSString stringWithCString:tags->encodingTool encoding: NSUTF8StringEncoding]
                     forKey:@"Encoding Tool"];

    if (tags->encodedBy)
        [tagsDict setObject:[NSString stringWithCString:tags->encodedBy encoding: NSUTF8StringEncoding]
                     forKey:@"Encoded By"];

    if (tags->hdVideo)
        hdVideo = *tags->hdVideo;

    if (tags->mediaType)
        mediaKind = *tags->mediaType;
    
    if (tags->contentRating)
        contentRating = *tags->contentRating;
    
    if (tags->gapless)
        gapless = *tags->gapless;


    if (tags->purchaseDate)
        [tagsDict setObject:[NSString stringWithCString:tags->purchaseDate encoding: NSUTF8StringEncoding]
                     forKey:@"Purchase Date"];

    if (tags->iTunesAccount)
        [tagsDict setObject:[NSString stringWithCString:tags->iTunesAccount encoding: NSUTF8StringEncoding]
                     forKey:@"iTunes Account"];
    
    if (tags->cnID)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->cnID]
                     forKey:@"cnID"];

    if (tags->artwork) {
        NSData *imageData = [NSData dataWithBytes:tags->artwork->data length:tags->artwork->size];
        NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
        if (imageRep != nil) {
            artwork = [[NSImage alloc] initWithSize:[imageRep size]];
            [artwork addRepresentation:imageRep];
        }
    }

    MP4TagsFree(tags);
    MP4Close(sourceHandle);
}

- (BOOL) writeMetadata
{
    MP4FileHandle *fileHandle = MP4Modify( [sourcePath UTF8String], MP4_DETAILS_ERROR, 0 );
    const MP4Tags* tags = MP4TagsAlloc();
    MP4TagsFetch( tags, fileHandle );

    MP4TagsSetName( tags, [[tagsDict valueForKey:@" Name"] UTF8String] );

    MP4TagsSetArtist( tags, [[tagsDict valueForKey:@"Artist"] UTF8String] );

    MP4TagsSetAlbumArtist( tags, [[tagsDict valueForKey:@"Album Artist"] UTF8String] );

    MP4TagsSetAlbum( tags, [[tagsDict valueForKey:@"Album"] UTF8String] );

    MP4TagsSetGrouping( tags, [[tagsDict valueForKey:@"Grouping"] UTF8String] );

    MP4TagsSetComposer( tags, [[tagsDict valueForKey:@"Composer"] UTF8String] );

    MP4TagsSetComments( tags, [[tagsDict valueForKey:@"Comments"] UTF8String] );

    MP4TagsSetGenre( tags, [[tagsDict valueForKey:@"Genre"] UTF8String] );

    MP4TagsSetReleaseDate( tags, [[tagsDict valueForKey:@"Date"] UTF8String] );

    MP4TagsSetTVShow( tags, [[tagsDict valueForKey:@"TV Show"] UTF8String] );
    
    MP4TagsSetTVNetwork( tags, [[tagsDict valueForKey:@"TV Network"] UTF8String] );
    
    MP4TagsSetTVEpisodeID( tags, [[tagsDict valueForKey:@"TV Episode ID"] UTF8String] );
    
    if ( [tagsDict valueForKey:@"TV Season"] ) {
        const uint32_t i = [[tagsDict valueForKey:@"TV Season"] integerValue];
        MP4TagsSetTVSeason( tags, &i );
    }
    else
        MP4TagsSetTVSeason( tags, NULL );
    
    if ( [tagsDict valueForKey:@"TV Episode"] ) {
        const uint32_t i = [[tagsDict valueForKey:@"TV Episode"] integerValue];
        MP4TagsSetTVEpisode( tags, &i );
    }
    else
        MP4TagsSetTVEpisode( tags, NULL );

    MP4TagsSetDescription( tags, [[tagsDict valueForKey:@"Description"] UTF8String] );

    MP4TagsSetLongDescription( tags, [[tagsDict valueForKey:@"Long Description"] UTF8String] );

    MP4TagsSetCopyright( tags, [[tagsDict valueForKey:@"Copyright"] UTF8String] );

    MP4TagsSetEncodingTool( tags, [[tagsDict valueForKey:@"Encoding Tool"] UTF8String] );

    MP4TagsSetEncodedBy( tags, [[tagsDict valueForKey:@"Encoded By"] UTF8String] );
    
    MP4TagsSetMediaType(tags, &mediaKind);
    
    MP4TagsSetHDVideo(tags, &hdVideo);
    
    MP4TagsSetGapless(tags, &gapless);
    
    if ( [tagsDict valueForKey:@"cnID"] ) {
        const uint32_t i = [[tagsDict valueForKey:@"cnID"] integerValue];
        MP4TagsSetCNID( tags, &i );
    }
    else
        MP4TagsSetCNID( tags, NULL );

    MP4TagsStore( tags, fileHandle );
    MP4TagsFree( tags );
    MP4Close( fileHandle );

    return YES;
}

@synthesize edited;
@synthesize artwork;
@synthesize mediaKind;
@synthesize contentRating;
@synthesize hdVideo;
@synthesize gapless;
@synthesize artwork;

-(void) dealloc
{
    [artwork release];
    [tagsDict release];
    [super dealloc];
}

@synthesize tagsDict;

@end
