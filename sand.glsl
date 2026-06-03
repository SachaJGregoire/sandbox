#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform readonly image2D input_grid;
layout(set = 0, binding = 1, rgba32f) uniform writeonly image2D output_grid;

layout(set = 0, binding = 2) buffer ParticleCounter {
	uint sand_count;
	uint stone_count;
	uint water_count;
} counters;

// We use Push Constants to quickly send mouse input from GDScript
layout(push_constant, std430) uniform Params {
	vec2 mouse_pos;    	// 8 bytes (offsets 0-7)
	float brush_size;  	// 4 bytes (offsets 8-11)
	int draw_mode;     	// 4 bytes (offsets 12-15)
	int frame_count;   	// 4 bytes (offsets 16-19)
	int is_frozen;     	// 4 bytes (offsets 20-23)
	int do_reset;      	// 4 bytes (offsets 24-27)
	int pad;    		// 4 bytes (offsets 28-31)
} params;

float hash2t(vec2 p, int frame) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + float(frame)) * 43758.5453);
}

bool coin(vec2 coord, int frame, float threshold) {
	float r = hash2t(coord, frame);
	return r < threshold;
}
bool coin(vec2 coord, int frame) { return coin(coord, frame, 0.5); }

bool shimmer(vec2 coord, int frame) {
	float r = hash2t(coord, frame + 7717);
	return r < 0.005;
}

const int WIDTH  = 512;
const int HEIGHT = 512;

const int Static = 0;
const int Solid = 1;
const int Liquid = 2;
const int Gas = 3;

const int Air = 0;
const int Sand = 1;
const int Water = 2;
const int Stone = 3;
const int Vapor = 4;
const int count_material = 5;

const vec4 Color_Air    = vec4(0.1,    0.1,    0.1,    1.0);
const vec4 Color_Sand   = vec4(0.86,   0.73,   0.36,   1.0);
const vec4 Color_Water  = vec4(0.0,    0.4,    0.9,    1.0);
const vec4 Color_Stone  = vec4(0.5,    0.5,    0.5,    1.0);
const vec4 Color_Vapor  = vec4(0.85,   0.90,   0.95,   0.45);

const vec4 material_colors[count_material] = vec4[count_material](
	Color_Air,
	Color_Sand,
	Color_Water,
	Color_Stone,
	Color_Vapor
);

struct Particle {
	int mat;
	int state;
	int density;
	float topple_prob;
	int dispertion_rate;
};

const Particle properties[count_material] = Particle[count_material](
//           mat,   state,  density, topple, dispersion
	Particle(Air,   Gas,    0,   0.0,  0),
	Particle(Sand,  Solid,  100, 0.5,  0),
	Particle(Water, Liquid, 50,  1.0,  6),
	Particle(Stone, Static, 255, 0.0,  0),
	Particle(Vapor, Gas,    30,  1.0,  5)
);


vec4 encode(int mat) {
	return material_colors[mat];
}

Particle decode(vec4 pixel) {
	for(int i = 0; i < count_material; i++) {
		if(length(pixel - material_colors[i]) < 0.15) {
			return properties[i];
		}
	}
	return properties[0];
}

int get_state(ivec2 p) {
	if (p.x < 0 || p.x >= WIDTH || p.y < 0 || p.y >= HEIGHT) {
		return Static;
	}
	return decode(imageLoad(input_grid, p)).state;
}

int get_mat(ivec2 p) {
	if (p.x < 0 || p.x >= WIDTH || p.y < 0 || p.y >= HEIGHT) {
		return Stone;
	}
	return decode(imageLoad(input_grid, p)).mat;
}

int get_water_move(ivec2 source, int dx, int dy, int dispertion, int frame) {
	if (!coin(source, frame)) return 0;
	
	int move = 0;
	for (int i = 1; i <= dispertion; i++) {
		ivec2 target = source + ivec2(dx * i, dy * i);
		
		if (get_mat(target) != Air) break;
		
		if (dy == 1) {
			if (get_mat(source + ivec2(dx * i, dy * i - 1)) != Air) break; 
		}

		int target_up = get_mat(target + ivec2(0, -1));
		if (target_up == Sand || target_up == Water) break;
		
		move = i;
	}
	return move;
}

