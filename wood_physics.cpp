#include "wood_physics.h"
#include <algorithm>
#include <cmath>

namespace fireplace {
namespace {
constexpr double pi = 3.141592653589793;
constexpr double floorHeight = -0.8;
constexpr double length = 1.710233902;
void constrain(WoodPoint &p) {
  p.y = std::max(p.y, floorHeight);
  // Keep the settling wood over the coal bed inside the stone ring.
  const double r = std::hypot(p.x, p.z);
  if (r > 0.98) {
    p.x *= 0.98 / r;
    p.z *= 0.98 / r;
  }
}
} // namespace
WoodPhysics::WoodPhysics() {
  for (std::size_t i = 0; i < logs.size(); ++i) {
    const double a = 2 * pi * i / logs.size();
    logs[i].ends = {{{0.67 * std::cos(a), floorHeight, 0.67 * std::sin(a)},
                     {0.12 * std::cos(a), 0.82, 0.12 * std::sin(a)}}};
    logs[i].previous = logs[i].ends;
  }
}
void WoodPhysics::advance(double seconds, double fuel) {
  accumulated_time += std::max(0.0, seconds);
  constexpr double dt = 0.01;
  while (accumulated_time >= dt) {
    accumulated_time -= dt;
    for (std::size_t i = 0; i < logs.size(); ++i) {
      auto &log = logs[i];
      if (fuel > 0.98 - 0.025 * i)
        continue;
      const double angle = 2 * pi * i / logs.size();
      for (int end = 0; end < 2; ++end) {
        auto &p = log.ends[end];
        auto &prev = log.previous[end];
        const auto old = p;
        // Damping and a speed limit keep impacts from throwing logs outward.
        constexpr double maxStep = 0.004;
        p.x += std::clamp((p.x - prev.x) * 0.94, -maxStep, maxStep);
        p.y += std::clamp((p.y - prev.y) * 0.94, -maxStep, maxStep) -
               gravity * dt * dt;
        p.z += std::clamp((p.z - prev.z) * 0.94, -maxStep, maxStep);
        // Tip each log inward, toward the fire, along its radial direction.
        const double radialPush = (end == 1 ? -1.1 : 0.25) * dt * dt;
        p.x += std::cos(angle) * radialPush;
        p.z += std::sin(angle) * radialPush;
        prev = old;
      }
    }
    for (int iteration = 0; iteration < 8; ++iteration) {
      for (std::size_t i = 0; i < logs.size(); ++i) {
        if (fuel > 0.98 - 0.025 * i)
          continue;
        auto &a = logs[i].ends[0];
        auto &b = logs[i].ends[1];
        const double dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z;
        const double d = std::max(1e-9, std::sqrt(dx * dx + dy * dy + dz * dz));
        const double burnedLength = length * std::clamp(fuel, 0.02, 1.0);
        const double correction = (d - burnedLength) / (2 * d);
        a.x += dx * correction;
        a.y += dy * correction;
        a.z += dz * correction;
        b.x -= dx * correction;
        b.y -= dy * correction;
        b.z -= dz * correction;
        constrain(a);
        constrain(b);
      }
      // Repel sampled points on released logs to approximate log contacts.
      for (std::size_t i = 0; i < logs.size(); ++i)
        for (std::size_t j = i + 1; j < logs.size(); ++j) {
          if (fuel > 0.98 - 0.025 * i || fuel > 0.98 - 0.025 * j)
            continue;
          for (int ai = 0; ai < 2; ++ai)
            for (int bj = 0; bj < 2; ++bj) {
              auto &a = logs[i].ends[ai];
              auto &b = logs[j].ends[bj];
              const double dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z;
              const double d = std::sqrt(dx * dx + dy * dy + dz * dz);
              if (d > 1e-6 && d < 0.24) {
                const double k = (0.24 - d) / (2 * d);
                a.x -= dx * k;
                a.y -= dy * k;
                a.z -= dz * k;
                b.x += dx * k;
                b.y += dy * k;
                b.z += dz * k;
                constrain(a);
                constrain(b);
              }
            }
        }
    }
    // Ground contact removes downward velocity and friction damps sliding.
    for (auto &log : logs) {
      for (int end = 0; end < 2; ++end) {
        auto &p = log.ends[end];
        auto &previous = log.previous[end];
        if (p.y <= floorHeight + 1e-6) {
          if (previous.y > p.y)
            previous.y = p.y;
          previous.x = p.x - (p.x - previous.x) * 0.7;
          previous.z = p.z - (p.z - previous.z) * 0.7;
        }
      }
    }
  }
}
} // namespace fireplace
