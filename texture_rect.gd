extends TextureRect

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var textures: Array[RID] = [RID(), RID()]
var current_texture_index: int = 0
var uniform_sets: Array[RID] = [RID(), RID()]

var counter_buffer: RID


const WIDTH: int = 512
const HEIGHT: int = 512	
const SHADER_PATH: String = "res://sand.glsl"

var is_frozen: bool = false
var do_reset: bool = false
var total_frames: int = 0

# Interactivity variables
var selected_material: int = 1
var is_drawing: bool = false
var brush_size: float = 12.0

func _ready():
	rd = RenderingServer.get_rendering_device()
	
	if not rd:
		printerr("RenderingDevice not available!")
		return
	
	textures[0] = create_texture()
	textures[1] = create_texture()
	
	initialize_simple_pattern(textures[0])
	initialize_simple_pattern(textures[1])
	
	counter_buffer = create_counter_buffer()
	
	if not create_compute_pipeline():
		printerr("Failed to create pipeline!")
		return
	
	uniform_sets[0] = create_uniform_set(textures[0], textures[1])
	uniform_sets[1] = create_uniform_set(textures[1], textures[0])
	
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	
	var tex_rd = Texture2DRD.new()
	tex_rd.texture_rd_rid = textures[0]
	texture = tex_rd
	
	print("Ready! Controls:")
	print("Left Click = Sand | Right Click = Wall | Esc = Erase | Space = Pause")

func create_texture() -> RID:
	var format = RDTextureFormat.new()
	format.width = WIDTH
	format.height = HEIGHT
	format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | \
						RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | \
						RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | \
						RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	return rd.texture_create(format, RDTextureView.new())

func create_counter_buffer() -> RID:
	var data = PackedInt32Array()
	data.resize(3)
	data[0] = 0  # sand
	data[1] = 0  # water
	data[2] = 0  # stone
	return rd.storage_buffer_create(data.size() * 4, data.to_byte_array())

func create_compute_pipeline() -> bool:
	if not FileAccess.file_exists(SHADER_PATH):
		printerr("Shader file not found: ", SHADER_PATH)
		return false
		
	var file = FileAccess.open(SHADER_PATH, FileAccess.READ)
	var shader_code = file.get_as_text()
	file.close()
	
	var shader_source = RDShaderSource.new()
	shader_source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	shader_source.source_compute = shader_code
	
	var shader_spirv = rd.shader_compile_spirv_from_source(shader_source)
	var error = shader_spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE)
	if error != "":
		printerr("Shader compilation error: ", error)
		return false
		
	shader = rd.shader_create_from_spirv(shader_spirv)
	if not shader.is_valid(): return false
	pipeline = rd.compute_pipeline_create(shader)
	if not pipeline.is_valid(): return false
	return true

func get_local_mouse_to_texture() -> Vector2:
	var local_mouse = get_local_mouse_position()
	var rect_size = get_rect().size
	var tex_x = (local_mouse.x / rect_size.x) * WIDTH
	var tex_y = (local_mouse.y / rect_size.y) * HEIGHT
	return Vector2(tex_x, tex_y)

func create_uniform_set(input_texture: RID, output_texture: RID) -> RID:
	var input_uniform = RDUniform.new()
	input_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	input_uniform.binding = 0
	input_uniform.add_id(input_texture)
	
	var output_uniform = RDUniform.new()
	output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output_uniform.binding = 1
	output_uniform.add_id(output_texture)
	
	var counter_uniform = RDUniform.new()
	counter_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	counter_uniform.binding = 2
	counter_uniform.add_id(counter_buffer)
	
	return rd.uniform_set_create([input_uniform, output_uniform, counter_uniform], shader, 0)

func _exit_tree():
	if rd:
		if shader.is_valid(): rd.free_rid(shader)
		if pipeline.is_valid(): rd.free_rid(pipeline)
		if textures[0].is_valid(): rd.free_rid(textures[0])
		if textures[1].is_valid(): rd.free_rid(textures[1])
		if uniform_sets[0].is_valid(): rd.free_rid(uniform_sets[0])
		if uniform_sets[1].is_valid(): rd.free_rid(uniform_sets[1])



func initialize_simple_pattern(texture_rid: RID) -> void:
	var data = PackedFloat32Array()
	data.resize(WIDTH * HEIGHT * 4)
	
	# Draw a little bowl/level design to get started
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var idx = (y * WIDTH + x) * 4
			var r = 0
			var g = 0
			var b = 0
			
			# Floor
			if y > 450 and y < 470 and x > 100 and x < 412:
				r = 0.3; g = 0.3; b = 0.35 # Wall Color
			# Walls
			if y > 350 and y <= 450 and (x > 100 and x < 120 or x > 392 and x < 412):
				r = 0.3; g = 0.3; b = 0.35 # Wall Color
				
			data[idx] = r
			data[idx + 1] = g
			data[idx + 2] = b
			data[idx + 3] = 0
			
	rd.texture_update(texture_rid, 0, data.to_byte_array())

func read_counters() -> Array:
	var raw  = rd.buffer_get_data(counter_buffer)
	var ints = raw.to_int32_array()
	return [ints[0], ints[1], ints[2]]  # [sand, water, stone]


func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_drawing = event.pressed


func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			is_frozen = !is_frozen
			print("Simulation: ", "FROZEN" if is_frozen else "RUNNING")
		elif event.keycode == KEY_ESCAPE:
			do_reset = true


func _process(_delta: float) -> void:
	if not rd or not pipeline.is_valid():
		return
		
	for i in range(4):
		total_frames += 1
		
		var input_idx = current_texture_index
		var output_idx = 1 - current_texture_index
		
		var compute_list = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, uniform_sets[input_idx], 0)
		
		var tex_mouse = get_local_mouse_to_texture()
		var push_bytes = PackedByteArray()
		push_bytes.resize(32) # must be mult of 16
		
		push_bytes.encode_float(0, tex_mouse.x)           					# vec2 mouse_pos.x
		push_bytes.encode_float(4, tex_mouse.y)           					# vec2 mouse_pos.y
		push_bytes.encode_float(8, brush_size)           					# float brush_size
		push_bytes.encode_s32(12, selected_material if is_drawing else 0)   # int selected_material (0 if not drawing)
		push_bytes.encode_s32(16, total_frames)           					# int frame_count
		push_bytes.encode_s32(20, 1 if is_frozen else 0)  					# int is_frozen
		push_bytes.encode_s32(24, 1 if do_reset else 0)   					# int do_reset
		push_bytes.encode_s32(28, total_frames % 4)     					# int offset_idx (for Margolus)
		
		rd.compute_list_set_push_constant(compute_list, push_bytes, push_bytes.size())
		# ---------------------------------------------
		
		var groups_x = (WIDTH + 15) / 16
		var groups_y = (HEIGHT + 15) / 16
		rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
		rd.compute_list_end()
	
		current_texture_index = output_idx
		do_reset = 0

	var tex_rd = Texture2DRD.new()
	tex_rd.texture_rd_rid = textures[current_texture_index]
	texture = tex_rd
	
	if total_frames % 30 == 0:
		var counts = read_counters()
		print("Sand: ", counts[0], " Water: ", counts[1], " Stone: ", counts[2])
	

func select_sand():
	selected_material = 1
	print("Material: SAND")
func select_stone():
	selected_material = 2
	print("Material: STONE")
func select_air():
	selected_material = 3
	print("Material: AIR")
func select_water():
	selected_material = 4
	print("Material: WATER")
