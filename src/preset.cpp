#include "grid.hpp"

void Grid::preset(size_t preset) {
    switch (preset) {
        case 1: // Sand and water piles
            for (int x = 60; x < 150; x++)
                for (int y = 150; y < 200; y++)
                    set(x, y, Mat::Sand);
            for (int x = 260; x < 390; x++)
                for (int y = 100; y < 150; y++)
                    set(x, y, Mat::Water);
            for (int x = 280; x < 320; x++)
                for (int y = 10; y < 50; y++)
                    set(x, y, Mat::Sand);
            break;
        default:
            break;
    }
}
