#include "grid.hpp"

void Grid::update_marg() {
	// TODO: DOES NOT DO BORDERS YET
	// I give up on this
	for (size_t x = margolus_offset_X; x < width - 1; x += 2) {
		for (size_t y = margolus_offset_Y; y < height - 1; y += 2) {
			Mat pTL = get(x, y);
			Mat pTR = get(x + 1, y);
			Mat pBL = get(x, y + 1);
			Mat pBR = get(x + 1, y + 1);
			bool col_left  = prop(pTL).state != State::Static && prop(pBL).state != State::Static && prop(pBL).density < prop(pTL).density;
			bool col_right = prop(pTR).state != State::Static && prop(pBR).state != State::Static && prop(pBR).density < prop(pTR).density;
			if (col_left || col_right) {
				if (col_left) swap(x, y, x, y + 1);
				if (col_right) swap(x + 1, y, x + 1, y + 1);
				continue;
			}
			bool diag_left = prop(pTL).state != State::Static && prop(pTR).density < prop(pTL).density && prop(pBR).density < prop(pTL).density;
			if (diag_left) {
				swap(x, y, x + 1, y + 1);
				continue;
			}
			bool diag_right = prop(pTR).state != State::Static && prop(pTL).density < prop(pTR).density && prop(pBL).density < prop(pTR).density;
			if (diag_right) {
				swap(x + 1, y, x, y + 1);
				continue;
			}
			bool row_top = (prop(pTL).state == State::Liquid || prop(pTL).state == State::Gas) && (prop(pTR).state == State::Liquid || prop(pTR).state == State::Gas);
			bool row_bot = (prop(pBL).state == State::Liquid || prop(pBL).state == State::Gas) && (prop(pBR).state == State::Liquid || prop(pBR).state == State::Gas);
			if (row_top) swap(x, y, x + 1, y);
			if (row_bot) swap(x, y + 1, x + 1, y + 1);
		}
	}
	margolus_offset_X = (margolus_offset_X + 1) % 2;
	margolus_offset_Y = (1 + margolus_offset_Y) % 2;
	// margolus_offset_Y = (margolus_offset_X + margolus_offset_Y) % 2;
}


/*
void Grid::update_marg2() {
	// Not working, do not use this :(
	for (size_t x = margolus_offset_X; x < width - 1; x += 2) {
		for (size_t y = margolus_offset_Y; y < height - 1; y += 2) {
			Particle pTL = get(x, y);
			Particle pTR = get(x + 1, y);
			if (!pTL.moveable && !pTR.moveable) continue;
			Particle pBL = get(x, y + 1);
			Particle pBR = get(x + 1, y + 1);
			if (pTL.moveable && pTR.moveable) {
				if (pBL.air || pBL.type == ParticleType::Water) swap(x, y, x, y + 1);
				if (pBR.air || pBR.type == ParticleType::Water) swap(x + 1, y, x + 1, y + 1);
			} else if (pTL.moveable) {
				if (pBL.air || pBL.type == ParticleType::Water) swap(x, y, x, y + 1);
				else if (pTR.air || pTR.type == ParticleType::Water) {
					if (pTL.type == ParticleType::Water) swap(x, y, x + 1, y);
					else if ((pBR.air || pBR.type == ParticleType::Water) && topple(pTL.topple_prob)) swap(x, y, x + 1, y + 1);
				}
			} else if (pTR.moveable) {
				if (pBR.air || pBR.type == ParticleType::Water) swap(x + 1, y, x + 1, y + 1);
				else if (pTL.air || pTL.type == ParticleType::Water) {
					if (pTR.type == ParticleType::Water) swap(x + 1, y, x, y);
					else if ((pBL.air || pBL.type == ParticleType::Water) && topple(pTR.topple_prob)) swap(x + 1, y, x, y + 1);
				}
			}
		}
	}
	margolus_offset_X = (margolus_offset_X + 1) % 2;
	margolus_offset_Y = (margolus_offset_X + margolus_offset_Y) % 2;
}

void Grid::update_marg2() {
	// TODO: DOES NOT DO BORDERS YET
	// LOGIC IS COMPLETELY WRONG
	for (size_t x = margolus_offset_X; x < width - 1; x += 2) {
		for (size_t y = margolus_offset_Y; y < height - 1; y += 2) {
			Mat pTL = get(x, y);
			Mat pTR = get(x + 1, y);
			if (prop(pTL).state == State::Static && prop(pTR).state == State::Static) continue;
			Mat pBL = get(x, y + 1);
			Mat pBR = get(x + 1, y + 1);
			if (!(prop(pTL).state == State::Static) && !(prop(pTR).state == State::Static)) {
				if (prop(pBL).density < prop(pTL).density) swap(x, y, x, y + 1);
				if (prop(pBR).density < prop(pTR).density) swap(x + 1, y, x + 1, y + 1);
			} else if (prop(pTR).state == State::Static) {
				if (prop(pBL).density < prop(pTL).density) swap(x, y, x, y + 1);
				else if ((prop(pTL).state == State::Gas || prop(pTL).state == State::Liquid) && (prop(pBR).state == State::Gas || prop(pBR).state == State::Liquid) && topple(prop(pTL).topple_prob))
					swap(x, y, x + 1, y + 1);
			} else if (!(prop(pTR).state == State::Static)) {
				if (prop(pBR).density < prop(pTR).density) swap(x + 1, y, x + 1, y + 1);
				else if ((prop(pTL).state == State::Gas || prop(pTL).state == State::Liquid) && (prop(pBR).state == State::Gas || prop(pBR).state == State::Liquid) && topple(prop(pTL).topple_prob))
					swap(x + 1, y, x, y + 1);
			}
		}
	}
	margolus_offset_X = (margolus_offset_X + 1) % 2;
	margolus_offset_Y = (margolus_offset_X + margolus_offset_Y) % 2;
}
*/
