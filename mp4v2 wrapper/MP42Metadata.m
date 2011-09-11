//
//  MP42Metadata.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42Metadata.h"
#import "MP42Utilities.h"
#import "RegexKitLite.h"

typedef struct mediaKind_t
{
    uint8_t stik;
    NSString *english_name;
} mediaKind_t;

static const mediaKind_t mediaKind_strings[] = {
    {1, @"Music"},
    {2, @"Audiobook"},
    {6, @"Music Video"},
    {9, @"Movie"},
    {10, @"TV Show"},
    {11, @"Booklet"},
    {14, @"Ringtone"},  
    {0, NULL},
};

typedef struct contentRating_t
{
    uint8_t rtng;
    NSString *english_name;
} contentRating_t;

static const contentRating_t contentRating_strings[] = {
    {0, @"None"},
    {2, @"Clean"},
    {4, @"Explicit"},
    {0, NULL},
};

typedef struct iTMF_rating_t
{
    const char * rating;
    const char * english_name;
} iTMF_rating_t;

static const iTMF_rating_t rating_strings[] = {
    {"--", "-- United States"},
    {"mpaa|NR|000|", "Not Rated"},          // 1
    {"mpaa|G|100|", "G"},
    {"mpaa|PG|200|", "PG"},
    {"mpaa|PG-13|300|", "PG-13"},
    {"mpaa|R|400|", "R" },
    {"mpaa|NC-17|500|", "NC-17"},
    {"mpaa|Unrated|???|", "Unrated"},
    {"--", ""},
    {"us-tv|TV-Y|100|", "TV-Y"},            // 9
    {"us-tv|TV-Y7|200|", "TV-Y7"},
    {"us-tv|TV-G|300|", "TV-G"},
    {"us-tv|TV-PG|400|", "TV-PG"},
    {"us-tv|TV-14|500|", "TV-14"},
    {"us-tv|TV-MA|600|", "TV-MA"},
    {"us-tv|Unrated|???|", "Unrated"},
    {"--", "-- United Kingdom"},
    {"uk-movie|NR|000|", "Not Rated"},      // 17
    {"uk-movie|U|100|", "U"},
    {"uk-movie|Uc|150|", "Uc"},
    {"uk-movie|PG|200|", "PG"},
    {"uk-movie|12|300|", "12"},
    {"uk-movie|12A|325|", "12A"},
    {"uk-movie|15|350|", "15"},
    {"uk-movie|18|400|", "18"},
    {"uk-movie|R18|600|", "R18"},
    {"uk-movie|E|0|", "Exempt" },
    {"uk-movie|Unrated|???|", "Unrated"},
    {"--", ""},
    {"uk-tv|Caution|500|", "Caution"},      // 29
    {"--", "-- Germany"},
    {"de-movie|ab 0 Jahren|75|", "ab 0 Jahren"},		// 31
    {"de-movie|ab 6 Jahren|100|", "ab 6 Jahren"},
    {"de-movie|ab 12 Jahren|200|", "ab 12 Jahren"},
    {"de-movie|ab 16 Jahren|500|", "ab 16 Jahren"},
    {"de-movie|ab 18 Jahren|600|", "ab 18 Jahren"},
    {"--", ""},
    {"de-tv|ab 0 Jahren|75|", "ab 0 Jahren"},		// 37
    {"de-tv|ab 6 Jahren|100|", "ab 6 Jahren"},
    {"de-tv|ab 12 Jahren|200|", "ab 12 Jahren"},
    {"de-tv|ab 16 Jahren|500|", "ab 16 Jahren"},
    {"de-tv|ab 18 Jahren|600|", "ab 18 Jahren"},
    {"--", "-- Australia"},
    {"au-movie|G|100|", "G"},               // 43
    {"au-movie|PG|200|", "PG"},
    {"au-movie|M|350|", "M"},
    {"au-movie|MA15+|375|", "MA 15+"},
    {"au-movie|R18+|400|", "R18+"},
    {"--", ""},
    {"au-tv|P|100|", "P"},                  // 49
    {"au-tv|C|200|", "C"},
    {"au-tv|G|300|", "G"},
    {"au-tv|PG|400|", "PG"},
    {"au-tv|M|500|", "M"},
    {"au-tv|MA15+|550|", "MA 15+"},
    {"au-tv|AV15+|575|", "AV 15+"},
    {"au-tv|R18+|600|", "R18+"},
    {"--", "-- France"},
    {"fr-movie|Tout Public|100|", "Tout Public"},     // 58
    {"fr-movie|-10|100|", "-10"},
    {"fr-movie|-12|300|", "-12"},
    {"fr-movie|-16|375|", "-16"},
    {"fr-movie|-18|400|", "-18"},
    {"fr-movie|Unrated|???|", "Unrated"},
    {"--", ""},
    {"fr-tv|-10|100|", "-10"},              // 65
    {"fr-tv|-12|200|", "-12"},
    {"fr-tv|-16|500|", "-16"},
    {"fr-tv|-18|600|", "-18"},
    {"--", "-- Canada"},
    {"ca-movie|G|100|", "G"},               // 70
    {"ca-movie|PG|200|", "PG"},
    {"ca-movie|14A|300|", "14A"},
    {"ca-movie|18A|350|", "18A"},
    {"ca-movie|R|400|", "R"},
    {"ca-movie|A|500|", "A"},
    {"--", ""},
    {"ca-tv|TV-E|000|", "TV-E"},              // 77
    {"ca-tv|TV-C|50|", "TV-C"},
    {"ca-tv|TV-C8|75|", "TV-C8"},
    {"ca-tv|TV-G|100|", "TV-G"},
    {"ca-tv|TV-PG|200|", "TV-PG"},
    {"ca-tv|TV-14+|300|", "TV-14+"},
    {"ca-tv|TV-18+|350|", "TV-18+"},
    {"ca-tv|TV-21+|500|", "TV-21+"},
    {"--", ""},
    {"--", "Unknown"},                      // 85
    {NULL, NULL},
};

