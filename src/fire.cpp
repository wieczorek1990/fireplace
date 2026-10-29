#include "fire.h"

#include <cmath>

namespace fireplace {
namespace {
// Stable pseudo-random values keep animation reproducible without frame state.
double noise(double seed) {
  const double value = std::sin(seed * 127.1 + 311.7) * 43758.5453;
  return value - std::floor(value);
}
// Slowly changing gusts affect every part of the plume together.
double wind(double time) {
  return 0.32 + 0.35 * std::sin(time * 0.34) +
         0.18 * std::sin(time * 0.91 + 0.7);
}

// Integrate the wind over a particle's lifetime so it follows the gusts
// it has actually experienced rather than jumping when the wind changes.
double wind_distance(double time, double duration) {
  const double start = time - duration;
  return 0.32 * duration +
         0.35 / 0.34 * (std::cos(start * 0.34) - std::cos(time * 0.34)) +
         0.18 / 0.91 *
             (std::cos(start * 0.91 + 0.7) - std::cos(time * 0.91 + 0.7));
}
} // namespace

std::array<BedFlame, 48> flame_bed(double time) {
  std::array<BedFlame, 48> flames{};
  for (std::size_t i = 0; i < flames.size(); ++i) {
    const double seed = static_cast<double>(i);
    const double angle = seed * 6.28318530718 / 48;
    const double pulse = 0.5 + 0.25 * std::sin(time * 7.3 + seed * 2.4) +
                         0.25 * std::sin(time * 11.1 + seed * 1.7);
    static_cast<Flame &>(flames[i]) = {
        {0.96 * std::cos(angle), -0.83 + 0.30 * std::sin(angle)},
        {0.96 * std::cos(angle), -0.83 + 0.30 * std::sin(angle)},
        0.075 + pulse * 0.045,
        0.25 + pulse * 0.55,
        0.08 * std::sin(time * 4.3 + seed) + wind(time) * (0.25 + pulse * 0.35),
        0.68,
        std::sin(angle) > 0};
  }
  return flames;
}

std::array<RisingWisp, 172> rising_wisps(double time) {
  std::array<RisingWisp, 172> flames{};
  for (std::size_t i = 0; i < flames.size(); ++i) {
    const double seed = static_cast<double>(i + 48);
    const double speed = 0.55 + noise(seed + 3) * 0.65;
    const double clock = time * speed + noise(seed + 9);
    const double age = clock - std::floor(clock);
    const double cycle = std::floor(clock);
    const double angle = noise(seed + 17) * 6.28318530718;
    const double variation = noise(seed + cycle * 13.7);
    const double sway = std::sin(time * 3.2 + seed) * age * 0.10 +
                        std::sin(time * 6.1 + seed * 2) * age * 0.045;
    static_cast<Flame &>(flames[i]) = {
        {0.96 * std::cos(angle) + sway + wind_distance(time, age / speed) * 0.8,
         -0.83 + 0.30 * std::sin(angle) + age * (0.85 + variation * 0.65)},
        {0.96 * std::cos(angle), -0.83 + 0.30 * std::sin(angle)},
        (0.055 + noise(seed + 4) * 0.065) * (1 - age * 0.75),
        (0.24 + variation * 0.42) * (1 - age * 0.5),
        0.10 * std::sin(time * 4 + seed) + sway +
            wind(time) * (0.2 + age * 0.25),
        std::sin(age * 3.14159265359) * (1 - age) * 0.65,
        std::sin(angle) > 0};
  }
  return flames;
}
std::array<Ember, 45> fire_embers(double time) {
  std::array<Ember, 45> embers{};
  for (std::size_t i = 0; i < embers.size(); ++i) {
    const double seed = static_cast<double>(i);
    const double speed = 0.18 + noise(seed + 7) * 0.22;
    const double clock = time * speed + noise(seed);
    const double age = clock - std::floor(clock);
    const double angle = noise(seed + 21) * 6.28318530718;
    embers[i] = {{0.9 * std::cos(angle) +
                      age * 0.25 * std::sin(time * 1.5 + seed) +
                      wind_distance(time, age / speed) * 0.65,
                  -0.8 + 0.3 * std::sin(angle) + age * 2.8},
                 {0.9 * std::cos(angle), -0.8 + 0.3 * std::sin(angle)},
                 std::sin(age * 3.14159265359) * (1 - age),
                 0.003 + noise(seed + 2) * 0.005,
                 std::sin(angle) > 0};
  }
  return embers;
}

std::array<SmokePuff, 28> fire_smoke(double time) {
  std::array<SmokePuff, 28> puffs{};
  for (std::size_t i = 0; i < puffs.size(); ++i) {
    const double speed = 0.12 + (i % 5) * 0.014;
    const double clock = time * speed + i * 0.618033989;
    const double age = clock - std::floor(clock);
    puffs[i] = {{0.45 * std::sin(i * 2.4) +
                     age * 0.24 * std::sin(time * 0.6 + i) +
                     wind_distance(time, age / speed) * 0.7,
                 -0.15 + age * 2.7},
                0.08 + age * 0.30,
                0.055 * std::sin(age * 3.14159265359)};
  }
  return puffs;
}

} // namespace fireplace
