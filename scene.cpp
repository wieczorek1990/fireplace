#include "scene.h"

#include <algorithm>
#include <cmath>

namespace fireplace {

namespace {
struct Vector { double x, y, z; };
Vector rotate(Vector p, double yaw, double pitch) {
    const double x = p.x * std::cos(yaw) + p.z * std::sin(yaw);
    const double z = -p.x * std::sin(yaw) + p.z * std::cos(yaw);
    return {x, p.y * std::cos(pitch) - z * std::sin(pitch),
            p.y * std::sin(pitch) + z * std::cos(pitch)};
}
}

std::array<Face, 6> cube_faces(double yaw, double pitch) {
    constexpr std::array<Vector, 8> vertices{{
        {-0.6, -0.6, -0.6}, {0.6, -0.6, -0.6},
        {0.6, 0.6, -0.6}, {-0.6, 0.6, -0.6},
        {-0.6, -0.6, 0.6}, {0.6, -0.6, 0.6},
        {0.6, 0.6, 0.6}, {-0.6, 0.6, 0.6},
    }};
    constexpr std::array<std::array<int, 4>, 6> indices{{
        {0, 3, 2, 1}, {4, 5, 6, 7}, {0, 4, 7, 3},
        {1, 2, 6, 5}, {0, 1, 5, 4}, {3, 7, 6, 2},
    }};
    constexpr std::array<Vector, 6> normals{{
        {0, 0, -1}, {0, 0, 1}, {-1, 0, 0},
        {1, 0, 0}, {0, -1, 0}, {0, 1, 0},
    }};
    struct ProjectedFace { Face face; double depth; };
    std::array<ProjectedFace, 6> projected{};
    for (std::size_t i = 0; i < indices.size(); ++i) {
        auto &result = projected[i];
        for (std::size_t j = 0; j < 4; ++j) {
            const auto point = rotate(vertices[indices[i][j]], yaw, pitch);
            result.face.points[j] = {point.x, point.y};
            result.depth += point.z / 4;
        }
        const auto normal = rotate(normals[i], yaw, pitch);
        // Fixed light above and to the left of the viewer.
        const double light = 0.55 + 0.45 * std::max(0.0,
            -normal.x * 0.4 + normal.y * 0.8 + normal.z * 0.4472135955);
        result.face.color = {0.72 * light, 0.43 * light, 0.21 * light};
    }
    std::ranges::sort(projected, {}, &ProjectedFace::depth);
    std::array<Face, 6> faces{};
    for (std::size_t i = 0; i < faces.size(); ++i) {
        faces[i] = projected[i].face;
    }
    return faces;
}

std::array<GrainLine, 12> wood_grain(const Face &face) {
    std::array<GrainLine, 12> lines{};
    for (std::size_t i = 0; i < lines.size(); ++i) {
        for (std::size_t j = 0; j < lines[i].size(); ++j) {
            const double v = static_cast<double>(j) / (lines[i].size() - 1);
            const double u = (i + 0.5) / lines.size()
                + 0.022 * std::sin(v * 7 + i * 1.7)
                + 0.013 * std::sin(v * 12 + i * 0.9);
            // Map grain into the projected face so it rotates with the wood.
            const auto &p = face.points;
            lines[i][j] = {
                (1-u)*(1-v)*p[0].x + u*(1-v)*p[1].x + u*v*p[2].x + (1-u)*v*p[3].x,
                (1-u)*(1-v)*p[0].y + u*(1-v)*p[1].y + u*v*p[2].y + (1-u)*v*p[3].y
            };
        }
    }
    return lines;
}
}
