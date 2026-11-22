extends SceneTree
## With a window: tests the real viewport and keys. Add -- --capture to regenerate the PNGs.
## With --headless: validates packed scenes, clip tracks and motion; no pixel claims.

const ROOT := "res://art/monster_trial/"
const Trial := preload("res://art/monster_trial/monster_trial.gd")
const Stage := preload("res://art/monster_trial/MonsterTrial.tscn")
const ASSETS := ["Slime", "Goblin", "Wolf"]
const ID_COLORS := [Color(1, 0, 1), Color(0, 1, 1), Color(1, 0, 0)]
const ID_PIXELS := [0xff00ffff, 0x00ffffff, 0xff0000ff]
var _checks := 0
var _failures := 0
var _capture := false

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, what: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: ", what)

func _run() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture")
	_assets()
	if DisplayServer.get_name() != "headless":
		await _render()
	elif _capture:
		_expect(false, "PNG capture needs a rendering window")
	print("MONSTER TRIAL: %d checks, %d failures%s" % [_checks, _failures, " (headless, no pixels)" if DisplayServer.get_name() == "headless" else " (GL viewport)"])
	quit(0 if _failures == 0 else 1)

func _assets() -> void:
	for i in ASSETS.size():
		var path: String = ROOT + ASSETS[i] + ".tscn"
		var scene := load(path) as PackedScene
		_expect(scene != null, path)
		if scene == null:
			continue
		_expect(ResourceLoader.get_dependencies(path).is_empty(), ASSETS[i] + " has no external runtime dependencies")
		var actor := scene.instantiate() as Node3D
		root.add_child(actor)
		var player := actor.get_node_or_null("AnimationPlayer") as AnimationPlayer
		_expect(player != null and player.autoplay == &"idle", "AnimationPlayer and idle autoplay")
		if player == null:
			actor.free()
			continue
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var signature: StringName = Trial.ACTIONS[i]
		_expect(player.has_animation(&"RESET"), "RESET pose present")
		var valid := true
		for clip: StringName in [&"idle", &"move", signature]:
			var animation := player.get_animation(clip) if player.has_animation(clip) else null
			var loop_mode := Animation.LOOP_NONE if clip == signature else Animation.LOOP_LINEAR
			var correct := animation != null and animation.length > 0.6 and animation.loop_mode == loop_mode
			_expect(correct, "%s %s exists and has correct looping" % [ASSETS[i], clip])
			valid = valid and correct
			if not correct:
				continue
			var all_tracks_valid := true
			for track in animation.get_track_count():
				all_tracks_valid = all_tracks_valid and actor.has_node(animation.track_get_path(track))
			_expect(all_tracks_valid, "clip tracks address existing pivots")
		_expect(actor.find_children("*", "CollisionObject3D", true, false).is_empty(), "visual-only asset")
		_expect(not actor.find_children("*", "MeshInstance3D", true, false).is_empty(), "editable mesh nodes")
		if not valid:
			actor.free()
			continue
		_poses(i, actor, player, signature)
		var second := scene.instantiate() as Node3D
		root.add_child(second)
		var before: Transform3D = second.get_node("Rig").transform
		_seek(player, signature, 0.55)
		_expect(second.get_node("Rig").transform.is_equal_approx(before), "asset instances have independent pose")
		var finished: Array[StringName] = []
		player.animation_finished.connect(func(id: StringName) -> void: finished.append(id))
		player.stop()
		player.play(signature)
		player.advance(0)
		player.advance(player.get_animation(signature).length + 0.04)
		_expect(finished == [signature], "one-shot emits one animation_finished")
		_expect(actor.transform.is_equal_approx(Transform3D.IDENTITY), "clips leave placement root untouched")
		second.free()
		actor.free()

