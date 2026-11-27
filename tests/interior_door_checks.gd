extends SceneTree
## Run with a real renderer, once at each pixel preset (default and -- --320).
const MainScene := preload("res://Main.tscn")
const Catalog := preload("res://world/interiors/room_catalog.gd")
var main
var session
var failures := 0
# Representative visual/physical silhouettes for each zone, followed by a
# traversable path from the door to the far-side working or living space.
const EXPECTED := {
	"place.smith_stock": [["ToolRack", "IronRack1", "MaterialBins", "ReceivingBench"], [Vector2(.0, .48), Vector2(.0, -1.09), Vector2(1.35, -1.09)]],
	"place.hay_barn": [["HayBale3", "Grain1", "GranaryShelf", "EastStockShelf"], [Vector2(0, .42), Vector2(0, -1.79), Vector2(0, .40), Vector2(.91, .40)]],
	"place.lime_house": [["Cot1", "BootBench", "SeedWorkbench", "DiningTable1"], [Vector2(-1.52, .43), Vector2(-1.52, -1.48)]],
	"place.orchard_house": [["Cot1", "Screen", "ProduceBin", "SortingBench"], [Vector2(.72, 1.45), Vector2(.68, .15), Vector2(-.72, .15), Vector2(-.72, -1.04), Vector2(.87, -1.25)]],
	# The two genuine lofts also have their own stair routes in copper_loft_walk_checks.gd.
	"place.sill_house": [["DiningTable1", "DiningChair1", "DiningChair2", "VisitorSeat"], [Vector2(-.32, 1.36), Vector2(.22, 1.15), Vector2(.22, -.78)]],
	"place.bakery": [["ShopCounter1", "DisplayHutch", "Oven", "PrepBench"], [Vector2(1.53, 1.49), Vector2(-.72, 1.49), Vector2(-.72, -.54), Vector2(.75, -.54)]],
}
const BLOCKERS := {
	"place.smith_stock": "MaterialBins", "place.hay_barn": "Grain1",
	"place.lime_house": "DiningTable1", "place.orchard_house": "Cot1",
	"place.sill_house": "DiningTable1", "place.bakery": "ShopCounter1",
}
const State := preload("res://scripts/foundation/world_state.gd")
var expected_size: Vector2i
var capture_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func ticks(n: int) -> void:
	for i in n: await physics_frame

func steer(world: Vector3) -> void:
	var right: Vector3 = main.active_actor().get_viewport().get_camera_3d().global_basis.x.slide(Vector3.UP).normalized()
	var axis := Vector2(world.dot(right), world.dot(right.cross(Vector3.UP)))
	var actions := [&"walk_left", &"walk_right", &"walk_up", &"walk_down"]
	var amount := [-axis.x, axis.x, -axis.y, axis.y]
	for i in actions.size():
		if amount[i] > .001: Input.action_press(actions[i], amount[i])
		else: Input.action_release(actions[i])

func walk(to: Vector3, limit: int, stop_at_door: bool) -> bool:
	for i in limit:
		if main.crossing: break
		var offset: Vector3 = (to - main.active_actor().global_position).slide(Vector3.UP)
		if offset.length() < .085: break
		steer(offset.normalized())
		await physics_frame
	steer(Vector3.ZERO)
	if stop_at_door: return main.crossing
	return not main.crossing and (to - main.active_actor().global_position).slide(Vector3.UP).length() < .13

func check_hinge_approach(lot: Node3D, label: String) -> void:
	var door := Catalog.outdoor_door(lot)
	var hinge := Catalog.outdoor_hinge(lot)
	var near := door.to_global(Vector3(0, 0, .54))
	check(await walk(near, 105, false), label + " stopped on the landing without a transition")
	await ticks(16)
	check(not main.indoors and not main.crossing and hinge.is_clear(), label + " proximity opens the door without switching worlds")
	for leaf: Node3D in hinge.get_children():
		check(is_equal_approx(leaf.rotation.y, float(leaf.get_meta("swing")) * PI * .5), label + " actual hinged leaf turns inward")

