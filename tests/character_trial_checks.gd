extends SceneTree
## Native-window proof against Main (F5). Inject the ordinary actions, use an
## isolated slot, and save the real Pixels buffer with its normal follow camera.
const MAIN := preload("res://Main.tscn")
const Rig := preload("res://art/character_trial/cast_rig.gd")
const Survey := preload("res://world/outskirts/outskirts_profile.gd")
const Dir := preload("res://art/character_trial/cast_director.gd")
const ACTIONS := [&"walk_left", &"walk_right", &"walk_up", &"walk_down"]
var main
var actor: CharacterBody3D
var lead: Rig
var cast: Dir
var field: SubViewport
var orbit: Camera3D
var sky
var slot: String
var out := ""
var passed := 0
var failed := 0
var matte := StandardMaterial3D.new()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var legacy := "--legacy-cast" in args
	for arg in args:
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=")
	if not legacy and (DisplayServer.get_name() == "headless" or out.is_empty() or DirAccess.dir_exists_absolute(out) or DirAccess.make_dir_recursive_absolute(out) != OK):
		printerr("Need windowed Main and --output=<new absolute directory>.")
		quit(2)
		return
	var token := Crypto.new().generate_random_bytes(16).hex_encode()
	slot = "user://cast_check_%s.slot" % token
	main = MAIN.instantiate()
	main.get_node("Session").slot_path = slot
	main.get_node("BindingPanel").settings_path = "user://cast_check_%s.cfg" % token
	# This rig/gait fixture explicitly opts into Reed; default F5 is Isaac.
	main.get_node("CharacterTrial").player_look = 0
	root.add_child(main)
	actor = main.field_actor
	cast = main.get_node("CharacterTrial")
	field = main.field
	orbit = main.orbit
	sky = field.get_node("Clearing/Almanac")
	await _ticks(8)
	if legacy:
		check(actor.get("artwork") == actor.get_node("Appearance") and actor.get_node("Appearance").visible and cast.outdoor == null,"legacy flag restores original art and removes the sample townsfolk")
		check(main.room_actor.artwork == main.room_actor.get_node("Appearance"),"legacy flag applies inside too")
		_finish()
		return
	var expected := Vector2i(320,180) if "--320" in args else Vector2i(480,270)
	check(field.size == expected and root.size == expected,"native window and viewport match %s; window is %s" % [expected,root.size])
	lead = actor.get("artwork") as Rig
	var wanted := &"linnet" if "--hero=linnet" in args else &"reed"
	if not check(lead != null and lead.profile == wanted,"F5 selected player look: "+wanted):
		_finish()
		return
	check(main.room_actor.artwork.profile == wanted and not main.room_actor.get_node("Appearance").visible,"same look in the original cabin actor")
	var body := actor.get_node("Body").shape as CapsuleShape3D
	check(body != null and is_equal_approx(body.height,1.68) and is_equal_approx(body.radius,.31) and not actor.get_node("Appearance").visible,"same CapsuleShape3D; legacy art still present but hidden")
	check(not main.indoors and not main.crossing and Survey.xz(actor.global_position).distance_to(Survey.ROUTE[0]) < .02,"original spawn and active outdoor world")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://Main.tscn" and field.get_camera_3d() == orbit and orbit.zoom_step == 4 and is_equal_approx(orbit.pitch_degrees,36.0),"configured F5 entry and unmodified default camera")
	check(cast.companion.profile != wanted and cast.companion.get_world_3d() == actor.get_world_3d(),"other protagonist already in the scene")
	var locals := cast.outdoor.find_children("*", "CharacterBody3D", true, false)
	var solid := locals.size() == 4
	for local_body: CharacterBody3D in locals:
		var shape := local_body.get_node_or_null("SolidBody") as CollisionShape3D
		solid = solid and local_body.is_in_group(&"field_occupant") and shape != null and shape.shape is CapsuleShape3D and (local_body.collision_layer & actor.collision_mask) != 0
	check(solid and cast.outdoor.find_children("*", "Area3D", true, false).is_empty(),"each townsfolk rig has a physical capsule and no attack Area3D")
	matte.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	matte.cull_mode = BaseMaterial3D.CULL_DISABLED
	matte.albedo_color = Color.MAGENTA
	var idle := await _sample("01-hero-idle",lead)
	await _sample("02-companion",cast.companion)
	var still := actor.global_position
	check(await _wait_mode(lead,&"gesture"),"an uninterrupted idle reaches the signature pose")
	await _ticks(8) # Photograph the held pose, after anticipation.
	var gesture := await _sample("03-hero-pose",lead)
	check(actor.global_position.distance_to(still) < .02 and _difference(idle,gesture) >= .11,"gesture changes silhouette without moving gameplay feet")
	var down := (Survey.ROUTE[2]-Survey.ROUTE[0]).normalized()
	var walk := await _move_sample("04-hero-walk",down,false,.68)
	var run := await _move_sample("05-hero-run",down,true,.80)
	print("Foot-aligned mask changes: idle-pose %.1f%%; idle-walk %.1f%%; walk-run %.1f%%" % [_difference(idle,gesture)*100.0,_difference(idle,walk)*100.0,_difference(walk,run)*100.0])
	check(_difference(idle,walk) >= .15 and _difference(walk,run) >= .15,"native silhouette distinguishes idle/walk/run")
	await _ticks(12)
	check(lead.mode == &"idle" and is_zero_approx(lead.phase),"neutral settles without gait advance")
	check(await _walk(Survey.ROUTE[3]),"continued along the original stone lane")
	for pair: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2(1,1).normalized(), Vector2(1,-1).normalized()]:
		for k: float in [1.0,-1.0]:
			_axis(pair*k,false)
			await _ticks(12)
			var right := orbit.global_basis.x.slide(Vector3.UP).normalized()
			var desired := (right*pair.x+right.cross(Vector3.UP)*pair.y)*k
			var heading: Vector3 = lead.get_node("Facing").global_basis.z
			check(lead.mode == &"walk" and heading.dot(desired) > .98,"camera-relative visible heading %s" % [pair*k])
	_drive(Vector2.ZERO)
	await _ticks(4)
	var saved_point := actor.global_position
	check(not FileAccess.file_exists(slot),"appearance and ordinary walking do not auto-save")
	_key(KEY_F5)
	check(FileAccess.file_exists(slot) and not FileAccess.get_file_as_string(slot).contains("\"appearance\""),"ordinary F5 saves, no trial-appearance field")
	_drive(down)
	await _ticks(18)
	_drive(Vector2.ZERO)
	_key(KEY_F9)
	await _ticks(6)
	check(actor.global_position.distance_to(saved_point) < .03 and actor.get("artwork") == lead and lead.mode == &"idle","ordinary F9 restores same actor, world feet and selected appearance")
	if "--full-route" in args: await _settlements()
	_finish()

