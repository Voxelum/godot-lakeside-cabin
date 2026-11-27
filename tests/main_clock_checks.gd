extends SceneTree
## Render Main with normal bindings, no input and an isolated (absent) slot.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	main.get_node("Session").slot_path = "user://clock-probe-%s.slot" % Time.get_ticks_usec()
	root.add_child(main)
	await RenderingServer.frame_post_draw
	var sky = main.get_node("Pixels/Clearing/Almanac")
	var ledger = main.session.state.village
	var before: float = sky.hour
	var angle: Vector3 = sky._sun.rotation
	var light: float = sky.daylight
	var start_image: Image = main.field.get_texture().get_image()
	await create_timer(6.0).timeout
	await RenderingServer.frame_post_draw
	var end_image: Image = main.field.get_texture().get_image()
	var changed := 0
	for y in start_image.get_height():
		for x in start_image.get_width():
			if start_image.get_pixel(x,y) != end_image.get_pixel(x,y): changed += 1
	var ok: bool = not sky.halted and sky.hour >= before + 1 and angle != sky._sun.rotation and light != sky.daylight and changed > 0 and floori(sky.hour) == int(ledger.d.hour)%24 and absi(main.get_node("Dial").minutes-floori(sky.hour*60))<=2
	print("MAIN_CLOCK default input: %.3f -> %.3f; daylight %.3f -> %.3f; changed pixels %d; economic hour %d; ok=%s" % [before,sky.hour,light,sky.daylight,changed,ledger.d.hour,ok])
	sky.handle_key(KEY_2)
	var frozen: Dictionary = ledger.d.duplicate(true)
	sky.handle_key(KEY_2)
	ok = ok and frozen == ledger.d
	await main._trip()
	ok = ok and main.indoors and main.get_node("Dial").visible and frozen == ledger.d
	main.session._save_slot()
	ledger.step()
	await process_frame
	await process_frame
	ok = ok and floori(sky.hour) == int(ledger.d.hour)%24
	main.session._read_slot()
	ok = ok and frozen == ledger.d and is_equal_approx(sky.hour,16.75)
	await main._trip()
	ok = ok and not main.indoors and frozen == ledger.d
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.session.slot_path))
	print("MAIN_CLOCK preset replay, paused step, indoor save/load, round trip: ",ok)
	quit(0 if ok else 1)
