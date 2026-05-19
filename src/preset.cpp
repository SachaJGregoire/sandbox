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
        case 2: // Sand, water and vapor
            for (int x = 200; x < 400; x++)
                for (int y = 10; y < 60; y++)
                    set(x, y, Mat::Sand);
            for (int x = 200; x < 400; x++)
                for (int y = 120; y < 170; y++)
                    set(x, y, Mat::Water);
            for (int x = 200; x < 400; x++)
                for (int y = 200; y < 250; y++)
                    set(x, y, Mat::Vapor);
            break;
        case 3: // only water
            for (int x = 250; x < 350; x++)
                for (int y = 50; y < 300; y++)
                    set(x, y, Mat::Water);
            break;
        default:
            break;
    }
}