typedef struct genreType_t
{
    uint8_t index;
    const char *short_name;
    const char *english_name;
} genreType_t;

static const genreType_t genreType_strings[] = {
    {1,   "blues",             "Blues" },
    {2,   "classicrock",       "Classic Rock" },
    {3,   "country",           "Country" },
    {4,   "dance",             "Dance" },
    {5,   "disco",             "Disco" },
    {6,   "funk",              "Funk" },
    {7,   "grunge",            "Grunge" },
    {8,   "hiphop",            "Hop-Hop" },
    {9,   "jazz",              "Jazz" },
    {10,  "metal",             "Metal" },
    {11,  "newage",            "New Age" },
    {12,  "oldies",            "Oldies" },
    {13,  "other",             "Other" },
    {14,  "pop",               "Pop" },
    {15,  "rand_b",            "R&B" },
    {16,  "rap",               "Rap" },
    {17,  "reggae",            "Reggae" },
    {18,  "rock",              "Rock" },
    {19,  "techno",            "Techno" },
    {20,  "industrial",        "Industrial" },
    {21,  "alternative",       "Alternative" },
    {22,  "ska",               "Ska" },
    {23,  "deathmetal",        "Death Metal" },
    {24,  "pranks",            "Pranks" },
    {25,  "soundtrack",        "Soundtrack" },
    {26,  "eurotechno",        "Euro-Techno" },
    {27,  "ambient",           "Ambient" },
    {28,  "triphop",           "Trip-Hop" },
    {29,  "vocal",             "Vocal" },
    {30,  "jazzfunk",          "Jazz+Funk" },
    {31,  "fusion",            "Fusion" },
    {32,  "trance",            "Trance" },
    {33,  "classical",         "Classical" },
    {34,  "instrumental",      "Instrumental" },
    {35,  "acid",              "Acid" },
    {36,  "house",             "House" },
    {37,  "game",              "Game" },
    {38,  "soundclip",         "Sound Clip" },
    {39,  "gospel",            "Gospel" },
    {40,  "noise",             "Noise" },
    {41,  "alternrock",        "AlternRock" },
    {42,  "bass",              "Bass" },
    {43,  "soul",              "Soul" },
    {44,  "punk",              "Punk" },
    {45,  "space",             "Space" },
    {46,  "meditative",        "Meditative" },
    {47,  "instrumentalpop",   "Instrumental Pop" },
    {48,  "instrumentalrock",  "Instrumental Rock" },
    {49,  "ethnic",            "Ethnic" },
    {50,  "gothic",            "Gothic" },
    {51,  "darkwave",          "Darkwave" },
    {52,  "technoindustrial",  "Techno-Industrial" },
    {53,  "electronic",        "Electronic" },
    {54,  "popfolk",           "Pop-Folk" },
    {55,  "eurodance",         "Eurodance" },
    {56,  "dream",             "Dream" },
    {57,  "southernrock",      "Southern Rock" },
    {58,  "comedy",            "Comedy" },
    {59,  "cult",              "Cult" },
    {60,  "gangsta",           "Gangsta" },
    {61,  "top40",             "Top 40" },
    {62,  "christianrap",      "Christian Rap" },
    {63,  "popfunk",           "Pop/Funk" },
    {64,  "jungle",            "Jungle" },
    {65,  "nativeamerican",    "Native American" },
    {66,  "cabaret",           "Cabaret" },
    {67,  "newwave",           "New Wave" },
    {68,  "psychedelic",       "Psychedelic" },
    {69,  "rave",              "Rave" },
    {70,  "showtunes",         "Showtunes" },
    {71,  "trailer",           "Trailer" },
    {72,  "lofi",              "Lo-Fi" },
    {73,  "tribal",            "Tribal" },
    {74,  "acidpunk",          "Acid Punk" },
    {75,  "acidjazz",          "Acid Jazz" },
    {76,  "polka",             "Polka" },
    {77,  "retro",             "Retro" },
    {78,  "musical",           "Musical" },
    {79,  "rockand_roll",      "Rock & Roll" },
    
    {80,  "hardrock",          "Hard Rock" },
    {81,  "folk",              "Folk" },
    {82,  "folkrock",          "Folk-Rock" },
    {83,  "nationalfolk",      "National Folk" },
    {84,  "swing",             "Swing" },
    {85,  "fastfusion",        "Fast Fusion" },
    {86,  "bebob",             "Bebob" },
    {87,  "latin",             "Latin" },
    {88,  "revival",           "Revival" },
    {89,  "celtic",            "Celtic" },
    {90,  "bluegrass",         "Bluegrass" },
    {91,  "avantgarde",        "Avantgarde" },
    {92,  "gothicrock",        "Gothic Rock" },
    {93,  "progressiverock",   "Progresive Rock" },
    {94,  "psychedelicrock",   "Psychedelic Rock" },
    {95,  "symphonicrock",     "SYMPHONIC_ROCK" },
    {96,  "slowrock",          "Slow Rock" },
    {97,  "bigband",           "Big Band" },
    {98,  "chorus",            "Chorus" },
    {99,  "easylistening",     "Easy Listening" },
    {100, "acoustic",          "Acoustic" },
    {101, "humour",            "Humor" },
    {102, "speech",            "Speech" },
    {103, "chanson",           "Chason" },
    {104, "opera",             "Opera" },
    {105, "chambermusic",      "Chamber Music" },
    {106, "sonata",            "Sonata" },
    {107, "symphony",          "Symphony" },
    {108, "bootybass",         "Booty Bass" },
    {109, "primus",            "Primus" },
    {110, "porngroove",        "Porn Groove" },
    {111, "satire",            "Satire" },
    {112, "slowjam",           "Slow Jam" },
    {113, "club",              "Club" },
    {114, "tango",             "Tango" },
    {115, "samba",             "Samba" },
    {116, "folklore",          "Folklore" },
    {117, "ballad",            "Ballad" },
    {118, "powerballad",       "Power Ballad" },
    {119, "rhythmicsoul",      "Rhythmic Soul" },
    {120, "freestyle",         "Freestyle" },
    {121, "duet",              "Duet" },
    {122, "punkrock",          "Punk Rock" },
    {123, "drumsolo",          "Drum Solo" },
    {124, "acapella",          "A capella" },
    {125, "eurohouse",         "Euro-House" },
    {126, "dancehall",         "Dance Hall" },
    {255, "none",              "none" },
    
    {0, "undefined" } // must be last
};

