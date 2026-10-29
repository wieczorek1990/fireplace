#include "combustion.h"
#include <algorithm>
#include <cmath>

namespace fireplace {
void Combustion::advance(double seconds, double ventilation) {
  // Small steps keep the exchange stable even after a delayed frame.
  while (seconds > 0) {
    const double dt = std::min(seconds, 0.05);
    seconds -= dt;
    const double air = std::clamp(ventilation, 0.0, 2.0);
    const double burning = std::min(fuel / dt, 0.018 * std::sqrt(fuel) *
                                                   oxygen * (0.3 + 0.7 * heat));
    fuel = std::max(0.0, fuel - burning * dt);
    // Some burned wood becomes charcoal, which burns more slowly than wood.
    const double coalBurning = std::min(coal / dt, coal * oxygen * 0.006);
    coal = std::max(0.0, coal + (burning * 0.32 - coalBurning) * dt);
    oxygen = std::clamp(oxygen + (air * (1.0 - oxygen) * 0.6 - burning * 15.0 -
                                  coalBurning * 6.0) *
                                     dt,
                        0.0, 1.0);
    const double coalTarget =
        std::clamp(coalBurning * 120.0 + burning * 20.0, 0.0, 1.0);
    coal_heat += (coalTarget - coal_heat) * 0.12 * dt;
    const double incomplete = 1.0 - oxygen;
    carbon_dioxide += (coalBurning + burning * (1.0 - 0.65 * incomplete) -
                       air * 0.3 * carbon_dioxide) *
                      dt;
    carbon_monoxide +=
        (burning * incomplete * 0.65 - air * 0.3 * carbon_monoxide) * dt;
    soot += (burning * incomplete * 0.9 - air * 0.25 * soot) * dt;
    heat = std::clamp(
        heat + (burning * 15.0 + coalBurning * 8.0 - heat * 0.18) * dt, 0.0,
        1.0);
    flame = std::clamp(burning / 0.012, 0.0, 1.0);
  }
}
} // namespace fireplace
