#import <AppKit/AppKit.h>

#include "window.h"
#include "scene.h"

#include <algorithm>

@interface FireplaceSceneView : NSView {
    double yaw;
    double pitch;
    NSPoint lastMousePosition;
}
@end

@implementation FireplaceSceneView
- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        yaw = -0.7853981634;
        pitch = 0.6154797087;
    }
    return self;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    return YES;
}

- (void)mouseDown:(NSEvent *)event {
    lastMousePosition = [self convertPoint:event.locationInWindow fromView:nil];
}

- (void)mouseDragged:(NSEvent *)event {
    const NSPoint position = [self convertPoint:event.locationInWindow fromView:nil];
    yaw += (position.x - lastMousePosition.x) * 0.01;
    pitch -= (position.y - lastMousePosition.y) * 0.01;
    lastMousePosition = position;
    [self setNeedsDisplay:YES];
}

- (BOOL)isOpaque {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    const NSRect bounds = self.bounds;
    [[NSColor colorWithCalibratedRed:0.075 green:0.095 blue:0.13 alpha:1.0] setFill];
    NSRectFill(bounds);

    const double scale = std::min(bounds.size.width, bounds.size.height) * 0.27;
    const double cx = NSMidX(bounds);
    const double cy = NSMidY(bounds) + scale * 0.08;

    // A soft ground shadow anchors the cube in the scene.
    [NSGraphicsContext saveGraphicsState];
    NSShadow *shadow = [[NSShadow alloc] init];
    shadow.shadowColor = [NSColor colorWithWhite:0 alpha:0.45];
    shadow.shadowBlurRadius = scale * 0.15;
    shadow.shadowOffset = NSMakeSize(0, 0);
    [shadow set];
    [[NSColor colorWithWhite:0 alpha:0.25] setFill];
    [[NSBezierPath bezierPathWithOvalInRect:
        NSMakeRect(cx - scale * 0.85, cy - scale * 1.12,
                   scale * 1.7, scale * 0.25)] fill];
    [NSGraphicsContext restoreGraphicsState];

    for (const auto &face : fireplace::cube_faces(yaw, pitch)) {
        NSBezierPath *path = [NSBezierPath bezierPath];
        const auto first = face.points.front();
        [path moveToPoint:NSMakePoint(cx + first.x * scale, cy + first.y * scale)];
        for (std::size_t i = 1; i < face.points.size(); ++i) {
            const auto point = face.points[i];
            [path lineToPoint:NSMakePoint(cx + point.x * scale, cy + point.y * scale)];
        }
        [path closePath];
        NSColor *color = [NSColor colorWithCalibratedRed:face.color.red
                                                 green:face.color.green
                                                  blue:face.color.blue alpha:1.0];
        [color setFill];
        [path fill];
        [color setStroke];
        [path setLineWidth:0.5];
        [path stroke];
    }
}
@end

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
        [window setContentView:[[FireplaceSceneView alloc] initWithFrame:
            NSMakeRect(0, 0, 800, 600)]];
        [window setContentMinSize:NSMakeSize(320, 240)];
        [window center];
        [window makeKeyAndOrderFront:nil];
        [app activateIgnoringOtherApps:YES];
        [app run];

        [app setDelegate:nil];
    }
    return 0;
}

}
