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

var is_frozen: bool = true
var do_reset: bool = false
var total_frames: int = 0

# Interactivity variables
var selected_material: int = 1
var is_drawing: bool = false
var brush_size: float = 10

# On ready variables
@onready var SIMULATION: Label = $CanvasLayer/Status/Simulation
@onready var BRUSHSIZE: Label = $CanvasLayer/BrushStuff/BrushSize
@onready var CURRENTSELECTED: Label = $CanvasLayer/Status/CurrentSelected
@onready var PRESETLIST: OptionButton = $CanvasLayer/Presets/PresetsList

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
	
	refresh_dropdown()
	
	Engine.max_fps = 0

	print("Ready!")
	
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
	data.resize(4)
	data[0] = 0  # sand
	data[1] = 0  # rock
	data[2] = 0  # water
	data[3] = 0  # vapor
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


const AIR = 0
const SAND = 1
const WATER = 2
const ROCK = 3
const VAPOR = 4
const COUNT_MATERIAL = 5;

const MATERIAL_COLORS = [
	Color(0.1,  0.1,  0.1,  1.0),  # Air
	Color(0.86, 0.73, 0.36, 1.0),  # Sand
	Color(0.0,  0.4,  0.9,  1.0),  # Water
	Color(0.5,  0.5,  0.5,  1.0),  # Rock
	Color(0.85, 0.90, 0.95, 0.45)  # Vapor
]

func draw(index : int, variance: float) -> Color:
	if index == 0:
		return MATERIAL_COLORS[index]
	if index == ROCK:
		return Color(
			MATERIAL_COLORS[index].r,
			MATERIAL_COLORS[index].g + 0.05 * variance,
			MATERIAL_COLORS[index].b + 0.05 * variance,
			MATERIAL_COLORS[index].a
		)
	return Color(
		MATERIAL_COLORS[index].r,
		MATERIAL_COLORS[index].g + 0.15 * variance,
		MATERIAL_COLORS[index].b + 0.15 * variance,
		MATERIAL_COLORS[index].a
	)

var TEST : int = 0

func initialize_simple_pattern(texture_rid: RID) -> void:
	var data = PackedFloat32Array()
	data.resize(WIDTH * HEIGHT * 4)
	
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var variance = randf() - 0.5
			var idx = (y * WIDTH + x) * 4
			var color = draw(AIR, variance) 

			var H = HEIGHT / 6
			var W = WIDTH / 6
			if y > 1.5 * H and y < 2.5 * H and x > 2.5 * W and x < 3.5 * W:
				color = draw(SAND, variance)
			
			data[idx] = color.r
			data[idx + 1] = color.g
			data[idx + 2] = color.b
			data[idx + 3] = color.a
			
	rd.texture_update(texture_rid, 0, data.to_byte_array())

func read_counters() -> Array:
	var raw  = rd.buffer_get_data(counter_buffer)
	var ints = raw.to_int32_array()
	return [ints[0], ints[1], ints[2], ints[3]]  # [sand, rock, water, vapor]


func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_drawing = event.pressed


func _unhandled_input(event):  
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			is_frozen = !is_frozen
			if is_frozen:
				SIMULATION.text = "Simulation: Frozen"
			else:
				SIMULATION.text = "Simulation: Running"
		elif event.keycode == KEY_ESCAPE:
			do_reset = true
		elif event.keycode == KEY_UP:
			change_brush_size(1)
			BRUSHSIZE.text = "Brush size: %d" % brush_size
		elif event.keycode == KEY_DOWN:
			change_brush_size(-1)
			BRUSHSIZE.text = "Brush size: %d" % brush_size
		elif event.keycode == KEY_PLUS:
			Engine.max_fps = clamp(0, Engine.max_fps + 5, 180)
			print(Engine.max_fps)
		elif event.keycode == KEY_MINUS:
			Engine.max_fps = clamp(0, Engine.max_fps - 5, 180)
			print(Engine.max_fps)
		elif event.keycode == KEY_A:
			CURRENTSELECTED.text = "Selected: Air"
			select(0)
		elif event.keycode == KEY_S:
			CURRENTSELECTED.text = "Selected: Sand"
			select(1)
		elif event.keycode == KEY_W:
			CURRENTSELECTED.text = "Selected: Water"
			select(2)
		elif event.keycode == KEY_R:
			CURRENTSELECTED.text = "Selected: Rock"
			select(3)
		elif event.keycode == KEY_V:
			CURRENTSELECTED.text = "Selected: Vapor"
			select(4)

