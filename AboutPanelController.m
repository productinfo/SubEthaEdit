//
//  AboutPanelController.m
//  SubEthaEdit
//
//  Created by Martin Ott on Thu May 13 2004.
//  Copyright (c) 2004 TheCodingMonkeys. All rights reserved.
//

#import "AboutPanelController.h"
#import "SetupController.h"
#import <OgreKit/OgreKit.h>


@implementation AboutPanelController

- (id)init {
    self = [super initWithWindowNibName:@"AboutPanel"];
    return self;
}

- (void)fillLicenseInfoField {
    //NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *serial = @"";
    NSString *name = @"Apple Computer, Inc.";
    NSString *organization = @"Evaluation License expires on 10/01/2004";
    if (name && [serial isValidSerial]) {
        [O_licenseeLabel setHidden:NO];
        [O_licenseeNameField setObjectValue:name];
        [O_licenseeOrganizationField setObjectValue:organization];
    } else {
        [O_licenseeLabel setHidden:YES];
        [O_licenseeNameField setObjectValue:NSLocalizedString(@"Licensed for non-commercial use", nil)];
        [O_licenseeOrganizationField setObjectValue:@""];
    }
}

- (void)windowDidLoad {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *versionString = [NSString stringWithFormat:@"%@ (v%@)", 
                                [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                                [mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"]];
    NSString *ogreVersion = [NSString stringWithFormat:@"OgreKit v%@, Oniguruma v%@", [OGRegularExpression version], [OGRegularExpression onigurumaVersion]];

    [O_versionField setObjectValue:versionString];
    [O_ogreVersionField setObjectValue:ogreVersion];
    [O_legalTextField setObjectValue:[mainBundle objectForInfoDictionaryKey:@"NSHumanReadableCopyright"]];

    [self fillLicenseInfoField];
    [[self window] center];
}

- (IBAction)showWindow:(id)sender {
    [self fillLicenseInfoField];
    [[self window] center];
    [super showWindow:self];
}

@end
