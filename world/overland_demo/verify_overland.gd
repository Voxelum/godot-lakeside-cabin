extends SceneTree
## Real window by default. --capture saves new native pixels; --perf has no
## readbacks or synthetic fixed FPS. Headless checks only movement and setup.
const Demo := preload("res://world/overland_demo/overland_demo.gd")
const Trail := preload("res://world/overland_demo/overland_map.gd")
const Kit := preload("res://art/building_trial/trial_site.gd")
const Site := preload("res://world/overland_demo/integrated_site.gd")
const Specimen := preload("res://world/overland_demo/specimen.gd")
const SCENE := preload("res://world/overland_demo/Overland.tscn")
const ACTIONS := [&"walk_left", &"walk_right", &"walk_up", &"walk_down", &"sprint"]
const PREVIEWS := "res://world/overland_demo/previews"
const BAY_ROAD_INDEXES := [4, 6, 9]
const BAY_FILES := ["03-slime.png", "04-goblin.png", "05-wolf.png"]
const MASK := Color("ff08f7")
const APEX := [.46, .56, .57]

var demo: Demo
var checks := 0
var failures := 0
var _actor: int
var _space: RID
var _min_floor := 0.0
var _max_step := 0.0
var _last_foot := Vector3.ZERO
var _captures: Dictionary[String, Image] = {}
var _render := false
var _measure := false
var _intervals := PackedFloat64Array()
var _last_usec := 0
var _draw_counts := PackedInt32Array()
var _matched_frames := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_render = DisplayServer.get_name() != "headless"
	var flags := OS.get_cmdline_user_args()
	var perf := "--perf" in flags
	var capture := "--capture" in flags
	if not _render and (perf or capture) or perf and capture:
		printerr("--capture and --perf are separate real-window runs")
		quit(2)
		return
	root.size = Vector2i(960, 540)
	if perf:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	var start := Time.get_ticks_usec()
	demo = SCENE.instantiate() as Demo
	root.add_child(demo)
	print("Scene mount (scene already preloaded, before first render): %.1f ms; %s; GPU %s" % [(Time.get_ticks_usec() - start) / 1000.0, DisplayServer.get_name(), RenderingServer.get_video_adapter_name()])
	await _tick(24)
	_actor = demo.player.get_instance_id()
	_space = demo.pixels.find_world_3d().space
	_last_foot = demo.player.global_position
	demo.player.stepped.connect(_observe)
	_expect(demo.pixels.get_camera_3d() == demo.camera and demo.map.village.get_node_or_null("Camera") == null and demo.map.town.get_node_or_null("Air") == null, "one shared camera/environment")
	_expect(demo.map.village.get_world_3d().space == _space and demo.map.town.get_world_3d().space == _space and demo.map.specimens.size() == 3, "both sites and all three models resident at spawn")
	_expect(demo.player.is_on_floor(), "Walker lands on shared floor")
	var path := demo.map.centerline()
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	print("Centerline %.2f m; %s m terrain" % [length, Trail.BOUNDS.size])
	if perf:
		process_frame.connect(_frame_sample)
		_measure = true
		await _follow(path, "perf start to end")
		_measure = false
		_report_perf()
	else:
		await _input_check()
		await _journey()
		path.reverse()
		await _follow(path, "walk back to cottage")
		_expect(demo.zone == 0, "guide returns to start")
	_expect(_min_floor >= -.035 and _max_step < .113 and _matched_frames > 300, "no discontinuous position changes or drop through shared floor (min y %.3f, max stride %.3f, %d physics frames)" % [_min_floor, _max_step, _matched_frames])
	_expect(demo.player.get_instance_id() == _actor and demo.pixels.find_world_3d().space == _space, "same Walker and World3D at finish")
	if capture and failures == 0:
		_save()
	print("Overland: %d / %d checks passed (%s)." % [checks - failures, checks, "window" if _render else "headless"])
	quit(0 if failures == 0 else 1)

