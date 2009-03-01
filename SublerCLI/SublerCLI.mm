#import <Foundation/Foundation.h>
#import "MP42File.h"

void print_help()
{
    printf("usage:\n");
    printf("\t\t-i set input file\n");
    printf("\t\t-s set subtitle input file\n");
    printf("\t\t-d set delay in ms\n");
    printf("\t\t-h print this help information\n");
    printf("\t\t-l print version\n");
}
void print_version()
{
    printf("\t\tversion 0.8a4\n");
}

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    char* input_file = NULL;
    char* input_sub = NULL;
    char* language = "English";
    int delay = 0;
    unsigned int height = 60;

    if (argc == 1) {
        print_help();
        exit(-1);
    }

    char opt_char=0;
    while ((opt_char = getopt(argc, (char * const*)argv, "i:s:d:a:l:vh")) != -1) {
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
            default:
                print_help();
                exit(-1);
                break;
        }
    }

    if (input_file && input_sub)
    {
        MP42File *mp4File;
        mp4File = [[MP42File alloc] initWithExistingFile:[NSString stringWithCString:input_file encoding:NSUTF8StringEncoding]
                                             andDelegate:nil];

        MP42SubtitleTrack * subTrack = [MP42SubtitleTrack subtitleTrackFromFile:[NSString stringWithCString:input_sub
                                                                                                   encoding:NSUTF8StringEncoding]
                                                                          delay:delay
                                                                         height:height
                                                                       language:[NSString stringWithCString:language
                                                                                                   encoding:NSUTF8StringEncoding]];
        [mp4File addTrack:subTrack];
        [mp4File writeToFile];

        [mp4File release];
    }

    [pool drain];
    return 0;
}