func _poses(i: int, actor: Node3D, player: AnimationPlayer, signature: StringName) -> void:
	if i == 0:
		var jelly := actor.get_node("Rig") as Node3D
		_seek(player, signature, 0.34)
		var squash := jelly.scale.y
		_seek(player, signature, 0.56)
		var jump := jelly.position.y
		_seek(player, &"move", 0.51)
		var travel_hop := jelly.position.y
		_expect(squash < 0.46 and jump > 0.32 and travel_hop > 0.17, "slime squash, rebound and travelling hop differ")
		print("Slime: squash %.3f, rebound %.3f m, move hop %.3f m" % [squash, jump, travel_hop])
		return
	var soles := actor.find_children("Sole", "Marker3D", true, false)
	var minimum := INF
	var maximum := 0.0
	for f in 51:
		_seek(player, &"move", float(f) / 51.0)
		for node in soles:
			var sole := node as Marker3D
			minimum = minf(sole.global_position.y, minimum)
			maximum = maxf(sole.global_position.y, maximum)
	_expect(soles.size() == (2 if i == 1 else 4) and minimum >= -0.024 and minimum < 0.037 and maximum > 0.093, "locomotion has planted and lifted poses")
	print(ASSETS[i], " move sole range %.4f..%.4f m" % [minimum, maximum])
	var one_shot_minimum := INF
	for f in 51:
		_seek(player, signature, float(f) / 50.0)
		for node in soles:
			var sole := node as Marker3D
			one_shot_minimum = minf(sole.global_position.y, one_shot_minimum)
	_expect(one_shot_minimum >= -0.024, "signature sole markers do not sink below tolerance")
	print(ASSETS[i], " signature lowest sole %.4f m" % one_shot_minimum)
	if i == 1:
		var tip := actor.find_child("Tip", true, false) as Marker3D
		_seek(player, signature, 0.37)
		var drawn := tip.global_position
		_seek(player, signature, 0.56)
		var swung := tip.global_position.distance_to(drawn)
		_expect(swung > 0.65, "feint visibly changes swing silhouette")
		print("Goblin: club tip wind-up to follow-through %.3f m" % swung)
	else:
		var body := actor.get_node("Rig/Body") as Node3D
		_seek(player, signature, 0.37)
		var crouch := body.position.y
		_seek(player, signature, 0.56)
		var apex := body.position.y
		_seek(player, signature, 0.73)
		var reach := body.position.z
		_expect(crouch < 0.53 and apex > 0.86 and reach > 0.48, "wolf crouches, launches and lands forward")
		print("Wolf: body crouch %.3f m, flight %.3f m, forward reach %.3f m" % [crouch, apex, reach])

func _seek(player: AnimationPlayer, id: StringName, p: float) -> void:
	if player.current_animation != id:
		player.play(id)
	player.seek(p * player.get_animation(id).length, true)

func _render() -> void:
	var demo := Stage.instantiate() as Trial
	root.add_child(demo)
	await _keys(demo)
	demo.set_process(false)
	var fresh_phases: Array[float] = [0.09, 0.06, 0.13]
	var windups: Array[float] = [0.34, 0.37, 0.37]
	var apexes: Array[float] = [0.56, 0.56, 0.61]
	demo.set_framing(Trial.PIXELS, Trial.WIDE)
	demo.set_dusk(false)
	demo.set_silhouette(false)
	demo.study_poses(0, fresh_phases)
	_expect(demo.pixels.msaa_3d == Viewport.MSAA_DISABLED and demo.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "same outdoor AA and ortho projection")
	_expect(is_equal_approx(demo.camera.rotation_degrees.x, -36.0) and is_equal_approx(demo.camera.rotation_degrees.y, 30.0), "outdoor camera pitch and yaw")
	var day := await _frame(demo.pixels)
	_expect(day != null and day.get_size() == Trial.PIXELS, "native 480x270 image readback")
	if day == null:
		demo.free()
		return
	var wide_id := await _id_frame(demo)
	var report := _framing(wide_id, "480 day/wide", 190)
	var shapes: Array = report[0]
	_expect(shapes[0].size.y < shapes[1].size.y and shapes[2].size.x > shapes[0].size.x * 1.35, "wide silhouettes separate by height and length, not color")
	_contrast(day, wide_id, await _without_actors(demo), "day 480", 0.09)
	await _captions(demo, day, "480 paper")

	demo.set_framing(Trial.LOW_PIXELS, Trial.WIDE)
	demo.set_dusk(true)
	demo.study_poses(0, fresh_phases)
	var dusk := await _frame(demo.pixels)
	var small_id := await _id_frame(demo)
	_framing(small_id, "320 dusk/wide", 86)
	_contrast(dusk, small_id, await _without_actors(demo), "dusk 320", 0.05)
	await _captions(demo, dusk, "320 paper")
	demo.set_silhouette(true)
	var silhouette := await _frame(demo.pixels)
	var small := Image.create_empty(320, 360, false, Image.FORMAT_RGBA8)
	small.blit_rect(dusk, Rect2i(0, 0, 320, 180), Vector2i.ZERO)
	small.blit_rect(silhouette, Rect2i(0, 0, 320, 180), Vector2i(0, 180))
	demo.set_silhouette(false)
	demo.set_dusk(false)

	demo.set_framing(Trial.PIXELS, Trial.NEAR)
	for j in 9:
		demo.pose_at(1, 4.0 * j / 9.0)
		var lap_image := await _id_frame(demo)
		_framing(lap_image, "near/turn %d" % (j + 1), 375, false)
	demo.study_poses(0, fresh_phases)
	var rest_id := await _id_frame(demo)
	var contact := Image.create_empty(480, 4 * 154, false, Image.FORMAT_RGBA8)
	for row in 4:
		var action_mode := mini(row, 2)
		const TROT_PHASES: Array[float] = [0.47, 0.87, 0.78]
		var pose: Array[float] = [fresh_phases, TROT_PHASES, windups, apexes][row]
		demo.study_poses(action_mode, pose)
		var frame := await _frame(demo.pixels)
		contact.blit_rect(frame, Rect2i(0, 49, 480, 154), Vector2i(0, row * 154))
		if row > 0:
			var ids := await _id_frame(demo)
			_framing(ids, "near/motion row %d" % (row + 1), 395, false)
			var delta := _changes(rest_id, ids)
			print("Near row %d changed silhouette pixels: %s" % [row + 1, delta])
			for diff in delta:
				_expect(diff > 80, "the rendered move or signature alters each silhouette")

	if _capture and _failures == 0:
		_save(day, "01-field-480.png")
		_save(small, "02-dusk-silhouette-320.png")
		_save(contact, "03-action-poses.png")
	demo.free()

