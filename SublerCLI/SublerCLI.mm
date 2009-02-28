#import <Foundation/Foundation.h>
#import "MP42File.h"
int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    if (argc == 6) {
        MP42File *mp4File;
        mp4File = [[MP42File alloc] initWithExistingFile:[NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding]
                                             andDelegate:nil];

        int delay = 0;
        unsigned int height = 60;
    
        sscanf(argv[3], "%d", &delay);
        sscanf(argv[4], "%d", &height);
    
        MP42SubtitleTrack * subTrack = [MP42SubtitleTrack subtitleTrackFromFile:[NSString stringWithCString:argv[2]
                                                                                                   encoding:NSUTF8StringEncoding]
                                                                          delay:delay
                                                                         height:height
                                                                       language:[NSString stringWithCString:argv[5]
                                                                                                   encoding:NSUTF8StringEncoding]];
        [mp4File addTrack:subTrack];
        [mp4File writeToFile];

        [mp4File release];
    }
    else {
        NSLog(@"<input> <subtitleinput> <delay> <height> <language>");
    }

    [pool drain];
    return 0;
}
