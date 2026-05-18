#ifndef GRID_HPP
#define GRID_HPP

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
#include "materials.hpp"

class Grid {
	/*
	(0,0) is top left
	cells[x][y] -> first coordinate is x, second coordinate is y : 1. width, 2. height 
	*/

private:
    size_t width, height;
    std::vector<Mat> cells;
    bool margolus_offset_X = 0;
    bool margolus_offset_Y = 0;
    double topple_counter = 0;    // Simulate topple probability

public:
    Grid() {}
    Grid(size_t w, size_t h) : width(w), height(h), cells(w*h) {}
    void preset(size_t preset);

    Mat get(size_t x, size_t y) const { return cells[x + width * y]; }
    void set(size_t x, size_t y, const Mat& value) { cells[x + width * y] = value; }
    void swap(size_t x1, size_t y1, size_t x2, size_t y2) { std::swap(cells[x1 + width * y1], cells[x2 + width * y2]); }

    // Simulate topple probability
    bool topple(double topple_prob) {
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
        Mat check = get(x,y);
        
        if(check_if_water) return prop(check).state == State::Liquid || prop(check).state == State::Gas;

        return prop(check).state == State::Gas;
    }

    void update_seq();
    void update_marg2();
    void update() { update_seq(); };
};

#endif // GRID_HPP
