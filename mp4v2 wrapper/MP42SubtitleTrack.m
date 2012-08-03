//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42SubtitleTrack.h"
#import "MP42Utilities.h"
#import "lang.h"

@implementation MP42SubtitleTrack

@synthesize verticalPlacement;
@synthesize someSamplesAreForced;
@synthesize allSamplesAreForced;

- (id) initWithSourceURL:(NSURL *)URL trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
    if ((self = [super initWithSourceURL:URL trackID:trackID fileHandle:fileHandle]))
    {
        if (![format isEqualToString:@"VobSub"]) {
            MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.tx3g.defTextBoxBottom", &height);
            MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.tx3g.defTextBoxRight", &width);
        }
    }

    return self;
}

-(id) init
{
    if ((self = [super init]))
    {
        name = @"Subtitle Track";
        format = @"3GPP Text";
    }

    return self;
}

- (BOOL) writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError
{
    if (isEdited && !muxed)
    {
        if (!Id && (outError != NULL))
            *outError = MP42Error(@"Error: couldn't mux subtitle track",
                                  nil,
                                  120);
        else {
            muxed = YES;
            enableFirstSubtitleTrack(fileHandle);

            MP4GetTrackFloatProperty(fileHandle, Id, "tkhd.width", &trackWidth);
            MP4GetTrackFloatProperty(fileHandle, Id, "tkhd.height", &trackHeight);

            uint8_t *val;
            uint8_t nval[36];
            uint32_t *ptr32 = (uint32_t*) nval;
            uint32_t size;

            MP4GetTrackBytesProperty(fileHandle ,Id, "tkhd.matrix", &val, &size);
            memcpy(nval, val, size);
            offsetX = CFSwapInt32BigToHost(ptr32[6]) / 0x10000;
            offsetY = CFSwapInt32BigToHost(ptr32[7]) / 0x10000;
            free(val);

            [super writeToFile:fileHandle error:outError];
        }
        return Id;
    }
    else
        [super writeToFile:fileHandle error:outError];

    if ([format isEqualToString:@"VobSub"]) {
    }
    else {
        MP4SetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.tx3g.defTextBoxBottom", trackHeight);
        MP4SetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.tx3g.defTextBoxRight", trackWidth);
    }

    return YES;
}

struct style_record {
    uint16_t startChar;
    uint16_t endChar;
    uint16_t fontID;
    uint8_t  fontStyleFlags;
    uint8_t  fontSize;
    uint8_t	 textColorRGBA[4];
};

