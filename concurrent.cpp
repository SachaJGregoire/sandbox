#include "grid.hpp"

void Grid::update_marg2() {
	// TODO: DOES NOT DO BORDERS YET
	for (size_t x = margolus_offset; x < width - 1; x += 2) {
		for (size_t y = margolus_offset; y < height - 1; y += 2) {
			Particle pTL = get(x, y);
			Particle pTR = get(x + 1, y);
			if (!pTL.moveable && !pTR.moveable) continue;
			Particle pBL = get(x, y + 1);
			Particle pBR = get(x + 1, y + 1);
			if (pTL.moveable && pTR.moveable) {
				if (pBL.air) swap(x, y, x, y + 1);
				if (pBR.air) swap(x + 1, y, x + 1, y + 1);
			} else if (pTL.moveable) {
				if (pBL.air) swap(x, y, x, y + 1);
				else if (pTR.air && pBR.air && topple(pTL.topple_prob)) swap(x, y, x + 1, y + 1);
			} else if (pTR.moveable) {
				if (pBR.air) swap(x + 1, y, x + 1, y + 1);
				else if (pTL.air && pBL.air && topple(pTR.topple_prob)) swap(x + 1, y, x, y + 1);
			}
		}
	}
	margolus_offset = (margolus_offset + 1) % 2;
}
