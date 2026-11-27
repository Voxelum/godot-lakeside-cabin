extends SceneTree
## The actual F5 scene, with isolated session/controls paths and a real window.
const MAIN := preload("res://Main.tscn")
const Survey := preload("res://world/outskirts/outskirts_profile.gd")
const Body := preload("res://art/field_cast/field_body.gd")
const ACTIONS := [&"walk_left", &"walk_right", &"walk_up", &"walk_down"]
# These six bodies now live in their farm pens; they still must block the Walker.
const HABITATS := [&"ReedSlime", &"FernGoblin", &"StoneWolf", &"GiantRat", &"SkeletonSentry", &"RootMaw"]
const OLD_NPCS := [&"LakesideCompanion", &"HazelTender", &"WellPotter", &"BakeryRunner"]
const NEW_NPCS := [&"NetMender", &"Lamplighter"]
var main
var actor: CharacterBody3D
var clearing: Node3D
var inhabitants := {}
var count := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	count += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func ticks(n: int) -> void:
	for i in n:
		await physics_frame

func drive(direction: Vector2, fast := false) -> void:
	var right: Vector3 = main.orbit.global_basis.x.slide(Vector3.UP).normalized()
	var dir := Vector3(direction.x, 0, direction.y)
	var x := dir.dot(right)
	var y := dir.dot(right.cross(Vector3.UP))
	var amounts := [-x,x,-y,y]
	for i in 4:
		if amounts[i] > .001: Input.action_press(ACTIONS[i], amounts[i])
		else: Input.action_release(ACTIONS[i])
	if fast: Input.action_press(&"sprint")
	else: Input.action_release(&"sprint")

func ground(p: Vector2) -> Vector3:
	var at := Survey.point(p)
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP*.48, at - Vector3.UP*.34)
	var omit: Array[RID] = [actor.get_rid()]
	for body: Body in inhabitants.values():
		omit.append(body.get_rid())
	query.exclude = omit
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("position", at)

func stage(p: Vector2) -> void:
	actor.global_position = ground(p) + Vector3.UP * .009
	actor.velocity = Vector3.ZERO
	actor.reset_physics_interpolation()

func walk(dest: Vector2, fast := true) -> bool:
	var at := Survey.xz(actor.global_position)
	var limit := ceili(at.distance_to(dest) * 60. / (actor.sprint_speed if fast else actor.walk_speed)) + 75
	for t in limit:
		var remaining := dest - Survey.xz(actor.global_position)
		if remaining.length() < .086:
			drive(Vector2.ZERO)
			return true
		drive(remaining.normalized(), fast)
		await physics_frame
		if main.indoors or main.crossing:
			break
	drive(Vector2.ZERO)
	printerr("Route blocked: ", at, " -> ", dest, " at ", actor.global_position)
	return false

func obstruction(body: Body, fast: bool) -> bool:
	var id := str(body.name)
	var center := Survey.xz(body.global_position)
	var approach := (Survey.nearest_track(center)-center).normalized()
	# Each probe approaches from a free shoulder; the road itself is tested
	# separately by walking the complete itinerary without any fixture jumps.
	if id == "NetMender": approach = Vector2.RIGHT
	if id == "LakesideCompanion": approach = Vector2(-1, .30).normalized()
	if id == "GiantRat": approach = Vector2(-.3,1).normalized()
	if id == "BakeryRunner": approach = Vector2(0,-1)
	if id == "SkeletonSentry": approach = Vector2(-1,.35).normalized()
	var start := center + approach * 1.40
	drive(Vector2.ZERO)
	stage(start)
	await ticks(5)
	var contact := false
	var still_outside := true
	var closest := 3.0
	for i in 92:
		var live := Survey.xz(body.global_position)
		var to_body := live-Survey.xz(actor.global_position)
		closest = minf(closest,to_body.length())
		still_outside = still_outside and to_body.length() > .38
		drive(to_body.normalized(), fast)
		await physics_frame
		for k in actor.get_slide_collision_count():
			var hit := actor.get_slide_collision(k)
			if hit.get_collider() == body and absf(hit.get_normal().y) < .57:
				contact = true
	drive(Vector2.ZERO)
	print("%s %s: contact=%s, closest %.3f m" % [id, "sprint" if fast else "walk", contact, closest])
	return contact and still_outside and not main.indoors and not main.crossing

