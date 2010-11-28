//
//  PrefsController.m
//
//  Created by Damiano Galassi on 13/05/08.
//  Copyright 2008 Damiano Galassi. All rights reserved.
//

#import "PrefsController.h"

@implementation PrefsController

-(id) init
{
    self = [super initWithWindowNibName:@"Prefs"];
    return self;
}

- (void)awakeFromNib
{
    [[self window] center];
}

@end
