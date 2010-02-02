//
//  AppDelegate.m
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    return NO;
}

- (void) showPrefsWindow: (id) sender;
{
    if (!fPrefs) {
        fPrefs = [[PrefsController alloc] init];
    }
    [fPrefs showWindow:self];
}

- (IBAction) donate:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL
                                             URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=YKZHVC6HG6AFQ&lc=IT&item_name=Subler&currency_code=EUR&bn=PP%2dDonationsBF%3abtn_donateCC_LG%2egif%3aNonHosted"]];
}

- (IBAction) help:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL
                                             URLWithString:@"http://code.google.com/p/subler/w/list"]];
}

@end