func _run() -> void:
	if DisplayServer.get_name() == "headless" and not "--fast-debug" in OS.get_cmdline_user_args():
		printerr("Run without --headless for pixel-preset and visibility evidence.")
		quit(2)
		return
	main = MAIN.instantiate()
	var token := Crypto.new().generate_random_bytes(12).hex_encode()
	var slot := "user://field_occupants_%s.slot" % token
	var prefs := "user://field_occupants_%s.cfg" % token
	main.get_node("Session").slot_path = slot
	main.get_node("BindingPanel").settings_path = prefs
	root.add_child(main)
	clearing = main.get_node("Pixels/Clearing")
	actor = main.field_actor
	await ticks(9)
	var target_size := Vector2i(320,180) if "--320" in OS.get_cmdline_user_args() else Vector2i(480,270)
	check(main.field.size == target_size and ProjectSettings.get_setting("application/run/main_scene") == "res://Main.tscn" and main.field.get_camera_3d() == main.orbit, "F5, active follow camera, native pixel preset")
	check(main.field_actor.artwork.profile == &"isaac" and main.room_actor.artwork.profile == &"isaac", "default Isaac appears on both Walkers without changing outdoor occupancy")
	for candidate in get_nodes_in_group(&"field_occupant"):
		inhabitants[candidate.name] = candidate
	for label in HABITATS + OLD_NPCS + NEW_NPCS:
		var body := inhabitants.get(label) as Body
		check(body != null and body.get_world_3d() == actor.get_world_3d(), "%s has a body in the same world" % label)
		if not body: continue
		check(is_instance_valid(body.solid) and body.solid.get_parent() == body and body.solid.shape != null and (body.collision_layer & actor.collision_mask) != 0 and body.find_children("*", "Area3D", true, false).is_empty(), "%s uses a single physical shape, not an area" % label)
	for label in NEW_NPCS + [&"RootMaw"]:
		var unit := inhabitants.get(label) as Body
		if not unit: continue
		var foot := unit.global_position
		var lift := foot.y - ground(Survey.xz(foot)).y
		check(lift >= -.02 and lift < .05, "%s stays at the terrain in its outdoor spot (lift %.3f m)" % [label,lift])
	for i in range(1, Survey.ROUTE.size()):
		var reached := await walk(Survey.ROUTE[i])
		check(reached, "main route outbound station %d" % i)
		if not reached: break
	for i in range(Survey.ROUTE.size()-2, -1, -1):
		var reached := await walk(Survey.ROUTE[i])
		check(reached, "main route return station %d" % i)
		if not reached: break
	if "--route-only" not in OS.get_cmdline_user_args():
		# Isolate collision probes from hostile motion / HP, checked live in farm_checks.
		main.session.farm.set_physics_process(false)
		await _motion_sync()
		await _blocked_patrol()
		for label in HABITATS + OLD_NPCS + NEW_NPCS:
			var body := inhabitants.get(label) as Body
			if not body: continue
			check(await obstruction(body, false), "%s blocks real walk" % label)
			check(await obstruction(body, true), "%s blocks real sprint" % label)
		if DisplayServer.get_name() != "headless": await _render_new()
		await _swap_companion()
	check(not FileAccess.file_exists(slot) and not FileAccess.file_exists(prefs), "no test or player slot/preferences written")
	print("field_occupancy_checks: %d/%d passed · %s · %s" % [count-failures, count, main.field.size, DisplayServer.get_name()])
	quit(int(failures != 0))

func _motion_sync() -> void:
	var before := {}
	var reach := {}
	var normal := {}
	var vertical_min := {}
	var vertical_max := {}
	var last := {}
	var worst_step := {}
	var sync_ok := {}
	var driven := [&"BakeryRunner"] # Farm movers no longer run the old autonomous display timetable.
	for label in driven:
		if not inhabitants.has(label): continue
		var body: Body = inhabitants[label]
		before[label] = Survey.xz(body.global_position)
		last[label] = body.global_position
		normal[label] = body.solid.position
		reach[label] = 0.
		vertical_min[label] = 1.
		vertical_max[label] = 0.
		worst_step[label] = 0.
		sync_ok[label] = true
	for i in 840:
		await physics_frame
		for label in before:
			var body: Body = inhabitants[label]
			var visual := body.get_child(0) as Node3D
			var point := body.global_position
			reach[label] = maxf(reach[label], Survey.xz(point).distance_to(before[label]))
			worst_step[label] = maxf(worst_step[label], point.distance_to(last[label]))
			last[label] = point
			var relative_y := point.y - Survey.surface(Survey.xz(point))
			vertical_min[label] = minf(vertical_min[label],relative_y)
			vertical_max[label] = maxf(vertical_max[label],relative_y)
			sync_ok[label] = sync_ok[label] and (visual.global_position.distance_to(point) < .001) and (body.solid.global_position.distance_to(body.to_global(normal[label])) < .001)
			if label in HABITATS:
				sync_ok[label] = sync_ok[label] and ((visual.get_node("Rig") as Node3D).position.length() < .001)
			if i % 17 == 0:
				var p := body.solid.global_position
				var ray := PhysicsRayQueryParameters3D.create(p + Vector3.RIGHT*1.25, p, 1, [actor.get_rid()])
				var hit := body.get_world_3d().direct_space_state.intersect_ray(ray)
				sync_ok[label] = sync_ok[label] and hit.get("collider") == body
	for label in before:
		check(reach[label] > (.9 if label == &"BakeryRunner" else .34) and worst_step[label] < .073, "%s true displacement %.3f m; max step %.3f m" % [label, reach[label], worst_step[label]])
		check(sync_ok[label], "%s visual root and registered physics shape follow the same motion" % label)
		print("%s: peak match travel %.3f m; relative Y range %.3f–%.3f m; max step %.3f m" % [label, reach[label], vertical_min[label], vertical_max[label], worst_step[label]])
	if vertical_max.has(&"ReedSlime"):
		check(vertical_max[&"ReedSlime"] > .31 and vertical_min[&"ReedSlime"] < .04, "slime body leaves the ground during the visible rebound, then lands")

