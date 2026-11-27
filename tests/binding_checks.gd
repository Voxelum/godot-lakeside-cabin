extends SceneTree

const Store = preload("res://scripts/controls/binding_store.gd")
const BindingPanel = preload("res://scripts/controls/binding_panel.gd")
const Walker = preload("res://scripts/walker.gd")
var failures := 0

func _initialize() -> void:
	call_deferred(&"_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr(message)

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event

func motion(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event

func _run() -> void:
	for pair: Array in [[&"ui_up", JOY_BUTTON_DPAD_UP], [&"ui_down", JOY_BUTTON_DPAD_DOWN], [&"ui_accept", JOY_BUTTON_A], [&"ui_cancel", JOY_BUTTON_B]]:
		var nav := InputEventJoypadButton.new()
		nav.button_index = pair[1]; nav.pressed = true
		check(nav.is_action_pressed(pair[0]), "controller menu navigation unavailable: " + String(pair[0]))
	var defaults := Store.snapshot(true)
	check(Store.valid(defaults), "default map invalid")
	check(key(KEY_F2).is_action_pressed(&"bindings"), "wrong bindings default")
	check(key(KEY_SHIFT).is_action_pressed(&"sprint"), "wrong sprint default")
	check(key(KEY_TAB).is_action_pressed(&"inventory"), "wrong inventory default")
	var path := "user://s03_binding_checks_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	var panel := BindingPanel.new()
	panel.settings_path = path
	var small_view := SubViewport.new()
	small_view.size = Vector2i(320, 180)
	root.add_child(small_view)
	small_view.add_child(panel)
	check(not panel.visible, "panel starts visible")
	panel.open_panel()
	await process_frame
	await process_frame
	var scroll := panel._scroll
	check(panel.size == Vector2(320, 180) and scroll.get_v_scroll_bar().visible, "320x180 action rows scroll")
	check(panel._close.has_focus() and not scroll.get_global_rect().intersects(panel._close.get_global_rect()), "return button stays visible outside scrolling rows")
	panel._begin(&"walk_left", false)
	check(panel.handle_modal_input(key(KEY_F5)), "reserved key leaked")
	check(panel.handle_modal_input(key(KEY_F6)), "reserved key leaked")
	check(panel.handle_modal_input(key(KEY_F9)), "reserved key leaked")
	check(panel.handle_modal_input(key(KEY_D)), "duplicate key leaked")
	check(Store.snapshot() == defaults and not FileAccess.file_exists(path), "reject changed bindings")
	check(panel.handle_modal_input(key(KEY_ESCAPE)) and panel.visible, "Escape did not cancel capture")
	panel._begin(&"walk_left", false)
	check(panel.handle_modal_input(key(KEY_J)), "accepted event leaked")
	check(Store.snapshot()[&"walk_left"].has(Vector2i(1, KEY_J)), "not remapped")
	check(Store.snapshot()[&"walk_left"].has(Vector2i(5, JOY_AXIS_LEFT_X)), "key remap erased pad")
	panel._begin(&"walk_left", true)
	panel.handle_modal_input(motion(JOY_AXIS_RIGHT_X, -0.2))
	check(not Store.snapshot()[&"walk_left"].has(Vector2i(5, JOY_AXIS_RIGHT_X)), "axis noise captured")
	panel.handle_modal_input(motion(JOY_AXIS_RIGHT_X, -0.8))
	check(panel.handle_modal_input(motion(JOY_AXIS_RIGHT_X, -0.5)), "captured stick leaked before release")
	check(panel.handle_modal_input(motion(JOY_AXIS_RIGHT_X, 0.0)), "captured stick release leaked")
	check(not panel.handle_modal_input(motion(JOY_AXIS_RIGHT_X, 0.8)), "stick failed to rearm GUI delivery")
	var edited := Store.snapshot()
	check(edited[&"walk_left"].has(Vector2i(1, KEY_J)) and edited[&"walk_left"].has(Vector2i(5, JOY_AXIS_RIGHT_X)), "axis remap lost key or sign")
	Store.apply(defaults)
	check(Store.load_bindings(path) == OK and Store.snapshot() == edited, "save/load round trip failed")
	panel._restore()
	check(Store.snapshot() == defaults and Store.load_bindings(path) == OK, "restore not persisted")
	var broken := ConfigFile.new()
	broken.set_value(Store.SECTION, &"walk_left", [Vector2i(1, KEY_F5)])
	check(broken.save(path) == OK, "could not write isolated malformed config")
	check(Store.load_bindings(path) == ERR_INVALID_DATA and Store.snapshot() == defaults, "bad config was not rejected")

	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	var walker := Walker.new()
	var art := Node3D.new()
	art.name = "Appearance"
	walker.add_child(art)
	root.add_child(walker)
	walker.set_physics_process(false)
	walker.locked = true
	Input.action_press(&"walk_right", 0.6)
	walker._physics_process(0.016)
	check(is_zero_approx(walker.velocity.x), "root lock leaked global movement")
	check(panel.handle_modal_input(key(KEY_ESCAPE)) and not panel.visible, "Escape did not close")
	walker.locked = false
	walker._physics_process(0.016)
	check(is_zero_approx(walker.velocity.x), "held movement passed unlock")
	Input.action_press(&"walk_right", 0.5)
	Input.action_press(&"walk_left", 0.5)
	walker._physics_process(0.016)
	Input.action_release(&"walk_left")
	walker._physics_process(0.016)
	check(is_zero_approx(walker.velocity.x), "opposing held inputs disarmed release gate")
	Input.action_release(&"walk_right")
	Input.parse_input_event(motion(JOY_AXIS_LEFT_X, 0.08))
	Input.flush_buffered_events()
	walker._physics_process(0.016)
	check(is_zero_approx(walker.velocity.x), "small stick drift moved character")
	Input.parse_input_event(motion(JOY_AXIS_LEFT_X, 0.6))
	Input.flush_buffered_events()
	walker._physics_process(0.016)
	check(is_equal_approx(walker.velocity.x, walker.walk_speed * 0.5), "lost analog magnitude")
	Input.action_press(&"sprint")
	walker._physics_process(0.016)
	check(is_equal_approx(walker.velocity.x, walker.sprint_speed * 0.5), "sprint lost analog magnitude")
	Input.action_release(&"walk_right")
	Input.action_release(&"sprint")
	DirAccess.remove_absolute(path)
	print("S03 binding checks: %d failures" % failures)
	quit(int(failures != 0))
