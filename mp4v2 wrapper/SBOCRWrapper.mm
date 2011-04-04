//
//  SBOcr.mm
//  Subler
//
//  Created by Damiano Galassi on 27/03/11.
//  Copyright 2011 Damiano Galassi. All rights reserved.
//

#import "SBOCRWrapper.h"

// Tesseract OCR
#include "tesseract/baseapi.h"

#include <iostream>
#include <string>
#include <cstdio>

#include "lang.h"

using namespace tesseract;

class OCRWrapper {
public:
OCRWrapper(const char* lang) {
    NSString * path = [[NSBundle mainBundle] bundlePath];
    path = [string stringByAppendingString:@"/Contents/Resources/"];

    setenv("TESSDATA_PREFIX", [path UTF8String], 1);
    tess_base_api.Init("/usr/local/share", lang);
    tess_base_api.SetAccuracyVSpeed(AVS_MOST_ACCURATE);
}
char* OCRFrame(const unsigned char *image, int bytes_per_pixel, int bytes_per_line, int width, int height) {
    char* text = tess_base_api.TesseractRect(image,
                                             bytes_per_pixel,
                                             bytes_per_line,
                                             0, 0,
                                             width, height);
    return text;
}

protected:
    TessBaseAPI tess_base_api;
};

@implementation SBOCRWrapper

- (id)init
{
    if ((self = [super init]))
    {
        tess_base = (void *)new OCRWrapper(lang_for_english([_language UTF8String])->iso639_2);
    }
    return self;
}

- (id) initWithLanguage: (NSString*) language
{
    if ((self = [super init]))
    {
        _language = [language retain];
        
        tess_base = (void *)new OCRWrapper(lang_for_english([_language UTF8String])->iso639_2);
    }
    return self;
}

- (NSString*) performOCROnCGImage:(CGImageRef)cgImage {
    NSMutableString * text;

    OCRWrapper *ocr = (OCRWrapper *)tess_base;
    size_t bytes_per_line   = CGImageGetBytesPerRow(cgImage);
    size_t bytes_per_pixel  = CGImageGetBitsPerPixel(cgImage) / 8.0;
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);

    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
    const UInt8 *imageData = CFDataGetBytePtr(data);

    char* string = ocr->OCRFrame(imageData,
                                 bytes_per_pixel,
                                 bytes_per_line,
                                 width,
                                 height);

    CFRelease(data);

    if (string) {
        text = [NSMutableString stringWithUTF8String:string];
        if ([text characterAtIndex:[text length] -1] == '\n')
            [text replaceOccurrencesOfString:@"\n\n" withString:@"" options:nil range:NSMakeRange(0,[text length])];
    }
    else
        text = nil;

    delete[]string;

    return text;

}

- (void) dealloc {
    OCRWrapper *ocr = (OCRWrapper *)tess_base;
    delete ocr;

    [_language release];
    [super dealloc];
}
@end
