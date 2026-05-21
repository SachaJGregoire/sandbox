#ifndef MATERIALS_HPP
#define MATERIALS_HPP
#include <cstdint>
#include <godot_cpp/variant/color.hpp>

enum class Mat : uint8_t {
    Air,
    Sand,
    Water,
    Stone,
    Vapor,
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
	uint8_t density = 0;
    // TODO: change order or make constructors or something smart
    double topple_prob = 0;
    uint8_t dispertion_rate = 0;
};
extern Particle properties[256];
godot::Color get_color(Mat m);

#endif // MATERIALS_HPP
