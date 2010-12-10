//
//  AppDelegate.h
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PrefsController.h"

@interface AppDelegate : NSObject {

    PrefsController *fPrefs;
}

- (IBAction) showPrefsWindow: (id) sender;
- (IBAction) donate:(id)sender;
- (IBAction) help:(id)sender;

@end

@interface SBDocumentController : NSDocumentController {
}

@end