func cross(to: Vector3, label: String) -> bool:
	if not await walk(to, 180, true):
		check(false, label + " could not walk through threshold at %s (goal %s)" % [main.active_actor().global_position, to])
		return false
	var phases := {}
	var locked := true
	var black := true
	var prior_slot := FileAccess.get_sha256(session.slot_path) if FileAccess.file_exists(session.slot_path) else ""
	while main.crossing:
		phases[main.shutter_phase] = true
		locked = locked and main.field_actor.locked and main.room_actor.locked
		if String(main.shutter_phase).begins_with("black_"):
			black = black and is_zero_approx(main.iris_radius) and main.shutter.get_shader_parameter(&"shutter") == true
		await process_frame
	check(locked and black and phases.has_all(["close", "black_source", "black_destination", "open"]), label + " used the existing rendered shutter")
	var after_slot := FileAccess.get_sha256(session.slot_path) if FileAccess.file_exists(session.slot_path) else ""
	check(after_slot == prior_slot, label + " did not autosave")
	await ticks(4)
	return true

func frame() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return main.room.get_texture().get_image()

func capture(id: String) -> void:
	var image := await frame()
	check(not image.is_empty() and image.get_size() == expected_size, id + " rendered native frame")
	if not image.is_empty():
		check(image.get_pixel(0, 0).get_luminance() < .015, id + " actually rendered black around the room")
	if not capture_dir.is_empty():
		var path := capture_dir.path_join(id.trim_prefix("place.") + ".png")
		check(not FileAccess.file_exists(path) and image.save_png(path) == OK, id + " saved native screenshot")

func verify_furnishings(id: String, furnishings: Node3D, names: Array, ray_height := 2.45) -> void:
	var space: PhysicsDirectSpaceState3D = main.room.find_world_3d().direct_space_state
	var colors := [Color.MAGENTA, Color.CYAN, Color.GREEN, Color.RED]
	var originals := {}
	for i in names.size():
		var item := furnishings.get_node(names[i]) as Node3D
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(item.global_position + Vector3.UP * ray_height, item.global_position + Vector3.UP * .12))
		check(hit.has("collider") and item.is_ancestor_of(hit["collider"]), id + " static furniture footprint: " + item.name)
		# An ID-only draw measures the visible silhouette in the actual game
		# camera, including walls, props and Guest occluding it. Never save it.
		var ink := StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.albedo_color = colors[i]
		for child in item.find_children("*", "MeshInstance3D", true, false):
			var mesh := child as MeshInstance3D
			originals[mesh] = mesh.material_override
			mesh.material_override = ink
	var mask := await frame()
	for mesh: MeshInstance3D in originals:
		mesh.material_override = originals[mesh]
	var counts := PackedInt32Array([0, 0, 0, 0])
	for y in mask.get_height():
		for x in mask.get_width():
			var sample := mask.get_pixel(x, y)
			if sample.r > .95 and sample.g < .05 and sample.b > .95: counts[0] += 1
			elif sample.r < .05 and sample.g > .95 and sample.b > .95: counts[1] += 1
			elif sample.r < .05 and sample.g > .95 and sample.b < .05: counts[2] += 1
			elif sample.r > .95 and sample.g < .05 and sample.b < .05: counts[3] += 1
	for i in names.size():
		check(counts[i] >= (55 if expected_size.x == 320 else 110), "%s %s visible: %s px" % [id, names[i], counts[i]])
	print(id, " 路 ", expected_size, " 路 silhouette px ", counts, " ", names)

func _check_walk(to: Vector3, id: String) -> void:
	var reached := await walk(to, 170, false)
	check(reached, "%s lane %s stopped at %s" % [id, to, main.room_actor.global_position])

func verify_blocker(id: String, item: Node3D) -> void:
	var guest: CharacterBody3D = main.room_actor
	var contacted := false
	for i in 95:
		var offset := (item.global_position - guest.global_position).slide(Vector3.UP)
		if offset.length() < .09: break
		steer(offset.normalized())
		await physics_frame
		for j in guest.get_slide_collision_count():
			contacted = contacted or item.is_ancestor_of(guest.get_slide_collision(j).get_collider())
	steer(Vector3.ZERO)
	check(contacted and (item.global_position - guest.global_position).slide(Vector3.UP).length() > .22, id + " real Walker stopped against " + item.name)

func check_framing(id: String) -> void:
	var structure: Node3D = main.building_structure()
	var camera: Camera3D = main.room.get_camera_3d()
	var safe := Rect2(Vector2(3, 3), Vector2(expected_size) - Vector2(6, 6))
	var art := structure.get_node("GroundCutaway") as MeshInstance3D
	var bounds := Rect2(camera.unproject_position(art.global_position), Vector2.ZERO)
	var pieces: Array[MeshInstance3D] = [art]
	for side in art.get_children():
		var full := side.get_node("Full") as MeshInstance3D
		pieces.append(full if full.visible else side.get_node("Section") as MeshInstance3D)
	for piece in pieces:
		for i in piece.mesh.get_surface_count():
			var vertices: PackedVector3Array = piece.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				bounds = bounds.expand(camera.unproject_position(piece.to_global(vertex)))
	check(safe.encloses(bounds), "%s entire visible ground geometry in camera: %s / %s" % [id, bounds, safe])

