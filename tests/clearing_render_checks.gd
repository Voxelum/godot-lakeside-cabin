extends SceneTree
## Render the actual F5 Main/PixelViewport, not a reconstruction of its lighting.
## Windowed: godot --path . --disable-vsync --fixed-fps 60 --script res://tests/clearing_render_checks.gd -- --output=<new directory> [--baseline] [--320]
const MAIN := preload("res://Main.tscn")
const Survey := preload("res://world/outskirts/outskirts_profile.gd")
const VISITS := [
	["village-day", Vector2(12.55,25.25), 14.0],
	["village-dusk", Vector2(12.55,25.25), 18.66667],
	["grade-old", Vector2(16.26,39.42), 14.0],
	["grade-new", Vector2(15.57,40.31), 14.0],
	["town-day", Vector2(30.20,73.98), 14.0],
	["town-dusk", Vector2(30.20,73.98), 18.66667],
]
const ORIGINAL := [
	["spawn", Vector2(-1.15, 6.25), 14.0],
	["bank-day", Vector2(6.7, 3.95), 14.0, Vector3(6.7, .1, 3.95)],
	["bank-dusk", Vector2(6.7, 3.95), 18.66667, Vector3(6.7, .1, 3.95)],
	["lane-old", Vector2(-.45, 10.1), 14.0, Vector3(.28, 1.15, 12.35)],
	["lane-new", Vector2(2.4, 17.45), 14.0, Vector3(3.35, 1.17, 18.55)],
]
var main
var field: SubViewport
var clock: Node
var actor: CharacterBody3D
var orbit: Camera3D
var out := ""
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func grab() -> Image:
	for i in 4:
		await process_frame
		await RenderingServer.frame_post_draw
	return field.get_texture().get_image()

func frame(p: Vector2, height: float, hour: float, focus: Variant = null) -> void:
	actor.global_position = Vector3(p.x, height + .003, p.y)
	actor.velocity = Vector3.ZERO
	actor.reset_physics_interpolation()
	clock.hour = hour
	clock._advance_sky()
	if focus == null:
		orbit.align_at_subject()
	else:
		orbit.aim = focus
		orbit._apply()

func save(label: String, image: Image) -> void:
	if out.is_empty():
		check(image.get_size() == field.size, label + " native frame")
		return
	var path := out.path_join(label + ".png")
	check(image.get_size() == field.size and not FileAccess.file_exists(path) and image.save_png(path) == OK, "save " + path)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("A windowed Godot renderer is required.")
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--output="):
			out = arg.trim_prefix("--output=")
	if (out.is_empty() and not "--checks-only" in args) or (not out.is_empty() and (DirAccess.dir_exists_absolute(out) or DirAccess.make_dir_recursive_absolute(out) != OK)):
		printerr("Provide --checks-only or --output=<new directory> after --; no captures are overwritten.")
		quit(2)
		return
	var token := Crypto.new().generate_random_bytes(16).hex_encode()
	main = MAIN.instantiate()
	main.get_node("Session").slot_path = "user://clearing_render_%s.slot" % token
	main.get_node("BindingPanel").settings_path = "user://clearing_render_%s.cfg" % token
	root.add_child(main)
	field = main.field
	actor = main.field_actor
	orbit = main.orbit
	var clearing: Node3D = field.get_node("Clearing")
	clock = clearing.get_node("Almanac")
	check(not main.indoors and not main.crossing, "fresh Main outdoors")
	for i in 6:
		await physics_frame
	await grab()
	orbit.set_process(false)
	clearing.get_node("ForestLife").set_process(false)
	var spawn: Vector3 = actor.global_position
	for item in ORIGINAL:
		frame(item[1], spawn.y - .003 if item[0] == "spawn" else 0.0, item[2], item[3] if item.size() > 3 else null)
		var image := await grab()
		check(image.get_size() == field.size, item[0] + " native viewport")
		save(item[0], image)
	if not "--baseline" in args:
		var outskirts: Node3D = clearing.get_node("Outskirts")
		for item in VISITS:
			frame(item[1], Survey.surface(item[1]), item[2])
			save(item[0],await grab())
		await _specimens(clearing.get_node("MonsterFarm"))
		await _facades(outskirts.get_node("Lots"))
	print("clearing_render_checks: ", failures, " failures; native ", field.size, "; ", out)
	quit(int(failures != 0))

func _matte() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.MAGENTA
	return m

