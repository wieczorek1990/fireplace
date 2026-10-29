#pragma once

#include <array>
#include "wood_physics.h"
#include "light_shader.h"

namespace fireplace {

struct Point {
  double x, y;
};
struct Face {
  std::array<Point, 4> points;
  Color color;
  double fire_light;
  double fire_center_strength;
  bool faces_fire;
};

// Orthographic projection, sorted from farthest to nearest face.
std::array<Face, 48> log_faces(double yaw, double pitch,
                               const std::array<WoodLog, 8> &logs, double fuel,
                               double fire_intensity);

using GrainLine = std::array<Point, 25>;
std::array<GrainLine, 12> wood_grain(const Face &face);

} // namespace fireplace
