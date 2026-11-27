extends SceneTree
## Use the real F5 entry, Traveler and camera-relative input. Optional
## -- --alternate=<baked SplitSpur.tscn> swaps just the mountain for this test.
const MAIN := preload("res://Main.tscn")
const Survey := preload("res://world/outskirts/outskirts_profile.gd")
const Ridge := preload("res://source/mountain/ridge_mesh.gd")
const DEFAULT := preload("res://source/mountain/fern_fold.tres")
const OTHER := preload("res://source/mountain/split_spur.tres")
const MOVE := [&"walk_left", &"walk_right", &"walk_up", &"walk_down"]
var main
var actor: CharacterBody3D
var mountain: StaticBody3D
var plan := DEFAULT
var ridge := Ridge.new()
var slot := ""
var failures := 0
var checks := 0
var airborne := 0
var walking_ticks := 0
var max_step := 0.0
var on_same_map := true

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func ticks(n: int) -> void:
	for i in n: await physics_frame

func drive(direction: Vector2, fast := false) -> void:
	var right: Vector3 = main.orbit.global_basis.x.slide(Vector3.UP).normalized()
	var flat := Vector3(direction.x, 0, direction.y)
	var axis := Vector2(flat.dot(right), flat.dot(right.cross(Vector3.UP)))
	var amounts := [-axis.x, axis.x, -axis.y, axis.y]
	for i in MOVE.size():
		if amounts[i] > .001: Input.action_press(MOVE[i], amounts[i])
		else: Input.action_release(MOVE[i])
	if fast: Input.action_press(&"sprint")
	else: Input.action_release(&"sprint")

func walk(to: Vector2, fast: bool) -> bool:
	var speed: float = actor.sprint_speed if fast else actor.walk_speed
	var budget := ceili(to.distance_to(Survey.xz(actor.position)) * 60.0 / speed) + 85
	for i in budget:
		var from := actor.position
		var delta := to - Survey.xz(from)
		if delta.length() < .073:
			drive(Vector2.ZERO)
			return true
		drive(delta.normalized(), fast)
		await physics_frame
		walking_ticks += 1
		airborne += int(not actor.is_on_floor())
		max_step = maxf(max_step, from.distance_to(actor.position))
		on_same_map = on_same_map and not main.indoors and not main.crossing and main.active_actor() == actor and not actor.locked
	drive(Vector2.ZERO)
	printerr("stuck going to ", to, " from ", actor.position)
	return false

func action_event(event: InputEvent) -> void:
	for pressed: bool in [true, false]:
		var edge := event.duplicate() as InputEvent
		edge.pressed = pressed
		Input.parse_input_event(edge)
		Input.flush_buffered_events()

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	action_event(event)

func _run() -> void:
	var alternate := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--alternate="): alternate = arg.trim_prefix("--alternate=")
	var token := Crypto.new().generate_random_bytes(16).hex_encode()
	slot = "user://mountain_route_%s.slot" % token
	main = MAIN.instantiate()
	main.get_node("Session").slot_path = slot
	main.get_node("BindingPanel").settings_path = "user://mountain_route_%s.cfg" % token
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
	actor = main.field_actor
	await ticks(7)
	check(ridge.build(plan).is_empty(), "valid mountain profile")
	_ground_checks()
	check(Survey.xz(actor.position).distance_to(Survey.ROUTE[0]) < .002 and actor.is_on_floor(), "original dry spawn")
	var take := InputEventKey.new()
	take.keycode = KEY_F
	take.physical_keycode = KEY_F
	var state = main.session.state
	var expected_bag: Dictionary = state.inventory.duplicate()
	expected_bag["item.sample"] = int(expected_bag.get("item.sample",0))+1
	action_event(take)
	check(state.inventory == expected_bag, "original pickup still works alongside starting equipment")
	var exhausted := [state.remaining("bank.sample_a", 1), state.remaining("bank.sample_b", 1)]
	var finished := await _round_trip()
	check(finished and Survey.xz(actor.position).distance_to(Survey.ROUTE[0]) < .075, "original spawn to summit and back under Walker input")
	check(on_same_map and state.location_id == "place.clearing", "same outdoor actor and place, no door or reset")
	check(airborne <= 2 and max_step < .115, "continuous footing (including both directions over the toe)")
	check(state.inventory == expected_bag and exhausted == [state.remaining("bank.sample_a", 1), state.remaining("bank.sample_b", 1)],
		"load preserves the original inventory and depleted source")
	# These independent wall probes seed the starting position only. The climb,
	# descent and return above never teleport except the actual F9 restore.
	await _cliff_probe(0, 54.0)
	await _cliff_probe(1, 25.0)
	if FileAccess.file_exists(slot):
		check(DirAccess.remove_absolute(slot) == OK, "remove own scratch save")
	print("mountain_checks: %d/%d; native %s; airborne %d/%d; max stride %.4f m" % [
		checks-failures, checks, main.field.size, airborne, walking_ticks, max_step])
	quit(int(failures != 0))

