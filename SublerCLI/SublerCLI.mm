#import <Foundation/Foundation.h>
#import "MP42File.h"
#import "MP42FileImporter.h"
#import "RegexKitLite.h"

void print_help()
{
    printf("usage:\n");
    printf("\t\t -dest <destination file> \n");
    printf("\t\t -source <source file> \n");
    printf("\t\t -chapters <chapters file> \n");
    printf("\t\t -chapterspreview Create chapters preview images \n");
    printf("\t\t -delay Delay in ms \n");
    printf("\t\t -height Height in pixel \n");
    printf("\t\t -language Track language (i.e. English) \n");
    printf("\t\t -remove Remove existing subtitles \n");
    printf("\t\t -optimize Optimize \n");
    printf("\t\t -help Print this help information \n");
    printf("\t\t -version Print version \n");
    printf("\t\t -metadata set tags {Tag Name:Tag Value}* \n");
    printf("\t\t -downmix Downmix audio (mono, stereo, dolby, pl2) \n");
    printf("\n");
    printf("\t\t -listtracks For source file only, lists the tracks in the source movie. \n");

}

void print_version()
{
    printf("\t\tversion 0.15\n");
}

// ---------------------------------------------------------------------------
//		printArgs
// ---------------------------------------------------------------------------
static void printArgs(int argc, const char **argv)
{
	int i;
	for( i = 0; i < argc; i++ )
		printf("%s ", argv[i]);
	printf("\n");
}

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    NSString *destinationPath = nil;
    NSString *sourcePath = nil;
    NSString *chaptersPath = nil;
    NSString *metadata = nil;

    NSString *language = NULL;
    int delay = 0;
    unsigned int height = 0;
    BOOL removeExisting = false;
    BOOL chapterPreview = false;
    BOOL modified = false;
    BOOL optimize = false;

    BOOL downmixAudio = NO;
    NSString *downmixType = nil;

    if (argc == 1) {
        print_help();
        exit(-1);
    }

    printArgs(argc,argv);

    argv += 1;
    argc--;

	while ( argc > 0 && **argv == '-' )
	{
		const char*	args = &(*argv)[1];
		
		argc--;
		argv++;
		
		if ( ! strcmp ( args, "source" ) )
		{
            sourcePath = [NSString stringWithUTF8String: *argv++];
			argc--;
		}
		else if (( ! strcmp ( args, "dest" )) || ( ! strcmp ( args, "destination" )) )
		{
			destinationPath = [NSString stringWithUTF8String: *argv++];
			argc--;
		}
        else if ( ! strcmp ( args, "chapters" ) )
		{
			chaptersPath = [NSString stringWithUTF8String: *argv++];
			argc--;
		}
        else if ( ! strcmp ( args, "chapterspreview" ) )
		{
			chapterPreview = YES;
		}
        else if ( ! strcmp ( args, "metadata" ) )
		{
			metadata = [NSString stringWithUTF8String: *argv++];
            argc--;
		}
        else if ( ! strcmp ( args, "optimize" ) )
		{
			optimize = YES;
		}
        else if ( ! strcmp ( args, "downmix" ) )
		{
            downmixAudio = YES;
            if (strcasecmp( optarg, "mono" ) == 0) downmixType = SBMonoMixdown;
            else if (strcasecmp( optarg, "stereo" ) == 0) downmixType = SBStereoMixdown;
            else if (strcasecmp( optarg, "dolby" ) == 0) downmixType = SBDolbyMixdown;
            else if (strcasecmp( optarg, "pl2" ) == 0) downmixType = SBDolbyPlIIMixdown;
            else {
                printf( "Error: unsupported downmix type '%s'\n", optarg );
                printf( "Valid downmix types are: 'mono', 'stereo', 'dolby' and 'pl2'\n" );
                exit( -1 );
            }
            argc--;
		}
        else if ( ! strcmp ( args, "delay" ) )
		{
			delay = atoi(*argv++);
            argc--;
		}
        else if ( ! strcmp ( args, "height" ) )
		{
            height = atoi(*argv++);
            argc--;
		}
        else if ( ! strcmp ( args, "language" ) )
		{
            language = [NSString stringWithUTF8String: *argv++];
			argc--;
		}
        else if ( ! strcmp ( args, "remove" ) )
		{
            removeExisting = YES;
		}
		else if (( ! strcmp ( args, "version" )) || ( ! strcmp ( args, "v" )) )
		{
			print_version();
		}
		else if ( ! strcmp ( args, "help" ) )
		{
			print_help();
		}
		else {
			printf("Invalid input parameter: %s\n", args );
			print_help();
			return nil;
		}
	}

    NSMutableDictionary * attributes = [[NSMutableDictionary alloc] init];
    if (chapterPreview)
        [attributes setObject:[NSNumber numberWithBool:YES] forKey:MP42CreateChaptersPreviewTrack];

    if (sourcePath || chaptersPath || removeExisting || metadata || chapterPreview)
    {
        NSError *outError;
        MP42File *mp4File;
        if ([[NSFileManager defaultManager] fileExistsAtPath:destinationPath])
            mp4File = [[MP42File alloc] initWithExistingFile:[NSURL fileURLWithPath:destinationPath]
                                                 andDelegate:nil];
        else
            mp4File = [[MP42File alloc] initWithDelegate:nil];

        if (!mp4File) {
            printf("Error: %s\n", "the mp4 file couln't be opened.");
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

        if (sourcePath) {
            MP42FileImporter *fileImporter = [[MP42FileImporter alloc] initWithDelegate:nil
                                                                                andFile:[NSURL fileURLWithPath:sourcePath]
                                                                                error:&outError];

            for (MP42Track * track in [fileImporter tracksArray]) {
                if (language)
                    [track setLanguage:language];
                if (delay)
                    [track setStartOffset:delay];
                if (height && [track isMemberOfClass:[MP42SubtitleTrack class]])
                    [(MP42VideoTrack*)track setTrackHeight:height];

                [track setTrackImporterHelper:fileImporter];
                [mp4File addTrack:track];
            }

            modified = YES;
        }

        if (chaptersPath) {
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
          
          newChapterTrack = [MP42ChapterTrack chapterTrackFromFile:[NSURL fileURLWithPath:chaptersPath]];
          
          if([newChapterTrack chapterCount] > 0) {
            [mp4File addTrack:newChapterTrack];            
            modified = YES;      
          }
        }

        if (downmixAudio) {
            for (MP42AudioTrack *track in [mp4File tracks]) {
                if (![track isKindOfClass: [MP42AudioTrack class]]) continue;
                
                [track setNeedConversion: YES];
                [track setMixdownType: downmixType];
                
                modified = YES;
            }
        }

        if (metadata) {
            NSString *searchString = metadata;
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
            success = [mp4File writeToUrl:[NSURL fileURLWithPath:destinationPath]
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
        mp4File = [[MP42File alloc] initWithExistingFile:[NSURL fileURLWithPath:destinationPath]
                                             andDelegate:nil];
        if (!mp4File) {
            printf("Error: %s\n", "the mp4 file couln't be opened.");
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
