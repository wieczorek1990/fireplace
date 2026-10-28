#import <AppKit/AppKit.h>

#include "fire.h"
#include "scene.h"
#include "window.h"
#include <span>

#include <algorithm>
#include <cmath>

namespace {
void drawSmoke(double time, double cx, double cy, double scale) {
  for (const auto &puff : fireplace::fire_smoke(time)) {
    const double radius = scale * puff.radius;
    const double x = cx + scale * puff.position.x;
    const double y = cy + scale * puff.position.y;
    const double opacity = puff.opacity;
    NSGradient *smoke = [[NSGradient alloc]
        initWithStartingColor:[NSColor colorWithCalibratedRed:0.34
                                                        green:0.32
                                                         blue:0.30
                                                        alpha:opacity]
                  endingColor:[NSColor colorWithWhite:0.3 alpha:0]];
    [smoke drawInBezierPath:[NSBezierPath
                                bezierPathWithOvalInRect:NSMakeRect(x - radius,
                                                                    y - radius,
                                                                    radius * 2,
                                                                    radius * 2)]
        relativeCenterPosition:NSZeroPoint];
  }
}

template <typename Particle>
void drawFlames(std::span<const Particle> flames, bool behind, double cx,
                double cy, double scale) {
  [NSGraphicsContext saveGraphicsState];
  // Light from overlapping flames accumulates instead of obscuring other
  // flames.
  [[NSGraphicsContext currentContext]
      setCompositingOperation:NSCompositingOperationPlusLighter];
  for (const auto &flame : flames) {
    if (flame.behind != behind)
      continue;
    const double x = cx + flame.base.x * scale;
    const double y = cy + flame.base.y * scale;
    const double w = flame.width * scale;
    const double h = flame.height * scale;
    const double lean = flame.lean * scale;
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(x - w, y)];
    [path curveToPoint:NSMakePoint(x + lean, y + h)
         controlPoint1:NSMakePoint(x - w * 1.4, y + h * 0.35)
         controlPoint2:NSMakePoint(x + lean - w, y + h * 0.7)];
    [path curveToPoint:NSMakePoint(x + w, y)
         controlPoint1:NSMakePoint(x + lean * 0.3, y + h * 0.45)
         controlPoint2:NSMakePoint(x + w * 1.5, y + h * 0.25)];
    [path closePath];
    NSGradient *gradient = [[NSGradient alloc]
        initWithColorsAndLocations:[NSColor
                                       colorWithCalibratedRed:1
                                                        green:0.91
                                                         blue:0.48
                                                        alpha:flame.opacity],
                                   0.0,
                                   [NSColor
                                       colorWithCalibratedRed:1
                                                        green:0.44
                                                         blue:0.035
                                                        alpha:flame.opacity *
                                                              0.8],
                                   0.4,
                                   [NSColor colorWithCalibratedRed:0.8
                                                             green:0.12
                                                              blue:0.01
                                                             alpha:0],
                                   1.0, nil];
    [gradient drawInBezierPath:path angle:90];
    NSGradient *core = [[NSGradient alloc]
        initWithStartingColor:[NSColor
                                  colorWithCalibratedRed:1
                                                   green:0.79
                                                    blue:0.26
                                                   alpha:flame.opacity * 0.22]
                  endingColor:[NSColor colorWithCalibratedRed:1
                                                        green:0.3
                                                         blue:0
                                                        alpha:0]];
    [core drawInBezierPath:[NSBezierPath
                               bezierPathWithOvalInRect:NSMakeRect(x - w * 1.8,
                                                                   y - h * 0.1,
                                                                   w * 3.6,
                                                                   h * 0.8)]
        relativeCenterPosition:NSMakePoint(0, -0.5)];
  }
  [NSGraphicsContext restoreGraphicsState];
}

void drawEmbers(double time, bool behind, double cx, double cy, double scale) {
  [NSGraphicsContext saveGraphicsState];
  [[NSGraphicsContext currentContext]
      setCompositingOperation:NSCompositingOperationPlusLighter];
  for (const auto &ember : fireplace::fire_embers(time)) {
    if (ember.behind != behind)
      continue;
    const double radius = std::max(0.5, ember.radius * scale);
    [[NSColor colorWithCalibratedRed:1 green:0.6 blue:0.15
                               alpha:ember.opacity] setFill];
    [[NSBezierPath
        bezierPathWithOvalInRect:NSMakeRect(
                                     cx + ember.position.x * scale - radius,
                                     cy + ember.position.y * scale - radius,
                                     radius * 2, radius * 3)] fill];
  }
  [NSGraphicsContext restoreGraphicsState];
}

void drawFire(double time, bool behind, double cx, double cy, double scale) {
  const auto bed = fireplace::flame_bed(time);
  const auto wisps = fireplace::rising_wisps(time);
  drawFlames(std::span<const fireplace::BedFlame>(bed), behind, cx, cy, scale);
  drawFlames(std::span<const fireplace::RisingWisp>(wisps), behind, cx, cy,
             scale);
  drawEmbers(time, behind, cx, cy, scale);
}

} // namespace

@interface FireplaceSceneView : NSView {
  double yaw;
  double pitch;
  NSPoint lastMousePosition;
  NSTimer *animationTimer;
  NSTimeInterval animationStart;
}
@end

