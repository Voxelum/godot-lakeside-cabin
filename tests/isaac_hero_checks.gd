extends SceneTree
## Native-window proof using the F5 scene, ordinary Walker input, actual meshes,
## scene lights and an isolated slot. Freeze observed poses; never paste sprites.
const MAIN := preload("res://Main.tscn")
const Look := preload("res://art/character_trial/isaac/isaac_look.gd")
const Rig := preload("res://art/character_trial/cast_rig.gd")
const ACTIONS := [&"walk_left", &"walk_right", &"walk_up", &"walk_down"]
const DIRS := ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
var main
var lead: Look
var guest: Look
var passed := 0
var failed := 0
var out := ""
var index := {}
var slot := ""
var body_matte := StandardMaterial3D.new()
var head_matte := StandardMaterial3D.new()

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> bool:
	if ok: passed += 1
	else:
		failed += 1; printerr("ISAAC FAIL: ",label)
	return ok

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not out.is_absolute_path() or DirAccess.dir_exists_absolute(out) or DirAccess.make_dir_recursive_absolute(out) != OK:
		printerr("Use a native window and --output=<new absolute directory>."); quit(2); return
	var token := Crypto.new().generate_random_bytes(16).hex_encode(); slot = "user://isaac_%s.slot" % token
	main = MAIN.instantiate(); main.get_node("Session").slot_path = slot
	main.get_node("BindingPanel").settings_path = "user://isaac_%s.cfg" % token
	root.add_child(main); await _ticks(9)
	var expected := Vector2i(320,180) if "--320" in args else Vector2i(480,270)
	check(root.size == expected and main.field.size == expected and main.room.size == expected,"native window and both buffers")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://Main.tscn" and main.orbit.zoom_step == 4,"F5 entry and default camera")
	lead = main.field_actor.artwork as Look; guest = main.room_actor.artwork as Look
	if not check(lead != null and guest != null and main.active_actor() == main.field_actor,"default F5 look, both Walkers"): _finish(); return
	var body := main.field_actor.get_node("Body") as CollisionShape3D
	check(is_equal_approx(body.shape.height,1.68) and is_equal_approx(body.shape.radius,.31) and not main.field_actor.get_node("Appearance").visible,"original capsule and hidden Courier")
	check(main.get_node("CharacterTrial").companion.profile == &"linnet","original companion")
	var solid := true
	for part: MeshInstance3D in lead.find_children("*","MeshInstance3D",true,false):
		var mat := part.get_active_material(0) as StandardMaterial3D
		var dims := part.mesh.get_aabb().size
		solid = solid and part.mesh is ArrayMesh and dims[dims.min_axis_index()] > .016
		solid = solid and mat != null and mat.albedo_texture == null and mat.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED and mat.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED and part.get_parent() is BoneAttachment3D
	check(ResourceLoader.get_dependencies(Look.MODEL.resource_path).is_empty(),"native scene owns its mesh, material, skeleton and clips; no external art dependencies")
	check(solid and lead.find_children("*","MeshInstance3D",true,false).size()==16 and lead.find_children("*","SpriteBase3D",true,false).is_empty() and lead.rig.get_bone_count()==15,"16 genuine positive-volume meshes on 15 bones; no cards, sprites, or textures")
	for clip in [&"idle", &"walk", &"run"]: check(lead.motion.has_animation(clip) and lead.motion.get_animation(clip).get_track_count() >= 14,"native 3D motion tracks: "+str(clip))
	body_matte.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; body_matte.albedo_color = Color.MAGENTA
	head_matte.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; head_matte.albedo_color = Color.GREEN
	var start: Vector3 = main.field_actor.global_position
	await _capture("spawn",lead)
	# Opposite pairs avoid leaving the birth lane. Check the actual 3D +Z basis.
	for o in [0,4,1,5,2,6,3,7]:
		_axis(_direction(o)); await _ticks(12)
		check(lead.mode == &"walk" and _octant(lead)==o,"walk bearing "+DIRS[o])
		_axis(_direction(o),true); await _ticks(5)
		check(lead.mode == &"run" and _octant(lead)==o,"sprint bearing "+DIRS[o])
		_axis(Vector2.ZERO); await _ticks(8)
		check(lead.mode == &"idle" and _octant(lead)==o,"rest bearing "+DIRS[o])
		await _capture("idle_"+DIRS[o],lead)
	var head := lead.rig.find_bone("Head"); var still := lead.rig.get_bone_pose_rotation(head)
	var rest: Vector3 = main.field_actor.global_position
	await _ticks(132)
	check(still.angle_to(lead.rig.get_bone_pose_rotation(head)) < .009,"reference long initial hold")
	await _ticks(42)
	check(still.angle_to(lead.rig.get_bone_pose_rotation(head)) > .035 and rest.distance_to(main.field_actor.global_position)<.025,"skeletal head turn without moving feet")
	await _capture("idle_shift",lead)
	for tick in 55:
		if lead.motion.current_animation_position >= 3.595: break
		await physics_frame
	check(lead.rig.get_bone_pose_scale(lead.rig.find_bone("Eyes")).y < .37,"actual eye-bone compression during the short blink")
	await _capture("idle_blink",lead)
	await _six(false); await _six(true)
	# Step into the open lane before rotating the live camera, so the cabin's
	# foreground doesn't obscure the rear view. Keep the same pose while orbiting.
	check(await _walk_to(Vector3(-.30,0,10.46)),"walk to orbit station on the native lane")
	_axis(Vector2.DOWN); await _ticks(15); _axis(Vector2.ZERO); await _ticks(10)
	var old_yaw: float = main.orbit.yaw_degrees; var world_basis := lead.facing.global_basis
	var visible_mesh: Mesh = lead.rig.get_node("Head/SweptCrownAndLocks").mesh
	main.field_actor.set_physics_process(false)
	for turn in [0,90,180]:
		main.orbit.yaw_degrees = old_yaw+turn; main.orbit.align_at_subject(); await _ticks(4)
		check(lead.facing.global_basis.is_equal_approx(world_basis) and _octant(lead) == roundi(turn/45.0) and lead.rig.get_node("Head/SweptCrownAndLocks").mesh == visible_mesh,"camera orbit %d: same world-facing geometry" % turn)
		await _capture("orbit_%d" % turn,lead); main.field_actor.set_physics_process(false)
	main.field_actor.set_physics_process(true); main.orbit.yaw_degrees = old_yaw; main.orbit.align_at_subject(); await _ticks(4)
	check(await _walk_to(start),"continuous return to birth lane")
	if not await _cross(): _finish(); return
	check(main.active_actor() == main.room_actor and main.room_actor.artwork == guest,"cabin retains selected rig")
	await _capture("cabin",guest); _key(KEY_F5)
	check(FileAccess.file_exists(slot) and not FileAccess.get_file_as_string(slot).contains("isaac"),"normal F5 save; appearance not persisted")
	if not await _cross(): _finish(); return
	check(main.field_actor.artwork == lead and main.field.get_camera_3d() == main.orbit,"same field actor and world camera on return")
	await _capture("returned",lead); _key(KEY_F9); await _ticks(6)
	check(main.indoors and main.active_actor() == main.room_actor and guest.mode == &"idle","F9 restores cabin actor and idle")
	var cast = main.get_node("CharacterTrial")
	for key in [&"reed", &"linnet"]:
		cast.select_hero(key); await _ticks(2)
		check(main.field_actor.artwork is Rig and main.room_actor.artwork is Rig and main.room_actor.artwork.profile == key and main.field_actor.artwork.profile == key,"both worlds revert to "+str(key))
	cast.select_hero(Look.PROFILE); await _ticks(2)
	check(main.field_actor.artwork is Look and main.room_actor.artwork is Look and main.field_actor.get_node("Body") == body,"reselect without rebuilding Walker or capsule")
	_finish()

