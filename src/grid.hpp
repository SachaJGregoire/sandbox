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
    std::vector<bool> updated;
    bool margolus_offset_X = 0;
    bool margolus_offset_Y = 0;
    double topple_counter = 0;    // Simulate topple probability

public:
    Grid() {}
    Grid(size_t w, size_t h) : width(w), height(h), cells(w*h), updated(w*h) {}
    void preset(size_t preset);

    Mat get(size_t x, size_t y) const { return cells[x + width * y]; }
    void set(size_t x, size_t y, const Mat& value) { cells[x + width * y] = value; }
    void swap(size_t x1, size_t y1, size_t x2, size_t y2) {
        std::swap(cells[x1 + width * y1], cells[x2 + width * y2]);
        // When swapping two cells, mark them as updated
        updated[x1 + width * y1] = true;
        updated[x2 + width * y2] = true;
    }

    // Simulate topple probability
    bool topple(double topple_prob) {
        topple_counter += topple_prob;
        if (topple_counter >= 1) {
            topple_counter -= 1;
            return true;
        }
        return false;
    }

    // check if the square is a valid square
    bool check_valid(size_t x_cur, size_t y_cur, size_t x_next, size_t y_next) {
        if((x_next >= 0 && x_next < width) && (y_next >= 0 && y_next < height) && !updated[x_next + width * y_next]) {
            Mat cur = get(x_cur, y_cur);
            Mat next = get(x_next, y_next);
            return prop(cur).density > prop(next).density;
        }
        return false;
    }
    size_t check_valid_iter(size_t x_cur, size_t y_cur, size_t x_next, size_t y_next, size_t nbiter) {
        int x_disp = (int) x_next - (int) x_cur, y_disp = (int) x_next - (int) x_cur;
        size_t iter_res = 0;
        for(size_t i = 1; i <= nbiter; i++) {
            if((x_next >= 0 && x_next < width) && (y_next >= 0 && y_next < height) && !updated[x_next + width * y_next]) {
                Mat cur = get(x_cur, y_cur);
                Mat next = get(x_next, y_next);
                if(prop(cur).density > prop(next).density)
                    iter_res = i;
                else
                    break;
            }
            x_next += x_disp;
            y_next += y_disp;
        }
        return iter_res;
    }

    void update_cell(size_t x, size_t y);
    void update_seq();
    void update_marg();
    void update() { update_seq(); };
};

#endif // GRID_HPP