@implementation FireplaceSceneView
- (void)viewDidMoveToWindow {
  [super viewDidMoveToWindow];
  [animationTimer invalidate];
  animationTimer = nil;
  if (self.window) {
    animationStart = NSProcessInfo.processInfo.systemUptime;
    __weak FireplaceSceneView *weakSelf = self;
    animationTimer = [NSTimer timerWithTimeInterval:1.0 / 60.0
                                            repeats:YES
                                              block:^(NSTimer *timer) {
                                                [weakSelf setNeedsDisplay:YES];
                                              }];
    [[NSRunLoop mainRunLoop] addTimer:animationTimer
                              forMode:NSRunLoopCommonModes];
  }
}

- (void)dealloc {
  [animationTimer invalidate];
}

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
  const NSPoint position = [self convertPoint:event.locationInWindow
                                     fromView:nil];
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
  [[NSColor colorWithCalibratedRed:0.075 green:0.095 blue:0.13
                             alpha:1.0] setFill];
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
  [[NSBezierPath
      bezierPathWithOvalInRect:NSMakeRect(cx - scale * 0.85, cy - scale * 1.12,
                                          scale * 1.7, scale * 0.25)] fill];
  [NSGraphicsContext restoreGraphicsState];

  const double time = NSProcessInfo.processInfo.systemUptime - animationStart;
  NSGradient *glow = [[NSGradient alloc]
      initWithStartingColor:[NSColor colorWithCalibratedRed:1
                                                      green:0.24
                                                       blue:0.015
                                                      alpha:0.22]
                endingColor:[NSColor colorWithCalibratedRed:1
                                                      green:0.12
                                                       blue:0
                                                      alpha:0]];
  [glow drawInBezierPath:[NSBezierPath
                             bezierPathWithOvalInRect:NSMakeRect(
                                                          cx - scale * 1.5,
                                                          cy - scale * 1.5,
                                                          scale * 3, scale * 2)]
      relativeCenterPosition:NSMakePoint(0, -0.15)];
  drawSmoke(time, cx, cy, scale);
  drawFire(time, true, cx, cy, scale);
  for (const auto &face : fireplace::cube_faces(yaw, pitch)) {
    NSBezierPath *path = [NSBezierPath bezierPath];
    const auto first = face.points.front();
    [path moveToPoint:NSMakePoint(cx + first.x * scale, cy + first.y * scale)];
    for (std::size_t i = 1; i < face.points.size(); ++i) {
      const auto point = face.points[i];
      [path
          lineToPoint:NSMakePoint(cx + point.x * scale, cy + point.y * scale)];
    }
    [path closePath];
    NSColor *color = [NSColor colorWithCalibratedRed:face.color.red
                                               green:face.color.green
                                                blue:face.color.blue
                                               alpha:1.0];
    [color setFill];
    [path fill];
    [color setStroke];
    [path setLineWidth:0.5];
    [path stroke];

    [NSGraphicsContext saveGraphicsState];
    [path addClip];
    std::size_t grainIndex = 0;
    for (const auto &line : fireplace::wood_grain(face)) {
      NSBezierPath *grain = [NSBezierPath bezierPath];
      [grain moveToPoint:NSMakePoint(cx + line[0].x * scale,
                                     cy + line[0].y * scale)];
      for (std::size_t i = 1; i < line.size(); ++i) {
        [grain lineToPoint:NSMakePoint(cx + line[i].x * scale,
                                       cy + line[i].y * scale)];
      }
      const bool highlight = grainIndex++ % 4 == 0;
      NSColor *grainColor = highlight ? [NSColor colorWithCalibratedRed:1
                                                                  green:0.77
                                                                   blue:0.44
                                                                  alpha:0.22]
                                      : [NSColor colorWithCalibratedRed:0.19
                                                                  green:0.085
                                                                   blue:0.025
                                                                  alpha:0.3];
      [grainColor setStroke];
      [grain setLineWidth:std::max(0.5, scale * (highlight ? 0.010 : 0.016))];
      [grain stroke];
    }
    const double flicker =
        0.14 + 0.035 * std::sin(time * 9.7) + 0.025 * std::sin(time * 17.3);
    NSGradient *firelight = [[NSGradient alloc]
        initWithStartingColor:[NSColor colorWithCalibratedRed:1
                                                        green:0.32
                                                         blue:0.035
                                                        alpha:flicker]
                  endingColor:[NSColor colorWithCalibratedRed:1
                                                        green:0.5
                                                         blue:0.1
                                                        alpha:0]];
    [firelight drawInBezierPath:path angle:90];
    [NSGraphicsContext restoreGraphicsState];
  }
  drawFire(time, false, cx, cy, scale);
}
@end

@interface FireplaceAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation FireplaceAppDelegate
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)sender {
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

    NSWindow *window =
        [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 600)
                                    styleMask:(NSWindowStyleMaskTitled |
                                               NSWindowStyleMaskClosable |
                                               NSWindowStyleMaskMiniaturizable |
                                               NSWindowStyleMaskResizable)
                                      backing:NSBackingStoreBuffered
                                        defer:NO];
    [window setReleasedWhenClosed:NO];
    [window setTitle:@"Fireplace"];
    [window setContentView:[[FireplaceSceneView alloc]
                               initWithFrame:NSMakeRect(0, 0, 800, 600)]];
    [window setContentMinSize:NSMakeSize(320, 240)];
    [window center];
    [window makeKeyAndOrderFront:nil];
    [app activateIgnoringOtherApps:YES];
    [app run];

    [app setDelegate:nil];
  }
  return 0;
}

} // namespace fireplace