- (BOOL)exportToURL:(NSURL *)url error:(NSError **)error
{
    MP4FileHandle fileHandle = MP4Read([[sourceURL path] UTF8String]);
    if (!fileHandle)
        return NO;

    MP4TrackId srcTrackId = Id;

    MP4SampleId sampleId = 1;
    NSUInteger srtSampleNumber = 1;

    MP4Timestamp time = 0;
    uint32_t timeScale = MP4GetTrackTimeScale(fileHandle, srcTrackId);
    uint64_t samples = MP4GetTrackNumberOfSamples(fileHandle, srcTrackId);

    NSMutableString *srtFile = [[[NSMutableString alloc] init] autorelease];

    for (sampleId = 1; sampleId <= samples; sampleId++) {
        uint8_t *pBytes = NULL;
        uint32_t pos = 0;
        uint32_t numBytes = 0;
        MP4Duration sampleDuration;
        MP4Duration renderingOffset;
        MP4Timestamp pStartTime;
        bool isSyncSample;

        if (!MP4ReadSample(fileHandle,
                           srcTrackId,
                           sampleId,
                           &pBytes, &numBytes,
                           &pStartTime, &sampleDuration, &renderingOffset,
                           &isSyncSample)) {
            break;
        }

        NSMutableString * sampleText = nil;
        NSUInteger textSampleLength = ((pBytes[0] << 8) & 0xff00) + pBytes[1];

        if (textSampleLength) {
            sampleText = [[[NSMutableString alloc] initWithBytes:(pBytes+2)
                                                          length:textSampleLength
                                                        encoding:NSUTF8StringEncoding] autorelease];
        }

        // Let's see if there is an atom after the text sample
        pos = textSampleLength + 2;

		while (pos + 8 < numBytes && sampleText) {
			uint8_t *styleAtoms = pBytes + pos;
			size_t atomLength = ((styleAtoms[0] << 24) & 0xff000000) + ((styleAtoms[1] << 16) & 0xff0000) + ((styleAtoms[2] << 8) & 0xff00) + styleAtoms[3];

            pos += atomLength;

			if (pos <= numBytes) {
                // If we found a style atom, read it and insert html-like tags in the new file
                if (styleAtoms[4] == 's' && styleAtoms[5] == 't' && styleAtoms[6] == 'y' && styleAtoms[7] == 'l') {
                    uint8_t styleCount = ((styleAtoms[8] << 8) & 0xff00) + styleAtoms[9];
                    uint8_t *style_sample = styleAtoms + 10;
                    uint8_t numberOfInsertedChars = 0;

                    while (styleCount) {
                        struct style_record record;
                        record.startChar    = (style_sample[0] << 8) & 0xff00;
                        record.startChar    += style_sample[1];
                        record.endChar      = (style_sample[2] << 8) & 0xff00;
                        record.endChar      += style_sample[3];
                        record.fontID       = (style_sample[4] << 8) & 0xff00;
                        record.fontID       += style_sample[5];
                        record.fontStyleFlags	= style_sample[6];
                        record.fontSize			= style_sample[7];
                        record.textColorRGBA[0] = style_sample[8];
                        record.textColorRGBA[1] = style_sample[9];
                        record.textColorRGBA[2] = style_sample[10];
                        record.textColorRGBA[3] = style_sample[11];

                        uint8_t insertedChars = 0;
                        uint8_t insertedStartChars = 0;

                        if (record.fontStyleFlags & 0x1) {
                            [sampleText insertString:@"<b>" atIndex:record.startChar + numberOfInsertedChars];
                            [sampleText insertString:@"</b>" atIndex:record.endChar + numberOfInsertedChars + 3];
                            insertedChars += 7;
                            insertedStartChars += 3;
                        }
                        if (record.fontStyleFlags & 0x2) {
                            [sampleText insertString:@"<i>" atIndex:record.startChar + numberOfInsertedChars + insertedStartChars];
                            [sampleText insertString:@"</i>" atIndex:record.endChar + numberOfInsertedChars + insertedStartChars + 3];
                            insertedChars += 7;
                            insertedStartChars += 3;
                        }
                        if (record.fontStyleFlags & 0x4) {
                            [sampleText insertString:@"<u>" atIndex:record.startChar + numberOfInsertedChars + insertedStartChars];
                            [sampleText insertString:@"</u>" atIndex:record.endChar + numberOfInsertedChars + insertedStartChars + 3];
                            insertedChars += 7;
                        }

                        numberOfInsertedChars += insertedChars;

                        styleCount--;
                        style_sample += 12;
                    }
                }
            }
        }

        if (textSampleLength) {
            if ([sampleText characterAtIndex:[sampleText length] - 1] == '\n')
                [sampleText deleteCharactersInRange:NSMakeRange([sampleText length] - 1, 1)];

            [srtFile appendFormat:@"%d\n%@ --> %@\n", srtSampleNumber++,
                                                      SRTStringFromTime(time, timeScale, ','), SRTStringFromTime(time + sampleDuration, timeScale, ',')];
            [srtFile appendString:sampleText];
            [srtFile appendString:@"\n\n"];
		}

        time += sampleDuration;
    }

    return [srtFile writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:error];
}

- (void) dealloc
{
    [super dealloc];
}

@end
