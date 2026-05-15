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

// TODO: Maybe do something with this later
enum class ParticleType {
    Empty,
    Sand,
    Stone,
    Water
};

class Particle {
	Particle() : air(1) {}
    Particle(bool air, bool moveable) : air(air), moveable(moveable) {}
    bool air = 0;
    bool moveable = 0;
    bool on_air = 0; // TODO: Just for computation purposes?
};

class Grid {
	/*
	(0,0) is bottom left
	cells[x][y] -> first coordinate is x, second coordinate is y : 1. width, 2. height 
	*/

private:
    size_t width, height;
    std::vector<Particle> cells;
    int margOffset = 0;

public:
    Grid() : Grid(80, 100) {}
    Grid(size_t w, size_t h) : width(w), height(h), cells(w*h) {}

    Particle get(size_t x, size_t y) const { return cells[x + width * y]; }
    void set(size_t x, size_t y, const Particle& value) { cells[x + width * y] = value; }

    void update_seq();
    void update_marg2();
    void update_marg3(); // TODO: hehehehe
};

#endif // SEQUENTIAL_HPP