func _input_check() -> void:
	var right := demo.camera.global_basis.x.slide(Vector3.UP).normalized()
	var before := demo.player.global_position
	_key(KEY_D, true)
	await _tick(18)
	_key(KEY_D, false)
	await _tick(2)
	_expect((demo.player.global_position - before).dot(right) > .4, "physical D event moves Walker to screen-right")
	_expect(await _walk(before, .11), "walk back to start after input check")
	_key(KEY_V, true)
	await process_frame
	_key(KEY_V, false)
	await process_frame
	_expect(demo.pixels.size == Demo.LOW and demo.screen.size == Vector2(960, 540), "V switches to native 320×180, 3× nearest display")
	_key(KEY_V, true)
	await process_frame
	_key(KEY_V, false)
	await process_frame
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(480, 270)
	Input.parse_input_event(wheel)
	await process_frame
	_expect(demo.camera.zoom_step == 3 and is_equal_approx(demo.camera.size, 10.85), "mouse wheel reuses orbit zoom")
	wheel = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = Vector2(480, 270)
	Input.parse_input_event(wheel)
	await process_frame
	_expect(demo.pixels.size == Demo.FULL and is_equal_approx(demo.camera.size, 13.4) and demo.screen.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "walking view restored to 480×270 and 13.4 m")

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _journey() -> void:
	if _render:
		await _store("01-cottage.png")
	var cottage := demo.map.get_node("Cottage")
	var landing: Vector3 = cottage.get_node("DoorAnchor").global_position
	var porch := landing + Vector3(0, 0, .35)
	_expect(await _walk(landing + Vector3(0, 0, 1.0), .13), "walk off trail to the cabin porch")
	_expect(await _walk(porch, .10), "cabin step accessible")
	var inside := landing - Vector3(0, 0, .74)
	_expect(not await _walk(inside, .10, false, 52), "cabin door remains a closed exterior, no transfer or pass-through")
	_expect(await _walk(Trail.point(Trail.WEST_PATH[2]), .13), "walk back from cabin porch")
	await _follow([Trail.WEST_PATH[3], Trail.VILLAGE_AT + Kit.LANE[0]], "cottage/village seam")
	await _settlement(demo.map.village, Trail.VILLAGE_AT, Kit.LANE, "02-village.png", 3)
	for i in range(1, Trail.FOREST_PATH.size() - 1):
		var p: Vector2 = Trail.FOREST_PATH[i]
		_expect(await _walk(Trail.point(p), .16, true), "forest path waypoint %d" % i)
		var bay_i := BAY_ROAD_INDEXES.find(i)
		if bay_i < 0:
			continue
		_expect(await _walk(Trail.point(Trail.VIEWING[bay_i]), .15), "enter gravel viewing bay %d" % bay_i)
		if _render:
			await _specimen_view(bay_i)
		_expect(await _walk(Trail.point(p), .15), "walk back from viewing bay %d" % bay_i)
	await _follow([Trail.TOWN_AT + Kit.STREET[0]], "forest/town seam")
	await _settlement(demo.map.town, Trail.TOWN_AT, Kit.STREET, "06-town.png", 3)
	_expect(await _walk(Trail.point(Trail.RETURN_MARK), .13, true), "reach eastern amber route end")
	_expect(demo.zone == 3 and demo.route_hint.text.contains("终点"), "end sign and route hint agree")
	_expect(not await _walk(Vector3(79, 0, 0), .11, true, 183) and demo.player.global_position.x <= 77.72 and demo.player.global_position.x > 77.0, "visible eastern fence stops sprinting Walker")
	_expect(await _walk(Trail.point(Trail.RETURN_MARK), .13, true), "turn at boundary without teleporting")

