#pragma once

#include <array>

namespace fireplace {

struct Point { double x, y; };
struct Color { double red, green, blue; };
struct Face {
    std::array<Point, 4> points;
    Color color;
};

// Orthographic projection, sorted from farthest to nearest face.
std::array<Face, 6> cube_faces(double yaw, double pitch);

}