func _settlements() -> void:
	for i in range(4,Survey.ROUTE.size()):
		if not check(await _walk(Survey.ROUTE[i]),"continuous Walker arrival at lane station %d" % i): return
		if i == 8:
			check(_on_ground(cast.tender),"tender's soles at the surveyed shoulder")
			check(await _wait_mode(cast.tender,&"gesture"),"hazel tender's weight shift")
			await _sample("06-village-tender",cast.tender)
		if i == 10:
			check(_on_ground(cast.potter),"potter's soles on the well verge")
			check(await _wait_mode(cast.potter,&"gesture"),"well potter tips the jug")
			await _sample("07-village-potter",cast.potter)
			sky.handle_key(KEY_3)
			await _sample("08-village-dusk",cast.potter)
			sky.handle_key(KEY_1)
	check(not main.indoors and not main.crossing and main.active_actor() == actor,"original continuous F5 world through to bakery")
	check(await _wait_mode(cast.baker,&"idle",820),"bakery runner rests on the verge")
	check(_on_ground(cast.baker),"bakery runner stays on native terrain")
	await _sample("09-town-idle",cast.baker)
	check(await _wait_mode(cast.baker,&"walk",820),"bakery runner walks the short errand")
	await _ticks(16)
	await _sample("10-town-walk",cast.baker)
	check(await _wait_mode(cast.baker,&"run",820),"bakery runner sprints back")
	await _ticks(16)
	await _sample("11-town-run",cast.baker)

