extends "res://tests/interior_door_checks.gd"
## Real renderer/physics, the original F5 Main, and isolated slots. --sill
## uses the same stair proof plus the live projecting upper window bay.
var room_id := "place.copper_loft"
var sill := false
var token := Crypto.new().generate_random_bytes(12).hex_encode()
var slot := "user://copper-walk-" + token + ".slot"
var config := "user://copper-walk-" + token + ".cfg"

func mount_main() -> void:
	main = MainScene.instantiate()
	session = main.get_node("Session")
	session.slot_path = slot
	main.get_node("BindingPanel").settings_path = config
	root.add_child(main)
	await ticks(7)

func key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var input := InputEventKey.new()
		input.keycode = code
		input.physical_keycode = code
		input.pressed = pressed
		Input.parse_input_event(input)
		Input.flush_buffered_events()
	await process_frame

func foot() -> Vector3:
	return main.room_actor.global_position

func step(x: float, z: float, label: String) -> void:
	var goal := Vector3(x, 0, z)
	for i in 200:
		var delta := (goal - foot()).slide(Vector3.UP)
		if delta.length() < .027 or main.crossing: break
		steer(delta.normalized() * clampf(delta.length()/.074, .43, 1.0))
		await physics_frame
	steer(Vector3.ZERO)
	check(not main.crossing and (goal - foot()).slide(Vector3.UP).length() < .036, "%s missed %s at %s" % [label, goal, foot()])

