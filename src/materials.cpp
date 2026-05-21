#include "grid.hpp"

Particle properties[256] = {
//   material, 		state, 			density, topple_prob, dispertion_rate	
	{Mat::Air, 		State::Gas, 	0},
	{Mat::Sand, 	State::Solid, 	100, 	0.5	},
	{Mat::Water, 	State::Liquid, 	50,     0,            5},
	{Mat::Stone, 	State::Static, 	255},
    {Mat::Vapor, 	State::Gas, 	5,     0,            5},
};

godot::Color get_color(Mat m) {
    switch (m) {
        case Mat::Air   :   return godot::Color(0.1,    0.1,    0.1,    1.0);
        case Mat::Sand  :   return godot::Color(0.86,   0.73,   0.36,   1.0);
        case Mat::Water :   return godot::Color(0.0,    0.4,    0.9,    1.0);
        case Mat::Stone :   return godot::Color(0.5,    0.5,    0.5,    1.0);
        case Mat::Vapor :   return godot::Color(0.85,   0.90,   0.95,   0.45);
        default         :   return godot::Color(0.1,    0.1,    0.1,    1.0);
    }
}
