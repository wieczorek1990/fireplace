#include "light_shader.h"
#include <algorithm>
#include <cmath>

namespace fireplace {
ShadedLight shade_wood(Color albedo, LightVector p, LightVector n,
                       LightVector view, double fuel, double intensity) {
  const LightVector toFire{-p.x, -0.55 - p.y, -p.z};
  const double distance = std::max(0.001, std::sqrt(toFire.x * toFire.x +
      toFire.y * toFire.y + toFire.z * toFire.z));
  const double facing = std::max(0.0, (n.x * toFire.x + n.y * toFire.y +
                                      n.z * toFire.z) / distance);
  const double fire = std::clamp(intensity, 0.0, 1.0) * (0.15 + 0.85 * facing) /
                      (1.0 + distance * distance);
  const double key = 0.55 + 0.45 * std::max(0.0, -view.x * 0.4 +
                                        view.y * 0.8 + view.z * 0.4472135955);
  const double charFactor = 0.25 + 0.75 * std::clamp(fuel, 0.0, 1.0);
  return {{std::clamp(albedo.red * key * charFactor + fire * 0.35, 0.0, 1.0),
           std::clamp(albedo.green * key * charFactor + fire * 0.12, 0.0, 1.0),
           std::clamp(albedo.blue * key * charFactor + fire * 0.025, 0.0, 1.0)},
          fire, facing};
}
} // namespace fireplace
