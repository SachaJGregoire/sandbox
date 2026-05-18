#ifndef MATERIALS_HPP
#define MATERIALS_HPP
#include <cstdint>
#include <godot_cpp/variant/color.hpp>

enum class Mat : uint8_t {
    Air,
    Sand,
    Water,
    Stone,
};



enum class State {
    Static,
    Solid,
    Liquid,
    Gas
};
struct Particle {
	Mat m;
    State state = State::Static;
	uint16_t density = 0;
    double topple_prob = 0;
};
extern Particle properties[256];
Particle& prop(Mat m);
godot::Color get_color(Mat m);

#endif // MATERIALS_HPP