func _finish() -> void:
	_axis(Vector2.ZERO)
	var f := FileAccess.open(out.path_join("captures.json"),FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(index,"  ")); f.close()
	if FileAccess.file_exists(slot): check(DirAccess.remove_absolute(slot) == OK,"remove isolated slot")
	print("isaac_hero_checks: %d/%d; %s; %s" % [passed,passed+failed,main.field.size,out]); quit(int(failed != 0))

func _direction(o: int) -> Vector2: return Vector2(-sin(o*PI/4.0),cos(o*PI/4.0))
func _octant(look: Look) -> int:
	var camera := look.get_viewport().get_camera_3d(); var right := camera.global_basis.x.slide(Vector3.UP).normalized(); var f := look.facing.global_basis.z
	return posmod(roundi(atan2(-f.dot(right),f.dot(right.cross(Vector3.UP)))/(PI/4.0)),8)
func _axis(v: Vector2, sprint := false) -> void:
	var amounts := [-v.x,v.x,-v.y,v.y]
	for i in ACTIONS.size():
		if amounts[i] > .001: Input.action_press(ACTIONS[i],amounts[i])
		else: Input.action_release(ACTIONS[i])
	if sprint: Input.action_press(&"sprint")
	else: Input.action_release(&"sprint")
func _world(v: Vector3,sprint := false) -> void:
	var camera: Camera3D = main.active_actor().get_viewport().get_camera_3d(); var right := camera.global_basis.x.slide(Vector3.UP).normalized()
	_axis(Vector2(v.dot(right),v.dot(right.cross(Vector3.UP))),sprint)