func _process(_delta: float) -> void:
	if not rd or not pipeline.is_valid():
		return
	
	
	for i in range(4):
		total_frames += 1
		
		rd.buffer_clear(counter_buffer, 0, 16)

		var input_idx = current_texture_index
		var output_idx = 1 - current_texture_index
		
		var compute_list = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, uniform_sets[input_idx], 0)
		
		var tex_mouse = get_local_mouse_to_texture()
		var push_bytes = PackedByteArray()
		push_bytes.resize(32) # must be mult of 16
		
		push_bytes.encode_float(0, tex_mouse.x)           								# vec2 mouse_pos.x
		push_bytes.encode_float(4, tex_mouse.y)           								# vec2 mouse_pos.y
		push_bytes.encode_float(8, brush_size)           								# float brush_size
		push_bytes.encode_s32(12, selected_material if is_drawing else COUNT_MATERIAL)  # int selected_material
		push_bytes.encode_s32(20, 1 if is_frozen else 0)  								# int is_frozen
		push_bytes.encode_s32(24, 1 if do_reset else 0)   								# int do_reset
		push_bytes.encode_s32(16, total_frames)           								# int frame_count
		
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
		$CanvasLayer/Counters/SandCounter.text = "%d" % counts[0]
		$CanvasLayer/Counters/RockCounter.text = "%d" % counts[1]
		$CanvasLayer/Counters/WaterCounter.text = "%d" % counts[2]
		$CanvasLayer/Counters/VaporCounter.text = "%d" % counts[3]

func select(x: int) -> void:
	selected_material = x

func change_brush_size(x: int) -> void:
	brush_size = clamp(brush_size + x, 1, 100)
	BRUSHSIZE.text = "Brush size: %d" % brush_size

func refresh_dropdown() -> void:
	PRESETLIST.clear()
	
	var dir = DirAccess.open("res://presets/")
	if not dir:
		DirAccess.make_dir_recursive_absolute("res://presets/")
		return
	
	dir.list_dir_begin()
	var filename = dir.get_next()
	while filename != "":
		if filename.ends_with(".bin"):
			PRESETLIST.add_item(filename.get_basename())
		filename = dir.get_next()
	dir.list_dir_end()

#---------------PRESETS--------------------------------#

func save_texture(texture_rid: RID, path: String) -> void:
	var raw = rd.texture_get_data(texture_rid, 0)
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(raw)
	file.close()
	print("Saved to ", path)
	
func load_texture(texture_rid: RID, path: String) -> void:
	if not FileAccess.file_exists(path):
		printerr("File not found: ", path)
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var raw = file.get_buffer(file.get_length())
	file.close()
	rd.texture_update(texture_rid, 0, raw)
	print("Loaded from ", path)

func preset_selector(index: int) -> void:
	var selected = PRESETLIST.get_item_text(index)
	if selected == "":
		printerr("Nothing selected")
		return
		
	load_texture(textures[0],"res://presets/%s.bin" % selected)
	load_texture(textures[1],"res://presets/%s.bin" % selected)

func save_button() -> void:
	var filename = $CanvasLayer/Presets/Name.text.strip_edges()
	if filename == "":
		printerr("No filename entered")
		return
	save_texture(textures[current_texture_index], "res://presets/%s.bin" % filename)
	refresh_dropdown()
