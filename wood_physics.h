#pragma once
#include <array>

namespace fireplace {
struct WoodPoint {
  double x, y, z;
};
struct WoodLog {
  std::array<WoodPoint, 2> ends{};
  std::array<WoodPoint, 2> previous{};
};
struct WoodPhysics {
  std::array<WoodLog, 8> logs{};
  double accumulated_time = 0;
  double gravity = 1.0; // Scene units per simulated second squared.
  WoodPhysics();
  void advance(double seconds, double fuel);
};
} // namespace fireplace
