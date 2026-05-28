#include <vector>
#include <iostream> 

// Algorithm and pseudocode from https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
std::vector<std::pair<size_t, size_t>> bresenham(size_t x0, size_t y0, size_t x1, size_t y1) {
    std::vector<std::pair<size_t, size_t>> ret;
    int dx = abs((int)(x1 - x0));
    int sx = x0 < x1 ? 1 : -1;
    int dy = -abs((int)(y1 - y0));
    int sy = y0 < y1 ? 1 : -1;
    int error = dx + dy;
    while (true) {
        ret.push_back({x0, y0});
        int e2 = 2 * error;
        if (e2 >= dy) {
            if (x0 == x1) break;
            error += dy;
            x0 += sx;
        }
        if (e2 <= dx) {
            if (y0 == y1) break;
            error += dx;
            y0 += sy;
        }
    }
    return ret;
}

/* Testing code: looks like it more or less works
int main() {
    auto res = bresenham(0, 1, 6, 4);
    for (int i = 0; i < res.size(); i++) std::cout << "(" << res[i].first << ", " << res[i].second << ")" << std::endl;
}
*/
