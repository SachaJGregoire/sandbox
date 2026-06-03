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
	Particle(Water, Liquid, 50,  0.0,  6),
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
