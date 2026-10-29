#import <AppKit/AppKit.h>

#include "combustion.h"
#include "fire.h"
#include "scene.h"
#include "window.h"
#include "wood_physics.h"
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

fireplace::Point groundPoint(double x, double z, double yaw, double pitch) {
  const double rotatedX = x * std::cos(yaw) + z * std::sin(yaw);
  const double rotatedZ = -x * std::sin(yaw) + z * std::cos(yaw);
  return {rotatedX, -0.8 * std::cos(pitch) - rotatedZ * std::sin(pitch)};
}

void drawStones(bool front, double cx, double cy, double scale, double light,
                double yaw, double pitch) {
  constexpr int count = 15;
  constexpr double pi = 3.141592653589793;
  for (int i = 0; i < count; ++i) {
    const double angle = 2 * pi * i / count;
    const double depth =
        -std::cos(angle) * std::sin(yaw) + std::sin(angle) * std::cos(yaw);
    if ((depth > 0) != front)
      continue;
    const auto position =
        groundPoint(1.12 * std::cos(angle), 1.12 * std::sin(angle), yaw, pitch);
    const double x = cx + position.x * scale;
    const double y = cy + position.y * scale;
    const double width = scale * (0.19 + 0.025 * std::sin(i * 3.1));
    const double height = scale * (0.105 + 0.018 * std::cos(i * 2.3));
    NSBezierPath *stone = [NSBezierPath bezierPath];
    [stone moveToPoint:NSMakePoint(x - width, y)];
    [stone curveToPoint:NSMakePoint(x, y + height)
          controlPoint1:NSMakePoint(x - width, y + height * 0.65)
          controlPoint2:NSMakePoint(x - width * 0.55, y + height)];
    [stone curveToPoint:NSMakePoint(x + width, y)
          controlPoint1:NSMakePoint(x + width * 0.6, y + height * 1.05)
          controlPoint2:NSMakePoint(x + width, y + height * 0.55)];
    [stone curveToPoint:NSMakePoint(x, y - height * 0.7)
          controlPoint1:NSMakePoint(x + width, y - height * 0.5)
          controlPoint2:NSMakePoint(x + width * 0.5, y - height * 0.75)];
    [stone curveToPoint:NSMakePoint(x - width, y)
          controlPoint1:NSMakePoint(x - width * 0.6, y - height * 0.75)
          controlPoint2:NSMakePoint(x - width, y - height * 0.45)];
    [stone closePath];
    const double shade = 0.34 + 0.055 * std::sin(i * 4.3);
    NSGradient *gradient = [[NSGradient alloc]
        initWithStartingColor:[NSColor colorWithCalibratedWhite:shade + 0.16
                                                          alpha:1]
                  endingColor:[NSColor colorWithCalibratedWhite:shade - 0.09
                                                          alpha:1]];
    [gradient drawInBezierPath:stone angle:90];
    [NSGraphicsContext saveGraphicsState];
    [stone addClip];
    NSGradient *reflected = [[NSGradient alloc]
        initWithStartingColor:[NSColor colorWithCalibratedRed:1
                                                        green:0.32
                                                         blue:0.06
                                                        alpha:light * 0.42]
                  endingColor:[NSColor colorWithCalibratedRed:1
                                                        green:0.22
                                                         blue:0.02
                                                        alpha:0]];
    [reflected drawInBezierPath:stone angle:(x < cx ? 0 : 180)];
    [NSGraphicsContext restoreGraphicsState];
    [[NSColor colorWithCalibratedWhite:0.19 alpha:0.9] setStroke];
    [stone setLineWidth:std::max(0.6, scale * 0.008)];
    [stone stroke];
  }
}