func check_direction(id: String, outer: Marker3D) -> void:
	var inner: Marker3D = main.room_door
	var eye: Vector3 = main.room_actor.artwork.get_node("Facing").global_basis.z
	var camera: Camera3D = main.room.get_camera_3d()
	var a: Vector3 = outer.global_basis.inverse()*main.field.get_camera_3d().global_basis.x
	var b := inner.global_basis.inverse()*camera.global_basis.x
	check(eye.dot(-inner.global_basis.z) > .998, id + " Guest looks inward after shutter opens and neutral input resumes")
	check(a.is_equal_approx(b), id + " exact building-local camera-right / walking axes on both sides")
	for side in main.building_structure().get_node("GroundCutaway").get_children():
		var normal: Vector3 = side.get_meta("normal")
		var expected := normal.dot(camera.global_basis.z) > .0001 * camera.global_basis.z.slide(Vector3.UP).length()
		check(side.get_node("Section").visible == expected and side.get_node("Full").visible != expected, id + " camera-facing wall is a section: " + side.name)

func hotkey(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await process_frame

func legacy_loads(id: String, snapshot: Dictionary) -> void:
	var binary := var_to_bytes(snapshot)
	for version in [1,2,3]:
		var old := snapshot.duplicate(true)
		old.version = version
		old.position = Vector3(3.21, 0, -3.27) # old oversized room or stale revision
		if version < 3: old.erase("building_revision")
		else: old.building_revision = "0".repeat(64)
		if version == 1: old.erase("player_stats")
		var f := FileAccess.open(session.slot_path, FileAccess.WRITE)
		f.store_buffer(var_to_bytes(old))
		f.close()
		await hotkey(KEY_F9)
		check(main.place_id() == id and main.room_actor.global_position.distance_to(main.room_entry.global_position) < .02 and session.state.inventory == snapshot.inventory and session.state.remaining("interior.fixture",2) == 0,id+" safe legacy/stale load and shared changes (v%d)" % version)
	var f := FileAccess.open(session.slot_path, FileAccess.WRITE)
	f.store_buffer(binary)
	f.close()

func check_display_fit() -> void:
	var screen := main.get_node("Screen") as TextureRect
	var base := Vector2(expected_size)
	var original_size: Vector2 = main.size
	check(main.field.size == expected_size, "display uses the selected native pixel buffer")
	verify_display_fit(screen, base * minf(original_size.x / base.x, original_size.y / base.y), "launch fit")
	# Resize the composer, not the OS window, so fullscreen and desktop size
	# cannot mask either scale. Exercise both limiting axes via resized.
	main.size = base * 2.0 + Vector2(0, 40)
	verify_display_fit(screen, base * 2.0, "integer fit (2x)")
	main.size = base * 1.5 + Vector2(40, 0)
	verify_display_fit(screen, base * 1.5, "fractional fit (1.5x)")
	main.size = original_size

func verify_display_fit(screen: TextureRect, fitted_size: Vector2, label: String) -> void:
	check(screen.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, label + " uses nearest-neighbour filtering")
	check(screen.size.is_equal_approx(fitted_size), label + " fills the limiting axis without stretching")
	check(Rect2(Vector2.ZERO, main.size).grow(0.01).encloses(screen.get_rect()), label + " does not crop")
	check(screen.position.is_equal_approx((main.size - screen.size) * 0.5), label + " is centered")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Door checks require a rendered Godot window")
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	expected_size = Vector2i(320, 180) if "--320" in args else Vector2i(480, 270)
	var only := ""
	for arg in args:
		if arg.begins_with("--capture="):
			capture_dir = ProjectSettings.globalize_path(arg.trim_prefix("--capture="))
		if arg.begins_with("--only="):
			only = "place." + arg.trim_prefix("--only=")
	if not capture_dir.is_empty() and not DirAccess.dir_exists_absolute(capture_dir):
		if DirAccess.make_dir_recursive_absolute(capture_dir) != OK:
			push_error("Unable to create screenshot destination: " + capture_dir)
			quit(2)
			return
	main = MainScene.instantiate()
	session = main.get_node("Session")
	var token := Crypto.new().generate_random_bytes(12).hex_encode()
	session.slot_path = "user://interior-door-" + token + ".slot"
	main.get_node("BindingPanel").settings_path = "user://interior-door-" + token + ".cfg"
	root.add_child(main)
	await ticks(4)
	check_display_fit()
	var guest = main.room_actor
	var state = session.state
	state.take_stack("interior.fixture", "item.sample", 2)
	for id: String in EXPECTED:
		if not only.is_empty() and id != only: continue
		var lot := Catalog.outdoor_lot(main.get_node("Pixels/Clearing"), id)
		var door := Catalog.outdoor_door(lot)
		var approach := Catalog.outdoor_return(lot)
		check(door != null and approach != null, id + " outdoor anchors")
		if door == null or approach == null: continue
		# Fixture starts at the route's outdoor approach, then actual Walker input
		# handles the slope, doors, shutter, room lane and return.
		main.show_place(false, approach.global_position, true)
		main.sync_control(true)
		await ticks(8)
		await check_hinge_approach(lot, id)
		if not await cross(door.to_global(Vector3(0,0,-.36)), id + " enter"): continue
		check(main.indoors and main.place_id() == id and state.location_id == id, id + " arrived in the correct room")
		check(main.room_actor == guest, id + " kept Guest and its artwork")
		check(main.room.get_camera_3d() == main.get_node("RoomPixels/Interior/Camera"), id + " mounted the destination camera")
		check(main.room_actor.global_position.distance_to(main.room_entry.global_position) < .10, id + " landed at the interior entry")
		var structure: Node3D = main.building_structure()
		check(main.room_entry.get_parent() == structure and main.room_door.get_parent() == structure and main.room_actor.is_on_floor(), id + " matching generated indoor anchors supported on ground")
		check(main.room.size == expected_size and main.get_node("Screen").texture == main.room.get_texture(), id + " is the active native gameplay viewport")
		check_direction(id, door)
		check_framing(id)
		await capture(id)
		var furnishing := main.get_node("RoomPixels/Interior/Furnishing") as Node3D
		await verify_furnishings(id, furnishing, EXPECTED[id][0], 1.65 if id == "place.sill_house" else 2.45)
		# Enter zones and return by the same trace; the last point is also the
		# source of the precision save/load position (not just the threshold).
		var route: Array = EXPECTED[id][1]
		for step: Vector2 in route:
			await _check_walk(Vector3(step.x, 0, step.y), id)
		await ticks(7)
		var saved: Vector3 = main.room_actor.global_position
		await hotkey(KEY_F5)
		var snapshot: Variant = bytes_to_var(FileAccess.get_file_as_bytes(session.slot_path)) if FileAccess.file_exists(session.slot_path) else null
		check(snapshot is Dictionary and snapshot.version == State.BUILDING_VERSION and snapshot.location_id == id and snapshot.building_revision == structure.get_meta("building_revision") and snapshot.position.distance_to(structure.to_local(saved)) < .018, id + " F5 stored tagged local feet in an isolated slot")
		await verify_blocker(id, furnishing.get_node(BLOCKERS[id]) as Node3D)
		await _check_walk(saved, id)
		for i in range(route.size()-2, -1, -1):
			var step: Vector2 = route[i]
			await _check_walk(Vector3(step.x, 0, step.y), id)
		await _check_walk(main.room_entry.global_position, id)
		if not await cross(main.room_door.to_global(Vector3(0, 0, .45)), id + " exit"): continue
		check(not main.indoors and state.location_id == Catalog.FIELD, id + " returned outdoors")
		check(main.field_actor.global_position.distance_to(approach.global_position) < .16, id + " returned to its own approach")
		check(main.field_actor.artwork.get_node("Facing").global_basis.z.dot(door.global_basis.z) > .998, id + " outside arrival looks away from the door")
		main.restore_place(Catalog.CABIN, Vector3.ZERO)
		await hotkey(KEY_F9)
		check(main.indoors and main.place_id() == id and session.state == state, id + " F9 restored after a different room was mounted")
		check(main.room_actor.global_position.distance_to(saved) < .02 and state.inventory.get("item.sample") == 2, id + " preserved saved feet and shared state")
		if snapshot is Dictionary: await legacy_loads(id,snapshot)
		await ticks(4)
		print(id, " 路 ", main.room.size)
	if not only.is_empty():
		_finish()
		return
	# The last slot belongs to the bakery. Verify startup, not only an F9
	# read on a live coordinator whose previous room could still be cached.
	main.queue_free()
	await process_frame
	main = MainScene.instantiate()
	session = main.get_node("Session")
	session.slot_path = "user://interior-door-" + token + ".slot"
	main.get_node("BindingPanel").settings_path = "user://interior-door-" + token + ".cfg"
	root.add_child(main)
	await ticks(4)
	check(main.indoors and main.place_id() == "place.bakery" and session.state.inventory.get("item.sample") == 2, "fresh Main restores the bakery slot")
	var bakery := Catalog.outdoor_lot(main.get_node("Pixels/Clearing"), "place.bakery")
	var old_field: Variant = bytes_to_var(FileAccess.get_file_as_bytes(session.slot_path))
	if old_field is Dictionary:
		old_field.erase("building_revision")
		old_field.version = 2
		old_field.location_id = Catalog.FIELD
		# Walkable behind the old 3.61-m shell, now within the new 4.33-m shell.
		old_field.position = bakery.to_global(Vector3(.21,.005,-2.14))
		var f := FileAccess.open(session.slot_path,FileAccess.WRITE)
		f.store_buffer(var_to_bytes(old_field))
		f.close()
		await hotkey(KEY_F9)
		await ticks(7)
		check(not main.indoors and main.field_actor.is_on_floor() and main.field_actor.global_position.distance_to(Catalog.outdoor_return(bakery).global_position) < .16 and session.state.inventory.get("item.sample") == 2, "legacy outdoor feet under an expanded lot recover at that lot's outside approach")
	var smith := Catalog.outdoor_lot(main.get_node("Pixels/Clearing"), "place.smith_stock")
	main.show_place(false, smith.to_global(Vector3(2.62, 0, 3.10)), true)
	main.sync_control(true)
	await ticks(8)
	check(await walk(smith.to_global(Vector3(2.62, 0, 1.77)), 150, false), "smith can walk into the open work bay without switching worlds")
	check(await walk(smith.to_global(Vector3(2.62, 0, 3.10)), 150, false), "smith can walk out of the bay without switching worlds")
	main.show_place(false, main.field_entry.global_position, true)
	main.sync_control(true)
	await ticks(6)
	await check_hinge_approach(Catalog.outdoor_lot(main.get_node("Pixels/Clearing"), Catalog.CABIN), Catalog.CABIN)
	if await cross(main.field_door.to_global(Vector3(0, 0, -.45)), "cabin enter after bakery"):
		check_direction(Catalog.CABIN,main.field_door)
		check_framing(Catalog.CABIN)
		await capture(Catalog.CABIN)
		var setup := main.get_node("RoomPixels/Interior") as Node3D
		await verify_furnishings(Catalog.CABIN,setup,["Dining","SouthChair","NorthChair"],1.70)
		check(await walk(Vector3(-1.30, 0, -.60), 150, false), "cabin table aisle is clear")
		await ticks(5)
		for i in 2: session._use()
		check(session.state.inventory.get("item.bread") == 1 and session.state.inventory.get("item.cup") == 1, "cabin cup and bread transfer once")
		await hotkey(KEY_F5)
		var cabin_slot: Variant = bytes_to_var(FileAccess.get_file_as_bytes(session.slot_path))
		await _check_walk(main.room_entry.global_position,Catalog.CABIN)
		if await cross(main.room_door.to_global(Vector3(0, 0, .45)), "cabin exit after pickups"):
			main.restore_place("place.smith_stock", Vector3.ZERO)
			await hotkey(KEY_F9)
			check(main.place_id() == Catalog.CABIN and main.room_actor.global_position.distance_to(Vector3(-1.30,0,-.60)) < .16, "F9 mounts the cabin again at the saved table after the smith stockroom")
			if cabin_slot is Dictionary: await legacy_loads(Catalog.CABIN,cabin_slot)
			for item_name in ["BreadPickup", "CupPickup"]:
				var source = main.get_node("RoomPixels/Interior/Dining/Tabletop/CabinSetting/" + item_name)
				check(not source.visible and source.amount(session.state) == 0, item_name + " stays consumed after re-instantiating the cabin and legacy reads")
	_finish()

func _finish() -> void:
	if FileAccess.file_exists(session.slot_path):
		check(DirAccess.remove_absolute(session.slot_path) == OK, "remove own test slot")
	print("INTERIOR DOORS ",expected_size,": ", failures, " failures")
	quit(int(failures != 0))