func _settlement(site: Site, at: Vector2, road: Array, screenshot: String, shot_index: int) -> void:
	for i in range(1, road.size()):
		var p: Vector2 = road[i]
		if site.setting == 1 and p.x > 15.0:
			break
		_expect(await _walk(Trail.point(at + p), .15, true), "%s main street waypoint %d" % [site.name, i])
		if i == shot_index and _render:
			await _store(screenshot)
		if i == 2 and site.setting == 1:
			for entry: Vector2 in Kit.ALLEY:
				_expect(await _walk(Trail.point(at + entry), .15, true), "town alley inbound %s" % entry)
			for j in range(Kit.ALLEY.size() - 2, -1, -1):
				var entry: Vector2 = Kit.ALLEY[j]
				_expect(await _walk(Trail.point(at + entry), .15, true), "town alley outbound %s" % entry)
			_expect(await _walk(Trail.point(at + p), .15), "alley rejoins town street")
		for lot in site.lots():
			var link := site.road_link(lot).global_position
			var nearest := 0
			for j in road.size():
				var a: Vector2 = road[j]
				var b: Vector2 = road[nearest]
				if absf(a.x + at.x - link.x) < absf(b.x + at.x - link.x):
					nearest = j
			if i != nearest:
				continue
			var approach := lot.marker("Approach").global_position
			var landing := lot.marker("Landing").global_position
			var door := lot.marker("DoorAnchor")
			var walk := await _walk(link, .09)
			walk = (await _walk(approach, .062)) and walk
			walk = (await _walk(landing, .054)) and walk
			_expect(walk and absf(demo.player.global_position.y - lot.threshold_rise) < .028 and demo.player.is_on_floor(), "%s landing acccessible from route (y %.3f)" % [lot.name, demo.player.global_position.y])
			_expect(not await _walk(door.global_position - door.global_basis.z * .63, .09, false, 54), "%s closed exterior blocks Walker" % lot.name)
			walk = await _walk(approach, .078)
			walk = (await _walk(link, .102)) and walk
			_expect(walk and absf(demo.player.global_position.y) < .028, "%s back down to the road" % lot.name)
			_expect(await _walk(Trail.point(at + p), .15), "%s branch rejoined" % lot.name)
	_expect(demo.zone == (1 if site.setting == 0 else 3), "%s shown in paper guide" % site.name)

func _observe(_before: Vector3, after: Vector3) -> void:
	_min_floor = minf(_min_floor, after.y)
	_max_step = maxf(_max_step, _last_foot.distance_to(after))
	_last_foot = after
	_matched_frames += 1

func _follow(points: Array, label: String) -> void:
	var passed := true
	for item: Vector2 in points:
		var reached := await _walk(Trail.point(item), .16, true)
		if not reached:
			printerr("Blocked while following %s at %s, expected %s" % [label, demo.player.global_position, item])
		passed = reached and passed
	_expect(passed and demo.player.is_on_floor(), label)

func _walk(target: Vector3, tolerance: float, sprint := false, max_ticks := 0) -> bool:
	var start := (target - demo.player.global_position).slide(Vector3.UP).length()
	var ticks := max_ticks if max_ticks > 0 else ceili(start * 60.0 / (4.1 if sprint else 2.45)) + 48
	var right := demo.camera.global_basis.x.slide(Vector3.UP).normalized()
	var down := right.cross(Vector3.UP)
	if sprint:
		Input.action_press(&"sprint")
	for i in ticks:
		var offset := (target - demo.player.global_position).slide(Vector3.UP)
		if offset.length() <= tolerance:
			_release()
			await _tick(2)
			return true
		var axes := Vector2(offset.dot(right), offset.dot(down)).normalized()
		var values := Vector4(-axes.x, axes.x, -axes.y, axes.y)
		for j in 4:
			if values[j] > 0.0:
				Input.action_press(ACTIONS[j], values[j])
			else:
				Input.action_release(ACTIONS[j])
		await physics_frame
	_release()
	await _tick(2)
	return false

func _release() -> void:
	for action in ACTIONS:
		Input.action_release(action)

func _tick(n: int) -> void:
	for i in n:
		await physics_frame

