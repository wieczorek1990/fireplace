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
        result.face.color = {0.72 * light, 0.89 * light, light};
    }
    std::ranges::sort(projected, {}, &ProjectedFace::depth);
    std::array<Face, 6> faces{};
    for (std::size_t i = 0; i < faces.size(); ++i) {
        faces[i] = projected[i].face;
    }
    return faces;
}
}
