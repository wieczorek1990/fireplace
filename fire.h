#pragma once

#include "scene.h"

namespace fireplace {

struct Flame {
    Point base;
    double width, height, lean, opacity;
    bool behind;
};

struct BedFlame : Flame {};
struct RisingWisp : Flame {};
std::array<BedFlame, 48> flame_bed(double time);
std::array<RisingWisp, 172> rising_wisps(double time);

struct Ember {
    Point position;
    double opacity, radius;
    bool behind;
};
std::array<Ember, 45> fire_embers(double time);

struct SmokePuff {
    Point position;
    double radius, opacity;
};
std::array<SmokePuff, 28> fire_smoke(double time);

}
