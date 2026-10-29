#pragma once

namespace fireplace {
// Relative quantities for a small, ventilated fire; not physical concentrations.
struct Combustion {
  double fuel = 1.0;
  double oxygen = 1.0;
  double carbon_dioxide = 0.0;
  double carbon_monoxide = 0.0;
  double soot = 0.0;
  double heat = 0.8;
  double coal = 0.0;
  double coal_heat = 0.0;
  double flame = 0.0;
  void advance(double seconds, double ventilation);
};
} // namespace fireplace