func check(ok: bool, label: String) -> bool:
	if ok: passed += 1
	else:
		failed += 1
		printerr("FAIL: ",label)
	return ok

func _finish() -> void:
	if FileAccess.file_exists(slot): check(DirAccess.remove_absolute(slot) == OK,"remove this run's isolated slot")
	print("character_trial_checks: %d/%d; native %s; %s" % [passed,passed+failed,field.size,out])
	quit(int(failed != 0))

func _drive(dir: Vector2, fast := false) -> void:
	var right := orbit.global_basis.x.slide(Vector3.UP).normalized()
	var heading := Vector3(dir.x,0,dir.y)
	_axis(Vector2(heading.dot(right),heading.dot(right.cross(Vector3.UP))),fast)

func _axis(v: Vector2, fast: bool) -> void:
	var amounts := [-v.x,v.x,-v.y,v.y]
	for i in ACTIONS.size():
		if amounts[i] > .001: Input.action_press(ACTIONS[i],amounts[i])
		else: Input.action_release(ACTIONS[i])
	if fast: Input.action_press(&"sprint")
	else: Input.action_release(&"sprint")

func _ticks(n: int) -> void:
	for i in n: await physics_frame

func _key(code: Key) -> void:
	for down in [true,false]:
		var e := InputEventKey.new()
		e.pressed = down; e.keycode = code; e.physical_keycode = code
		Input.parse_input_event(e)
		Input.flush_buffered_events()

func _walk(at: Vector2) -> bool:
	var limit := 130+ceili(Survey.xz(actor.global_position).distance_to(at)*60.0/4.1)
	for i in limit:
		var delta := at-Survey.xz(actor.global_position)
		if delta.length() < .087:
			_drive(Vector2.ZERO)
			return true
		_drive(delta.normalized(),true)
		await physics_frame
	_drive(Vector2.ZERO)
	return false

func _wait_mode(model: Rig, part: StringName, frames := 560) -> bool:
	for i in frames:
		await physics_frame
		if model.mode == part: return true
	return false

func _move_sample(label: String, dir: Vector2, sprint: bool, target: float) -> Dictionary:
	var start := actor.global_position
	var frames := 0
	var steps := {}
	var mode := &"run" if sprint else &"walk"
	_drive(dir,sprint)
	while frames < 50:
		await physics_frame
		frames += 1
		if lead.mode == mode: steps[floori(6.0*lead.phase)] = true
		if frames >= 22 and steps.size() >= 5 and absf(lead.phase-target) <= .075: break
	var metres := (actor.global_position-start).slide(Vector3.UP).length()
	var speed := metres*60.0/maxf(1,frames)
	print(label," speed ",snappedf(speed,.001),"m/s; phase ",snappedf(lead.phase,.001),"; pose sectors ",steps.size())
	check(lead.mode == mode and steps.size() >= 5 and absf(speed-(4.1 if sprint else 2.45)) < .19,label+" follows ordinary XY input, speed and pose cadence")
	var image := await _sample(label,lead)
	_drive(Vector2.ZERO)
	return image

func _on_ground(model: Rig) -> bool:
	var foot := model.global_position
	var ray := PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.15,foot-Vector3.UP*.18)
	ray.exclude = [actor.get_rid(), (model.get_parent() as CharacterBody3D).get_rid()]
	var result := model.get_world_3d().direct_space_state.intersect_ray(ray)
	return not result.is_empty() and absf(foot.y-result.position.y) <= .05

