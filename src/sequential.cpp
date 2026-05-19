#include "grid.hpp"

void Grid::update_seq() {
	// Reset everything to not updated
	updated.assign(width * height, false);
	bool ttob = coin();	// whether or not we go top to bottom
	for(size_t y = ttob ? 0 : height; ttob ? y < height : y-- > 0; y += ttob) {
		bool ltor = coin();	// whether or not we go left to right on this row
		for(size_t x = ltor ? 0 : width; ltor ? x < width : x-- > 0; x += ltor) {
			update_cell(x, y);
		}
	}
}

void Grid::update_cell(size_t x, size_t y) {
	if (updated[x + width * y]) return;
	Particle cur = part(x,y);
	if (cur.state == State::Static || cur.density == 0) return;

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