func _keys(demo: Trial) -> void:
	await process_frame
	_expect(demo.pixels.size == Trial.PIXELS and is_equal_approx(demo.camera.size, Trial.WIDE), "default camera and pixel preset")
	await _send(KEY_SPACE)
	_expect(demo._paused, "Space pauses the running timeline")
	await _send(KEY_2)
	_expect(demo._mode == 1 and not demo._auto and demo.players[1].current_animation == &"move", "2 selects movement")
	await _send(KEY_3)
	_expect(demo._mode == 2, "3 selects signature")
	await _send(KEY_1)
	_expect(demo._mode == 0 and not demo._auto, "1 returns to idle")
	await _send(KEY_A)
	_expect(demo._mode == 0 and demo._auto, "A enables the relay")
	await _send(KEY_Z)
	_expect(is_equal_approx(demo.camera.size, Trial.NEAR), "Z selects the actual near gear")
	await _send(KEY_R)
	_expect(demo.pixels.size == Trial.LOW_PIXELS, "R selects 320x180")
	var scale := demo.screen.size / Vector2(demo.pixels.size)
	_expect(scale.x == scale.y and scale.x == floorf(scale.x) and demo.screen.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "integer fit and nearest filter")
	await _send(KEY_L)
	_expect(demo._dusk, "L switches to dusk")
	await _send(KEY_V)
	_expect(demo._is_silhouette, "V renders silhouettes")
	# Fixed-stage captures below are unpaused poses; clear the pause mark in the caption.
	await _send(KEY_SPACE)