void update(ivec2 coord) {
	vec4 current_color  = imageLoad(input_grid, coord);
	if (current_color.a < 0.1) {
		current_color = material_colors[Air];
	}
	
	Particle cell = decode(current_color);

	vec4 next_color = current_color;

	int phase = params.frame_count % 4;
	int move_x = (phase == 0 || phase == 1) ? -1 : 1; 
	int move_y = (phase == 0 || phase == 2) ? 0 : 1;

	// SAND LOGIC
	if (cell.mat == Sand) {
		int mat_below = get_mat(coord + ivec2(0, 1));
		
		// vertical fall
		if (mat_below == Air) {
			next_color = material_colors[Air];
		}
		// sink below water
		else if (mat_below == Water) {
			next_color = imageLoad(input_grid, coord + ivec2(0, 1));
		}
		// diagonal fall
		else if (move_y == 1) { 
			int mat_target = get_mat(coord + ivec2(move_x, 1));
			int mat_side = get_mat(coord + ivec2(move_x, 0));
			
			if (mat_target == Air && mat_side == Air && coin(coord, params.frame_count)) {
				next_color = material_colors[Air];
			}
		}
	} 
	
	// WATER LOGIC
	else if (cell.mat == Water) {
		int mat_above = get_mat(coord + ivec2(0, -1));
		int mat_below = get_mat(coord + ivec2(0, 1));

		// rise above sand
		if (mat_above == Sand) {
			next_color = imageLoad(input_grid, coord + ivec2(0, -1));
		}
		// vertical fall
		else if (mat_below == Air) {
			next_color = material_colors[Air];
		}
		// horizontal or diagonal fall
		else {
			int move = get_water_move(coord, move_x, move_y, properties[Water].dispertion_rate, params.frame_count);
			if (move > 0) {
				next_color = material_colors[Air];
			}
			else {
				if (shimmer(coord, params.frame_count)) {                    
					float variance = (hash2t(coord, params.frame_count) - 0.5);
					next_color = material_colors[Water] + vec4(0.0, 0.15*variance, 0.15*variance, 0.0);
				}
			}
		}
	} 
	
	// AIR LOGIC
	else if (cell.mat == Air) {
		bool receiving = false;
		vec4 incoming_color = material_colors[Air];

		int mat_up = get_mat(coord + ivec2(0, -1));
		// vertical sand fall
		if (mat_up == Sand) {
			receiving = true;
			incoming_color = imageLoad(input_grid, coord + ivec2(0, -1));
		}
		// vertical water fall
		else if (mat_up == Water) {
			if (get_mat(coord + ivec2(0, -2)) != Sand) {
				receiving = true;
				incoming_color = imageLoad(input_grid, coord + ivec2(0, -1));
			}
		}

		if (!receiving) {
			// diagonal sand fall
			ivec2 sand_source = coord - ivec2(move_x, move_y);
			if (move_y == 1 && get_mat(sand_source) == Sand) {
				int mat_below_source = get_mat(sand_source + ivec2(0, 1));
				if (mat_below_source != Air && mat_below_source != Water) {
					int mat_side = get_mat(sand_source + ivec2(move_x, 0));
					if (mat_side == Air && coin(sand_source, params.frame_count)) {
						receiving = true;
						incoming_color = imageLoad(input_grid, sand_source);
					}
				}
			}
			
			// horizontal or diagonal water fall
			if (!receiving) {
				for (int i = 1; i <= properties[Water].dispertion_rate; i++) {
					ivec2 source = coord - ivec2(move_x * i, move_y * i);
					int source_mat = get_mat(source);
					
					if (source_mat == Water) {
						int mat_below_source = get_mat(source + ivec2(0, 1));
						int mat_above_source = get_mat(source + ivec2(0, -1));
						
						if (mat_below_source != Air && mat_above_source != Sand) {
							if (get_water_move(source, move_x, move_y, properties[Water].dispertion_rate, params.frame_count) == i) {
								receiving = true;
								incoming_color = imageLoad(input_grid, source);
							}
						}
						break;
					} 
					else if (source_mat != Air) {
						break;
					}
				}
			}
		}

		if (receiving) {
			next_color = incoming_color;
		}
	}
	imageStore(output_grid, coord, next_color);
}



const int ERROR = -1;
const int NONE	= 0;
const int TLTR	= 1;
const int TLBL	= 2;
const int TLBR 	= 3;
const int TRBL	= 4;
const int TRBR	= 5;
const int BLBR	= 6;
const int TTBB	= 7;

