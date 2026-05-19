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
    // TODO: atomic/lock or just ignore kekw
    std::vector<bool> updated;
    bool margolus_offset_X = 0;
    bool margolus_offset_Y = 0;
    double topple_counter = 0;

public:
    Grid() {}
    Grid(size_t w, size_t h) : width(w), height(h), cells(w*h), updated(w*h) {}
    void preset(size_t preset);

    // Getters, setters, swappers
    Mat get(size_t x, size_t y) const { return cells[x + width * y]; }
    void set(size_t x, size_t y, const Mat& value) { cells[x + width * y] = value; }
    void swap(size_t x1, size_t y1, size_t x2, size_t y2) {
        std::swap(cells[x1 + width * y1], cells[x2 + width * y2]);
        // When swapping two cells, mark them as updated
        updated[x1 + width * y1] = true; // OPTION: Mat next = get(x2, y2); true -> prop(next).density > 0 option
        updated[x2 + width * y2] = true;
    }
    Particle& part(size_t x, size_t y) { return prop(get(x, y)); }

    // Simulate probabilities
    bool coin() { return rand() % 2; }
    bool topple(double topple_prob) {
        topple_counter += topple_prob;
        if (topple_counter >= 1) {
            topple_counter -= 1;
            return true;
        }
        return false;
    }

    // check if the square is a valid square
    bool check_valid(size_t x_cur, size_t y_cur, size_t x_next, size_t y_next, bool dispersion = false) {
        if (x_next >= width || y_next >= height || updated[x_next + width * y_next]) return false;
        if (dispersion) return part(x_next, y_next).density == 0;
        return part(x_cur, y_cur).density > part(x_next, y_next).density;
    }
    size_t check_valid_iter(size_t x_cur, size_t y_cur, size_t x_next, size_t y_next, size_t nbiter, bool dispersion = false) {
        int x_disp = (int) x_next - (int) x_cur;
        int y_disp = (int) y_next - (int) y_cur;
        for(size_t i = 0; i < nbiter; i++) {
            if (!check_valid(x_cur, y_cur, x_next, y_next, dispersion)) return i;
            x_next += x_disp;
            y_next += y_disp;
        }
        return nbiter;
    }

    void update_cell(size_t x, size_t y);
    void update_seq();
    void update_marg();
    void update() { update_seq(); };
};

#endif // GRID_HPP
