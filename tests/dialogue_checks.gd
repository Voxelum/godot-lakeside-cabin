extends SceneTree
## Run with a window: --script res://tests/dialogue_checks.gd
const UI := preload("res://scripts/ui/ui_layout.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://Main.tscn").instantiate()
	var token := Crypto.new().generate_random_bytes(12).hex_encode()
	main.get_node("Session").slot_path = "user://dialogue_%s.slot" % token
	main.get_node("BindingPanel").settings_path = "user://dialogue_%s.cfg" % token
	root.mode = Window.MODE_WINDOWED
	root.add_child(main)
	await process_frame
	var dialogue = main.get_node("FieldDialogue")
	var tender = dialogue.get_node("Tender")
	var potter = dialogue.get_node("Potter")
	var player: Node3D = main.active_actor()
	player.global_position = tender.actor().global_position + Vector3(3, 0, 0)
	await _key(KEY_F)
	_check(not dialogue.visible, "out of reach")
	for dimensions in [Vector2i(960, 540), Vector2i(320, 180)]:
		main.field.size = Vector2i(480, 270) if dimensions.x == 960 else Vector2i(320, 180)
		root.min_size = Vector2i(320, 180)
		root.size = dimensions
		await process_frame
		main._fit()
		await process_frame
		player.global_position = tender.actor().global_position + Vector3(1, 0, 0)
		await _key(KEY_F)
		_check(dialogue.visible and main.session.is_modal() and player.locked, "open + modal")
		_check(dialogue._portrait.texture == tender.portrait and dialogue._name.text == tender.speaker_name, "tender binding")
		_check(root.gui_get_focus_owner() == dialogue._next, "initial focus")
		var k: float = main.get_node("UILayout").factor
		var panel: Rect2 = dialogue.get_global_rect()
		var screen: Rect2 = main.get_node("Screen").get_global_rect()
		_check(screen.encloses(panel) and panel.size.y < screen.size.y and is_equal_approx(screen.end.y - panel.end.y, (UI.REFERENCE.y - UI.SAFE.end.y) * k), "bottom non-fullscreen layout")
		for control in [dialogue._line, dialogue._next, dialogue._close]:
			_check(panel.grow(-6 * k).encloses(control.get_global_rect()), "controls inside safe area")
		var portrait: Rect2 = dialogue._portrait.get_global_rect()
		var tag: Rect2 = dialogue._tag.get_global_rect()
		_check(screen.encloses(portrait) and portrait.size.y >= 170 * k and portrait.end.y <= panel.position.y + 3 * k, "large portrait mostly above paper and on screen")
		_check(screen.encloses(tag) and tag.position.y < panel.position.y and tag.end.y > panel.position.y and tag.position.x - panel.position.x < 30 * k, "name tag straddles left upper edge")
		for control in [dialogue._line, dialogue._next, dialogue._close]:
			_check(not portrait.intersects(control.get_global_rect()) and not tag.intersects(control.get_global_rect()), "portrait and name avoid dialogue and controls")
		await _check_rendered_edges(main, dialogue, panel, portrait)
		await _key(KEY_RIGHT)
		_check(root.gui_get_focus_owner() == dialogue._close, "keyboard focus moves")
		await _key(KEY_LEFT)
		_check(root.gui_get_focus_owner() == dialogue._next, "keyboard focus returns")
		await _key(KEY_ENTER)
		_check(dialogue._line.text == tender.lines[1], "keyboard advances")
		await _key(KEY_ESCAPE)
		_check(not dialogue.visible and not main.session.is_modal() and not player.locked, "cancel restores controls")
		player.global_position = potter.actor().global_position + Vector3(1, 0, 0)
		var original_portrait: Texture2D = potter.portrait
		var model = potter.actor().get_node("Model")
		await _key(KEY_F)
		_check(dialogue._name.text == potter.speaker_name and dialogue._portrait.texture == original_portrait, "switch name and portrait")
		await _pad(JOY_BUTTON_DPAD_RIGHT)
		_check(root.gui_get_focus_owner() == dialogue._close, "pad focus moves")
		await _pad(JOY_BUTTON_A)
		_check(not dialogue.visible, "pad confirms focused close")
		potter.portrait = null
		await _key(KEY_F)
		_check(dialogue._portrait.texture == dialogue.fallback_portrait and potter.actor().get_node("Model") == model, "fallback does not alter model")
		await _mouse(dialogue._close.get_global_rect().get_center())
		_check(not dialogue.visible, "mouse closes")
		potter.portrait = original_portrait
		await _key(KEY_F)
		await _pad(JOY_BUTTON_B)
		_check(not dialogue.visible and not main.session.is_modal(), "pad cancels and releases modal")
		await _check_use_exclusion(main, dialogue, tender, player, str(dimensions.x))
		print("dialogue_checks: exercised ", root.size, " / pixel buffer ", main.field.size)
	print("dialogue_checks: ", "PASS" if failures == 0 else "FAIL (%s)" % failures)
	quit(0 if failures == 0 else 1)

