#import <Foundation/Foundation.h>
#import "MP42File.h"
#import "RegexKitLite.h"

void print_help()
{
    printf("usage:\n");
    printf("\t\t-i set input file\n");
    printf("\t\t-s set subtitle input file\n");
    printf("\t\t-c set chapter input file\n");
    printf("\t\t-p create chapters preview images\n");
    printf("\t\t-d set delay in ms\n");
    printf("\t\t-a set height in pixel\n");
    printf("\t\t-l set track language (i.e. English)\n");
    printf("\t\t-n set track name\n");
    printf("\t\t-r remove existing subtitles\n");
    printf("\t\t-O optimize\n");
    printf("\t\t-h print this help information\n");
    printf("\t\t-v print version\n");
    printf("\t\t-t set tags {Tag Name:Tag Value}*\n");
}
void print_version()
{
    printf("\t\tversion 0.9.7\n");
}

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    char* input_file = NULL;
    char* input_sub = NULL;
    char* input_chap = NULL;
    const char* name = "Subtitle Track";
    const char* language = "English";
    int delay = 0;
    unsigned int height = 60;
    BOOL removeExisting = false;
    BOOL chapterPreview = false;
    BOOL modified = false;
    BOOL optimize = false;
    char* tags = NULL;

    if (argc == 1) {
        print_help();
        exit(-1);
    }

    char opt_char=0;
    while ((opt_char = getopt(argc, (char * const*)argv, "i:s:c:d:a:l:n:t:prvhO")) != -1) {
        switch(opt_char) {
            case 'h':
                print_help();
                exit(-1);
                break;
            case 'v':
                print_version();
                exit(-1);
                break;
            case 'i':
                input_file = optarg;
                break;
            case 's':
                input_sub = optarg;
                break;
            case 'c':
                input_chap = optarg;
                break;
            case 'd':
                delay = atoi(optarg);
                break ;
            case 'a':
                height = atoi(optarg);
                break ;
            case 'l':
                language = optarg;
                break ;
            case 'n':
                name = optarg;
                break ;
            case 't':
                tags = optarg;
                break ;            
            case 'r':
                removeExisting = YES;
                break ;
            case 'O':
                optimize = YES;
                break ;
            case 'p':
                chapterPreview = YES;
                break;
            default:
                print_help();
                exit(-1);
                break;
        }
    }

    NSMutableDictionary * attributes = [[NSMutableDictionary alloc] init];
    if (chapterPreview)
        [attributes setObject:[NSNumber numberWithBool:YES] forKey:MP42CreateChaptersPreviewTrack];

    if (input_file && (input_sub || input_chap || removeExisting || tags || chapterPreview))
    {
        NSError *outError;
        MP42File *mp4File;
        mp4File = [[MP42File alloc] initWithExistingFile:[NSString stringWithCString:input_file encoding:NSUTF8StringEncoding]
                                             andDelegate:nil];
        if (!mp4File) {
            printf("Error: %s\n", "the mp4 file couln't be open.");
            return -1;
        }
        if (removeExisting) {
          NSMutableIndexSet *subtitleTrackIndexes = [[NSMutableIndexSet alloc] init];
          MP42Track *track;
          for (track in mp4File.tracks)
            if ([track isMemberOfClass:[MP42SubtitleTrack class]]) {
              [subtitleTrackIndexes addIndex:[mp4File.tracks indexOfObject:track]];
               modified = true;
            }
                              
          [mp4File removeTracksAtIndexes:subtitleTrackIndexes];
          [subtitleTrackIndexes release];
        }

        if (input_sub) {
            MP42SubtitleTrack *track = [MP42SubtitleTrack subtitleTrackFromFile:[NSString stringWithCString:input_sub
                                                                                                   encoding:NSUTF8StringEncoding]
                                                                          delay:delay
                                                                         height:height
                                                                       language:[NSString stringWithCString:language
                                                                                                   encoding:NSUTF8StringEncoding]];
            track.name = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
            [mp4File addTrack:track];
            modified = true;
        }
      
        if (input_chap) {
            MP42Track *oldChapterTrack = NULL;
            MP42ChapterTrack *newChapterTrack = NULL;
            
            MP42Track *track;
            for (track in mp4File.tracks)
              if ([track isMemberOfClass:[MP42ChapterTrack class]]) {
                oldChapterTrack = track;
                break;
              }
          
          if(oldChapterTrack != NULL) {
            [mp4File removeTrackAtIndex:[mp4File.tracks indexOfObject:oldChapterTrack]];
            modified = true;
          }
          
          newChapterTrack = [MP42ChapterTrack chapterTrackFromFile:[NSString stringWithCString:input_chap encoding:NSUTF8StringEncoding]];
          
          if([newChapterTrack chapterCount] > 0) {
            [mp4File addTrack:newChapterTrack];            
            modified = true;      
          }
        }

        if (tags) {
            NSString *searchString = [NSString stringWithCString:tags encoding:NSUTF8StringEncoding];
            NSString *regexCheck = @"(\\{[^:]*:[^\\}]*\\})*";

            // escaping the {, } and : charachters 
            NSString *left_normal = @"{";
            NSString *right_normal = @"}";
            NSString *semicolon_normal = @":";

            NSString *left_escaped = @"&#123;";
            NSString *right_escaped = @"&#125;";
            NSString *semicolon_escaped = @"&#58;";

            if (searchString != nil && [searchString isMatchedByRegex:regexCheck]) {

                NSString *regexSplitArgs = @"^\\{|\\}\\{|\\}$";
                NSString *regexSplitValue = @"([^:]*):(.*)";
                NSString *regexPositive = @"YES|Yes|yes|1";

                NSArray *argsArray = nil;
                NSString *arg = nil;
                NSString *key = nil;
                NSString *value = nil;
                argsArray = [searchString componentsSeparatedByRegex:regexSplitArgs];

                for (arg in argsArray) {
                    key = [arg stringByMatching:regexSplitValue capture:1L];
                    value = [arg stringByMatching:regexSplitValue capture:2L];

                    key = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

                    value = [value stringByReplacingOccurrencesOfString:left_escaped withString:left_normal];
                    value = [value stringByReplacingOccurrencesOfString:right_escaped withString:right_normal];
                    value = [value stringByReplacingOccurrencesOfString:semicolon_escaped withString:semicolon_normal];

                    if(key != nil) {
                        if([key isEqualToString:@"Media Kind"]) {
                            modified=[mp4File.metadata setMediaKindFromString:value];

                        } else if ([key isEqualToString:@"Content Rating"]) {
                            modified=[mp4File.metadata setContentRatingFromString:value];

                        } else if ([key isEqualToString:@"HD Video"]) {
                            if( value != nil && [value length] > 0 && [value isMatchedByRegex:regexPositive]) {
                                mp4File.metadata.hdVideo = 1;
                            } else {
                                mp4File.metadata.hdVideo = 0;
                            }

                        } else if ([key isEqualToString:@"Gapless"]) {                      
                            if( value != nil && [value length] > 0 && [value isMatchedByRegex:regexPositive]) {
                                mp4File.metadata.gapless = 1;
                            } else {
                              mp4File.metadata.gapless = 0;
                            }

                        } else if ([key isEqualToString:@"Artwork"]) {                      
                          modified = [mp4File.metadata setArtworkFromFilePath:value];
                          
                        } else if ([key isEqualToString:@"Rating"]) {                      
                          NSString *rating_index = [[NSNumber numberWithInt:[mp4File.metadata ratingIndexFromString:value]] stringValue];
                          modified = [mp4File.metadata setTag:rating_index forKey:key];
                          
                        } else {
                            if (value != nil && [value length] > 0) {                  
                                [mp4File.metadata setTag:value forKey:key];
                            } else{
                                [mp4File.metadata removeTagForKey:key];                  
                            }
                            modified = true;
                        }                    
                    }
                }
            }
        }
        
        if (chapterPreview)
            modified = true;

        if (modified && ![mp4File updateMP4FileWithAttributes:attributes error:&outError]) {
            printf("Error: %s\n", [[outError localizedDescription] UTF8String]);
            return -1;
        }

        [mp4File release];
    }
    if (optimize) {
        MP42File *mp4File;
        mp4File = [[MP42File alloc] initWithExistingFile:[NSString stringWithCString:input_file encoding:NSUTF8StringEncoding]
                                             andDelegate:nil];
        if (!mp4File) {
            printf("Error: %s\n", "the mp4 file couln't be open.");
            return -1;
        }
        printf("Optimizing...\n");
        [mp4File optimize];
        [mp4File release];
        printf("Done.\n");
    }

    [attributes release];
    [pool drain];
    return 0;
}