const int marg[81] = int[81](
	ERROR,	/*	0  (-1,-1,
					-1,-1) */
	TLBL,	/*	1  ( 0,-1,
					-1,-1) */
	ERROR,	/*	2  ( 1,-1,
					-1,-1) */
	TRBR,	/*	3  (-1, 0,
					-1,-1) */
	TTBB,	/*	4  ( 0, 0,
					-1,-1) */
	TRBR, 	/*	5  ( 1, 0,
					-1,-1) */
	ERROR,	/*	6  (-1, 1,
					-1,-1) */
	TLBL,	/*	7  ( 0, 1,
					-1,-1) */
	ERROR,	/*	8  ( 1, 1,
					-1,-1) */

	BLBR,	/*	9  (-1,-1,
					 0,-1) */
	TLBR,	/* 10 ( 0,-1,
					0,-1) */
	BLBR,	/* 11 ( 1,-1,
					0,-1) */
	TRBR,	/* 12 (-1, 0,
					0,-1) */
	TRBR,	/* 13 ( 0, 0,
					0,-1) */
	TRBR,	/* 14 ( 1, 0,
					0,-1) */
	BLBR,	/* 15 (-1, 1,
					0,-1) */
	BLBR,	/* 16 ( 0, 1,
					0,-1) */
	BLBR,	/* 17 ( 1, 1,
					0,-1) */

	ERROR,	/* 18 (-1,-1,
					1,-1) */
	TLBR,	/* 19 ( 0,-1,
					1,-1) */
	ERROR,	/* 20 ( 1,-1,
					1,-1) */
	TRBR,	/* 21 (-1, 0,
					1,-1) */
	TRBR,	/* 22 ( 0, 0,
					1,-1) */
	TRBR,	/* 23 ( 1, 0,
					1,-1) */
	ERROR,	/* 24 (-1, 1,
					1,-1) */
	NONE,	/* 25 ( 0, 1,
					1,-1) */
	ERROR,	/* 26 ( 1, 1,
					1,-1) */

	NONE,	/* 27 (-1,-1,
					1, 0) */
	TLTR,	/* 28 ( 0,-1,
					1, 0) */
	NONE,	/* 29 ( 1,-1,
					1, 0) */
	TLTR,	/* 30 (-1, 0,
					1, 0) */
	NONE,	/* 31 ( 0, 0,
					1, 0) */
	NONE,	/* 32 ( 1, 0,
					1, 0) */
	NONE,	/* 33 (-1, 1,
					1, 0) */
	NONE,	/* 34 ( 0, 1,
					1, 0) */
	NONE,	/* 35 ( 1, 1,
					1, 0) */

	NONE,	/* 36 (-1,-1,
					0, 0) */
	TLTR,	/* 37 ( 0,-1,
					0, 0) */
	NONE,	/* 38 ( 1,-1,
					0, 0) */
	TLTR,	/* 39 (-1, 0,
					0, 0) */
	NONE,	/* 40 ( 0, 0,
					0, 0) */
	NONE,	/* 41 ( 1, 0,
					0, 0) */
	NONE,	/* 42 (-1, 1,
					0, 0) */
	NONE,	/* 43 ( 0, 1,
					0, 0) */
	NONE,	/* 44 ( 1, 1,
					0, 0) */

	NONE,	/* 45 (-1,-1,
					1, 0) */
	TLTR,	/* 46 ( 0,-1,
					1, 0) */
	NONE,	/* 47 ( 1,-1,
					1, 0) */
	TLTR,	/* 48 (-1, 0,
					1, 0) */
	NONE,	/* 49 ( 0, 0,
					1, 0) */
	NONE,	/* 50 ( 1, 0,
					1, 0) */
	NONE,	/* 51 (-1, 1,
					1, 0) */
	NONE,	/* 52 ( 0, 1,
					1, 0) */
	NONE,	/* 53 ( 1, 1,
					1, 0) */

	ERROR,	/* 54 (-1,-1,
					1, 1) */
	TLTR,	/* 55 ( 0,-1,
					1, 1) */
	ERROR,	/* 56 ( 1,-1,
					1, 1) */
	TLTR,	/* 57 (-1, 0,
					1, 1) */
	NONE,	/* 58 ( 0, 0,
					1, 1) */
	NONE,	/* 59 ( 1, 0,
					1, 1) */
	ERROR,	/* 60 (-1, 1,
					1, 1) */
	NONE,	/* 61 ( 0, 1,
					1, 1) */
	ERROR,	/* 62 ( 1, 1,
					1, 1) */

	NONE,	/* 63 (-1,-1,
					0, 1) */
	TLTR,	/* 64 ( 0,-1,
					0, 1) */
	NONE,	/* 65 ( 1,-1,
					0, 1) */
	TLTR,	/* 66 (-1, 0,
					0, 1) */
	NONE,	/* 67 ( 0, 0,
					0, 1) */
	NONE,	/* 68 ( 1, 0,
					0, 1) */
	NONE,	/* 69 (-1, 1,
					0, 1) */
	NONE,	/* 70 ( 0, 1,
					0, 1) */
	NONE,	/* 71 ( 1, 1,
					0, 1) */

	ERROR,	/* 72 (-1,-1,
					1, 1) */
	TLTR,	/* 73 ( 0,-1,
					1, 1) */
	ERROR,	/* 74 ( 1,-1,
					1, 1) */
	TLTR,	/* 75 (-1, 0,
					1, 1) */
	NONE,	/* 76 ( 0, 0,
					1, 1) */
	NONE,	/* 77 ( 1, 0,
					1, 1) */
	ERROR,	/* 78 (-1, 1,
					1, 1) */
	NONE,	/* 79 ( 0, 1,
					1, 1) */
	ERROR	/* 80 ( 1, 1,
					1, 1) */
);