func _check_use_exclusion(main, dialogue, tender, player: Node3D, fixture_suffix: String) -> void:
	var pickup = preload("res://scripts/interaction/stack_target.gd").new()
	pickup.instance_id = "dialogue.test_overlap_" + fixture_suffix
	main.field.add_child(pickup)
	main.session._targets().append(pickup)
	player.global_position = tender.actor().global_position + Vector3(1, 0, 0)
	pickup.global_position = player.global_position
	var state = main.session.state
	_check(pickup.eligible(state, player.global_position, 1.55), "overlap fixture is eligible")
	await _key(KEY_F)
	_check(dialogue.visible and pickup.amount(state) == 1, "one F talks without picking up")
	await _key(KEY_ESCAPE)
	player.global_position = tender.actor().global_position + Vector3(3, 0, 0)
	pickup.global_position = player.global_position
	await _key(KEY_F)
	_check(not dialogue.visible and pickup.amount(state) == 0, "without a speaker F still picks up")
	main.session._targets().erase(pickup)
	pickup.queue_free()

func _check_rendered_edges(main, dialogue, panel: Rect2, portrait: Rect2) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var screen := main.get_node("Screen") as TextureRect
	var live_texture := screen.texture
	screen.texture = ImageTexture.create_from_image(live_texture.get_image())
	await RenderingServer.frame_post_draw
	var paper := root.get_texture().get_image()
	dialogue._portrait.hide()
	await RenderingServer.frame_post_draw
	var without_portrait := root.get_texture().get_image()
	dialogue._portrait.show()
	var face := Vector2i(portrait.get_center())
	var corner := Vector2i(portrait.position) + Vector2i(2, 2)
	_check(not paper.get_pixelv(face).is_equal_approx(without_portrait.get_pixelv(face)), "portrait actually renders above paper")
	_check(paper.get_pixelv(corner).is_equal_approx(without_portrait.get_pixelv(corner)), "portrait corner remains transparent")
	# Disable only the style for the reference frame; keep children and focus intact.
	dialogue.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	await RenderingServer.frame_post_draw
	var bare := root.get_texture().get_image()
	dialogue.remove_theme_stylebox_override(&"panel")
	screen.texture = live_texture
	for edge in range(4):
		var horizontal := edge < 2
		var reverse := edge % 2 == 1
		var length := panel.size.x if horizontal else panel.size.y
		var depths: Array[int] = []
		for along in range(ceili(length * .2), floori(length * .8)):
			var depth := 0
			for inward in range(12):
				var x: float = panel.position.x + (along if horizontal else (panel.size.x - 1 - inward if reverse else inward))
				var y: float = panel.position.y + (along if not horizontal else (panel.size.y - 1 - inward if reverse else inward))
				if not paper.get_pixel(int(x), int(y)).is_equal_approx(bare.get_pixel(int(x), int(y))):
					break
				depth += 1
			depths.append(depth)
		depths.sort()
		var variation := depths[floori(depths.size() * .9)] - depths[floori(depths.size() * .1)]
		_check(variation >= 1, "visible world through varied paper edge %s" % edge)

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func _pad(code: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func _mouse(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("dialogue_checks: FAIL: ", label)