func storey_frame(label: String) -> void:
	var image := await frame()
	check(not image.is_empty() and image.get_size() == expected_size, label + " produces native gameplay pixels")
	if not image.is_empty():
		check(image.get_pixel(expected_size.x/2,expected_size.y/2).v > .12, label + " has a lit room after the iris")
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--review-dir="):
				var file := arg.trim_prefix("--review-dir=").path_join("copper-%s-%d.png" % [label, expected_size.x])
				check(not FileAccess.file_exists(file) and image.save_png(file) == OK, label + " saved a new review image")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CopperLoft walk needs a rendered Godot window")
		quit(2)
		return
	expected_size = Vector2i(320,180) if "--320" in OS.get_cmdline_user_args() else Vector2i(480,270)
	sill = "--sill" in OS.get_cmdline_user_args()
	if sill: room_id = "place.sill_house"
	await mount_main()
	var guest = main.room_actor
	var lot := Catalog.outdoor_lot(main.get_node("Pixels/Clearing"), room_id)
	var approach := Catalog.outdoor_return(lot)
	check(lot.lot_id == StringName("clearing.stone_street." + room_id.trim_prefix("place.")), "original town lot ID")
	session.state.take_stack("copper.test", "item.sample", 2)
	main.show_place(false, approach.global_position, true)
	main.sync_control(true)
	await ticks(7)
	await check_hinge_approach(lot, room_id)
	if not await cross(Catalog.outdoor_door(lot).to_global(Vector3(0,0,-.36)), room_id + " enter"):
		quit(1)
		return
	check(main.indoors and main.place_id() == room_id and main.room_actor == guest, "same room ID and retained Guest")
	check_direction(room_id, Catalog.outdoor_door(lot))
	var structure: Node3D = main.building_structure()
	var upper: float = structure.get_meta("upper_floor")
	check(lot.get_meta("building_revision") == structure.get_meta("building_revision"), "mounted inner and outer scenes have the same source revision")
	check(main.room.size == expected_size and main.get_node("Screen").texture == main.room.get_texture(), "uses active native RoomPixels")
	await storey_frame("ground")
	var furnishing: Node3D = main.get_node("RoomPixels/Interior/Furnishing")
	await verify_furnishings(room_id, furnishing, ["DiningTable1", "VisitorSeat" if sill else "ArchiveShelf"], 1.65)
	var lower: Vector3 = structure.get_node("StairFoot").position
	var head: Vector3 = structure.get_node("StairHead").position
	var board_z := lower.z+.14
	var turn_z := head.z-.54
	if sill: await step(-.28, 1.36, "open ground entry behind the chairs")
	await step(.22 if sill else .25, -.78 if sill else -1.39, "ground parlor/archive lane")
	if sill: await step(-.28, 1.36, "leave the parlor without clipping the seat")
	await step(.27, board_z, "lower landing approach")
	await step(lower.x, board_z, "lower stair foot")
	await step(head.x, turn_z, "ascend to loft landing")
	await ticks(7)
	check(absf(foot().y - upper) < .036 and main.room_actor.is_on_floor(), "stairs actually climbed to a solid loft (feet %s)" % foot())
	await step(.15, turn_z, "turn on the upper landing")
	await step(.15, .55, "upper bed aisle")
	if sill:
		await step(.53, 2.29, "cross the upper floor in front of the rail")
		await step(.42, 2.92, "step on the real projecting oriel deck")
	await ticks(18)
	check(structure.get_node("LoftCutaway").visible and absf(foot().y - upper) < .036 and main.room_actor.is_on_floor(), "upper aisle/bay is passable without falling into the opening")
	await storey_frame("loft")
	await verify_furnishings(room_id, furnishing.get_node("Loft"), ["Cot1", "MendingDesk" if sill else "LedgerDesk"], 1.35)
	var saved := foot()
	await key(KEY_F5)
	var written: Variant = bytes_to_var(FileAccess.get_file_as_bytes(slot)) if FileAccess.file_exists(slot) else null

	check(written is Dictionary and written.version == State.BUILDING_VERSION and written.location_id == room_id and written.position.distance_to(structure.to_local(saved)) < .015, "F5 stores a tagged building-local position on the upper floor")
	if sill:
		await step(.53, 2.29, "leave the projecting oriel")
		await step(.15, .55, "return from the window nook past the rail")
	await step(.15, turn_z, "return along the loft aisle")
	await step(head.x, turn_z, "turn to descend")
	await step(lower.x, board_z, "descend to the ground storey")
	await step(.24, board_z, "lower passage to the center door")
	await ticks(6)
	check(absf(foot().y) < .038 and main.room_actor.is_on_floor(), "descended by normal Walker input (feet %s)" % foot())
	if await cross(main.room_door.to_global(Vector3(0,0,.39)), "CopperLoft exit"):
		check(not main.indoors and main.field_actor.global_position.distance_to(approach.global_position) < .16, "returns to the generated outdoor approach")
	await key(KEY_F9)
	check(main.indoors and main.room_actor.global_position.distance_to(saved) < .018 and main.building_structure().get_node("LoftCutaway").visible and session.state.inventory.get("item.sample") == 2, "F9 from outdoors restores exact loft feet, view and bag")
	main.queue_free()
	await process_frame
	await mount_main()
	check(main.indoors and main.place_id() == room_id and foot().distance_to(saved) < .018 and main.room_actor.is_on_floor(), "fresh Main automatically restores a physically supported upper-floor position")
	if written is Dictionary:
		for legacy in [1, 2, 3]:
			var fixture: Dictionary = written.duplicate(true)
			fixture.version = legacy
			if legacy < 3:
				fixture.erase("building_revision")
				fixture.position = Vector3(3.55, .004, -3.50) # old oversized room, outside the new shell
			else:
				fixture.building_revision = "0".repeat(64)
			if legacy == 1: fixture.erase("player_stats")
			var file := FileAccess.open(slot, FileAccess.WRITE)
			file.store_buffer(var_to_bytes(fixture))
			file.close()
			await key(KEY_F9)
			check(main.indoors and main.place_id() == room_id and foot().distance_to(main.room_entry.global_position) < .018 and session.state.inventory.get("item.sample") == 2, "legacy or older revision %d restores to safe ground entry, retaining inventory" % legacy)
	for path in [slot, config]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print(room_id, " WALK ", expected_size, ": ", failures, " failures; upstairs saved feet ", saved)
	quit(int(failures != 0))