int lookup(ivec4 key) {
	return marg[key.x + 3 * key.y + 9 * key.z + 27 * key.w];
}

void swap(inout vec4 a, inout vec4 b) {
    vec4 tmp = a;
    a = b;
    b = tmp;
}
void swap(inout Particle a, inout Particle b) {
    Particle tmp = a;
    a = b;
    b = tmp;
}
void swap(inout int a, inout int b) {
    int tmp = a;
    a = b;
    b = tmp;
}

void update_marg(ivec2 coord) {
	// TODO: Borders
	// Setting up offset
	int offset = params.frame_count % 4;
	int offset_x = (offset == 1 || offset == 2) ? 1 : 0;
	int offset_y = (offset == 1 || offset == 3) ? 1 : 0;
	if (coord.x % 2 != offset_x || coord.y % 2 != offset_y) return;

	// Draws bottom and right boxes that would be out of bounds (NOT TOP OR LEFT BOXES)
	if (coord.x + 1 == WIDTH && coord.y + 1 == HEIGHT) {
		imageStore(output_grid, coord, imageLoad(input_grid, coord));
		return;
	}
	else if (coord.x + 1 == WIDTH) {
		imageStore(output_grid, coord, imageLoad(input_grid, coord));
		imageStore(output_grid, coord + ivec2(0, 1), imageLoad(input_grid, coord + ivec2(0, 1)));
		return;
	}
	else if (coord.y + 1 == HEIGHT) {
		imageStore(output_grid, coord, imageLoad(input_grid, coord));
		imageStore(output_grid, coord + ivec2(1, 0), imageLoad(input_grid, coord + ivec2(1, 0)));
		return;
	}

	// Movement logic
	vec4 TL_color = imageLoad(input_grid, coord			  	 );
	vec4 TR_color = imageLoad(input_grid, coord + ivec2(1, 0));
	vec4 BL_color = imageLoad(input_grid, coord + ivec2(0, 1));
	vec4 BR_color = imageLoad(input_grid, coord + ivec2(1, 1));
	Particle TL = decode(TL_color);
	Particle TR = decode(TR_color);
	Particle BL = decode(BL_color);
	Particle BR = decode(BR_color);
	ivec4 key = ivec4(0, 0, 0, 0);
	bool cont = true;
	while (cont) {
		// Update key
		if (key.x == 1) key.x = 2;
		if (key.y == 1) key.y = 2;
		if (key.z == 1) key.z = 2;
		if (key.w == 1) key.w = 2;

		int m = -1;
		if (key.x == 0 && TL.density > m) m = TL.density;
		if (key.y == 0 && TR.density > m) m = TR.density; 
		if (key.z == 0 && BL.density > m) m = BL.density; 
		if (key.w == 0 && BR.density > m) m = BR.density;
		if (m == -1) break;

		if (TL.density == m) key.x = 1;
		if (TR.density == m) key.y = 1;
		if (BL.density == m) key.z = 1;
		if (BR.density == m) key.w = 1;
		if (m == 255) continue; // Skip static particles
		// Lookup movement pattern
		int op = lookup(key);
		// Apply movement pattern
		switch (op) {
			case ERROR:
				// assert(false), except that does not exist in this language
				break;
			case NONE: break;
			case TLTR:
				if (!true) break;	// TODO: true should be simulating liquid movement probability
				// Swap TL and TR
				swap(TL_color, TR_color);
				swap(TL, TR);
				swap(key.x, key.y);
				break;
			case TLBL:
				// Swap TL and BL
				swap(TL_color, BL_color);
				swap(TL, BL);
				swap(key.x, key.z);
				break;
			case TLBR:
				if (!coin(coord, params.frame_count, TL.topple_prob)) break;
				// Swap TL and BR
				swap(TL_color, BR_color);
				swap(TL, BR);
				swap(key.x, key.w);
				// Stop checking
				cont = false;
				break;
			case TRBL:
				if (!coin(coord + ivec2(1, 0), params.frame_count, TR.topple_prob)) break;
				// Swap TR and BL
				swap(TR_color, BL_color);
				swap(TR, BL);
				swap(key.y, key.z);
				// Stop checking
				cont = false;
				break;
			case TRBR:
				// Swap TR and BR
				swap(TR_color, BR_color);
				swap(TR, BR);
				swap(key.y, key.w);
				break;
			case BLBR:
				if (!true) break;	// TODO: true should be simulating liquid movement probability
				// Swap BL and BR
				swap(BL_color, BR_color);
				swap(BL, BR);
				swap(key.z, key.w);
				break;
			case TTBB:
				// Swap TL and BL
				swap(TL_color, BL_color);
				swap(TL, BL);
				swap(key.x, key.z);
				// Swap TR and BR
				swap(TR_color, BR_color);
				swap(TR, BR);
				swap(key.y, key.w);
				// Stop checking
				break;
		}
		cont = false;
	}
	// Write changes to grid
	imageStore(output_grid, coord			   , TL_color);
	imageStore(output_grid, coord + ivec2(1, 0), TR_color);
	imageStore(output_grid, coord + ivec2(0, 1), BL_color);
	imageStore(output_grid, coord + ivec2(1, 1), BR_color);
}



