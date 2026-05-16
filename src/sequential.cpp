#include "grid.hpp"

void Grid::update_seq() {
	// Implement here oompa loompa
	for(size_t x = width - 1; x >= 0; x--) {
		for(size_t y = height - 1; y >= 0; y--) {
			Particle cur = get(x, y);
			if(cur.type == ParticleType::Sand) {
				if(check_valid(x, y + 1) || check_valid(x, y + 1, true)) swap(x, y, x, y + 1);
				else {
					bool left = check_valid(x - 1, y + 1), right = check_valid(x + 1, y + 1);
					if(left && right) {
						if(rand() % 2 == 0) swap(x, y, x - 1, y + 1); // left
						else swap(x, y, x + 1, y + 1); // right
					} 
					else if(left) swap(x, y, x - 1, y + 1); // left
					else if(right) swap(x, y, x + 1, y + 1); // right
				}
			}
			else if(cur.type == ParticleType::Water) {
				if(check_valid(x, y + 1)) swap(x, y, x, y + 1);
				else {
					bool left = check_valid(x - 1, y), right = check_valid(x + 1, y);
					if(left && right) {
						if(rand() % 2 == 0) swap(x, y, x - 1, y); // left
						else swap(x, y, x + 1, y); // right
					} 
					else if(left) swap(x, y, x - 1, y); // left
					else if(right) swap(x, y, x + 1, y); // right
				}
			}
		}
	}
}
