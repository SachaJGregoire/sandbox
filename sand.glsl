#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform readonly image2D input_grid;
layout(set = 0, binding = 1, rgba32f) uniform writeonly image2D output_grid;

layout(set = 0, binding = 2) buffer ParticleCounter {
	uint sand_count;
	uint stone_count;
	uint water_count;
	uint vapor_count;
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

// Hash functions and its derivatives
float hash2t(vec2 p, int frame) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + float(frame)) * 43758.5453);
}
float hash3(vec2 p, int frame) {	
    vec3 x = vec3(p, float(frame));
    return fract(sin(dot(x, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

bool coin(vec2 coord, int frame, float threshold) {
	return hash3(coord, frame) < threshold;
}
bool coin(vec2 coord, int frame) { return coin(coord, frame, 0.5); }

bool shimmer(vec2 coord, int frame) {
	return hash3(coord, frame + 7717) < 0.005;
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
	int dispersion_rate;
};

const Particle properties[count_material] = Particle[count_material](
//           mat,   state,  density, topple, dispersion
	Particle(Air,   Gas,    10,   	0.0,  0),
	Particle(Sand,  Solid,  100, 	0.2,  0),
	Particle(Water, Liquid, 50,  	1.0,  6),
	Particle(Stone, Static, 255, 	0.0,  0),
	Particle(Vapor, Gas,    5,  	1.0,  12)
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

void draw(ivec2 coord) {
	vec4 state = imageLoad(input_grid, coord);
	int draw_mode = params.draw_mode;
	if (draw_mode == count_material) return;

	vec2 diff = vec2(coord) - params.mouse_pos;
	if (length(diff) > params.brush_size) return;

	if (draw_mode == 0) {
		imageStore(output_grid, coord, material_colors[Air]);
		return;
	}
	if (properties[draw_mode].state == Static) {
		float variance = (hash2t(coord, params.frame_count) - 0.5);
		imageStore(output_grid, coord, material_colors[draw_mode] + vec4(0.0, 0.05*variance, 0.05*variance, 0.0));
	}

	if (decode(state).mat != Air || !coin(coord, params.frame_count)) return;

	float variance = (hash2t(coord, params.frame_count) - 0.5);
	imageStore(output_grid, coord, material_colors[draw_mode] + vec4(0.0, 0.15*variance, 0.15*variance, 0.0));
}



int get_state(ivec2 p) {
	if (p.x < 0 || p.x >= WIDTH || p.y < 0 || p.y >= HEIGHT) return Static;
	return decode(imageLoad(input_grid, p)).state;
}

int get_mat(ivec2 p) {
	if (p.x < 0 || p.x >= WIDTH || p.y < 0 || p.y >= HEIGHT) return Stone;
	return decode(imageLoad(input_grid, p)).mat;
}

int get_water_move(ivec2 source, int dx, int dy, int dispersion, int frame) {
	// TODO: why coin?
	if (!coin(source, frame)) return 0;
	
	for (int i = 0; i < dispersion; i++) {
		ivec2 target = source + ivec2(dx * (i+1), dy * (i+1));
		
		// Do not disperse through non-gas particles
		if (get_state(target) != Gas) return i;
		// Do not disperse downwards if there is a non-gas particle above the target
		if (get_state(target + ivec2(0, -1)) != Gas) return i; 
	}
	return dispersion;
}

int get_gas_move(ivec2 source, int dx, int dy, int dispersion, int frame) {
	// TODO: why coin?
	if (!coin(source, frame)) return 0;
	
	for (int i = 0; i < dispersion; i++) {
		ivec2 target = source + ivec2(dx * (i+1), dy * (i+1));
		
		// Do not disperse through non-air particles
		if (get_mat(target) != Air) return i;
		// Do not disperse upwards if there is a non-gas particle above the target
        if (get_state(target + ivec2(0, -1)) != Gas) return i;
		// Do not disperse upwards if there is a gas particle below the target
        if (get_state(target + ivec2(0, 1)) == Gas && get_mat(target + ivec2(0, 1)) != Air) return i;
	}
	return dispersion;
}




void update_solid	(ivec2 coord, int move_x, int move_y, vec4 current_color) {
	ivec2 below = coord + ivec2(0, 1);
	int state_below = get_state(below);
	
	// Fall through Gases and Liquids
	if (state_below == Gas || state_below == Liquid) {
		imageStore(output_grid, coord, imageLoad(input_grid, below));
		return;
	}
	// Diagonal fall
	ivec2 target = coord + ivec2(move_x, 1);
	ivec2 side 	 = coord + ivec2(move_x, 0);
	if (move_y != 1 || get_state(target) != Gas || get_state(side) != Gas || !coin(coord, params.frame_count)) {
		imageStore(output_grid, coord, current_color);
		return;
	}
	
	// TODO: Change Air to correct color
	// TODO: Fix topple_prob
	imageStore(output_grid, coord, material_colors[Air]);
	return;
}

void update_liquid	(ivec2 coord, int move_x, int move_y, vec4 current_color) {
	ivec2 above = coord + ivec2(0,-1);
	ivec2 below = coord + ivec2(0, 1);
	int state_above = get_state(above);
	int state_below = get_state(below);

	// Rise above solids
	if (state_above == Solid) {
		imageStore(output_grid, coord, imageLoad(input_grid, above));
		return;
	}
	// Fall through gases
	if (state_below == Gas) {
		imageStore(output_grid, coord, imageLoad(input_grid, below));
		return;
	}

	// Horizontal or diagonal fall
	int move = get_water_move(coord, move_x, move_y, properties[Water].dispersion_rate, params.frame_count);
	if (move > 0) {
		// TODO: Change Air to correct color
		imageStore(output_grid, coord, material_colors[Air]);
		return;
	}
	if (shimmer(coord, params.frame_count)) {                    
		float variance = (hash2t(coord, params.frame_count) - 0.5);
		vec4 next_color = material_colors[decode(current_color).mat] + vec4(0.0, 0.15*variance, 0.15*variance, 0.0);
		imageStore(output_grid, coord, next_color);
		return;
	}

	imageStore(output_grid, coord, current_color);
}

void update_air		(ivec2 coord, int move_x, int move_y, vec4 current_color) {
	ivec2 above = coord + ivec2(0, -1);
	ivec2 below = coord + ivec2(0, 1);
	int state_above = get_state(above);
    int state_below = get_state(below);

	// Vertical Solid fall
	if (state_above == Solid) {
		imageStore(output_grid, coord, imageLoad(input_grid, above));
		return;
	}
	// Vertical Liquid fall
	if (state_above == Liquid && get_state(coord + ivec2(0, -2)) != Solid) {
		imageStore(output_grid, coord, imageLoad(input_grid, above));
		return;
	}
	// Vertical Gas rise
    if (state_below == Gas && get_mat(below) != Air) {
        imageStore(output_grid, coord, imageLoad(input_grid, below));
        return;
    }

	// Diagonal Solid fall
	ivec2 source = coord - ivec2(move_x, move_y);
	if (move_y == 1 && get_state(source) == Solid) {
		int state_below = get_state(source + ivec2(0, 1));
		if (state_below != Gas && state_below != Liquid) {
			int state_side = get_state(source + ivec2(move_x, 0));
			if (state_side == Gas && coin(source, params.frame_count)) {
				imageStore(output_grid, coord, imageLoad(input_grid, source));
				return;
			}
		}
	}
	
	// Horizontal or diagonal Liquid fall
	for (int i = 1; i <= properties[Water].dispersion_rate; i++) {
		ivec2 source = coord - ivec2(move_x * i, move_y * i);
		int state_source = get_state(source);
		
		if (state_source == Gas) continue;
		if (state_source == Solid || state_source == Static) break;

		int state_above_source = get_state(source + ivec2(0,-1));
		int state_below_source = get_state(source + ivec2(0, 1));
		
		if (state_below_source == Gas || state_above_source == Solid) break;
		if (get_water_move(source, move_x, move_y, properties[Water].dispersion_rate, params.frame_count) != i) break;

		imageStore(output_grid, coord, imageLoad(input_grid, source));
		return;
	}

	// Horizontal or diagonal Gas rise
    for (int i = 1; i <= properties[Vapor].dispersion_rate; i++) {
        ivec2 source = coord - ivec2(move_x * i, -move_y * i);
        int state_source = get_state(source);
        
        if (state_source != Gas || get_mat(source) == Air) continue;
		if (state_source == Solid || state_source == Static) break;

        int state_above_source = get_state(source + ivec2(0, -1));
		int material_above_source = get_mat(source + ivec2(0, -1));
        
        if (state_above_source == Solid || state_above_source == Liquid || material_above_source == Air) break;
        if (get_gas_move(source, move_x, -move_y, properties[Vapor].dispersion_rate, params.frame_count) != i) break;

        imageStore(output_grid, coord, imageLoad(input_grid, source));
        return;
    }

	imageStore(output_grid, coord, current_color);
}

void update_gas		(ivec2 coord, int move_x, int move_y, vec4 current_color) {
    ivec2 above = coord + ivec2(0, -1);
    int state_above = get_state(above);

	// Rise above Solids and Liquids
    if (state_above == Solid || state_above == Liquid) {
        imageStore(output_grid, coord, imageLoad(input_grid, above));
        return;
    }
    
    // Rise through Air
    if (get_mat(above) == Air) {
		int state_above_above = get_state(coord + ivec2(0, -2));

		bool falling_solid = (state_above_above == Solid);
        bool falling_liquid = (state_above_above == Liquid && get_state(coord + ivec2(0, -3)) != Solid);

		// Do not rise if a Solid or Liquid particle will fall in the target
		if (!falling_solid && !falling_liquid) {
			imageStore(output_grid, coord, imageLoad(input_grid, above));
			return;
		} else {
			imageStore(output_grid, coord, current_color);
            return;
		}
    }

	// Horizontal or diagonal fall
    int move = get_gas_move(coord, move_x, -move_y, properties[Vapor].dispersion_rate, params.frame_count);
    if (move > 0) {
		// TODO: Change Air to correct color
        imageStore(output_grid, coord, material_colors[Air]);
        return;
    }    
    if (shimmer(coord, params.frame_count)) {                    
        float variance = (hash2t(coord, params.frame_count) - 0.5);
        vec4 next_color = material_colors[decode(current_color).mat] + vec4(0.0, 0.15*variance, 0.15*variance, 0.0);
        imageStore(output_grid, coord, next_color);
        return;
    }

    imageStore(output_grid, coord, current_color);
}

void update(ivec2 coord) {
	vec4 current_color  = imageLoad(input_grid, coord);
	Particle cell = decode(current_color);

	int phase = params.frame_count % 4;
	int move_x = (phase == 0 || phase == 1) ? -1 : 1; 
	int move_y = (phase == 0 || phase == 2) ?  0 : 1;

	switch (cell.state) {
		case Static: break;
		case Solid:
			update_solid(coord, move_x, move_y, current_color);
			break;
		case Liquid:
			update_liquid(coord, move_x, move_y, current_color);
			break;
		case Gas:
			if (cell.mat == Air) update_air(coord, move_x, move_y, current_color);
			else 				 update_gas(coord, move_x, move_y, current_color);
			break;
	}
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
const int TRTL	= 8;
const int BRBL	= 9;

const int marg[81] = int[81](
	ERROR,	/*  0  (-1,-1,
					-1,-1) */
	TLBL,	/*  1  ( 0,-1,
					-1,-1) */
	ERROR,	/*  2  ( 1,-1,
					-1,-1) */
	TRBR,	/*  3  (-1, 0,
					-1,-1) */
	TTBB,	/*  4  ( 0, 0,
					-1,-1) */
	TRBR,	/*  5  ( 1, 0,
					-1,-1) */
	ERROR,	/*  6  (-1, 1,
					-1,-1) */
	TLBL,	/*  7  ( 0, 1,
					-1,-1) */
	ERROR,	/*  8  ( 1, 1,
					-1,-1) */

	BLBR,	/*  9  (-1,-1,
					 0,-1) */
	TLBR,	/* 10  ( 0,-1,
					 0,-1) */
	BLBR,	/* 11  ( 1,-1,
					 0,-1) */
	TRBR,	/* 12  (-1, 0,
					 0,-1) */
	TRBR,	/* 13  ( 0, 0,
					 0,-1) */
	TRBR,	/* 14  ( 1, 0,
					 0,-1) */
	BLBR,	/* 15  (-1, 1,
					 0,-1) */
	BLBR,	/* 16  ( 0, 1,
					 0,-1) */
	BLBR,	/* 17  ( 1, 1,
					 0,-1) */

	ERROR,	/* 18  (-1,-1,
					 1,-1) */
	TLBR,	/* 19  ( 0,-1,
					 1,-1) */
	ERROR,	/* 20  ( 1,-1,
					 1,-1) */
	TRBR,	/* 21  (-1, 0,
					 1,-1) */
	TRBR,	/* 22  ( 0, 0,
					 1,-1) */
	TRBR,	/* 23  ( 1, 0,
					 1,-1) */
	ERROR,	/* 24  (-1, 1,
					 1,-1) */
	NONE,	/* 25  ( 0, 1,
					 1,-1) */
	ERROR,	/* 26  ( 1, 1,
					 1,-1) */

	BRBL,	/* 27  (-1,-1,
					-1, 0) */
	TLBL,	/* 28  ( 0,-1,
					-1, 0) */
	BRBL,	/* 29  ( 1,-1,
					-1, 0) */
	TRBL,	/* 30  (-1, 0,
					-1, 0) */
	TLBL,	/* 31  ( 0, 0,
					-1, 0) */
	BRBL,	/* 32  ( 1, 0,
					-1, 0) */
	BRBL,	/* 33  (-1, 1,
					-1, 0) */
	TLBL,	/* 34  ( 0, 1,
					-1, 0) */
	BRBL,	/* 35  ( 1, 1,
					-1, 0) */

	NONE,	/* 36  (-1,-1,
					 0, 0) */
	TLTR,	/* 37  ( 0,-1,
					 0, 0) */
	NONE,	/* 38  ( 1,-1,
					 0, 0) */
	TRTL,	/* 39  (-1, 0,
					 0, 0) */
	NONE,	/* 40  ( 0, 0,
					 0, 0) */
	NONE,	/* 41  ( 1, 0,
					 0, 0) */
	NONE,	/* 42  (-1, 1,
					 0, 0) */
	NONE,	/* 43  ( 0, 1,
					 0, 0) */
	NONE,	/* 44  ( 1, 1,
					 0, 0) */

	NONE,	/* 45  (-1,-1,
					 1, 0) */
	TLTR,	/* 46  ( 0,-1,
					 1, 0) */
	NONE,	/* 47  ( 1,-1,
					 1, 0) */
	TRTL,	/* 48  (-1, 0,
					 1, 0) */
	NONE,	/* 49  ( 0, 0,
					 1, 0) */
	NONE,	/* 50  ( 1, 0,
					 1, 0) */
	NONE,	/* 51  (-1, 1,
					 1, 0) */
	NONE,	/* 52  ( 0, 1,
					 1, 0) */
	NONE,	/* 53  ( 1, 1,
					 1, 0) */

	ERROR,	/* 54  (-1,-1,
					-1, 1) */
	TLBL,	/* 55  ( 0,-1,
					-1, 1) */
	ERROR,	/* 56  ( 1,-1,
					-1, 1) */
	TRBL,	/* 57  (-1, 0,
					-1, 1) */
	TLBL,	/* 58  ( 0, 0,
					-1, 1) */
	NONE,	/* 59  ( 1, 0,
					-1, 1) */
	ERROR,	/* 60  (-1, 1,
					-1, 1) */
	TLBL,	/* 61  ( 0, 1,
					-1, 1) */
	ERROR,	/* 62  ( 1, 1,
					-1, 1) */

	NONE,	/* 63  (-1,-1,
					 0, 1) */
	TLTR,	/* 64  ( 0,-1,
					 0, 1) */
	NONE,	/* 65  ( 1,-1,
					 0, 1) */
	TRTL,	/* 66  (-1, 0,
					 0, 1) */
	NONE,	/* 67  ( 0, 0,
					 0, 1) */
	NONE,	/* 68  ( 1, 0,
					 0, 1) */
	NONE,	/* 69  (-1, 1,
					 0, 1) */
	NONE,	/* 70  ( 0, 1,
					 0, 1) */
	NONE,	/* 71  ( 1, 1,
					 0, 1) */

	ERROR,	/* 72  (-1,-1,
					 1, 1) */
	TLTR,	/* 73  ( 0,-1,
					 1, 1) */
	ERROR,	/* 74  ( 1,-1,
					 1, 1) */
	TRTL,	/* 75  (-1, 0,
					 1, 1) */
	NONE,	/* 76  ( 0, 0,
					 1, 1) */
	NONE,	/* 77  ( 1, 0,
					 1, 1) */
	ERROR,	/* 78  (-1, 1,
					 1, 1) */
	NONE,	/* 79  ( 0, 1,
					 1, 1) */
	ERROR	/* 80  ( 1, 1,
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
	// TODO: Make move_prob based on dispersion rate?
	float liquid_move_prob = 0.75;
	// Setting up offset (I think the 4offset looks better than the 2offset, but both work)
	int offset = params.frame_count % 4;
	int offset_x = (offset == 1 || offset == 2) ? 1 : 0;
	int offset_y = (offset == 1 || offset == 3) ? 1 : 0;
	//int offset_x = params.frame_count % 2;
	//int offset_y = params.frame_count % 2;

	// Hande top and left margins
	if (coord.y == 0 && offset_y == 1) {
		imageStore(output_grid, coord, imageLoad(input_grid, coord));
		return;
	}
	if (coord.x == 0 && offset_x == 1 && coord.y % 2 == offset_y && coord.y + 1 < HEIGHT) {
		vec4 T_color = imageLoad(input_grid, coord			  	);
		vec4 B_color = imageLoad(input_grid, coord + ivec2(0, 1));
		Particle T = decode(T_color);
		Particle B = decode(B_color);
		if (T.state != Static && T.density > B.density) swap(T_color, B_color);
		imageStore(output_grid, coord			   , T_color);
		imageStore(output_grid, coord + ivec2(0, 1), B_color);
		return;
	}
	// Handle bottom and right margins
	if (coord.y == HEIGHT - 1 && coord.y % 2 == offset_y) {
		imageStore(output_grid, coord, imageLoad(input_grid, coord));
		return;
	}
	if (coord.x == WIDTH - 1 && coord.x % 2 == offset_x && coord.y % 2 == offset_y && coord.y + 1 < HEIGHT) {
		vec4 T_color = imageLoad(input_grid, coord			  	);
		vec4 B_color = imageLoad(input_grid, coord + ivec2(0, 1));
		Particle T = decode(T_color);
		Particle B = decode(B_color);
		if (T.state != Static && T.density > B.density) swap(T_color, B_color);
		imageStore(output_grid, coord			   , T_color);
		imageStore(output_grid, coord + ivec2(0, 1), B_color);
		return;
	}

	// Return for cells that are not the representative (TL) of their margolus neighborhood
	if (coord.x % 2 != offset_x || coord.y % 2 != offset_y) return;

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
				if (TL.state == Solid || !coin(coord, params.frame_count, liquid_move_prob)) break;
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
				if (BL.state == Solid || !coin(coord + ivec2(0, 1), params.frame_count, liquid_move_prob)) break;
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
			case TRTL:
				if (TR.state == Solid || !coin(coord + ivec2(1, 0), params.frame_count, liquid_move_prob)) break;
				// Swap TL and TR
				swap(TL_color, TR_color);
				swap(TL, TR);
				swap(key.x, key.y);
				break;
			case BRBL:
				if (BR.state == Solid || !coin(coord + ivec2(1, 1), params.frame_count, liquid_move_prob)) break;
				// Swap BL and BR
				swap(BL_color, BR_color);
				swap(BL, BR);
				swap(key.z, key.w);
				break;
		}
	}
	// Write changes to grid
	imageStore(output_grid, coord			   , TL_color);
	imageStore(output_grid, coord + ivec2(1, 0), TR_color);
	imageStore(output_grid, coord + ivec2(0, 1), BL_color);
	imageStore(output_grid, coord + ivec2(1, 1), BR_color);
}



void main() {
	int method = 0;
	ivec2 coord = ivec2(gl_GlobalInvocationID.xy);

	if (params.do_reset == 1) {
		imageStore(output_grid, coord, material_colors[Air]);
		return;
	}

	if (params.is_frozen == 0) {
		switch (method) {
		case 0: update(coord); 		break;
		case 1: update_marg(coord);	break;
		}
	}

	// Process Mouse Input
	draw(coord);
	

	/*
	Probably this will need to be moved into the draw function if we still want to use it.

	int next_state = decode(imageLoad(output_grid, coord)).mat;
	
	if		(next_state == Sand) 	atomicAdd(counters.sand_count,  1u);
	else if (next_state == Water)	atomicAdd(counters.water_count, 1u);
	else if (next_state == Stone)	atomicAdd(counters.stone_count, 1u);
	else if (next_state == Vapor)	atomicAdd(counters.vapor_count, 1u);
	*/
}
