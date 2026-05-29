#include <thread>
#include "grid.hpp"

void Grid::update_seq() {
	// Reset everything to not updated (right now happens in sandbox.cpp)
	// updated.assign(width * height, false);
	bool ttob = coin();	// whether or not we go top to bottom
	for(size_t y = ttob ? 0 : height; ttob ? y < height : y-- > 0; y += ttob) {
		bool ltor = coin();	// whether or not we go left to right on this row
		for(size_t x = ltor ? 0 : width; ltor ? x < width : x-- > 0; x += ltor) {
			update_cell(x, y);
		}
	}
}

void Grid::update_seq_thread(size_t x_start, size_t y_start, size_t x_end, size_t y_end) {
	bool ttob = coin();	// whether or not we go top to bottom
	for(size_t y = ttob ? y_start : y_end; ttob ? y < y_end : y-- > y_start; y += ttob) {
		bool ltor = coin();	// whether or not we go left to right on this row
		for(size_t x = ltor ? x_start : x_end; ltor ? x < x_end : x-- > x_start; x += ltor) {
			update_cell(x, y);
		}
	}
}

void Grid::update_seq_threaded() {
	// This took forever. And it still causes stripes. But I do not know how to fix it.
	// Making the stripes vertical would at least make them less visible, but not solve the actual problem.
    size_t n = 16;
    size_t num_stripes = 2 * n;
    size_t stripe_h = height / (num_stripes - 1);
    size_t offset = rand() % stripe_h;
    for (int phase = 0; phase < 2; phase++) {
        std::vector<std::thread> threads(n - 1);
        for (size_t i = 0; i < n - 1; i++) {
            size_t y0 = (2 * i + phase) * stripe_h + offset;
            size_t y1 = std::min(y0 + stripe_h, height);
            threads[i] = std::thread(&Grid::update_seq_thread, this, 0, y0, width, y1);
        }
		if (phase == 0) update_seq_thread(0, 0, width, offset);
        for (auto &t : threads) t.join();
    }
}

void Grid::update_cell(size_t x, size_t y) {
	if (x >= width || y >= height) return;
	if (updated[x + width * y]) return;
	Particle cur = part(x,y);
	if (cur.m == Mat::Air || cur.state == State::Static) return;

	// Vertical
	int dir_ver = (cur.state == State::Gas) ? -1 : 1;
	bool vert = check_valid(x, y, x, y + dir_ver);
	if(vert) { swap(x, y, x, y + dir_ver); return; }

	// Diagonal
	bool left = check_valid(x, y, x - 1, y);
	bool right = check_valid(x, y, x + 1, y);
	bool diag_left = left && check_valid(x, y, x - 1, y + dir_ver);
	bool diag_right = right && check_valid(x, y, x + 1, y + dir_ver);
	if(diag_left && diag_right) {
		if (coin()) swap(x, y, x - 1, y + dir_ver);
		else 		swap(x, y, x + 1, y + dir_ver);
	}
	else if(diag_left) 	swap(x, y, x - 1, y + dir_ver);
	else if(diag_right) swap(x, y, x + 1, y + dir_ver);

	// Sideways (IF YOU ADD A STATE OF MATTER, THIS CODE IS COOKED)
	// TODO: Should not swap? But instead shift the row. Or something
	if(diag_left || diag_right || cur.state == State::Solid || (!left && !right)) return;
	if (left && right) {
		if (coin()) left = false;
		else 		right = false;
	}
	if (left) {
		size_t i = check_valid_iter(x, y, x - 1, y, cur.dispertion_rate, true);
		swap(x, y, x - i, y);
	}
	if (right) {
		size_t i = check_valid_iter(x, y, x + 1, y, cur.dispertion_rate, true);
		swap(x, y, x + i, y);
	}
}
