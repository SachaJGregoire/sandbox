#ifndef SEQUENTIAL_HPP
#define SEQUENTIAL_HPP

#include <future>
#include <iostream>
#include <iomanip>
#include <sstream>
#include <cstdarg>
#include <iterator>
#include <string>
#include <regex>
#include <numeric>
#include <cmath>
#include <set>
#include <string>
#include <limits>
#include <vector>
#include <random>

// TODO: Maybe do something with this later
enum class ParticleType {
    Empty,
    Sand,
    Stone,
    Water
};

class Particle {
public:
    Particle(bool air = 1, bool moveable = 0, double topple_prob = 0.0, ParticleType type = ParticleType::Empty) :
        air(air), moveable(moveable), topple_prob(topple_prob), type(type) {}
    bool air = 0;
    bool moveable = 0;
    double topple_prob = 0;
    ParticleType type = ParticleType::Empty; // idk if this works like this
    bool on_air = 0; // TODO: Just for computation purposes?

    static Particle Sand() { return Particle(false, true, 0.5, ParticleType::Sand); }
    static Particle Water() { return Particle(false, true, 1.0, ParticleType::Water); }
};

class Grid {
	/*
	(0,0) is top left
	cells[x][y] -> first coordinate is x, second coordinate is y : 1. width, 2. height 
	*/

private:
    size_t width, height;
    std::vector<Particle> cells;
    bool margolus_offset_X = 0;
    bool margolus_offset_Y = 0;
    double topple_counter = 0;    // Simulate topple probability

public:
    Grid() {}
    Grid(size_t w, size_t h) : width(w), height(h), cells(w*h) {}

    Particle get(size_t x, size_t y) const { return cells[x + width * y]; }
    void set(size_t x, size_t y, const Particle& value) { cells[x + width * y] = value; }
    void swap(size_t x1, size_t y1, size_t x2, size_t y2) { std::swap(cells[x1 + width * y1], cells[x2 + width * y2]); }

    bool topple(double topple_prob) {
        // Simulate topple probability
        topple_counter += topple_prob;
        if (topple_counter >= 1) {
            topple_counter -= 1;
            return true;
        }
        return false;
    }

    // check if the square is a valid square and then if it is an air particle
    bool check_valid(size_t x, size_t y, bool check_if_water = false) {
        if(!(x >= 0 && x < width) || !(y >= 0 && y < height)) return false;
        Particle check = get(x,y);
        
        if(check_if_water) return check.type == ParticleType::Water || check.air;

        return check.air;
    }

    void update_seq();
    void update_marg2();
    void update_marg3(); // TODO: hehehehe
    void update() { update_marg2(); };
};

#endif // SEQUENTIAL_HPP
