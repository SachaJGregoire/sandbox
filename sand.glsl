#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform readonly image2D input_grid;
layout(set = 0, binding = 1, rgba32f) uniform writeonly image2D output_grid;

layout(set = 0, binding = 2) buffer ParticleCounter {
	uint sand_count;
	uint water_count;
	uint stone_count;
} counters;

// We use Push Constants to quickly send mouse input from GDScript
layout(push_constant, std430) uniform Params {
	vec2 mouse_pos;    // 8 bytes (offsets 0-7)
	float brush_size;  // 4 bytes (offsets 8-11)
	int draw_mode;     // 4 bytes (offsets 12-15)
	int frame_count;   // 4 bytes (offsets 16-19)
	int is_frozen;     // 4 bytes (offsets 20-23)
	int do_reset;      // 4 bytes (offsets 24-27)
	int offset_idx;    // 4 bytes (offsets 28-31)
} params;

float hash2t(vec2 p, int frame) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + float(frame)) * 43758.5453);
}

bool coin(vec2 coord, int frame) {
	float r = hash2t(coord, frame);
	return r < 0.5;
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
	float  topple_prob;
	int dispertion_rate;
};

const Particle properties[count_material] = Particle[count_material](
//           mat,   state,  density, topple, dispersion
	Particle(Air,   Gas,    0,   0.0,  0),
	Particle(Sand,  Solid,  100, 0.5,  0),
	Particle(Water, Liquid, 50,  0.0,  5),
	Particle(Stone, Static, 100, 0.0,  0),
	Particle(Vapor, Gas,    30,  0.0,  5)
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

void update(ivec2 coord) {
    Particle cell = decode(imageLoad(input_grid, coord));
    int next_state = cell.mat;

    // 0, 1 : HL (-1,  0)
    // 2    : DL (-1,  1)
    // 3, 4 : HR ( 1,  0)
    // 5    : DR ( 1,  1)
	int phase = params.frame_count % 6;
    int move_x = (phase < 3) ? -1 : 1; 
    int move_y = (phase == 2 || phase == 5) ? 1 : 0;

    // SAND LOGIC
    if (cell.mat == Sand) {
        int mat_below = get_mat(coord + ivec2(0, 1));
        
		// vertical fall
        if (mat_below == Air) {
            next_state = Air;
        } 
		// sink below water
        else if (mat_below == Water) {
            next_state = Water;
        }
		// diagonal fall
        else if (move_y == 1) { 
            int mat_target = get_mat(coord + ivec2(move_x, 1));
            int mat_side = get_mat(coord + ivec2(move_x, 0));
            
            if (mat_target == Air && mat_side == Air && coin(coord, params.frame_count)) {
                next_state = Air;
            }
        }
    } 
    
    // WATER LOGIC
    else if (cell.mat == Water) {
        int mat_above = get_mat(coord + ivec2(0, -1));
        int mat_below = get_mat(coord + ivec2(0, 1));
        
		// rise above sand
        if (mat_above == Sand) {
            next_state = Sand;
        }
		// vertical fall
        else if (mat_below == Air) {
            next_state = Air;
        } 
		// horizontal or diagonal fall
        else {
            int mat_target = get_mat(coord + ivec2(move_x, move_y));
            int mat_side = get_mat(coord + ivec2(move_x, 0));
            
            bool can_move = false;
            if (move_y == 1) {
                can_move = (mat_target == Air && mat_side == Air);
            } else {
                can_move = (mat_target == Air);
            }
            
            if (can_move && coin(coord, params.frame_count)) {
                int mat_target_up = get_mat(coord + ivec2(move_x, move_y - 1));
                if (mat_target_up != Sand && mat_target_up != Water) {
                    next_state = Air;
                }
            }
        }
    } 
    
    // AIR LOGIC
    else if (cell.mat == Air) {
        bool receiving = false;
        int incoming_mat = Air;

        int mat_up = get_mat(coord + ivec2(0, -1));
        // vertical sand fall
        if (mat_up == Sand) {
            receiving = true;
            incoming_mat = Sand;
        } 
		// vertical water fall
        else if (mat_up == Water) {
            if (get_mat(coord + ivec2(0, -2)) != Sand) {
                receiving = true;
                incoming_mat = Water;
            }
        }

        if (!receiving) {
            ivec2 source_coord = coord - ivec2(move_x, move_y);
            int source_mat = get_mat(source_coord);
            
			// diagonal sand fall
            if (source_mat == Sand && move_y == 1) {
                int mat_below_source = get_mat(source_coord + ivec2(0, 1));
                if (mat_below_source != Air && mat_below_source != Water) {
                    int mat_side = get_mat(source_coord + ivec2(move_x, 0));

                    if (mat_side == Air && coin(source_coord, params.frame_count)) {
                        receiving = true;
                        incoming_mat = Sand;
                    }
                }
            } 
			// horizontal or diagonal water fall
            else if (source_mat == Water) {
                int mat_below_source = get_mat(source_coord + ivec2(0, 1));
                int mat_above_source = get_mat(source_coord + ivec2(0, -1));

                if (mat_below_source != Air && mat_above_source != Sand) {
                    bool valid_path = (move_y == 0) || (get_mat(source_coord + ivec2(move_x, 0)) == Air);
                    if (valid_path && coin(source_coord, params.frame_count)) {
                        receiving = true;
                        incoming_mat = Water;
                    }
                }
            }
        }

        if (receiving) {
            next_state = incoming_mat;
        }
    }
    imageStore(output_grid, coord, encode(next_state));
}



struct Entry {
	ivec4 key;
	ivec4 value;
};

const int MAP_SIZE = 16;
Entry map[MAP_SIZE] = Entry[MAP_SIZE](
// NO SAND
	Entry(ivec4(0, 0,
				0, 0),
		  ivec4(0, 0,
		  		0, 0)),

// ONE SAND
	Entry(ivec4(1, 0,
				0, 0),
		  ivec4(0, 0,
		  		1, 0)),

	Entry(ivec4(0, 1,
				0, 0),
		  ivec4(0, 0,
		  		0, 1)),

	Entry(ivec4(0, 0,
				1, 0),
		  ivec4(0, 0,
		  		1, 0)),

	Entry(ivec4(0, 0,
				0, 1),
		  ivec4(0, 0,
		  		0, 1)),

// TWO SANDS
	Entry(ivec4(1, 1,
				0, 0),
		  ivec4(0, 0,
		  		1, 1)),

	Entry(ivec4(1, 0,
				1, 0),
		  ivec4(0, 0,
		  		1, 1)),

	Entry(ivec4(1, 0,
				0, 1),
		  ivec4(0, 0,
		  		1, 1)),

	Entry(ivec4(0, 1,
				1, 0),
		  ivec4(0, 0,
		  		1, 1)),

	Entry(ivec4(0, 1,
				0, 1),
		  ivec4(0, 0,
		  		1, 1)),

	Entry(ivec4(0, 0,
				1, 1),
		  ivec4(0, 0,
		  		1, 1)),

// THREE SANDS
	Entry(ivec4(0, 1,
				1, 1),
		  ivec4(0, 1,
		  		1, 1)),

	Entry(ivec4(1, 0,
				1, 1),
		  ivec4(1, 0,
		  		1, 1)),

	Entry(ivec4(1, 1,
				0, 1),
		  ivec4(0, 1,
		  		1, 1)),

	Entry(ivec4(1, 1,
				1, 0),
		  ivec4(1, 0,
		  		1, 1)),

// FOUR SANDS
	Entry(ivec4(1, 1,
				1, 1),
		  ivec4(1, 1,
		  		1, 1))
);

ivec4 lookup(ivec4 key) {
	for (int i = 0; i < MAP_SIZE; i++) {
		if (map[i].key == key) return map[i].value;
	}
	return key;
}

void update_marg(ivec2 coord) {
	int offset_x = (params.offset_idx == 1 || params.offset_idx == 2) ? 1 : 0;
	int offset_y = (params.offset_idx == 1 || params.offset_idx == 3) ? 1 : 0;
	if (coord.x % 2 != offset_x || coord.y % 2 != offset_y) return;
	// TODO: Borders
	if (coord.x + 1 == WIDTH && coord.y + 1 == HEIGHT) {
		imageStore(output_grid, coord, encode(get_mat(coord)));
		return;
	}
	else if (coord.x + 1 == WIDTH) {
		imageStore(output_grid, coord, encode(get_mat(coord)));
		imageStore(output_grid, coord + ivec2(0, 1), encode(get_mat(coord + ivec2(0, 1))));
		return;
	}
	else if (coord.y + 1 == HEIGHT) {
		imageStore(output_grid, coord, encode(get_mat(coord)));
		imageStore(output_grid, coord + ivec2(1, 0), encode(get_mat(coord + ivec2(1, 0))));
		return;
	}
	Particle TL = decode(imageLoad(input_grid, coord));
	Particle TR = decode(imageLoad(input_grid, coord + ivec2(1, 0)));
	Particle BL = decode(imageLoad(input_grid, coord + ivec2(0, 1)));
	Particle BR = decode(imageLoad(input_grid, coord + ivec2(1, 1)));
	ivec4 key = ivec4(TL.mat, TR.mat, BL.mat, BR.mat);
	ivec4 res = lookup(key);
	imageStore(output_grid, coord, encode(res.x));
	imageStore(output_grid, coord + ivec2(1, 0), encode(res.y));
	imageStore(output_grid, coord + ivec2(0, 1), encode(res.z));
	imageStore(output_grid, coord + ivec2(1, 1), encode(res.w));
}

void main() {
	int method = 0;
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
			if (params.draw_mode == 1) { // Draw Sand
				if (next_state == Air && coin(coord, params.frame_count)) imageStore(output_grid, coord, encode(Sand));
			}
			else if (params.draw_mode == 2) { // Draw Stone
				if (next_state == Air) imageStore(output_grid, coord, encode(Stone));
			}
			else if (params.draw_mode == 3) { // Erase
				imageStore(output_grid, coord, encode(Air));
			}
			else if (params.draw_mode == 4) { // Draw Water
				if (next_state == Air && coin(coord, params.frame_count)) imageStore(output_grid, coord, encode(Water));
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
