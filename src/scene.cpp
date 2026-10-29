#include "scene.h"

#include <algorithm>
#include <cmath>

namespace fireplace {

namespace {
struct Vector {
  double x, y, z;
};
Vector rotate(Vector p, double yaw, double pitch) {
  const double x = p.x * std::cos(yaw) + p.z * std::sin(yaw);
  const double z = -p.x * std::sin(yaw) + p.z * std::cos(yaw);
  return {x, p.y * std::cos(pitch) - z * std::sin(pitch),
          p.y * std::sin(pitch) + z * std::cos(pitch)};
}
} // namespace

std::array<Face, 48> log_faces(double yaw, double pitch,
                               const std::array<WoodLog, 8> &logs, double fuel,
                               double fire_intensity) {
  constexpr int logCount = 8;
  constexpr int sides = 6;
  constexpr double pi = 3.141592653589793;
  struct ProjectedFace {
    Face face;
    double depth;
  };
  std::array<ProjectedFace, logCount * sides> projected{};
  for (int log = 0; log < logCount; ++log) {
    const double angle = 2 * pi * log / logCount;
    const auto &ends = logs[log].ends;
    const Vector bottom{ends[0].x, ends[0].y, ends[0].z};
    // The physics endpoints already shorten as the wood burns.
    const Vector top{ends[1].x, ends[1].y, ends[1].z};
    const double dx = top.x - bottom.x, dy = top.y - bottom.y,
                 dz = top.z - bottom.z;
    const double length =
        std::max(1e-9, std::sqrt(dx * dx + dy * dy + dz * dz));
    // Use the original tangential direction to build a rotating cross-section.
    const Vector tangent{-std::sin(angle), 0, std::cos(angle)};
    Vector radial{dy * tangent.z / length,
                  (dz * tangent.x - dx * tangent.z) / length,
                  -dy * tangent.x / length};
    const double r =
        std::max(1e-9, std::sqrt(radial.x * radial.x + radial.y * radial.y +
                                 radial.z * radial.z));
    radial = {radial.x / r, radial.y / r, radial.z / r};
    auto vertex = [&](bool upper, int side) {
      const double theta = 2 * pi * side / sides;
      const Vector center = upper ? top : bottom;
      return Vector{center.x + 0.16 * (radial.x * std::cos(theta) +
                                       tangent.x * std::sin(theta)),
                    center.y + 0.16 * radial.y * std::cos(theta),
                    center.z + 0.16 * (radial.z * std::cos(theta) +
                                       tangent.z * std::sin(theta))};
    };
    for (int side = 0; side < sides; ++side) {
      auto &result = projected[log * sides + side];
      const std::array<Vector, 4> corners{
          vertex(false, side), vertex(false, side + 1), vertex(true, side + 1),
          vertex(true, side)};
      for (int j = 0; j < 4; ++j) {
        const auto point = rotate(corners[j], yaw, pitch);
        result.face.points[j] = {point.x, point.y};
        result.depth += point.z / 4;
      }
      const double theta = 2 * pi * (side + 0.5) / sides;
      const Vector worldNormal{
          radial.x * std::cos(theta) + tangent.x * std::sin(theta),
          radial.y * std::cos(theta),
          radial.z * std::cos(theta) + tangent.z * std::sin(theta)};
      const auto normal = rotate(worldNormal, yaw, pitch);
      Vector center{};
      for (const auto &corner : corners) {
        center.x += corner.x * 0.25;
        center.y += corner.y * 0.25;
        center.z += corner.z * 0.25;
      }
      const double radialDistance = std::hypot(center.x, center.z);
      result.face.fire_center_strength =
          std::exp(-2.5 * radialDistance * radialDistance);
      const auto lighting = shade_wood(
          {0.72, 0.43, 0.21}, {center.x, center.y, center.z},
          {worldNormal.x, worldNormal.y, worldNormal.z},
          {normal.x, normal.y, normal.z}, fuel, fire_intensity);
      result.face.faces_fire = lighting.facing > 0.2;
      result.face.fire_light = lighting.fire_light;
      result.face.color = lighting.color;
    }
  }
  std::ranges::sort(projected, {}, &ProjectedFace::depth);
  std::array<Face, logCount * sides> faces{};
  for (std::size_t i = 0; i < faces.size(); ++i)
    faces[i] = projected[i].face;
  return faces;
}

std::array<GrainLine, 12> wood_grain(const Face &face) {
  std::array<GrainLine, 12> lines{};
  for (std::size_t i = 0; i < lines.size(); ++i) {
    for (std::size_t j = 0; j < lines[i].size(); ++j) {
      const double v = static_cast<double>(j) / (lines[i].size() - 1);
      const double u = (i + 0.5) / lines.size() +
                       0.022 * std::sin(v * 7 + i * 1.7) +
                       0.013 * std::sin(v * 12 + i * 0.9);
      // Map grain into the projected face so it rotates with the wood.
      const auto &p = face.points;
      lines[i][j] = {(1 - u) * (1 - v) * p[0].x + u * (1 - v) * p[1].x +
                         u * v * p[2].x + (1 - u) * v * p[3].x,
                     (1 - u) * (1 - v) * p[0].y + u * (1 - v) * p[1].y +
                         u * v * p[2].y + (1 - u) * v * p[3].y};
    }
  }
  return lines;
}
} // namespace fireplace