@interface MP42Metadata (Private)

-(void) readMetaDataFromFileHandle:(MP4FileHandle)fileHandle;

@end

@implementation MP42Metadata

-(id)init
{
	if ((self = [super init]))
	{
        presetName = @"Unnamed Set";
		sourceURL = nil;
        tagsDict = [[NSMutableDictionary alloc] init];
        isEdited = NO;
        isArtworkEdited = NO;
	}

    return self;
}

-(id)initWithSourceURL:(NSURL *)URL fileHandle:(MP4FileHandle)fileHandle
{
	if ((self = [super init]))
	{
		sourceURL = URL;
        tagsDict = [[NSMutableDictionary alloc] init];

        [self readMetaDataFromFileHandle: fileHandle];
        isEdited = NO;
        isArtworkEdited = NO;
	}

    return self;
}

- (NSString*) stringFromArray:(NSArray *)array
{
    NSString *result = [NSString string];
    for (NSDictionary* name in array) {
        if ([result length])
            result = [result stringByAppendingString:@", "];
        result = [result stringByAppendingString:[name valueForKey:@"name"]];
    }
    return result;
}

- (NSArray *) dictArrayFromString:(NSString *)data
{
    NSString *splitElements  = @",\\s+";
    NSArray *stringArray = [data componentsSeparatedByRegex:splitElements];
    NSMutableArray *dictElements = [[[NSMutableArray alloc] init] autorelease];
    for (NSString *name in stringArray) {
        [dictElements addObject:[NSDictionary dictionaryWithObject:name forKey:@"name"]];
    }
    return dictElements;
}

- (NSArray *) availableMetadata
{
    return [NSArray arrayWithObjects:  @"Name", @"Artist", @"Album Artist", @"Album", @"Grouping", @"Composer",
			@"Comments", @"Genre", @"Release Date", @"Track #", @"Disk #", @"Tempo", @"TV Show", @"TV Episode #",
			@"TV Network", @"TV Episode ID", @"TV Season", @"Description", @"Long Description", @"Rating", @"Rating Annotation",
            @"Studio", @"Cast", @"Director", @"Codirector", @"Producers", @"Screenwriters",
            @"Lyrics", @"Copyright", @"Encoding Tool", @"Encoded By", @"Keywords", @"Category", @"contentID", @"artistID", @"playlistID", @"genreID", @"composerID",
            @"XID", @"iTunes Account", @"Sort Name", @"Sort Artist", @"Sort Album Artist", @"Sort Album", @"Sort Composer", @"Sort TV Show", nil];
}

- (NSArray *) writableMetadata
{
    return [NSArray arrayWithObjects:  @"Name", @"Artist", @"Album Artist", @"Album", @"Grouping", @"Composer",
			@"Comments", @"Genre", @"Release Date", @"Track #", @"Disk #", @"Tempo", @"TV Show", @"TV Episode #",
			@"TV Network", @"TV Episode ID", @"TV Season", @"Cast", @"Director", @"Codirector", @"Producers", @"Screenwriters",
            @"Studio", @"Description", @"Long Description", @"Rating", @"Rating Annotation",
			@"Lyrics", @"Copyright", @"Encoding Tool", @"Encoded By", @"Keywords", @"Category", @"contentID", @"artistID", @"playlistID", @"genreID", @"composerID",
            @"XID", @"iTunes Account", @"Sort Name",
            @"Sort Artist", @"Sort Album Artist", @"Sort Album", @"Sort Composer", @"Sort TV Show", nil];
}

- (BOOL) setMediaKindFromString:(NSString *)mediaKindString;
{
    mediaKind_t *mediaKindList;
    for (mediaKindList = (mediaKind_t*) mediaKind_strings; mediaKindList->english_name; mediaKindList++) {
        if ([mediaKindString isEqualToString:mediaKindList->english_name]) {
            mediaKind = mediaKindList->stik;
            return YES;      
        }
    }
    return NO;
}

- (BOOL) setContentRatingFromString:(NSString *)contentRatingString;
{
    contentRating_t *contentRatingList;
    for ( contentRatingList = (contentRating_t*) contentRating_strings; contentRatingList->english_name; contentRatingList++) {
        if ([contentRatingString isEqualToString:contentRatingList->english_name]) {
            contentRating = contentRatingList->rtng;
            return YES;      
        }
    }
    return NO;
}

- (BOOL) setArtworkFromFilePath:(NSString *)imageFilePath;
{
    if(imageFilePath != nil && [imageFilePath length] > 0) {
        NSImage *artworkImage = nil;
        artworkImage = [[NSImage alloc] initByReferencingFile:imageFilePath];
        if([artworkImage isValid]) {
            [artwork release];
            artwork = artworkImage;
            isEdited =YES;
            isArtworkEdited = YES;
            return YES;
        } else {
            [artworkImage release];
            return NO;
        }
    } else {
        [artwork release];
        artwork = nil;
        isEdited =YES;
        isArtworkEdited = YES;
        return YES;
    }
}

- (NSArray *) availableRatings
{
    NSMutableArray *ratingsArray = [[NSMutableArray alloc] init];
    iTMF_rating_t *rating;
    for ( rating = (iTMF_rating_t*) rating_strings; rating->english_name; rating++ )
        [ratingsArray addObject:[NSString stringWithUTF8String:rating->english_name]];

    return [ratingsArray autorelease];
}

- (NSString *) genreFromIndex: (NSInteger)index {
    if ((index >= 0 && index < 127) || index == 255) {
        genreType_t *genre = (genreType_t*) genreType_strings;
        genre += index - 1;
        return [NSString stringWithUTF8String:genre->english_name];
    }
    else return nil;
}

