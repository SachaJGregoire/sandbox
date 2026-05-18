#include "grid.hpp"

Particle properties[256] = {
//   material, 		state, 			density, topple_prob	
	{Mat::Air, 		State::Gas, 	0},
	{Mat::Sand, 	State::Solid, 	100, 	0.5	},
	{Mat::Water, 	State::Liquid, 	50},
	{Mat::Stone, 	State::Static, 	100},
};

godot::Color get_color(Mat m) {
    switch (m) {
        case Mat::Air:      return godot::Color(0.1, 0.1, 0.1, 1.0);
        case Mat::Sand:     return godot::Color(0.86, 0.73, 0.36, 1.0);
        case Mat::Water:    return godot::Color(0.0, 0.4, 0.9, 1.0);
        case Mat::Stone:    return godot::Color(0.5, 0.5, 0.5, 1.0); // Did not test
        default:            return godot::Color(0.1, 0.1, 0.1, 1.0);
    }
}

Particle& prop(Mat m) {
    return properties[static_cast<uint8_t>(m)];
}