func _frame_sample() -> void:
	if not _measure:
		return
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		_intervals.append((now - _last_usec) / 1000.0)
	_draw_counts.append(demo.pixels.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
	_last_usec = now

func _report_perf() -> void:
	var total := 0.0
	for ms in _intervals:
		total += ms
	_intervals.sort()
	_draw_counts.sort()
	var n := _intervals.size()
	_expect(n > 300 and total > 10000.0, "nontrivial real-time window sample")
	if n == 0:
		return
	print("PERF: %d frames / %.2fs; %.1f mean FPS; p50 %.2f ms / p95 %.2f / p99 %.2f / max %.2f; visible viewport draw calls min %d / p50 %d / max %d" % [n, total / 1000.0, n * 1000.0 / total, _intervals[n / 2], _intervals[ceili(n * .95) - 1], _intervals[ceili(n * .99) - 1], _intervals[-1], _draw_counts[0], _draw_counts[_draw_counts.size() / 2], _draw_counts[-1]])

func _specimen_view(i: int) -> void:
	var stop := demo.map.specimens[i]
	stop.set_process(false)
	var peak := float(APEX[i]) * stop.animator.get_animation(stop.signature).length
	for size_value: Vector2i in [Demo.FULL, Demo.LOW]:
		demo.set_pixels(size_value)
		stop.pose_at(.71)
		var rest := await _mask(stop)
		stop.pose_at(Specimen.LAP_START + .31)
		var move := await _mask(stop)
		_expect(stop.animator.current_animation == &"move", "%s patrol animation plays" % stop.name)
		stop.pose_at(Specimen.SIGNATURE_START + peak)
		var action := await _mask(stop)
		_expect(stop.animator.current_animation == stop.signature, "%s signature animation plays" % stop.name)
		var visible := Rect2i(Vector2i(3, 3), size_value - Vector2i(6, 6))
		var enough := 160 if size_value == Demo.FULL else 72
		var rest_rect: Rect2i = rest[0]
		var move_rect: Rect2i = move[0]
		var action_rect: Rect2i = action[0]
		print("Mask %s %d: idle %s/%d px, walk %s/%d px, signature %s/%d px" % [stop.name, size_value.x, rest_rect.size, rest[1], move_rect.size, move[1], action_rect.size, action[1]])
		_expect(rest[1] >= enough and action[1] >= enough and move[1] >= enough and visible.encloses(rest_rect) and visible.encloses(move_rect) and visible.encloses(action_rect), "%s remains in frame and has a substantial rendered silhouette at %s" % [stop.name, size_value])
		_expect(_change(rest[2], action[2]) > enough / 3, "%s signature changes its rendered silhouette" % stop.name)
		await _contrast(stop, action[2], size_value.x)
		_expect(demo.tags[i].visible and Rect2(Vector2.ZERO, Vector2(size_value)).encloses(demo.tags[i].get_rect()), "%s label fits under actor at %d" % [stop.name, size_value.x])
		if size_value == Demo.FULL:
			await _store(BAY_FILES[i])
	demo.set_pixels(Demo.FULL)
	stop.set_process(true)

func _contrast(stop: Specimen, mask: Dictionary, width: int) -> void:
	var visible := await _grab()
	stop.model.hide()
	var bare := await _grab()
	stop.model.show()
	var distinct := 0
	for p: Vector2i in mask:
		var a := visible.get_pixelv(p)
		var b := bare.get_pixelv(p)
		var channel_difference := maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
		distinct += int(channel_difference >= .12)
	print("Contrast %s %d: %d / %d signature pixels differ by >= .12 in at least one sRGB channel" % [stop.name, width, distinct, mask.size()])
	_expect(distinct >= mask.size() * .65 and distinct > 0, "%s has contrast against the real gravel backdrop" % stop.name)

func _change(a: Dictionary, b: Dictionary) -> int:
	var count := 0
	for p in a:
		count += int(not b.has(p))
	for p in b:
		count += int(not a.has(p))
	return count

func _mask(stop: Specimen) -> Array:
	var original := {}
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = MASK
	for mesh: MeshInstance3D in stop.model.find_children("*", "MeshInstance3D", true, false):
		original[mesh] = mesh.material_override
		mesh.material_override = paint
	var img := await _grab()
	var bounds := Rect2i()
	var set_pixels := {}
	for y in img.get_height():
		for x in img.get_width():
			var color := img.get_pixel(x, y)
			if color.r > .93 and color.g < .08 and color.b > .9:
				var p := Vector2i(x, y)
				var unit := Rect2i(p, Vector2i.ONE)
				bounds = bounds.merge(unit) if not set_pixels.is_empty() else unit
				set_pixels[p] = true
	for mesh: MeshInstance3D in original:
		mesh.material_override = original[mesh]
	return [bounds, set_pixels.size(), set_pixels]

func _grab() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return demo.pixels.get_texture().get_image()

func _store(filename: String) -> void:
	var image := await _grab()
	var count := {}
	for y in range(0, image.get_height(), 7):
		for x in range(0, image.get_width(), 7):
			count[image.get_pixel(x, y).to_rgba32()] = true
	_expect(image.get_size() == demo.pixels.size and count.size() > 70, "%s native rendered window buffer is nonblank" % filename)
	_captures[filename] = image

func _save() -> void:
	var dir := ProjectSettings.globalize_path(PREVIEWS)
	_expect(DirAccess.make_dir_recursive_absolute(dir) == OK, "can create capture directory")
	for f: String in _captures:
		var file := dir.path_join(f)
		if not FileAccess.file_exists(file):
			_expect(_captures[f].save_png(file) == OK, "saved " + f)

func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", label)