- (NSInteger) genreIndexFromString: (NSString *)genreString {
    NSInteger genreIndex = 0;
    genreType_t *genreList;
    NSInteger k = 0;
    for ( genreList = (genreType_t*) genreType_strings; genreList->english_name; genreList++, k++ ) {
        if ([genreString isEqualToString:[NSString stringWithUTF8String:genreList->english_name]])
            genreIndex = k + 1;
    }
    return genreIndex;
}

- (NSString *) ratingFromIndex: (NSInteger)index {
    iTMF_rating_t *rating = (iTMF_rating_t*) rating_strings;
    rating += index;
    return [NSString stringWithUTF8String:rating->english_name];    
}

- (NSInteger) ratingIndexFromString: (NSString *)ratingString{
    NSInteger ratingIndex = 0;
    iTMF_rating_t *ratingList;
    NSInteger k = 0;
    for ( ratingList = (iTMF_rating_t*) rating_strings; ratingList->english_name; ratingList++, k++ ) {
        if ([ratingString isEqualToString:[NSString stringWithUTF8String:ratingList->english_name]])
            ratingIndex = k;
    }
    return ratingIndex;
}

- (NSArray *) availableGenres
{
    return [NSArray arrayWithObjects:  @"Animation", @"Classic TV", @"Comedy", @"Drama", 
            @"Fitness & Workout", @"Kids", @"Non-Fiction", @"Reality TV", @"Sci-Fi & Fantasy",
            @"Sports", nil];
}

- (void) removeTagForKey:(NSString *)aKey
{
    [tagsDict removeObjectForKey:aKey];
    isEdited = YES;
}

- (BOOL) setTag:(id)value forKey:(NSString *)key;
{
    NSString *regexPositive = @"YES|Yes|yes|1";

    if ([key isEqualToString:@"HD Video"]) {
        if( value != nil && [value length] > 0 && [value isMatchedByRegex:regexPositive]) {
            hdVideo = 1;
            isEdited = YES;
        }
        else {
            hdVideo = 0;
            isEdited = YES;
        }
            return YES;
    }
    else if ([key isEqualToString:@"Gapless"]) {
        if( value != nil && [value length] > 0 && [value isMatchedByRegex:regexPositive]) {
            gapless = 1;
            isEdited = YES;
        }
        else {
            gapless = 0;
            isEdited = YES;
        }
        return YES;
    }
    else if ([key isEqualToString:@"Content Rating"]) {
        isEdited = YES;
        return [self setContentRatingFromString:value];
        
    }
    else if ([key isEqualToString:@"Media Kind"]) {
        isEdited = YES;
        return [self setMediaKindFromString:value];
    }
    else if ([key isEqualToString:@"Artwork"])
        return [self setArtworkFromFilePath:value];
    
    else if ([key isEqualToString:@"Rating"] && ![[tagsDict valueForKey:key] isEqualTo:value]) {
        if ([value isKindOfClass:[NSNumber class]])
            [tagsDict setValue:value forKey:key];
        else {
            NSString *rating_index = [[NSNumber numberWithInt:[self ratingIndexFromString:value]] stringValue];
            [tagsDict setValue:rating_index forKey:key];
        }

        isEdited = YES;
        return YES;
    }

    else if (![[tagsDict valueForKey:key] isEqualTo:value]) {
        [tagsDict setValue:value forKey:key];
        isEdited = YES;
        return YES;
    }
    else
        return NO;
}

- (NSString *) stringFromMetadata:(const char*)cString {
    NSString *string;
    
    if ((string = [NSString stringWithCString:cString encoding: NSUTF8StringEncoding]))
        return string;

    if ((string = [NSString stringWithCString:cString encoding: NSASCIIStringEncoding]))
        return string;
    
    if ((string = [NSString stringWithCString:cString encoding: NSUTF16StringEncoding]))
        return string;

    return @"";
}