func _mask_positions(marked: Image) -> PackedVector2Array:
	var points := PackedVector2Array()
	for y in marked.get_height():
		for x in marked.get_width():
			var c := marked.get_pixel(x,y)
			if c.r>.94 and c.g<.08 and c.b>.94:
				points.append(Vector2(x,y))
	return points

func _specimens(farm: Node3D) -> void:
	var names := ["slime","goblin","wolf"]
	var matte := _matte()
	var poses := [.18, .32, .42]
	farm.set_physics_process(false)
	for i in names.size():
		var specimen = farm.pens[i].residents[0].actor
		# The jelly's authored .34 squash is its held anticipation; .42 is the
		# in-between as it crosses its ordinary silhouette on the way up.
		poses[2] = .34 if i==0 else .42
		specimen.set_physics_process(false)
		var model: Node3D = specimen.model
		var parts := model.find_children("*", "MeshInstance3D", true, false)
		var field_inks: Array[Material] = []
		for part: MeshInstance3D in parts:
			field_inks.append(part.material_override)
		var perch: Vector2 = farm.pens[i].gate + Vector2(.66,.49)
		for hour in [14.0,18.66667]:
			var suffix := "day" if hour==14.0 else "dusk"
			frame(perch, Survey.surface(perch), hour)
			var still_pixels := {}
			var signature_change := 0.0
			for j in poses.size():
				specimen.set_display_pose([&"idle", &"move", specimen.signature()][j],poses[j])
				var rendered := await grab()
				if j == 2:
					save(names[i]+"-"+suffix,rendered)
				model.hide()
				var no_model := await grab()
				model.show()
				for part: MeshInstance3D in parts: part.material_override = matte
				var mask := _mask_positions(await grab())
				for k in parts.size(): parts[k].material_override = field_inks[k]
				var bounds := Rect2(mask[0],Vector2.ZERO) if not mask.is_empty() else Rect2()
				var contrasted := 0
				var fore := Vector3.ZERO
				var back := Vector3.ZERO
				for p in mask:
					bounds = bounds.expand(p)
					var x := rendered.get_pixelv(Vector2i(p))
					var y := no_model.get_pixelv(Vector2i(p))
					fore += Vector3(x.r,x.g,x.b)
					back += Vector3(y.r,y.g,y.b)
					var c := x - y
					if maxf(absf(c.r),maxf(absf(c.g),absf(c.b))) >= .09:
						contrasted += 1
				var share := float(contrasted)/maxi(1,mask.size())
				var label: String = "%s %s phase %.2f" % [names[i],suffix,poses[j]]
				if j == 0:
					for p in mask: still_pixels[Vector2i(p)] = true
				elif j == 2:
					var overlap := 0
					for p in mask: overlap += int(still_pixels.has(Vector2i(p)))
					signature_change = 1.0-float(overlap)/maxi(1,mask.size()+still_pixels.size()-overlap)
				var n := maxi(1,mask.size())
				print("%s: %dx%d visible, %d pixels, %.1f%% separated; mean RGB %s vs %s" % [label,int(bounds.size.x)+1,int(bounds.size.y)+1,mask.size(),share*100.0,fore/n,back/n])
				check(mask.size()>=60 and bounds.size.x>=9 and bounds.size.y>=7 and Rect2(6,6,field.size.x-12,field.size.y-12).encloses(bounds),label+" in frame with a readable footprint")
				check(share>=.54,label+" not lost against its actual backdrop")
			check(signature_change>=.14,"%s %s signature shifts %.1f%% of its mask union"%[names[i],suffix,signature_change*100.0])

func _facades(lots: Node3D) -> void:
	var matte := _matte()
	for i in lots.get_child_count():
		var lot = lots.get_child(i)
		var where: Vector2 = VISITS[0 if i<3 else 4][1]
		if lot.name == &"Blacksmith" or String(lot.lot_id).begins_with("clearing.market_court."):
			var approach: Marker3D = lot.marker("Approach")
			# Test the road serving this lot: the later Inn/Guild cannot be seen
			# through the first row of houses from the old Stone Street station.
			where = Survey.nearest_on(Survey.xz(approach.global_position),Survey.ROUTE if lot.name==&"Blacksmith" else Survey.MARKET_ROUTE)
		frame(where,Survey.surface(where),14.0)
		lot.mesh_view.material_override = matte
		var mask := _mask_positions(await grab())
		lot.mesh_view.material_override = null
		print("facade ",lot.name,": ",mask.size()," visible pixels")
		check(mask.size()>=495,"building readable from the actual lane: "+lot.name)
