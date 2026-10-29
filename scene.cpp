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

std::array<Face, 48> log_faces(double yaw, double pitch) {
  constexpr int logCount = 8;
  constexpr int sides = 6;
  constexpr double pi = 3.141592653589793;
  struct ProjectedFace { Face face; double depth; };
  std::array<ProjectedFace, logCount * sides> projected{};
  for (int log = 0; log < logCount; ++log) {
    const double angle = 2 * pi * log / logCount;
    const Vector bottom{0.67 * std::cos(angle), -0.8, 0.67 * std::sin(angle)};
    const Vector top{0.12 * std::cos(angle), 0.82, 0.12 * std::sin(angle)};
    // A radial vector and a perpendicular vector span each log's cross section.
    const Vector radial{std::cos(angle) * 0.947, 0.321, std::sin(angle) * 0.947};
    const Vector tangent{-std::sin(angle), 0, std::cos(angle)};
    auto vertex = [&](bool upper, int side) {
      const double theta = 2 * pi * side / sides;
      const Vector center = upper ? top : bottom;
      return Vector{center.x + 0.16 * (radial.x * std::cos(theta) + tangent.x * std::sin(theta)),
                    center.y + 0.16 * radial.y * std::cos(theta),
                    center.z + 0.16 * (radial.z * std::cos(theta) + tangent.z * std::sin(theta))};
    };
    for (int side = 0; side < sides; ++side) {
      auto &result = projected[log * sides + side];
      const std::array<Vector, 4> corners{vertex(false, side), vertex(false, side + 1),
                                           vertex(true, side + 1), vertex(true, side)};
      for (int j = 0; j < 4; ++j) {
        const auto point = rotate(corners[j], yaw, pitch);
        result.face.points[j] = {point.x, point.y};
        result.depth += point.z / 4;
      }
      const double theta = 2 * pi * (side + 0.5) / sides;
      const auto normal = rotate({radial.x * std::cos(theta) + tangent.x * std::sin(theta),
                                  radial.y * std::cos(theta),
                                  radial.z * std::cos(theta) + tangent.z * std::sin(theta)}, yaw, pitch);
      const double light = 0.55 + 0.45 * std::max(0.0, -normal.x * 0.4 + normal.y * 0.8 + normal.z * 0.4472135955);
      result.face.color = {0.72 * light, 0.43 * light, 0.21 * light};
    }
  }
  std::ranges::sort(projected, {}, &ProjectedFace::depth);
  std::array<Face, logCount * sides> faces{};
  for (std::size_t i = 0; i < faces.size(); ++i) faces[i] = projected[i].face;
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
