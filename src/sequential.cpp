#include "grid.hpp"

void Grid::update_seq() {
	// Implement here oompa loompa
	for(size_t x = 0; x < width; x++) {
		for(size_t y = height; y-- > 0;) {
			Mat cur = get(x,y);
			if(prop(cur).state == State::Static) continue;

			int dir_ver = (prop(cur).state == State::Gas) ? -1 : 1;

			if(check_valid(x, y, x, y + dir_ver))
				swap(x, y, x, y + dir_ver); // vertical direction
			else if(check_valid(x, y, x - 1, y + dir_ver) && check_valid(x, y, x - 1, y)) {
				if(check_valid(x, y, x + 1, y + dir_ver) && check_valid(x, y, x + 1, y)) {
					if(rand() % 2 == 0) swap(x, y, x - 1, y + dir_ver);
					else swap(x, y, x + 1, y + dir_ver);
				} // left diag and right diag free
				else swap(x, y, x - 1, y + dir_ver); // left diag only
			}
			else if(check_valid(x, y, x + 1, y + dir_ver) && check_valid(x, y, x + 1, y))
				swap(x, y, x + 1, y + dir_ver); // right diag only
			// liquid logic
			else if(prop(cur).state == State::Liquid || prop(cur).state == State::Gas) {
				if(check_valid(x, y, x + 1, y)) {
					if(check_valid(x, y, x - 1, y)) {
						if(rand() % 2 == 0) swap(x, y, x - 1, y);
						else swap(x, y, x + 1, y);
					} // left and right free
					else swap(x, y, x + 1, y); // right free
				}
				else if(check_valid(x, y, x - 1, y))
					swap(x, y, x - 1, y); // left free
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
		}
	}
}