void main() {
	int method = 1;
	ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
	if (coord.x >= WIDTH || coord.y >= HEIGHT) return;
	if (params.is_frozen == 0) {
		switch (method) {
			case 0: update(coord); 		break;
			case 1: update_marg(coord);	break;
		}
	}
	if (params.do_reset == 1) {
		imageStore(output_grid, coord, encode(Air));
		return;
	}

	// Process Mouse Input
	int next_state = get_mat(coord);
	if (params.draw_mode > 0) {
		vec2 diff = vec2(coord) - params.mouse_pos;
		if (length(diff) <= params.brush_size) {
			float variance = (hash2t(coord, params.frame_count) - 0.5);
			if (params.draw_mode == 1) { // Draw Sand
				if (next_state == Air && coin(coord, params.frame_count)) {
					vec4 textured_sand = material_colors[Sand] + vec4(0.0, 0.15*variance, 0.15*variance, 0.0);                    
					imageStore(output_grid, coord, textured_sand);
				}
			}
			else if (params.draw_mode == 2) { // Draw Stone
				vec4 textured_stone = material_colors[Stone] + vec4(0.0, 0.05*variance, 0.05*variance, 0.0);                    
				imageStore(output_grid, coord, textured_stone);
			}
			else if (params.draw_mode == 3) { // Erase
				imageStore(output_grid, coord, encode(Air));
			}
			else if (params.draw_mode == 4) { // Draw Water
				if (next_state == Air && coin(coord, params.frame_count)) {
					vec4 textured_water = material_colors[Water] + vec4(0.0, 0.15*variance, 0.15*variance, 0.0);                    
					imageStore(output_grid, coord, textured_water);
				}
			}
		}
	}

	if (coord == ivec2(0, 0)) {
		atomicExchange(counters.sand_count,  0u);
		atomicExchange(counters.water_count, 0u);
		atomicExchange(counters.stone_count, 0u);
	}

	barrier();
	memoryBarrierBuffer();

	if		(next_state == Sand)  atomicAdd(counters.sand_count,  1u);
	else if (next_state == Water) atomicAdd(counters.water_count, 1u);
	else if (next_state == Stone) atomicAdd(counters.stone_count, 1u);
}
