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


/*
particles:
- moveable
- if_on_air
- 
*/

class particle {
    size_t type;
    bool moveable;
    bool on_air;
}

// (0,0) is bottom left
// cells[x][y] -> first coordinate is x, second coordinate is y : 1. width, 2. height 
class Grid {
    size_t width, height;
    std::vector<std::vector<size_t>> cells;

    public:
        Grid() : Grid(80, 100) {}

        Grid(size_t w, size_t h) :
            width(w), height(h),
            cells(w, std::vector<particle>(h, size_t)) {}

        size_t get(size_t x, size_t y) const {
            return cells[x][y];
        }

        void set(size_t x, size_t y, size_t value) {
            cells[x][y] = value;
        }
        
        void update() {
            
        }

}

