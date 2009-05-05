#import <Foundation/Foundation.h>
#import "MP42File.h"

void print_help()
{
    printf("usage:\n");
    printf("\t\t-i set input file\n");
    printf("\t\t-s set subtitle input file\n");
    printf("\t\t-d set delay in ms\n");
    printf("\t\t-a set height in pixel\n");
    printf("\t\t-l set track language (i.e. English)\n");
    printf("\t\t-n set track name\n");
    printf("\t\t-r remove existing subtitles\n");
    printf("\t\t-h print this help information\n");
    printf("\t\t-v print version\n");
}
void print_version()
{
    printf("\t\tversion 0.8a8\n");
}

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    char* input_file = NULL;
    char* input_sub = NULL;
    char* name = "Subtitle Track";
    char* language = "English";
    int delay = 0;
    unsigned int height = 60;
    BOOL removeExisting = false;
    BOOL modified = false;

    if (argc == 1) {
        print_help();
        exit(-1);
    }

    char opt_char=0;
    while ((opt_char = getopt(argc, (char * const*)argv, "i:s:d:a:l:n:rvh")) != -1) {
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
            case 'r':
                removeExisting = true;
                break ;                
            default:
                print_help();
                exit(-1);
                break;
        }
    }

    if (input_file && (input_sub || removeExisting))
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
            MP42Track *track;
            for (track in mp4File.tracks)
                if ([track isMemberOfClass:[MP42SubtitleTrack class]])
                    if (track.muxed) {
                        [mp4File removeTrackAtIndex:[mp4File.tracks indexOfObject:track]];
                        modified = true;
                    }
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
        }

        if (modified && ![mp4File updateMP4File:&outError]) {
            printf("Error: %s\n", [[outError localizedDescription] UTF8String]);
            return -1;
        }

        [mp4File release];
    }

    [pool drain];
    return 0;
}
