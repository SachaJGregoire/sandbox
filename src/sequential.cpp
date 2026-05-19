#include "grid.hpp"

void Grid::update_seq() {
	// Reset everything to not updated
	updated.assign(width * height, false);
	bool ttob = rand() % 2;	// whether or not we go top to bottom
	for(size_t y = ttob ? 0 : height; ttob ? y < height : y-- > 0; y += ttob) {
		bool ltor = rand() % 2;	// whether or not we go left to right on this row
		for(size_t x = ltor ? 0 : width; ltor ? x < width : x-- > 0; x += ltor) {
			update_cell(x, y);
		}
	}
}

void Grid::update_cell(size_t x, size_t y) {
	if (updated[x + width * y]) return;
	Mat cur = get(x,y);
	if(prop(cur).state == State::Static || cur == Mat::Air) return;

	int dir_ver = (prop(cur).state == State::Gas) ? -1 : 1;
	bool vert = check_valid(x, y, x, y + dir_ver);

	if(vert) {
		swap(x, y, x, y + dir_ver); // vertical direction
		return;
	}

	bool left = check_valid(x, y, x - 1, y);
	bool right = check_valid(x, y, x + 1, y);
	bool diag_left = left && check_valid(x, y, x - 1, y + dir_ver);
	bool diag_right = right && check_valid(x, y, x + 1, y + dir_ver);

	if(diag_left) {
		if (diag_right && rand() % 2) swap(x, y, x + 1, y + dir_ver);
		else swap(x, y, x - 1, y + dir_ver); // left diag only
	} else if(diag_right) swap(x, y, x + 1, y + dir_ver); // right diag only
	// liquid logic
	else if(prop(cur).state == State::Liquid || prop(cur).state == State::Gas) {
		if(left) {
			if(right && rand() % 2) { // right and right free
				size_t i = check_valid_iter(x, y, x + 1, y, prop(cur).dispertion_rate);
				swap(x, y, x + i, y);
			}
			else { // left free
				size_t i = check_valid_iter(x, y, x - 1, y, prop(cur).dispertion_rate);
				swap(x, y, x - i, y);
			} 
		} else if(right) { // right free
			size_t i = check_valid_iter(x, y, x + 1, y, prop(cur).dispertion_rate);
			swap(x, y, x + i, y);
		} 
	}
}
