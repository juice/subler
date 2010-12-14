#import <Foundation/Foundation.h>
#import "MP42File.h"
#import "MP42FileImporter.h"
#import "RegexKitLite.h"

void print_help()
{
    printf("usage:\n");
    printf("\t\t-o set output file\n");
    printf("\t\t-i set input file\n");
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
    printf("\t\tversion 0.11\n");
}

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    char* output_file = NULL;
    char* input_file = NULL;
    char* input_chap = NULL;
    const char* name = NULL;
    const char* language = NULL;
    int delay = 0;
    unsigned int height = 0;
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
    while ((opt_char = getopt(argc, (char * const*)argv, "o:i:c:d:a:l:n:t:prvhO")) != -1) {
        switch(opt_char) {
            case 'h':
                print_help();
                exit(-1);
                break;
            case 'v':
                print_version();
                exit(-1);
                break;
            case 'o':
                output_file = optarg;
                break;
            case 'i':
                input_file = optarg;
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

    if (input_file || input_chap || removeExisting || tags || chapterPreview)
    {
        NSError *outError;
        MP42File *mp4File;
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithCString:output_file encoding:NSUTF8StringEncoding]])
            mp4File = [[MP42File alloc] initWithExistingFile:[NSString stringWithCString:output_file encoding:NSUTF8StringEncoding]
                                                 andDelegate:nil];
        else
            mp4File = [[MP42File alloc] initWithDelegate:nil];

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
               modified = YES;
            }

          [mp4File removeTracksAtIndexes:subtitleTrackIndexes];
          [subtitleTrackIndexes release];
        }

        if (input_file) {
            MP42FileImporter *fileImporter = [[MP42FileImporter alloc] initWithDelegate:nil
                                                                                andFile:[NSString stringWithCString:input_file                                                                                                                                                                                 encoding:NSUTF8StringEncoding]];

            for (MP42Track * track in [fileImporter tracksArray]) {
                [track setTrackImporterHelper:fileImporter];

                if (language)
                    [track setLanguage:[NSString stringWithCString:language encoding:NSUTF8StringEncoding]];
                if (delay)
                    [track setStartOffset:delay];
                if (height && [track isMemberOfClass:[MP42SubtitleTrack class]])
                    [(MP42VideoTrack*)track setTrackHeight:height];

                [mp4File addTrack:track];
            }

            modified = YES;
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
            modified = YES;
          }
          
          newChapterTrack = [MP42ChapterTrack chapterTrackFromFile:[NSString stringWithCString:input_chap encoding:NSUTF8StringEncoding]];
          
          if([newChapterTrack chapterCount] > 0) {
            [mp4File addTrack:newChapterTrack];            
            modified = YES;      
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
                        if (value != nil && [value length] > 0) {                  
                            [mp4File.metadata setTag:value forKey:key];
                        }
                        else {
                            [mp4File.metadata removeTagForKey:key];                  
                        }
                        modified = YES;
                    }
                }
            }
        }
        
        if (chapterPreview)
            modified = YES;

        BOOL success;
        if (modified && [mp4File hasFileRepresentation])
            success = [mp4File updateMP4FileWithAttributes:attributes error:&outError];

        else if (modified && ![mp4File hasFileRepresentation])
            success = [mp4File writeToUrl:[NSURL fileURLWithPath:[NSString stringWithCString:output_file encoding:NSUTF8StringEncoding]]
                           withAttributes:attributes
                                    error:&outError];

        if (!success) {
            printf("Error: %s\n", [[outError localizedDescription] UTF8String]);
            return -1;
        }
        
        [mp4File release];
    }
    if (optimize) {
        MP42File *mp4File;
        mp4File = [[MP42File alloc] initWithExistingFile:[NSString stringWithCString:output_file encoding:NSUTF8StringEncoding]
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