-(void) readMetaDataFromFileHandle:(MP4FileHandle)sourceHandle
{
    const MP4Tags* tags = MP4TagsAlloc();
    MP4TagsFetch( tags, sourceHandle );

    if (tags->name)
        [tagsDict setObject:[self stringFromMetadata:tags->name]
                     forKey:@"Name"];

    if (tags->artist)
        [tagsDict setObject:[self stringFromMetadata:tags->artist]
                     forKey:@"Artist"];

    if (tags->albumArtist)
        [tagsDict setObject:[self stringFromMetadata:tags->albumArtist]
                     forKey:@"Album Artist"];

    if (tags->album)
        [tagsDict setObject:[self stringFromMetadata:tags->album]
                     forKey:@"Album"];

    if (tags->grouping)
        [tagsDict setObject:[self stringFromMetadata:tags->grouping]
                     forKey:@"Grouping"];

    if (tags->composer)
        [tagsDict setObject:[self stringFromMetadata:tags->composer]
                     forKey:@"Composer"];

    if (tags->comments)
        [tagsDict setObject:[self stringFromMetadata:tags->comments]
                     forKey:@"Comments"];

    if (tags->genre)
        [tagsDict setObject:[self stringFromMetadata:tags->genre]
                     forKey:@"Genre"];
    
    if (tags->genreType && !tags->genre) {
        [tagsDict setObject:[self genreFromIndex:*tags->genreType]
                     forKey:@"Genre"];
    }

    if (tags->releaseDate)
        [tagsDict setObject:[self stringFromMetadata:tags->releaseDate]
                     forKey:@"Release Date"];

    if (tags->track)
        [tagsDict setObject:[NSString stringWithFormat:@"%d/%d", tags->track->index, tags->track->total]
                     forKey:@"Track #"];
    
    if (tags->disk)
        [tagsDict setObject:[NSString stringWithFormat:@"%d/%d", tags->disk->index, tags->disk->total]
                     forKey:@"Disk #"];

    if (tags->tempo)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->tempo]
                     forKey:@"Tempo"];

    if (tags->tvShow)
        [tagsDict setObject:[self stringFromMetadata:tags->tvShow]
                     forKey:@"TV Show"];

    if (tags->tvEpisodeID)
        [tagsDict setObject:[self stringFromMetadata:tags->tvEpisodeID]
                     forKey:@"TV Episode ID"];

    if (tags->tvSeason)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->tvSeason]
                     forKey:@"TV Season"];

    if (tags->tvEpisode)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->tvEpisode]
                     forKey:@"TV Episode #"];

    if (tags->tvNetwork)
        [tagsDict setObject:[self stringFromMetadata:tags->tvNetwork]
                     forKey:@"TV Network"];

    if (tags->description)
        [tagsDict setObject:[self stringFromMetadata:tags->description]
                     forKey:@"Description"];

    if (tags->longDescription)
        [tagsDict setObject:[self stringFromMetadata:tags->longDescription]
                     forKey:@"Long Description"];

    if (tags->lyrics)
        [tagsDict setObject:[self stringFromMetadata:tags->lyrics]
                     forKey:@"Lyrics"];

    if (tags->copyright)
        [tagsDict setObject:[self stringFromMetadata:tags->copyright]
                     forKey:@"Copyright"];

    if (tags->encodingTool)
        [tagsDict setObject:[self stringFromMetadata:tags->encodingTool]
                     forKey:@"Encoding Tool"];

    if (tags->encodedBy)
        [tagsDict setObject:[self stringFromMetadata:tags->encodedBy]
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
        [tagsDict setObject:[self stringFromMetadata:tags->purchaseDate]
                     forKey:@"Purchase Date"];

    if (tags->iTunesAccount)
        [tagsDict setObject:[self stringFromMetadata:tags->iTunesAccount]
                     forKey:@"iTunes Account"];

    if (tags->contentID)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->contentID]
                     forKey:@"contentID"];

    if (tags->artistID)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->artistID]
                     forKey:@"artistID"];

    if (tags->playlistID)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->playlistID]
                     forKey:@"playlistID"];

    if (tags->genreID)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->genreID]
                     forKey:@"genreID"];

    if (tags->composerID)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->composerID]
                     forKey:@"composerID"];

    if (tags->xid)
        [tagsDict setObject:[self stringFromMetadata:tags->xid]
                     forKey:@"XID"];    

    if (tags->sortName)
        [tagsDict setObject:[self stringFromMetadata:tags->sortName]
                     forKey:@"Sort Name"];

    if (tags->sortArtist)
        [tagsDict setObject:[self stringFromMetadata:tags->sortArtist]
                     forKey:@"Sort Artist"];

    if (tags->sortAlbumArtist)
        [tagsDict setObject:[self stringFromMetadata:tags->sortAlbumArtist]
                     forKey:@"Sort Album Artist"];

    if (tags->sortAlbum)
        [tagsDict setObject:[self stringFromMetadata:tags->sortAlbum]
                     forKey:@"Sort Album"];

    if (tags->sortComposer)
        [tagsDict setObject:[self stringFromMetadata:tags->sortComposer]
                     forKey:@"Sort Composer"];

    if (tags->sortTVShow)
        [tagsDict setObject:[self stringFromMetadata:tags->sortTVShow]
                     forKey:@"Sort TV Show"];

    if (tags->podcast)
        podcast = *tags->podcast;

    if (tags->keywords)
        [tagsDict setObject:[self stringFromMetadata:tags->keywords]
                     forKey:@"Keywords"];

    if (tags->category)
        [tagsDict setObject:[self stringFromMetadata:tags->category]
                     forKey:@"Category"];

    if (tags->artwork) {
        NSData *imageData = [NSData dataWithBytes:tags->artwork->data length:tags->artwork->size];
        NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
        if (imageRep != nil) {
            artwork = [[NSImage alloc] initWithSize:[imageRep size]];
            [artwork addRepresentation:imageRep];
        }
    }

    MP4TagsFree(tags);

    /* read the remaining iTMF items */
    MP4ItmfItemList* list = MP4ItmfGetItemsByMeaning(sourceHandle, "com.apple.iTunes", "iTunEXTC");
    if (list) {
        uint32_t i;
        for (i = 0; i < list->size; i++) {
            MP4ItmfItem* item = &list->elements[i];
            uint32_t j;
            for (j = 0; j < item->dataList.size; j++) {
                MP4ItmfData* data = &item->dataList.elements[j];
                NSString *rating = [[NSString alloc] initWithBytes:data->value length: data->valueSize encoding:NSUTF8StringEncoding];
                NSString *splitElements  = @"\\|";
                NSArray *ratingItems = [rating componentsSeparatedByRegex:splitElements];
                NSInteger ratingIndex = R_UNKNOWN;
                if ([ratingItems count] >= 3) {
                    NSString *ratingCompareString = [NSString stringWithFormat:@"%@|%@|%@|", 
                                                     [ratingItems objectAtIndex:0],
                                                     [ratingItems objectAtIndex:1],
                                                     [ratingItems objectAtIndex:2]];
                    iTMF_rating_t *ratingList;
                    int k = 0;
                    for ( ratingList = (iTMF_rating_t*) rating_strings; ratingList->rating; ratingList++, k++ ) {
                        if ([ratingCompareString isEqualToString:[NSString stringWithUTF8String:ratingList->rating]])
                            ratingIndex = k;
                    }
                }
                [tagsDict setObject:[NSNumber numberWithInt:ratingIndex] forKey:@"Rating"];
                if ([ratingItems count] >= 4)
                    [tagsDict setObject:[ratingItems objectAtIndex:3] forKey:@"Rating Annotation"];
                
                [rating release];
            }
        }
        MP4ItmfItemListFree(list);
    }

    list = MP4ItmfGetItemsByMeaning(sourceHandle, "com.apple.iTunes", "iTunMOVI");
    if (list) {
        uint32_t i;
        for (i = 0; i < list->size; i++) {
            MP4ItmfItem* item = &list->elements[i];
            uint32_t j;
            for(j = 0; j < item->dataList.size; j++) {
                MP4ItmfData* data = &item->dataList.elements[j];
                NSData *xmlData = [NSData dataWithBytes:data->value length:data->valueSize];
                NSDictionary *dma = (NSDictionary *)[NSPropertyListSerialization
                                                         propertyListFromData:xmlData
                                                         mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                                         format:nil
                                                         errorDescription:nil];
                
                NSString *tag;
                if ([tag = [self stringFromArray:[dma valueForKey:@"cast"]] length])
                    [tagsDict setObject:tag forKey:@"Cast"];
                if ([tag = [self stringFromArray:[dma valueForKey:@"directors"]] length])
                    [tagsDict setObject:tag forKey:@"Director"];
                if ([tag = [self stringFromArray:[dma valueForKey:@"codirectors"]] length])
                    [tagsDict setObject:tag forKey:@"Codirector"];
                if ([tag = [self stringFromArray:[dma valueForKey:@"producers"]] length])
                    [tagsDict setObject:tag forKey:@"Producers"];
                if ([tag = [self stringFromArray:[dma valueForKey:@"screenwriters"]] length])
                    [tagsDict setObject:tag forKey:@"Screenwriters"];
                if ([tag = [dma valueForKey:@"studio"] length])
                    [tagsDict setObject:tag forKey:@"Studio"];
            }
        }
        MP4ItmfItemListFree(list);
    }
}

