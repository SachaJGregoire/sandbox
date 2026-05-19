#include "grid.hpp"

void Grid::preset(size_t preset) {
    switch (preset) {
        case 0: // Giant hourglass
        {
            const int cx = 500;
            const int cy = 500;
            const int halfWidth = 200;
            const int neckWidth = 5;
            const int height = 350;
            // Walls
            for (int y = cy - height; y <= cy + height; y++) {
                // 0 at center, 1 at top/bottom
                float t = float(abs(y - cy)) / height;
                int width = int(neckWidth + t * (halfWidth - neckWidth));
                set(cx - width, y, Mat::Stone);
                set(cx + width, y, Mat::Stone);
            }
            // Caps
            for (int x = cx - halfWidth; x <= cx + halfWidth; x++) {
                set(x, cy - height, Mat::Stone);
                set(x, cy + height, Mat::Stone);
            }
            // Fill top chamber with sand
            for (int y = cy - height + 1; y < cy; y++) {
                float t = float(abs(y - cy)) / height;
                int width = int(neckWidth + t * (halfWidth - neckWidth));
                for (int x = cx - width + 1; x < cx + width; x++) set(x, y, Mat::Sand);
            }
            // Tiny opening at center
            set(cx, cy, Mat::Air);
            break;
        }
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
