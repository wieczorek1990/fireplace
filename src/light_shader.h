#pragma once

namespace fireplace {
struct Color {
  double red, green, blue;
};
struct LightVector {
  double x, y, z;
};
struct ShadedLight {
  Color color;
  double fire_light;
  double facing;
};

// CPU light shader for the AppKit renderer. All vectors are in world space,
// except view_normal, which is used for the fixed ambient key light.
ShadedLight shade_wood(Color albedo, LightVector position, LightVector normal,
                       LightVector view_normal, double fuel,
                       double fire_intensity);
} // namespace fireplace