- (BOOL) writeMetadataWithFileHandle: (MP4FileHandle *)fileHandle
{
    if (!fileHandle)
        return NO;

    const MP4Tags* tags = MP4TagsAlloc();

    MP4TagsFetch(tags, fileHandle);

    MP4TagsSetName(tags, [[tagsDict valueForKey:@"Name"] UTF8String]);

    MP4TagsSetArtist(tags, [[tagsDict valueForKey:@"Artist"] UTF8String]);

    MP4TagsSetAlbumArtist(tags, [[tagsDict valueForKey:@"Album Artist"] UTF8String]);

    MP4TagsSetAlbum(tags, [[tagsDict valueForKey:@"Album"] UTF8String]);

    MP4TagsSetGrouping(tags, [[tagsDict valueForKey:@"Grouping"] UTF8String]);

    MP4TagsSetComposer(tags, [[tagsDict valueForKey:@"Composer"] UTF8String]);

    MP4TagsSetComments(tags, [[tagsDict valueForKey:@"Comments"] UTF8String]);

    uint16_t genreType = [self genreIndexFromString:[tagsDict valueForKey:@"Genre"]];
    if (genreType) {
        MP4TagsSetGenre(tags, NULL);
        MP4TagsSetGenreType(tags, &genreType);
    }
    else {
        MP4TagsSetGenreType(tags, NULL);
        MP4TagsSetGenre(tags, [[tagsDict valueForKey:@"Genre"] UTF8String]);
    }

    MP4TagsSetReleaseDate(tags, [[tagsDict valueForKey:@"Release Date"] UTF8String]);

    if ([tagsDict valueForKey:@"Track #"]) {
        MP4TagTrack dtrack; int trackNum = 0, totalTrackNum = 0;
        char separator;
        sscanf([[tagsDict valueForKey:@"Track #"] UTF8String],"%u%[/- ]%u", &trackNum, &separator, &totalTrackNum);
        dtrack.index = trackNum;
        dtrack.total = totalTrackNum;
        MP4TagsSetTrack(tags, &dtrack);
    }
    else
        MP4TagsSetTrack(tags, NULL);
    
    if ([tagsDict valueForKey:@"Disk #"]) {
        MP4TagDisk ddisk; int diskNum = 0, totalDiskNum = 0;
        char separator;
        sscanf([[tagsDict valueForKey:@"Disk #"] UTF8String],"%u%[/- ]%u", &diskNum, &separator, &totalDiskNum);
        ddisk.index = diskNum;
        ddisk.total = totalDiskNum;
        MP4TagsSetDisk(tags, &ddisk);
    }
    else
        MP4TagsSetDisk(tags, NULL);    
    
    if ([tagsDict valueForKey:@"Tempo"]) {
        const uint16_t i = [[tagsDict valueForKey:@"Tempo"] integerValue];
        MP4TagsSetTempo(tags, &i);
    }
    else
        MP4TagsSetTempo(tags, NULL);

    MP4TagsSetTVShow(tags, [[tagsDict valueForKey:@"TV Show"] UTF8String]);

    MP4TagsSetTVNetwork(tags, [[tagsDict valueForKey:@"TV Network"] UTF8String]);

    MP4TagsSetTVEpisodeID(tags, [[tagsDict valueForKey:@"TV Episode ID"] UTF8String]);

    if ([tagsDict valueForKey:@"TV Season"]) {
        const uint32_t i = [[tagsDict valueForKey:@"TV Season"] integerValue];
        MP4TagsSetTVSeason(tags, &i);
    }
    else
        MP4TagsSetTVSeason(tags, NULL);

    if ([tagsDict valueForKey:@"TV Episode #"]) {
        const uint32_t i = [[tagsDict valueForKey:@"TV Episode #"] integerValue];
        MP4TagsSetTVEpisode(tags, &i);
    }
    else
        MP4TagsSetTVEpisode(tags, NULL);

    MP4TagsSetDescription(tags, [[tagsDict valueForKey:@"Description"] UTF8String]);

    MP4TagsSetLongDescription(tags, [[tagsDict valueForKey:@"Long Description"] UTF8String]);

    MP4TagsSetLyrics(tags, [[tagsDict valueForKey:@"Lyrics"] UTF8String]);

    MP4TagsSetCopyright(tags, [[tagsDict valueForKey:@"Copyright"] UTF8String]);

    MP4TagsSetEncodingTool(tags, [[tagsDict valueForKey:@"Encoding Tool"] UTF8String]);

    MP4TagsSetEncodedBy(tags, [[tagsDict valueForKey:@"Encoded By"] UTF8String]);
    
    MP4TagsSetITunesAccount(tags, [[tagsDict valueForKey:@"iTunes Account"] UTF8String]);

    if (mediaKind != 0)
        MP4TagsSetMediaType(tags, &mediaKind);
    else
        MP4TagsSetMediaType(tags, NULL);

    if(hdVideo)
        MP4TagsSetHDVideo(tags, &hdVideo);
    else
        MP4TagsSetHDVideo(tags, NULL);
    
    if(gapless)
        MP4TagsSetGapless(tags, &gapless);
    else
        MP4TagsSetGapless(tags, NULL);
    
    if(podcast)
        MP4TagsSetPodcast(tags, &podcast);
    else
        MP4TagsSetPodcast(tags, NULL);

    MP4TagsSetKeywords(tags, [[tagsDict valueForKey:@"Keywords"] UTF8String]);

    MP4TagsSetCategory(tags, [[tagsDict valueForKey:@"Category"] UTF8String]);

    MP4TagsSetContentRating(tags, &contentRating);

    if ([tagsDict valueForKey:@"contentID"]) {
        const uint32_t i = [[tagsDict valueForKey:@"contentID"] integerValue];
        MP4TagsSetContentID(tags, &i);
    }
    else
        MP4TagsSetContentID(tags, NULL);

    if ([tagsDict valueForKey:@"genreID"]) {
        const uint32_t i = [[tagsDict valueForKey:@"genreID"] integerValue];
        MP4TagsSetGenreID(tags, &i);
    }
    else
        MP4TagsSetGenreID(tags, NULL);

    if ([tagsDict valueForKey:@"artistID"]) {
        const uint32_t i = [[tagsDict valueForKey:@"artistID"] integerValue];
        MP4TagsSetArtistID(tags, &i);
    }
    else
        MP4TagsSetArtistID(tags, NULL);

    if ([tagsDict valueForKey:@"playlistID"]) {
        const uint64_t i = [[tagsDict valueForKey:@"playlistID"] integerValue];
        MP4TagsSetPlaylistID(tags, &i);
    }
    else
        MP4TagsSetPlaylistID(tags, NULL);

    if ([tagsDict valueForKey:@"composerID"]) {
        const uint32_t i = [[tagsDict valueForKey:@"composerID"] integerValue];
        MP4TagsSetComposerID(tags, &i);
    }
    else
        MP4TagsSetComposerID(tags, NULL);

    MP4TagsSetXID(tags, [[tagsDict valueForKey:@"XID"] UTF8String]);

    MP4TagsSetSortName(tags, [[tagsDict valueForKey:@"Sort Name"] UTF8String]);

    MP4TagsSetSortArtist(tags, [[tagsDict valueForKey:@"Sort Artist"] UTF8String]);

    MP4TagsSetSortAlbumArtist(tags, [[tagsDict valueForKey:@"Sort Album Artist"] UTF8String]);

    MP4TagsSetSortAlbum(tags, [[tagsDict valueForKey:@"Sort Album"] UTF8String]);

    MP4TagsSetSortComposer(tags, [[tagsDict valueForKey:@"Sort Composer"] UTF8String]);

    MP4TagsSetSortTVShow(tags, [[tagsDict valueForKey:@"Sort TV Show"] UTF8String]);

    if (artwork && isArtworkEdited) {
        MP4TagArtwork newArtwork;
        NSArray *representations;
        NSData *bitmapData;

        representations = [artwork representations];
        bitmapData = [NSBitmapImageRep representationOfImageRepsInArray:representations 
                                                              usingType:NSPNGFileType properties:nil];

        newArtwork.data = (void *)[bitmapData bytes];
        newArtwork.size = [bitmapData length];
        newArtwork.type = MP4_ART_PNG;
        if (!tags->artworkCount)
            MP4TagsAddArtwork(tags, &newArtwork);
        else
            MP4TagsSetArtwork(tags, 0, &newArtwork);
    }
    else if (tags->artworkCount && isArtworkEdited)
        MP4TagsRemoveArtwork(tags, 0);

    MP4TagsStore(tags, fileHandle);
    MP4TagsFree(tags);

    /* Rewrite extended metadata using the generic iTMF api */

    if ([tagsDict valueForKey:@"Rating"] && ([[tagsDict valueForKey:@"Rating"] integerValue] != R_UNKNOWN) ) {
        MP4ItmfItemList* list = MP4ItmfGetItemsByMeaning(fileHandle, "com.apple.iTunes", "iTunEXTC");
        if (list) {
            uint32_t i;
            for (i = 0; i < list->size; i++) {
                MP4ItmfItem* item = &list->elements[i];
                MP4ItmfRemoveItem(fileHandle, item);
            }
        }
        MP4ItmfItemListFree(list);

        MP4ItmfItem* newItem = MP4ItmfItemAlloc( "----", 1 );
        newItem->mean = strdup( "com.apple.iTunes" );
        newItem->name = strdup( "iTunEXTC" );
        
        MP4ItmfData* data = &newItem->dataList.elements[0];
        NSString * ratingString = [NSString stringWithUTF8String:
                                   rating_strings[[[tagsDict valueForKey:@"Rating"] integerValue]].rating];
        if ([[tagsDict valueForKey:@"Rating Annotation"] length] && [ratingString length])
            ratingString = [ratingString stringByAppendingString:[tagsDict valueForKey:@"Rating Annotation"]];
        data->typeCode = MP4_ITMF_BT_UTF8;
        data->valueSize = strlen([ratingString UTF8String]);
        data->value = (uint8_t*)malloc( data->valueSize );
        memcpy( data->value, [ratingString UTF8String], data->valueSize );
        
        MP4ItmfAddItem(fileHandle, newItem);
    }
    else {
        MP4ItmfItemList* list = MP4ItmfGetItemsByMeaning(fileHandle, "com.apple.iTunes", "iTunEXTC");
        if (list) {
            uint32_t i;
            for (i = 0; i < list->size; i++) {
                MP4ItmfItem* item = &list->elements[i];
                MP4ItmfRemoveItem(fileHandle, item);
            }
        }
    }

    if ([tagsDict valueForKey:@"Cast"] || [tagsDict valueForKey:@"Director"] ||
        [tagsDict valueForKey:@"Codirector"] || [tagsDict valueForKey:@"Producers"] ||
        [tagsDict valueForKey:@"Screenwriters"] || [tagsDict valueForKey:@"Studio"]) {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        if ([tagsDict valueForKey:@"Cast"]) {
            [dict setObject:[self dictArrayFromString:[tagsDict valueForKey:@"Cast"]] forKey:@"cast"];
        }
        if ([tagsDict valueForKey:@"Director"]) {
            [dict setObject:[self dictArrayFromString:[tagsDict valueForKey:@"Director"]] forKey:@"directors"];
        }
        if ([tagsDict valueForKey:@"Codirector"]) {
            [dict setObject:[self dictArrayFromString:[tagsDict valueForKey:@"Codirector"]] forKey:@"codirectors"];
        }
        if ([tagsDict valueForKey:@"Producers"]) {
            [dict setObject:[self dictArrayFromString:[tagsDict valueForKey:@"Producers"]] forKey:@"producers"];
        }
        if ([tagsDict valueForKey:@"Screenwriters"]) {
            [dict setObject:[self dictArrayFromString:[tagsDict valueForKey:@"Screenwriters"]] forKey:@"screenwriters"];
        }
        if ([tagsDict valueForKey:@"Studio"]) {
            [dict setObject:[tagsDict valueForKey:@"Studio"] forKey:@"studio"];
        }
        NSData *serializedPlist = [NSPropertyListSerialization
                                        dataFromPropertyList:dict
                                        format:NSPropertyListXMLFormat_v1_0
                                        errorDescription:nil];
		[dict release];

        MP4ItmfItemList* list = MP4ItmfGetItemsByMeaning(fileHandle, "com.apple.iTunes", "iTunMOVI");
        if (list) {
            uint32_t i;
            for (i = 0; i < list->size; i++) {
                MP4ItmfItem* item = &list->elements[i];
                MP4ItmfRemoveItem(fileHandle, item);
            }
        }
        MP4ItmfItemListFree(list);

        MP4ItmfItem* newItem = MP4ItmfItemAlloc( "----", 1 );
        newItem->mean = strdup( "com.apple.iTunes" );
        newItem->name = strdup( "iTunMOVI" );

        MP4ItmfData* data = &newItem->dataList.elements[0];
        data->typeCode = MP4_ITMF_BT_UTF8;
        data->valueSize = [serializedPlist length];
        data->value = (uint8_t*)malloc( data->valueSize );
        memcpy( data->value, [serializedPlist bytes], data->valueSize );

        MP4ItmfAddItem(fileHandle, newItem);
    }
    else {
        MP4ItmfItemList* list = MP4ItmfGetItemsByMeaning(fileHandle, "com.apple.iTunes", "iTunMOVI");
        if (list) {
            uint32_t i;
            for (i = 0; i < list->size; i++) {
                MP4ItmfItem* item = &list->elements[i];
                MP4ItmfRemoveItem(fileHandle, item);
            }
        }
    }

    return YES;
}

