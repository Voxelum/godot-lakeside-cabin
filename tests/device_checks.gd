extends SceneTree
## Windowed Main integration. Optional --native runs only a Win32 driver handshake.
var main
var session
var hud
var panel
var attacks := 0
var failures := 0
var center: Vector2
const PAD := 42 # synthetic only; never impersonate a connected device

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func feed(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	feed(e)

func tap(code: Key) -> void:
	key(code, true)
	key(code, false)

func mouse(button: MouseButton, down: bool, pos: Vector2, ctrl := false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = down
	e.position = pos
	e.global_position = pos
	e.ctrl_pressed = ctrl
	feed(e)

func click(button: MouseButton, pos: Vector2) -> void:
	mouse(button, true, pos)
	mouse(button, false, pos)

func gui_click(control: Control, local: Vector2) -> void:
	click(MOUSE_BUTTON_LEFT, control.get_global_transform_with_canvas() * local)

func pad(button: JoyButton, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = PAD
	e.button_index = button
	e.pressed = down
	feed(e)

func axis(value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = PAD
	e.axis = JOY_AXIS_LEFT_Y
	e.axis_value = value
	feed(e)

func frames(count: int) -> void:
	for i in count: await physics_frame

func put_near_pickup() -> void:
	for target in get_nodes_in_group(&"test_stack_source"):
		if main.field.is_ancestor_of(target) and target.is_pickup:
			main.field_actor.global_position = target.global_position
			return

func run() -> void:
	var suffix := Crypto.new().generate_random_bytes(12).hex_encode()
	main = load("res://Main.tscn").instantiate()
	session = main.get_node("Session")
	hud = main.get_node("FieldHUD")
	panel = main.get_node("BindingPanel")
	session.slot_path = "user://device_slot_" + suffix + ".json"
	panel.settings_path = "user://device_bindings_" + suffix + ".cfg"
	root.add_child(main)
	session.attack_requested.connect(func(): attacks += 1)
	await frames(8)
	center = main.get_node("Screen").get_rect().get_center()
	check(DisplayServer.get_name() != "headless" and root.visible, "windowed display=" + DisplayServer.get_name())
	var ids := Input.get_connected_joypads()
	print("JOY_IDS ", ids)
	for id in ids: print("JOY ", id, " ", Input.get_joy_name(id))
	if "--pad-live" in OS.get_cmdline_user_args():
		await physical_pad(ids)
		return
	if "--native" in OS.get_cmdline_user_args():
		await native_checks()
		quit(failures)
		return
	var actor = main.field_actor
	var start: Vector3 = actor.position
	var forward: Vector3 = -main.orbit.global_basis.x.slide(Vector3.UP).normalized().cross(Vector3.UP)
	key(KEY_W, true)
	await frames(8)
	var walk: Vector3 = actor.velocity.slide(Vector3.UP)
	check((actor.position - start).slide(Vector3.UP).dot(forward) > 0.1 and walk.normalized().dot(forward) > 0.98, "camera-relative W displacement")
	key(KEY_SHIFT, true)
	await frames(4)
	check(actor.velocity.slide(Vector3.UP).length() > walk.length() * 1.4, "Shift sprint > walk")
	key(KEY_SHIFT, false)
	key(KEY_W, false)
	axis(-0.55)
	await frames(4)
	var partial: float = actor.velocity.slide(Vector3.UP).length()
	axis(-1.0)
	await frames(4)
	check(partial > 0.1 and partial < actor.velocity.slide(Vector3.UP).length() * 0.85, "synthetic pad analog partial/full")
	axis(0.0)
	pad(JOY_BUTTON_X, true)
	pad(JOY_BUTTON_X, false)
	check(attacks == 1, "synthetic pad X attack")
	var yaw: float = main.orbit.yaw_degrees
	main.developer_camera = false
	mouse(MOUSE_BUTTON_LEFT, true, center, true)
	drag()
	mouse(MOUSE_BUTTON_LEFT, false, center, true)
	check(not main.orbit.dragging and is_equal_approx(main.orbit.yaw_degrees, yaw) and attacks == 1, "normal Ctrl-drag does not rotate or attack")
	main.developer_camera = true
	mouse(MOUSE_BUTTON_LEFT, true, center, true)
	drag()
	var rotated: bool = main.orbit.dragging and not is_equal_approx(main.orbit.yaw_degrees, yaw)
	mouse(MOUSE_BUTTON_LEFT, false, center, true)
	check(rotated and not main.orbit.dragging and attacks == 1, "developer Ctrl-drag rotates without attack")
	main.developer_camera = false
	put_near_pickup()
	pad(JOY_BUTTON_BACK, true)
	pad(JOY_BUTTON_BACK, false)
	await frames(2)
	check(hud.inventory_open, "synthetic pad Back opens inventory")
	await modal_checks("inventory")
	var close: Button = hud.get_node("InventoryOverlay/Parchment/Close")
	gui_click(close, close.size / 2)
	check(not hud.inventory_open, "inventory GUI Close via mouse dispatch")
	tap(KEY_F2)
	await frames(2)
	var book = main.get_node("SettingsBook")
	check(book.opened and not panel.visible, "F2 opens settings book")
	await modal_checks("settings")
	gui_click(book._bindings, book._bindings.size / 2)
	check(panel.visible and not book.opened, "settings opens bindings")
	await modal_checks("bindings")
	var bind_button: Button = panel._buttons[&"walk_left"][0]
	gui_click(bind_button, bind_button.size / 2)
	check(panel._action == &"walk_left", "bindings GUI selects keyboard slot")
	tap(KEY_ESCAPE)
	gui_click(panel._close, panel._close.size / 2)
	check(not panel.visible and book.opened, "bindings returns to settings via mouse dispatch")
	tap(KEY_ESCAPE)
	# The same A button that uses an object in the world now belongs exclusively to the GUI.
	var before_menu: Dictionary = session.state.inventory.duplicate()
	pad(JOY_BUTTON_START, true); pad(JOY_BUTTON_START, false)
	await frames(2)
	check(book.opened and book._back.has_focus(), "pad Start opens settings with focus")
	pad(JOY_BUTTON_DPAD_LEFT, true); pad(JOY_BUTTON_DPAD_LEFT, false)
	pad(JOY_BUTTON_A, true); pad(JOY_BUTTON_A, false)
	await frames(2)
	check(panel.visible and panel._close.has_focus(), "pad enters control settings")
	pad(JOY_BUTTON_DPAD_UP, true); pad(JOY_BUTTON_DPAD_UP, false)
	await frames(2)
	var focus := root.gui_get_focus_owner()
	check(focus != null and focus != panel._close, "pad D-pad moves focus")
	pad(JOY_BUTTON_A, true); pad(JOY_BUTTON_A, false)
	check(panel._action != &"" and session.state.inventory == before_menu, "pad A activates focused binding without using world target")
	tap(KEY_ESCAPE)
	pad(JOY_BUTTON_B, true); pad(JOY_BUTTON_B, false)
	check(not panel.visible and book.opened, "pad B returns to settings")
	pad(JOY_BUTTON_B, true); pad(JOY_BUTTON_B, false)
	check(not session.is_modal() and session.state.inventory == before_menu, "pad B closes settings without transfer")
	put_near_pickup()
	tap(KEY_F)
	check(session.state.inventory != before_menu, "F transfers reachable pickup into inventory")
	tap(KEY_TAB)
	await frames(2)
	var list: ItemList = hud.get_node("InventoryOverlay/Parchment/Items")
	if list.item_count > 0:
		list.deselect_all()
		gui_click(list, list.get_item_rect(0).get_center())
	check(list.is_selected(0) if list.item_count > 0 else false, "inventory GUI row mouse selection")
	quit(failures)

func drag() -> void:
	var e := InputEventMouseMotion.new()
	e.position = center
	e.global_position = center
	e.relative = Vector2(32, 12)
	e.ctrl_pressed = true
	feed(e)

func modal_checks(label: String) -> void:
	var actor = main.field_actor
	var before: Vector3 = actor.position
	var prior := attacks
	var inventory: Dictionary = session.state.inventory.duplicate()
	var clock = main.get_node("Pixels/Clearing/Almanac")
	var sunbreak = main.get_node("Pixels/Clearing/Sunbreak")
	var shown: bool = sunbreak.shown
	# Freeze explicitly for this input-isolation check; Main now runs by default.
	var was_halted: bool = clock.halted
	clock.halted = true
	var hour: float = clock.hour
	key(KEY_W, true)
	# A is also GUI confirm: when Close has focus it should close, not leak a
	# world-use. Exercise that separately; here the modal must remain open.
	pad(JOY_BUTTON_X, true)
	pad(JOY_BUTTON_X, false)
	click(MOUSE_BUTTON_RIGHT, center)
	tap(KEY_F)
	tap(KEY_B)
	tap(KEY_2)
	tap(KEY_P)
	key(KEY_T, true)
	await frames(6)
	key(KEY_T, false)
	key(KEY_W, false)
	check(actor.position.is_equal_approx(before) and actor.locked, label + " blocks movement")
	check(attacks == prior and session.state.inventory == inventory, label + " blocks use/attack")
	check(not clock.allow_fast_key and clock.halted and is_equal_approx(clock.hour, hour) and sunbreak.shown == shown, label + " blocks legacy light controls")
	clock.halted = was_halted

func native_checks() -> void:
	var actor = main.field_actor
	var before: Vector3 = actor.position
	print("NATIVE_READY ", OS.get_process_id(), " ", DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE), " ", int(center.x), " ", int(center.y))
	var until := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < until and attacks == 0:
		await process_frame
	check((actor.position - before).slide(Vector3.UP).length() > 0.15, "Win32 WM_KEYDOWN/UP moved actor")
	check(attacks == 1, "Win32 WM_LBUTTONDOWN/UP requested attack")
	put_near_pickup()
	var before_menu: Dictionary = session.state.inventory.duplicate()
	print("NATIVE_USE")
	until = Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < until and session.state.inventory == before_menu:
		await process_frame
	check(session.state.inventory != before_menu, "Win32 WM_KEYDOWN/UP (F) transferred pickup")

func physical_pad(ids: Array[int]) -> void:
	# Optional, operator-driven. No parse_input_event/action_press in this mode;
	# enumeration alone, or an unattended timeout, must not produce a pass.
	if ids.is_empty():
		printerr("NOT VERIFIED: no gamepad enumerated"); quit(2); return
	var id := ids[0]
	root.title = "手柄实按验收：左杆横向轻推、推满，再按住 LB 推满；松开后按 X"
	print("LIVE PAD ", id, " ", Input.get_joy_name(id), ": partial stick, full stick, LB + stick, X (25s)")
	var partial := false; var full := false; var sprint := false; var x_button := false
	var until := Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < until:
		await physics_frame
		var raw := Vector2(Input.get_joy_axis(id, JOY_AXIS_LEFT_X), Input.get_joy_axis(id, JOY_AXIS_LEFT_Y)).length()
		var speed: float = main.active_actor().velocity.slide(Vector3.UP).length()
		var walk: float = main.active_actor().walk_speed
		partial = partial or (raw > 0.3 and raw < 0.8 and speed > 0.1 and speed < walk * 0.9)
		full = full or (raw > 0.95 and is_equal_approx(speed, walk))
		sprint = sprint or (raw > 0.9 and Input.is_joy_button_pressed(id, JOY_BUTTON_LEFT_SHOULDER) and speed > walk * 1.25)
		x_button = x_button or (Input.is_joy_button_pressed(id, JOY_BUTTON_X) and attacks > 0)
		if partial and full and sprint and x_button:
			print("PASS live controller movement / sprint / attack"); quit(0); return
	print("NOT VERIFIED live controller: partial=", partial, " full=", full, " LB=", sprint, " X=", x_button)
	quit(2)
