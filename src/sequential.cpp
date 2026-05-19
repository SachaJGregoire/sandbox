#include "grid.hpp"

void Grid::update_seq() {
	// Implement here oompa loompa
	updated.assign(width * height, false);
	for(size_t y = height; y-- > 0;) {
		bool ltor = (rand() % 2 == 0);	// whether or not we go left to right on this row
		/* Extremely unreadable code. Bad practice. But, it works. */
		for(size_t x = ltor ? 0 : width; ltor ? x < width : x-- > 0; x += ltor) {
			if (updated[x + width * y]) continue;
			Mat cur = get(x,y);
			if(prop(cur).state == State::Static || cur == Mat::Air) continue;

			int dir_ver = (prop(cur).state == State::Gas) ? -1 : 1;
			bool vert = check_valid(x, y, x, y + dir_ver);

			if(vert) {
				swap(x, y, x, y + dir_ver); // vertical direction
				continue;
			}

			bool left = check_valid(x, y, x - 1, y);
			bool right = check_valid(x, y, x + 1, y);
			bool diag_left = left && check_valid(x, y, x - 1, y + dir_ver);
			bool diag_right = right && check_valid(x, y, x + 1, y + dir_ver);

			if(diag_left) {
				if (diag_right && rand() % 2 == 0) swap(x, y, x + 1, y + dir_ver);
				else swap(x, y, x - 1, y + dir_ver); // left diag only
			} else if(diag_right) swap(x, y, x + 1, y + dir_ver); // right diag only
			// liquid logic
			else if(prop(cur).state == State::Liquid || prop(cur).state == State::Gas) {
				if(left) {
					if(right && rand() % 2 == 0) swap(x, y, x + 1, y); // left and right free
					else swap(x, y, x - 1, y); // right free
				} else if(right) swap(x, y, x + 1, y); // left free
			}
		}
	}
}


			/*
			if(prop(cur).state == State::Solid) {
				if(check_valid(x, y + 1) || check_valid(x, y + 1, true)) swap(x, y, x, y + 1);
				else {
					bool left = check_valid(x - 1, y + 1, true), right = check_valid(x + 1, y + 1, true);
					if(left && right) {
						if(rand() % 2 == 0) swap(x, y, x - 1, y + 1); // left
						else swap(x, y, x + 1, y + 1); // right
					} 
					else if(left) swap(x, y, x - 1, y + 1); // left
					else if(right) swap(x, y, x + 1, y + 1); // right
				}
			}
			else if(prop(cur).state == State::Liquid) {
				if(check_valid(x, y + 1)) swap(x, y, x, y + 1);
				else {
					bool left = check_valid(x - 1, y), right = check_valid(x + 1, y);
					if(left && right) {
						if(rand() % 2 == 0) swap(x, y, x - 1, y); // left
						else swap(x, y, x + 1, y); // rightg
					} 
					else if(left) swap(x, y, x - 1, y); // left
					else if(right) swap(x, y, x + 1, y); // right
				}
			}
			*/