void drawCoals(double time, double cx, double cy, double scale, double amount,
               double heat, double yaw, double pitch) {
  constexpr int count = 32;
  const double coverage = std::clamp(amount * 12.0, 0.0, 1.0);
  for (int i = 0; i < count; ++i) {
    if (i >= coverage * count)
      break;
    const double angle = i * 2.3999632297;
    const double radius = std::sqrt((i + 0.5) / count);
    const auto position =
        groundPoint(0.75 * radius * std::cos(angle),
                    0.75 * radius * std::sin(angle), yaw, pitch);
    const double x = cx + scale * position.x;
    const double y = cy + scale * position.y;
    const double size =
        scale * (0.045 + 0.018 * (0.5 + 0.5 * std::sin(i * 7.2)));
    const double glow =
        std::clamp(heat * (0.8 + 0.2 * std::sin(time * 2.5 + i)), 0.0, 1.0);
    NSBezierPath *coal = [NSBezierPath
        bezierPathWithOvalInRect:NSMakeRect(x - size, y - size * 0.55, size * 2,
                                            size * 1.1)];
    [[NSColor colorWithCalibratedRed:0.12 + glow * 0.65
                               green:0.045 + glow * 0.2
                                blue:0.025 + glow * 0.025
                               alpha:1] setFill];
    [coal fill];
    [[NSColor colorWithCalibratedRed:1 green:0.35 blue:0.04
                               alpha:glow * 0.7] setStroke];
    [coal setLineWidth:std::max(0.5, scale * 0.006)];
    [coal stroke];
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

fireplace::Point woodSource(const fireplace::Face &face, std::size_t index) {
  // Pick stable points along the log surface, including near its burning edge.
  const double u = 0.2 + 0.6 * ((index * 37 % 97) / 96.0);
  const double v = 0.08 + 0.84 * ((index * 53 % 101) / 100.0);
  const auto &p = face.points;
  return {(1 - u) * (1 - v) * p[0].x + u * (1 - v) * p[1].x + u * v * p[2].x +
              (1 - u) * v * p[3].x,
          (1 - u) * (1 - v) * p[0].y + u * (1 - v) * p[1].y + u * v * p[2].y +
              (1 - u) * v * p[3].y};
}

std::size_t innerFace(const std::array<fireplace::Face, 48> &faces,
                      std::size_t seed) {
  std::array<std::size_t, 48> inner{};
  std::size_t count = 0;
  for (std::size_t i = 0; i < faces.size(); ++i)
    if (faces[i].faces_fire && faces[i].opacity > 0.01)
      inner[count++] = i;
  return count ? inner[(seed * 17) % count] : seed % faces.size();
}

template <typename Particle, std::size_t N>
void attachFlames(std::array<Particle, N> &particles,
                  const std::array<fireplace::Face, 48> &faces,
                  double intensity) {
  for (std::size_t i = 0; i < N; ++i) {
    auto &flame = particles[i];
    const auto faceIndex = innerFace(faces, i);
    const auto source = woodSource(faces[faceIndex], i);
    flame.behind = faceIndex < faces.size() / 2;
    flame.base.x += source.x - flame.source.x;
    flame.base.y += source.y - flame.source.y;
    const double center = faces[faceIndex].fire_center_strength;
    flame.height *= (0.55 + 0.65 * center) * std::sqrt(intensity);
    flame.width *= 0.75 + 0.25 * center;
    flame.opacity *= 0.35 + 0.65 * center;
  }
}

void drawEmbers(double time, bool behind, double cx, double cy, double scale,
                double remaining,
                const std::array<fireplace::Face, 48> &faces) {
  [NSGraphicsContext saveGraphicsState];
  [[NSGraphicsContext currentContext]
      setCompositingOperation:NSCompositingOperationPlusLighter];
  auto embers = fireplace::fire_embers(time);
  for (std::size_t i = 0; i < embers.size(); ++i) {
    auto &ember = embers[i];
    const auto faceIndex = innerFace(faces, i);
    const auto source = woodSource(faces[faceIndex], i);
    if ((faceIndex < faces.size() / 2) != behind || remaining <= 0)
      continue;
    ember.position.x += source.x - ember.source.x;
    ember.position.y += source.y - ember.source.y;
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

void drawFire(double time, bool behind, double cx, double cy, double scale,
              double intensity, const std::array<fireplace::Face, 48> &faces) {
  auto bed = fireplace::flame_bed(time);
  auto wisps = fireplace::rising_wisps(time);
  attachFlames(bed, faces, intensity);
  attachFlames(wisps, faces, intensity);
  drawFlames(std::span<const fireplace::BedFlame>(bed), behind, cx, cy, scale);
  drawFlames(std::span<const fireplace::RisingWisp>(wisps), behind, cx, cy,
             scale);
  drawEmbers(time, behind, cx, cy, scale, intensity, faces);
}

} // namespace

@interface FireplaceSceneView : NSView {
  double yaw;
  double pitch;
  NSPoint lastMousePosition;
  NSTimer *animationTimer;
  NSTimeInterval animationStart;
  NSTimeInterval lastSimulationTime;
  double simulationTime;
  double timeSpeed;
  fireplace::Combustion combustion;
  fireplace::WoodPhysics woodPhysics;
}
@end

@implementation FireplaceSceneView
- (void)viewDidMoveToWindow {
  [super viewDidMoveToWindow];
  [animationTimer invalidate];
  animationTimer = nil;
  if (self.window) {
    animationStart = NSProcessInfo.processInfo.systemUptime;
    lastSimulationTime = animationStart;
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
    timeSpeed = 1.0;
  }
  return self;
}

- (void)setTimeSpeed:(double)speed {
  timeSpeed = speed;
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

  // A soft ground shadow anchors the logs in the scene.
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

  const double now = NSProcessInfo.processInfo.systemUptime;
  const double elapsed = std::max(0.0, now - lastSimulationTime) * timeSpeed;
  lastSimulationTime = now;
  simulationTime += elapsed;
  const double time = simulationTime;
  const double ventilation = 0.7 + 0.25 * std::sin(time * 0.34);
  combustion.advance(elapsed, ventilation);
  woodPhysics.advance(elapsed, combustion.fuel);
  // Remaining fuel controls the length of the burning logs.
  const double remaining = combustion.fuel;
  const double fireIntensity = combustion.flame;
  const double flicker =
      0.83 + 0.10 * std::sin(time * 7.3) + 0.07 * std::sin(time * 12.7 + 0.8);
  const double firelight = std::clamp(
      (fireIntensity + combustion.coal_heat * 0.45) * flicker, 0.0, 1.0);
  const double fireScale = scale;
  const double fireCy = cy;
  const auto faces =
      fireplace::log_faces(yaw, pitch, woodPhysics.logs, remaining, firelight);
  // A broad, soft pool of warm light illuminates the background and ground.
  NSGradient *ambientLight = [[NSGradient alloc]
      initWithStartingColor:[NSColor colorWithCalibratedRed:1
                                                      green:0.24
                                                       blue:0.035
                                                      alpha:firelight * 0.18]
                endingColor:[NSColor colorWithCalibratedRed:1
                                                      green:0.18
                                                       blue:0.01
                                                      alpha:0]];
  [ambientLight
            drawInBezierPath:[NSBezierPath
                                 bezierPathWithOvalInRect:NSMakeRect(
                                                              cx - scale * 2.8,
                                                              cy - scale * 2.4,
                                                              scale * 5.6,
                                                              scale * 4.7)]
      relativeCenterPosition:NSMakePoint(0, -0.25)];
  // Scattered light lifts the dark surroundings toward a warm pale grey.
  NSGradient *scatteredLight = [[NSGradient alloc]
      initWithStartingColor:[NSColor colorWithCalibratedRed:1.0
                                                      green:0.89
                                                       blue:0.72
                                                      alpha:firelight * 0.30]
                endingColor:[NSColor colorWithCalibratedRed:1.0
                                                      green:0.85
                                                       blue:0.65
                                                      alpha:0]];
  [scatteredLight
            drawInBezierPath:[NSBezierPath
                                 bezierPathWithOvalInRect:NSMakeRect(
                                                              cx - scale * 3.5,
                                                              cy - scale * 2.8,
                                                              scale * 7.0,
                                                              scale * 5.8)]
      relativeCenterPosition:NSMakePoint(0, -0.2)];
  [NSGraphicsContext saveGraphicsState];
  CGContextSetAlpha(NSGraphicsContext.currentContext.CGContext,
                    std::max(fireIntensity, combustion.coal_heat * 0.65) *
                        flicker);
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
  [NSGraphicsContext restoreGraphicsState];
  drawStones(false, cx, cy, scale, firelight, yaw, pitch);
  drawCoals(time, cx, cy, scale, combustion.coal, combustion.coal_heat, yaw,
            pitch);
  [NSGraphicsContext saveGraphicsState];
  CGContextSetAlpha(NSGraphicsContext.currentContext.CGContext, fireIntensity);
  [NSGraphicsContext saveGraphicsState];
  CGContextSetAlpha(NSGraphicsContext.currentContext.CGContext,
                    std::clamp(0.3 + combustion.soot * 30.0, 0.0, 1.0));
  drawSmoke(time, cx, fireCy, fireScale);
  [NSGraphicsContext restoreGraphicsState];
  drawFire(time, true, cx, fireCy, fireScale, fireIntensity, faces);
  [NSGraphicsContext restoreGraphicsState];
  if (remaining > 0) {
    [NSGraphicsContext saveGraphicsState];
    for (const auto &face : faces) {
      if (face.opacity <= 0)
        continue;
      [NSGraphicsContext saveGraphicsState];
      CGContextSetAlpha(NSGraphicsContext.currentContext.CGContext, face.opacity);
      NSBezierPath *path = [NSBezierPath bezierPath];
      const auto first = face.points.front();
      [path moveToPoint:NSMakePoint(cx + first.x * fireScale,
                                    fireCy + first.y * fireScale)];
      for (std::size_t i = 1; i < face.points.size(); ++i) {
        const auto point = face.points[i];
        [path lineToPoint:NSMakePoint(cx + point.x * fireScale,
                                      fireCy + point.y * fireScale)];
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
        [grain moveToPoint:NSMakePoint(cx + line[0].x * fireScale,
                                       fireCy + line[0].y * fireScale)];
        for (std::size_t i = 1; i < line.size(); ++i) {
          [grain lineToPoint:NSMakePoint(cx + line[i].x * fireScale,
                                         fireCy + line[i].y * fireScale)];
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
      const double woodLight = face.fire_light * 0.24;
      NSGradient *firelight = [[NSGradient alloc]
          initWithStartingColor:[NSColor colorWithCalibratedRed:1
                                                          green:0.32
                                                           blue:0.035
                                                          alpha:woodLight]
                    endingColor:[NSColor colorWithCalibratedRed:1
                                                          green:0.5
                                                           blue:0.1
                                                          alpha:0]];
      [firelight drawInBezierPath:path angle:90];
      [NSGraphicsContext restoreGraphicsState];
      [NSGraphicsContext restoreGraphicsState];
    }
    [NSGraphicsContext restoreGraphicsState];
  }
  [NSGraphicsContext saveGraphicsState];
  CGContextSetAlpha(NSGraphicsContext.currentContext.CGContext, fireIntensity);
  drawFire(time, false, cx, fireCy, fireScale, fireIntensity, faces);
  [NSGraphicsContext restoreGraphicsState];
  drawStones(true, cx, cy, scale, firelight, yaw, pitch);
}
@end

@interface FireplaceControls : NSObject
@property(nonatomic, weak) FireplaceSceneView *scene;
@property(nonatomic, weak) NSTextField *speedLabel;
- (void)speedChanged:(NSSlider *)slider;
@end

@implementation FireplaceControls
- (void)speedChanged:(NSSlider *)slider {
  const double speed = slider.doubleValue;
  [self.scene setTimeSpeed:speed];
  self.speedLabel.stringValue =
      [NSString stringWithFormat:@"Speed: %.1f×", speed];
}
@end

@interface FireplaceAppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) FireplaceControls *controls;
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
    FireplaceSceneView *scene =
        [[FireplaceSceneView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
    [window setContentView:scene];
    FireplaceControls *controls = [[FireplaceControls alloc] init];
    delegate.controls = controls;
    controls.scene = scene;
    NSTextField *speedLabel = [NSTextField labelWithString:@"Speed: 1.0×"];
    speedLabel.frame = NSMakeRect(20, 45, 120, 20);
    speedLabel.textColor = NSColor.whiteColor;
    speedLabel.autoresizingMask = NSViewMaxXMargin | NSViewMaxYMargin;
    [scene addSubview:speedLabel];
    controls.speedLabel = speedLabel;
    NSSlider *speedSlider = [NSSlider sliderWithValue:1.0
                                             minValue:0.0
                                             maxValue:32.0
                                               target:controls
                                               action:@selector(speedChanged:)];
    speedSlider.frame = NSMakeRect(20, 20, 180, 20);
    speedSlider.autoresizingMask = NSViewMaxXMargin | NSViewMaxYMargin;
    [scene addSubview:speedSlider];
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
