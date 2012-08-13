//
//  SBLanguages.h
//  Subler
//
//  Created by Damiano Galassi on 13/08/12.
//
//

#import <Foundation/Foundation.h>

@interface SBLanguages : NSObject

+ (SBLanguages*)defaultManager;
- (NSArray*) languages;

@end