func _send(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = code
	Input.parse_input_event(release)
	await process_frame

func _frame(view: Viewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := view.get_texture().get_image()
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
	return img

func _without_actors(demo: Trial) -> Image:
	for actor in demo.actors:
		actor.hide()
	var img := await _frame(demo.pixels)
	for actor in demo.actors:
		actor.show()
	return img

func _id_frame(demo: Trial) -> Image:
	var materials: Dictionary = {}
	for i in demo.actors.size():
		var m := StandardMaterial3D.new()
		m.albedo_color = ID_COLORS[i]
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for node in demo.actors[i].find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			materials[mesh] = mesh.material_override
			mesh.material_override = m
	var image := await _frame(demo.pixels)
	for mesh: MeshInstance3D in materials:
		mesh.material_override = materials[mesh]
	return image

func _captions(demo: Trial, ink: Image, mode: String) -> void:
	# Check the actual paper texture and glyph bounds, not only the Control rectangles.
	demo.hud.hide()
	var bare := await _frame(demo.pixels)
	demo.hud.show()
	var viewport_rect := Rect2i(Vector2i.ZERO, ink.get_size())
	var used: Array[Rect2i] = []
	for control in demo.hud.get_children():
		var area := Rect2i((control as Control).get_global_rect())
		if control is Label:
			_expect(viewport_rect.encloses(area), mode + " shortcut legend fits")
			continue
		var label := control.get_child(0) as Label
		var gap: Vector2 = Vector2(area.size) - label.get_combined_minimum_size()
		_expect(viewport_rect.encloses(area) and gap.x >= 6.0 and gap.y >= 2.0, "%s paper caption %s is padded and unclipped (%s, pad=%s)" % [mode, label.text, area, gap])
		if not viewport_rect.encloses(area):
			continue
		var separated := true
		for other in used:
			separated = separated and not area.intersects(other)
		_expect(separated, mode + " paper labels do not touch")
		used.append(area)
		var bands: Array[Rect2i] = [
			Rect2i(area.position, Vector2i(area.size.x, 5)),
			Rect2i(area.position.x, area.end.y - 5, area.size.x, 5),
			Rect2i(area.position, Vector2i(5, area.size.y)),
			Rect2i(area.end.x - 5, area.position.y, 5, area.size.y),
		]
		for band in bands:
			var uncovered := false
			var paper := false
			for y in range(band.position.y, band.end.y):
				for x in range(band.position.x, band.end.x):
					if ink.get_pixel(x, y).is_equal_approx(bare.get_pixel(x, y)):
						uncovered = true
					else:
						paper = true
			_expect(uncovered and paper, "%s %s has a see-through paper edge (%s)" % [mode, label.text, band])

func _framing(ids: Image, label: String, min_area: int, show_log := true) -> Array:
	var areas: Array[int] = [0, 0, 0]
	var bounds: Array[Rect2i] = [Rect2i(), Rect2i(), Rect2i()]
	for y in ids.get_height():
		for x in ids.get_width():
			var i := ID_PIXELS.find(ids.get_pixel(x, y).to_rgba32())
			if i < 0:
				continue
			var pixel := Rect2i(x, y, 1, 1)
			bounds[i] = pixel if areas[i] == 0 else bounds[i].merge(pixel)
			areas[i] += 1
	var safe := Rect2i(Vector2i.ONE * 3, ids.get_size() - Vector2i.ONE * 6)
	for i in 3:
		_expect(areas[i] >= min_area and safe.encloses(bounds[i]), "%s %s silhouette area=%d / %s has margin" % [label, ASSETS[i], areas[i], bounds[i]])
		if i < 2:
			_expect(bounds[i].end.x + 3 < bounds[i + 1].position.x, "%s distinct subjects do not overlap" % label)
	if show_log:
		var dimensions: Array[Vector2i] = [bounds[0].size, bounds[1].size, bounds[2].size]
		print(label, " silhouette widths/heights ", dimensions, "; pixels ", areas)
	return [bounds, areas]

func _contrast(ink: Image, ids: Image, background: Image, label: String, floor_value: float) -> void:
	var total: Array[float] = [0.0, 0.0, 0.0]
	var n: Array[int] = [0, 0, 0]
	for y in ids.get_height():
		for x in ids.get_width():
			var i := ID_PIXELS.find(ids.get_pixel(x, y).to_rgba32())
			if i < 0:
				continue
			var p := ink.get_pixel(x, y)
			var q := background.get_pixel(x, y)
			var d := Vector3(p.r - q.r, p.g - q.g, p.b - q.b)
			total[i] += d.length()
			n[i] += 1
	var means := PackedFloat32Array()
	for i in 3:
		means.append(total[i] / maxi(n[i], 1))
		_expect(means[i] >= floor_value, "%s %s mean RGB contrast %.3f" % [label, ASSETS[i], means[i]])
	print(label, " mean RGB distances ", means)

func _changes(a: Image, b: Image) -> PackedInt32Array:
	var delta := PackedInt32Array([0, 0, 0])
	for y in a.get_height():
		for x in a.get_width():
			var id_a := ID_PIXELS.find(a.get_pixel(x, y).to_rgba32())
			var id_b := ID_PIXELS.find(b.get_pixel(x, y).to_rgba32())
			if id_a != id_b:
				if id_a >= 0:
					delta[id_a] += 1
				if id_b >= 0:
					delta[id_b] += 1
	return delta

func _save(image: Image, leaf: String) -> void:
	var path := ROOT + "previews/" + leaf
	_expect(image.save_png(path) == OK, "save " + path)
	if FileAccess.file_exists(path):
		print("PREVIEW ", path, " ", image.get_size())
