#import <AppKit/AppKit.h>

#include "window.h"

@interface FireplaceAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation FireplaceAppDelegate
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}
@end

namespace fireplace {

int run_window() {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];

        FireplaceAppDelegate *delegate = [[FireplaceAppDelegate alloc] init];
        [app setDelegate:delegate];

        NSMenu *menuBar = [[NSMenu alloc] init];
        NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
        [menuBar addItem:appMenuItem];
        NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Fireplace"];
        [appMenu addItemWithTitle:@"Quit Fireplace"
                          action:@selector(terminate:)
                   keyEquivalent:@"q"];
        [appMenuItem setSubmenu:appMenu];
        [app setMainMenu:menuBar];

        NSWindow *window = [[NSWindow alloc]
            initWithContentRect:NSMakeRect(0, 0, 800, 600)
                      styleMask:(NSWindowStyleMaskTitled |
                                 NSWindowStyleMaskClosable |
                                 NSWindowStyleMaskMiniaturizable |
                                 NSWindowStyleMaskResizable)
                        backing:NSBackingStoreBuffered
                          defer:NO];
        [window setReleasedWhenClosed:NO];
        [window setTitle:@"Fireplace"];
        [window setBackgroundColor:
            [NSColor colorWithCalibratedRed:0.15 green:0.08 blue:0.04 alpha:1.0]];
        [window center];
        [window makeKeyAndOrderFront:nil];
        [app activateIgnoringOtherApps:YES];
        [app run];

        [app setDelegate:nil];
    }
    return 0;
}

}