func _grab() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return field.get_texture().get_image()

func _sample(label: String, model: Rig) -> Dictionary:
	# Freeze a frame, not the camera design. Tint only the selected rig to
	# measure pixels that are actually visible after world occlusion and depth.
	actor.set_physics_process(false)
	cast.set_physics_process(false)
	orbit.set_process(false)
	var view := await _grab()
	var path := out.path_join(label+".png")
	check(view.get_size() == field.size and not FileAccess.file_exists(path) and view.save_png(path)==OK,label+" saved at native size")
	model.hide()
	var backdrop := await _grab()
	model.show()
	var origin := Vector2i(orbit.unproject_position(model.global_position).round())
	var points := _points(await _mark(model),origin)
	var dims := _bounds(points)
	var pixels := {}
	var distinguished := 0
	for p in points:
		pixels[p-origin] = true
		var delta := view.get_pixelv(p)-backdrop.get_pixelv(p)
		if maxf(absf(delta.r),maxf(absf(delta.g),absf(delta.b))) >= .09: distinguished += 1
	var fraction := float(distinguished)/maxf(1,pixels.size())
	print(label,": ",dims.size," ",pixels.size()," px; backdrop-separated ",snappedf(100.0*fraction,.1),"%; foot at ",origin,", bbox ",dims.position)
	var small := field.size.x == 320
	check(dims.size.x >= (7 if small else 10) and dims.size.y >= (13 if small else 19) and Rect2i(Vector2i.ONE*3,field.size-Vector2i.ONE*6).encloses(dims),label+" in frame with character-scale silhouette")
	check(fraction >= .57,label+" separated from the rendered backdrop")
	if label in ["01-hero-idle","02-companion"]:
		var skull := model.get_node("Facing/Waist/Chest/Head") as Node3D
		var skull_bounds := _bounds(_points(await _mark(skull,skull.get_node_or_null("LowPlait")),origin))
		var heads := float(skull_bounds.size.y)/maxf(1,dims.size.y)
		print("  head with crown, excluding hanging plait: ",skull_bounds.size," = ",snappedf(heads*100.0,.1),"% of height")
		check(heads >= .34 and heads <= .55,label+" enlarged compact head mass")
	actor.set_physics_process(true)
	cast.set_physics_process(true)
	orbit.set_process(true)
	return pixels

func _mark(root_part: Node3D, omit: Node3D = null) -> Image:
	var painted: Array[MeshInstance3D] = []
	var original: Array[Material] = []
	for mesh: MeshInstance3D in root_part.find_children("*","MeshInstance3D",true,false):
		if omit != null and omit.is_ancestor_of(mesh): continue
		painted.append(mesh)
		original.append(mesh.material_override)
		mesh.material_override = matte
	var image := await _grab()
	for i in painted.size(): painted[i].material_override = original[i]
	return image

func _points(mask: Image, origin: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for y in range(maxi(0,origin.y-86),mini(field.size.y,origin.y+31)):
		for x in range(maxi(0,origin.x-52),mini(field.size.x,origin.x+52)):
			var ink := mask.get_pixel(x,y)
			if ink.r>.94 and ink.g<.08 and ink.b>.94: points.append(Vector2i(x,y))
	return points

func _bounds(points: Array[Vector2i]) -> Rect2i:
	var box := Rect2i()
	for p in points:
		var next := Rect2i(p,Vector2i.ONE)
		box = next if not box.has_area() else box.merge(next)
	return box

func _difference(a: Dictionary, b: Dictionary) -> float:
	var overlap := 0
	for p in a:
		if b.has(p): overlap += 1
	return 1.0-float(overlap)/maxf(1,a.size()+b.size()-overlap)
