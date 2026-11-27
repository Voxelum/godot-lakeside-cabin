extends SceneTree
## Windowed renderer only: actual Main/Pixels and its ordinary camera. Frames
## are staged separately from the input-driven route and wall checks.
const MAIN := preload("res://Main.tscn")
const Ridge := preload("res://source/mountain/ridge_mesh.gd")
const DEFAULT := preload("res://source/mountain/fern_fold.tres")
const OTHER := preload("res://source/mountain/split_spur.tres")
var plan := DEFAULT
var ridge := Ridge.new()
var main
var field: SubViewport
var actor: CharacterBody3D
var orbit: Camera3D
var mountain: Node3D
var clock: Node
var out := ""
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _run() -> void:
	var alternate := ""
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=")
		if arg.begins_with("--alternate="): alternate = arg.trim_prefix("--alternate=")
	if DisplayServer.get_name() == "headless":
		printerr("Run with a window; this is a check of the actual GL renderer.")
		quit(2)
		return
	if not out.is_empty() and (DirAccess.dir_exists_absolute(out) or DirAccess.make_dir_recursive_absolute(out) != OK):
		printerr("--output must be a new directory; existing captures are never replaced.")
		quit(2)
		return
	var token := Crypto.new().generate_random_bytes(16).hex_encode()
	main = MAIN.instantiate()
	main.get_node("Session").slot_path = "user://mountain_pixels_%s.slot" % token
	main.get_node("BindingPanel").settings_path = "user://mountain_pixels_%s.cfg" % token
	var clearing: Node3D = main.get_node("Pixels/Clearing")
	mountain = clearing.get_node("MountainRise")
	if not alternate.is_empty():
		var scene := load(alternate) as PackedScene
		if scene == null:
			main.free()
			printerr("Could not load the alternate bake.")
			quit(2)
			return
		mountain.free()
		mountain = scene.instantiate()
		clearing.add_child(mountain)
		plan = OTHER
	root.add_child(main)
	field = main.field
	actor = main.field_actor
	orbit = main.orbit
	clock = clearing.get_node("Almanac")
	var screen: TextureRect = main.get_node("Screen")
	var expected := Vector2i(320, 180) if "--320" in args else Vector2i(480, 270)
	check(field.size == expected and field.get_camera_3d() == orbit and screen.texture == field.get_texture(), "native F5 camera/viewport")
	var scale := screen.size / Vector2(expected)
	check(screen.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and scale.x == scale.y and scale.x == floorf(scale.x), "nearest-neighbour integer fit")
	check(ridge.build(plan).is_empty(), "valid profile at staging points")
	orbit.set_process(false)
	await _view(3, 14.0, "fork")
	var overlook := 12 if alternate.is_empty() else 9
	await _view(overlook, 14.0, "shelves-day", true)
	await _view(overlook, 18.66667, "shelves-dusk", true)
	await _view(18, 14.0, "upper-path")
	if not alternate.is_empty():
		# An extra development orbit exposes the alternate ramp on the opposite face.
		orbit.set("yaw_degrees", 144.0)
		await _view(12, 14.0, "reverse-ramp", true)
	print("mountain_pixel_checks: %d failures; %s; %s" % [failures, field.size, out])
	quit(int(failures != 0))

func _view(index: int, hour: float, label: String, inspect := false) -> void:
	var p := plan.trail[index]
	actor.position = plan.origin + Vector3(p.x, ridge.height_at(p)+.003, p.y)
	actor.velocity = Vector3.ZERO
	actor.reset_physics_interpolation()
	for i in 4: await physics_frame
	orbit.call(&"align_at_subject")
	clock.set("hour", hour)
	clock.call(&"_advance_sky")
	var frame := await _frame()
	check(not frame.is_empty() and frame.get_size() == field.size, "complete native frame " + label)
	if not out.is_empty():
		var path := out.path_join(label + ".png")
		check(not FileAccess.file_exists(path) and frame.save_png(path) == OK, "capture " + path)
	if inspect: await _readability_numbers(frame, label)

func _frame() -> Image:
	for i in 4:
		await process_frame
		await RenderingServer.frame_post_draw
	return field.get_texture().get_image()

func _ink(color: Color) -> StandardMaterial3D:
	var flat := StandardMaterial3D.new()
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat.cull_mode = BaseMaterial3D.CULL_DISABLED
	flat.albedo_color = color
	return flat

func _readability_numbers(frame: Image, label: String) -> void:
	# Re-render only the material IDs to locate visible terrain in the real frame.
	# No image from this diagnostic pass is delivered as an art preview.
	var shale := Shader.new()
	shale.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float tier_y;
varying float local_y;
void vertex() { local_y = VERTEX.y; }
void fragment() { ALBEDO = local_y < tier_y ? vec3(1,0,1) : vec3(0,1,1); }
"""
	var bed_id := ShaderMaterial.new()
	bed_id.shader = shale
	bed_id.set_shader_parameter(&"tier_y", plan.tiers[0].height-.002)
	var grass_id := _ink(Color.GREEN)
	var trail_id := _ink(Color.RED)
	var props: Dictionary = {}
	for obj in mountain.get_children():
		if not obj is MeshInstance3D: continue
		var instance := obj as MeshInstance3D
		var mask: Material = null
		match String(obj.name):
			"Turf_and_Ramp_Floors": mask = grass_id
			"Exposed_Bedding": mask = bed_id
			"Dust_and_Worn_Edges": mask = trail_id
		if String(obj.name).begins_with("Handcut_Flagstones"): mask = trail_id
		if mask == null: continue
		props[instance] = instance.material_override
		instance.material_override = mask
	var encoded := await _frame()
	for obj: MeshInstance3D in props: obj.material_override = props[obj]
	var w := field.size.x
	var h := field.size.y
	var role := PackedByteArray()
	var count := PackedInt32Array([0, 0, 0, 0, 0])
	for y in h:
		for x in w:
			var c := encoded.get_pixel(x, y)
			var id := 0
			if c.r > .98 and c.g < .02 and c.b > .98: id = 1
			elif c.r < .02 and c.g > .98 and c.b > .98: id = 2
			elif c.r < .02 and c.g > .98 and c.b < .02: id = 3
			elif c.r > .98 and c.g < .02 and c.b < .02: id = 4
			count[id] += 1
			role.append(id)
	var edges := PackedInt32Array([0, 0, 0]) # lower and upper bedding vs grass, path vs grass
	var contrasted := PackedInt32Array([0, 0, 0])
	for y in h-1:
		for x in w-1:
			var first := role[y*w+x]
			for d in [Vector2i.RIGHT, Vector2i.DOWN]:
				var second := role[(y+d.y)*w+x+d.x]
				if first == second or mini(first,second) == 0 or (first != 3 and second != 3): continue
				var other := second if first == 3 else first
				var sample := 2 if other == 4 else other-1
				var delta := frame.get_pixel(x, y) - frame.get_pixel(x+d.x, y+d.y)
				edges[sample] += 1
				if maxf(absf(delta.r), maxf(absf(delta.g), absf(delta.b))) >= .060:
					contrasted[sample] += 1
	print("%s: both exposed tiers, shelf grass and trail %s px; .06 edge separation %s / %s" % [label, count.slice(1), contrasted, edges])
	for i in range(1, 5):
		check(count[i] >= (75 if w == 320 else 150), "%s: feature %d visible at native size" % [label, i])
	for i in 3:
		check(edges[i] >= 12 and float(contrasted[i]) / maxi(1, edges[i]) >= .24, "%s: material boundary %d not lost in light" % [label, i])