func _ticks(n: int) -> void:
	for i in n: await physics_frame
func _key(code: Key) -> void:
	for down in [true,false]:
		var e := InputEventKey.new(); e.pressed = down; e.keycode = code; e.physical_keycode = code
		Input.parse_input_event(e); Input.flush_buffered_events()

func _six(sprint: bool) -> void:
	var mode := &"run" if sprint else &"walk"; var marks := {}; var zs := []
	_axis(_direction(1),sprint)
	# The first steps include a deliberate idle→move crossfade. Measure all
	# six keys after that transition and near the recorded pose times.
	await _ticks(12)
	for i in 110:
		await physics_frame
		if lead.mode != mode or _octant(lead)!=1 or fposmod(lead.phase*6.0,1.0)>.22: continue
		var k := floori(lead.phase*6.0)%6
		if not marks.has(k):
			marks[k] = true; zs.append(lead.rig.get_bone_global_pose(lead.rig.find_bone("FootL")).origin.z)
			await _capture("%s_SW_%d" % [mode,k],lead)
		if marks.size() == 6: break
	check(marks.size() == 6 and zs.max()-zs.min()>(.43 if sprint else .33),"six "+str(mode)+" beats with measurable 3D boot travel")
	_axis(Vector2.ZERO); await _ticks(8)

func _walk_to(target: Vector3) -> bool:
	for i in 250:
		var delta := (target-main.field_actor.global_position as Vector3).slide(Vector3.UP)
		if delta.length() < .07: _axis(Vector2.ZERO); await _ticks(3); return true
		_world(delta.normalized(),true); await physics_frame
	_axis(Vector2.ZERO); return false
func _cross() -> bool:
	var inside: bool = main.indoors; var door: Marker3D = main.room_door if inside else main.field_door
	var beyond := door.global_position+Vector3.BACK*(.4 if inside else -.4)
	for tick in 330:
		if main.crossing: break
		_world((beyond-main.active_actor().global_position as Vector3).slide(Vector3.UP).normalized()); await physics_frame
	if not check(main.crossing,"actually walked across door plane"): _axis(Vector2.ZERO); return false
	_axis(Vector2.ZERO)
	for tick in 340:
		if not main.crossing: break
		await process_frame
	await _ticks(4)
	return check(not main.crossing and main.indoors != inside,"visible world switch completed")

func _grab(vp: SubViewport) -> Image:
	await process_frame; await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()
func _capture(label: String, look: Look) -> void:
	var walker: CharacterBody3D = look.get_parent(); var vp := look.get_viewport() as SubViewport
	walker.set_physics_process(false); main.orbit.set_process(false)
	var image := await _grab(vp); var foot := Vector2i(vp.get_camera_3d().unproject_position(look.global_position).round())
	var pieces := look.find_children("*","MeshInstance3D",true,false)
	for m: MeshInstance3D in pieces: m.material_override = head_matte if m.get_parent().name in [&"Head",&"Eyes"] else body_matte
	var matte := await _grab(vp)
	for m: MeshInstance3D in pieces: m.material_override = null
	var mask := Image.create_empty(vp.size.x,vp.size.y,false,Image.FORMAT_L8); var box := Rect2i(); var skull := Rect2i(); var n := 0
	for y in range(maxi(0,foot.y-90),mini(vp.size.y,foot.y+16)):
		for x in range(maxi(0,foot.x-38),mini(vp.size.x,foot.x+38)):
			var c := matte.get_pixel(x,y); var head := c.g>.93 and c.r<.09 and c.b<.09
			if head or (c.r>.93 and c.b>.93 and c.g<.09):
				var dot := Rect2i(x,y,1,1); box = box.merge(dot) if box.has_area() else dot
				if head: skull = skull.merge(dot) if skull.has_area() else dot
				mask.set_pixel(x,y,Color.WHITE if head else Color(.5,.5,.5)); n += 1
	var ratio := float(skull.size.y)/maxi(1,box.size.y)
	print(label," ",box," head ",snappedf(ratio,.01),"; ",n," pixels; bearing ",DIRS[_octant(look)]," ",look.mode," ",snappedf(look.phase,.01))
	check(n>65 and box.size.x>6 and box.size.y>15 and ratio>.33 and ratio<.74,label+" body and crown visible with depth")
	check(image.get_size()==vp.size and image.save_png(out.path_join(label+".png"))==OK and mask.save_png(out.path_join(label+"-mask.png"))==OK,label+" saved native scene and depth-tested character mask")
	index[label] = {"foot":[foot.x,foot.y],"bounds":[box.position.x,box.position.y,box.size.x,box.size.y],"dir":DIRS[_octant(look)],"phase":look.phase,"head":ratio,"pixels":n}
	walker.set_physics_process(true); main.orbit.set_process(true)