func _blocked_patrol() -> void:
	var baker := inhabitants.get(&"BakeryRunner") as Body
	if not baker: return
	var cast = main.get_node("CharacterTrial")
	for i in 820:
		if fposmod(cast._elapsed,cast.BAKER_ROUND) < .20: break
		await physics_frame
	var on_its_path := Vector2(32.12,75.605)
	stage(on_its_path)
	var furthest := baker.global_position.x
	var closest := 3.
	for i in 270:
		await physics_frame
		furthest = maxf(furthest,baker.global_position.x)
		closest = minf(closest, absf(actor.global_position.x-baker.global_position.x))
	check(furthest > 31.32 and furthest < 31.83 and closest > .49 and Survey.xz(actor.global_position).distance_to(on_its_path) < .035,
		"runner reaches a real player, stops without ghosting or pushing (x %.3f, gap %.3f)" % [furthest,closest])
	check(await walk(Vector2(32.12,74.54),false), "player can step out of runner's short route")
	await ticks(82)
	check(baker.global_position.x > 33.05, "runner resumes from stopped position and reaches the verge endpoint")

func _swap_companion() -> void:
	var cast = main.get_node("CharacterTrial")
	var old := inhabitants.get(&"LakesideCompanion") as Body
	if not old: return
	var radius := (old.solid.shape as CapsuleShape3D).radius
	cast.select_hero(&"linnet")
	var next := cast.outdoor.get_node("LakesideCompanion") as Body
	check(next != null and next != old and not old.is_inside_tree() and (next.solid.shape as CapsuleShape3D).radius > radius,
		"changing the hero replaces the companion body too; no hidden old collider")
	await ticks(2)
	cast.select_hero(&"isaac")
	await ticks(2)
	var count_named := 0
	for candidate in get_nodes_in_group(&"field_occupant"):
		if candidate.name == &"LakesideCompanion": count_named += 1
	check(main.field_actor.artwork.profile == &"isaac" and count_named == 1, "switching back restores Isaac and leaves exactly one outdoor companion")

func _grab() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return main.field.get_texture().get_image()

func _render_new() -> void:
	# Freeze the actual follow framing from a road point near each actor.
	main.orbit.set_process(false)
	var almanac = clearing.get_node("Almanac")
	almanac.hour = 14.0
	almanac.halted = true
	almanac._advance_sky()
	var matte := StandardMaterial3D.new()
	matte.albedo_color = Color(1,0,1)
	matte.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var resolution: Vector2i = main.field.size
	for label in NEW_NPCS + [&"RootMaw"]:
		var body := inhabitants.get(label) as Body
		if not body: continue
		var visual := body.get_node("Model") as Node3D
		visual.set_physics_process(false)
		if label==&"RootMaw":
			stage(main.session.farm.pens[9].gate-Vector2(0,.65))
		else: stage(Survey.nearest_track(Survey.xz(body.global_position)))
		await ticks(4)
		main.orbit.align_at_subject()
		var real := await _grab()
		visual.hide()
		var empty := await _grab()
		visual.show()
		var parts := visual.find_children("*", "MeshInstance3D", true, false)
		var old: Array[Material] = []
		for part: MeshInstance3D in parts:
			old.append(part.material_override)
			part.material_override = matte
		var marked := await _grab()
		for i in parts.size(): parts[i].material_override = old[i]
		visual.set_physics_process(true)
		var shown := 0
		var contrast := 0
		var hi := Vector2i.ZERO
		var lo := resolution
		for y in resolution.y:
			for x in resolution.x:
				var c := marked.get_pixel(x,y)
				if c.r < .93 or c.g > .07 or c.b < .93: continue
				var xy := Vector2i(x,y)
				shown += 1
				lo = lo.min(xy)
				hi = hi.max(xy)
				var d := real.get_pixel(x,y) - empty.get_pixel(x,y)
				if maxf(absf(d.r),maxf(absf(d.g),absf(d.b))) > .09: contrast += 1
		var extent := hi-lo+Vector2i.ONE
		var ratio := float(contrast)/maxi(1,shown)
		print("%s: %s, %d visible pixels, %.1f%% separated from backdrop" % [label,extent,shown,100.*ratio])
		check(shown >= 49 and extent.x >= 8 and extent.y >= 8 and ratio >= .50, "%s reads from the road with the actual F5 camera/lights" % label)