func _ground_checks() -> void:
	var shape: ConcavePolygonShape3D = mountain.get_node("Dry_Relief_Collision").shape
	var grass: MeshInstance3D = mountain.get_node("Turf_and_Ramp_Floors")
	var rock: MeshInstance3D = mountain.get_node("Exposed_Bedding")
	check(mountain.position.is_equal_approx(plan.origin) and actor.get_world_3d() == mountain.get_world_3d(), "bake in original field World3D")
	check(ridge.faces == shape.get_faces(), "baked collider matches the seeded loft triangle-for-triangle")
	check(grass.mesh.get_faces().size() + rock.mesh.get_faces().size() == ridge.faces.size(), "one rendered triangle per dry collision triangle")
	var seam := 0.0
	for i in Survey.MOUNTAIN_VERGE.size()-1:
		for j in 17:
			var p: Vector2 = Survey.MOUNTAIN_VERGE[i].lerp(Survey.MOUNTAIN_VERGE[i+1], j / 16.0)
			seam = maxf(seam, ridge.height_at(p - Survey.xz(plan.origin)))
	check(seam < .035, "existing-style verge stays in flat ground (max rise %.3f m)" % seam)
	var count := 0
	var error := 0.0
	for i in plan.trail.size() - 1:
		for j in 9:
			var p := plan.trail[i].lerp(plan.trail[i+1], j / 9.0)
			p += (plan.trail[i+1] - plan.trail[i]).normalized().orthogonal() * .23
			var world := p + Survey.xz(plan.origin)
			var y := ridge.height_at(p)
			if y <= .01: continue
			var ray := PhysicsRayQueryParameters3D.create(Vector3(world.x, y + .5, world.y), Vector3(world.x, y - .35, world.y))
			ray.exclude = [actor.get_rid()]
			var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or hit.collider != mountain: error = INF
			else: error = maxf(error, absf(hit.position.y - y))
			count += 1
	check(count > 70 and error < .005, "ramp/shelf samples use the same height as the baked visible grade (n=%d, max %.5f m)" % [count, error])

func _round_trip() -> bool:
	for i in range(1, 7):
		if not await walk(Survey.ROUTE[i], true): return false
	var offset := Survey.xz(plan.origin)
	for i in plan.trail.size():
		if not await walk(offset + plan.trail[i], i < 7 or i >= 14): return false
		if i in [8, 12, 19]:
			print("trail station %d: rooted %.3f m (soil %.3f m)" % [i, actor.position.y, ridge.height_at(plan.trail[i])])
			check(actor.is_on_floor(), "grounded at station %d" % i)
	await ticks(4)
	var saved := actor.position
	check(absf(saved.y - plan.tiers[-1].height) < .022, "not just halfway: reached the summit shelf")
	check(not FileAccess.file_exists(slot), "walking does not auto-save")
	key(KEY_F5)
	check(FileAccess.file_exists(slot), "F5 saves at summit")
	if not await walk(offset + plan.trail[-4], false): return false
	check(actor.position.distance_to(saved) > 2.0, "moved away before reloading")
	key(KEY_F9)
	await ticks(5)
	check(actor.position.distance_to(saved) < .025 and actor.is_on_floor(), "F9 restores elevated feet and collision")
	for i in range(plan.trail.size()-2, -1, -1):
		if not await walk(offset + plan.trail[i], true): return false
	for i in range(6, -1, -1):
		if not await walk(Survey.ROUTE[i], true): return false
	return true

func _cliff_probe(tier_index: int, bearing: float) -> void:
	var tier = plan.tiers[tier_index]
	var angle := deg_to_rad(bearing)
	var dir := Vector2.from_angle(angle)
	var section: Vector3 = tier.section(angle, 0.0)
	var start := dir * (section.x + section.y + .69)
	var low: float = 0.0 if tier_index == 0 else plan.tiers[tier_index-1].height
	var p := start + Survey.xz(plan.origin)
	actor.position = Vector3(p.x, low + .005, p.y)
	actor.reset_physics_interpolation()
	actor.velocity = Vector3.ZERO
	await ticks(8)
	check(absf(actor.position.y-low) < .025 and actor.is_on_floor(), "on the lower side of scarp %d" % tier_index)
	var hit_scarp := false
	var peak := actor.position.y
	var top_contact := 0.0
	for i in 58:
		drive(-dir, true)
		await physics_frame
		peak = maxf(peak, actor.position.y)
		for j in actor.get_slide_collision_count():
			var hit := actor.get_slide_collision(j)
			if hit.get_collider() == mountain and hit.get_collider_shape() == mountain.get_node("Dry_Relief_Collision") and hit.get_normal().y < .707:
				hit_scarp = true
				top_contact = maxf(top_contact, hit.get_normal().y)
	drive(Vector2.ZERO)
	var advance := (p - Survey.xz(actor.position)).dot(dir)
	print("scarp %d: sprint reached %.3f m beyond start; peak %.3f m above foot; blocking normal up %.3f" % [tier_index, advance, peak-low, top_contact])
	check(hit_scarp and peak-low < .22 and advance < 1.33, "visible rock scarp %d actually blocks Walker from below" % tier_index)