- (BOOL) mergeMetadata: (MP42Metadata *) newMetadata
{
    NSString * tagValue;
    for (NSString * key in [self writableMetadata])
            if((tagValue = [newMetadata.tagsDict valueForKey:key]))
                [tagsDict setObject:tagValue forKey:key];

    if (!artwork) {
        artwork = [newMetadata.artwork retain];
        isArtworkEdited = YES;
    }

    mediaKind = newMetadata.mediaKind;
    contentRating = newMetadata.contentRating;
    gapless = newMetadata.gapless;
    hdVideo = newMetadata.hdVideo;

    isEdited = YES;
    return YES;
}

@synthesize presetName;

@synthesize isEdited;
@synthesize isArtworkEdited;
@synthesize artwork;
@synthesize artworkURL;
@synthesize artworkThumbURLs;
@synthesize artworkFullsizeURLs;
@synthesize mediaKind;
@synthesize contentRating;
@synthesize hdVideo;
@synthesize gapless;
@synthesize podcast;

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInt:1 forKey:@"MP42TagEncodeVersion"];

    [coder encodeObject:presetName forKey:@"MP42SetName"];
    [coder encodeObject:tagsDict forKey:@"MP42TagsDict"];
    [coder encodeObject:artwork forKey:@"MP42Artwork"];

    [coder encodeInt:mediaKind forKey:@"MP42MediaKind"];
    [coder encodeInt:contentRating forKey:@"MP42ContentRating"];
    [coder encodeInt:hdVideo forKey:@"MP42HDVideo"];
    [coder encodeInt:gapless forKey:@"MP42Gapless"];
    [coder encodeInt:podcast forKey:@"MP42Podcast"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];

    presetName = [[decoder decodeObjectForKey:@"MP42SetName"] retain];

    tagsDict = [[decoder decodeObjectForKey:@"MP42TagsDict"] retain];
    artwork = [[decoder decodeObjectForKey:@"MP42Artwork"] retain];

    mediaKind = [decoder decodeIntForKey:@"MP42MediaKind"];
    contentRating = [decoder decodeIntForKey:@"MP42ContentRating"];
    hdVideo = [decoder decodeIntForKey:@"MP42HDVideo"];
    gapless = [decoder decodeIntForKey:@"MP42Gapless"];
    podcast = [decoder decodeIntForKey:@"MP42Podcast"];

    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MP42Metadata *newObject = [[MP42Metadata allocWithZone:zone] init];

    if (presetName)
        newObject.presetName = presetName;

    [newObject mergeMetadata:self];

    newObject.contentRating = contentRating;
    newObject.gapless = gapless;
    newObject.hdVideo = hdVideo;
    newObject.podcast = podcast;

    return newObject;
}

-(void) dealloc
{
    [presetName release];

    [artwork release];
    [artworkURL release];
    [artworkThumbURLs release];
    [artworkFullsizeURLs release];
    [tagsDict release];
    [super dealloc];
}

@synthesize tagsDict;

@end
