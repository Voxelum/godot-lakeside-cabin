extends SceneTree
## Real GL window only. Optional -- --320 and --capture=<existing directory>.
const MAIN := preload("res://Main.tscn")
const UI := preload("res://scripts/ui/ui_layout.gd")
var failures := 0
var capture_dir := ""

func _initialize() -> void:
	call_deferred(&"_run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("ui_layout_checks: FAIL: ", label)

func bounds(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func em(control: Control, role := &"font_size") -> float:
	return control.get_theme_font_size(role) * control.get_global_transform_with_canvas().get_scale().y

func gap(a: Rect2, b: Rect2) -> float:
	var x := maxf(0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var y := maxf(0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(x, y).length()

func inset(outer: Rect2, inner: Rect2) -> float:
	return minf(minf(inner.position.x - outer.position.x, inner.position.y - outer.position.y),
		minf(outer.end.x - inner.end.x, outer.end.y - inner.end.y))

func save(label: String) -> void:
	if capture_dir.is_empty(): return
	var path := capture_dir.path_join(label + ".png")
	check(not FileAccess.file_exists(path) and root.get_texture().get_image().save_png(path) == OK, "save new frame " + path)

func settle() -> void:
	await create_timer(.18).timeout
	await RenderingServer.frame_post_draw

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame

# Isolate actual glyphs against the identical rendered vellum underneath, not
# just the logical font metric. Two adjacent controls are disjoint in this pass.
func glyph_boxes(controls: Array[Control]) -> Array[Rect2i]:
	var ink := root.get_texture().get_image()
	for control in controls: control.hide()
	await RenderingServer.frame_post_draw
	var paper := root.get_texture().get_image()
	for control in controls: control.show()
	var boxes: Array[Rect2i] = []
	for control in controls:
		var area := bounds(control).grow(2)
		var box := Rect2i()
		for y in range(floori(area.position.y), ceili(area.end.y)):
			for x in range(floori(area.position.x), ceili(area.end.x)):
				if absf(ink.get_pixel(x, y).get_luminance() - paper.get_pixel(x, y).get_luminance()) > 0.075:
					var pixel := Rect2i(x, y, 1, 1)
					box = box.merge(pixel) if box.has_area() else pixel
		boxes.append(box)
	await RenderingServer.frame_post_draw
	return boxes

func verify_doll(hud, k: float, label: String) -> void:
	var view: TextureRect = hud._card.get_node("Preview")
	var paper: Rect2 = bounds(hud._card)
	var texture: Image = hud._portrait.get_texture().get_image()
	var used := texture.get_used_rect()
	var inner := Rect2i(Vector2i.ONE, texture.get_size() - Vector2i(2, 2))
	check(used.size.y > 50 and inner.encloses(used), label + " rendered model has transparent margins on all sides")
	check(view.size.aspect() == Vector2(texture.get_size()).aspect(), label + " preview rectangle preserves texture aspect")
	var display := view.get_global_transform_with_canvas() * Rect2(Vector2(used.position) * .5, Vector2(used.size) * .5)
	var slot_clear := INF
	for slot: Control in hud._slot_buttons.values():
		check(not bounds(slot).intersects(bounds(view)), label + " preview rect does not overlap " + str(slot.name))
		slot_clear = minf(slot_clear, gap(display, bounds(slot)))
	check(slot_clear >= 10 * k and inset(paper, display) >= 20 * k, label + " actual doll ink clears slots and paper edge")
	print(label, " doll alpha=", used, " native ink=", display, " nearest-slot/edge px=", Vector2(slot_clear, inset(paper, display)))

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("ui_layout_checks needs a real window")
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	var main = MAIN.instantiate()
	var session = main.get_node("Session")
	var hud = main.get_node("FieldHUD")
	var dialogue = main.get_node("FieldDialogue")
	var book = main.get_node("SettingsBook")
	var bindings = main.get_node("BindingPanel")
	var dial := main.get_node("Dial") as Control
	var layout: UI = main.get_node("UILayout")
	var token := Crypto.new().generate_random_bytes(12).hex_encode()
	session.slot_path = "user://ui-layout-%s.slot" % token
	bindings.settings_path = "user://ui-layout-%s.cfg" % token
	root.add_child(main)
	await process_frame
	var near: Vector3 = dialogue.get_node("Tender").actor().global_position + Vector3(1, 0, 0)
	main.show_place(false, near, true)
	main.get_node("Pixels/Clearing/Almanac").handle_key(KEY_1)
	await settle()
	# Freeze the real game's world texture so the pair is pixel-registered even
	# with ambient animations; the real HUD, session, and controls remain live.
	var screen := main.get_node("Screen") as TextureRect
	screen.texture = ImageTexture.create_from_image(screen.texture.get_image())
	var preset_string := str(main.field.size.x)
	check(main.field.size == (Vector2i(320, 180) if "--320" in OS.get_cmdline_user_args() else Vector2i(480, 270)), "world preset unchanged")
	for mode in ["fullscreen", "window", "wide"]:
		root.mode = Window.MODE_FULLSCREEN if mode == "fullscreen" else Window.MODE_WINDOWED
		if mode == "window": root.size = Vector2i(960, 540)
		if mode == "wide": root.size = Vector2i(1100, 540)
		await settle()
		var label: String = "%s-%s" % [mode, preset_string]
		check(root.mode == (Window.MODE_FULLSCREEN if mode == "fullscreen" else Window.MODE_WINDOWED), label + " native mode")
		if mode != "fullscreen": check(root.size == (Vector2i(960, 540) if mode == "window" else Vector2i(1100, 540)), label + " native size")
		var k := minf(root.size.x / UI.REFERENCE.x, root.size.y / UI.REFERENCE.y)
		var safe := Rect2(layout.origin + UI.SAFE.position * k, UI.SAFE.size * k).grow(.05)
		check(is_equal_approx(layout.factor, k), label + " native layout factor")
		for control: Control in [hud.actor_sheet._tag, book.launcher, dial]:
			check(safe.encloses(bounds(control)) and control.scale.is_equal_approx(Vector2.ONE * k), label + " HUD and launcher share scale and safe area")
		check(is_equal_approx(em(hud.actor_sheet._health), UI.BODY * k), label + " health uses body token")
		await key(KEY_TAB)
		check(hud.inventory_open and hud._list.has_focus(), label + " inventory focus")
		await settle()
		var paper: Rect2 = bounds(hud._card)
		var title := hud._card.get_node("InventoryTitle") as Control
		var title_px := em(title)
		var item_px := em(hud._list)
		var notes_px := em(hud._details, &"normal_font_size")
		check(safe.encloses(paper) and paper.size.is_equal_approx(Vector2(544, 246) * k), label + " character paper in safe area")
		check(is_equal_approx(title_px, UI.TITLE * k) and is_equal_approx(item_px, UI.BODY * k) and is_equal_approx(notes_px, item_px), label + " character type has exactly one scale")
		verify_doll(hud, k, label)
		if mode != "wide": save(label + "-character")
		var character_ink := await glyph_boxes([title, hud._details])
		check(character_ink[0].has_area() and character_ink[1].has_area(), label + " title and notes contain rendered ink")
		check(bounds(title).encloses(Rect2(character_ink[0])) and bounds(hud._details).encloses(Rect2(character_ink[1])), label + " character text inside its own panels")
		print(label, " native=", root.size, " inventory fraction=", paper.size / Vector2(root.size), " em=", Vector3(title_px, item_px, notes_px), " title/notes ink=", Vector2i(character_ink[0].size.y, character_ink[1].size.y))
		await key(KEY_ESCAPE)
		await key(KEY_F)
		check(dialogue.visible and dialogue._next.has_focus(), label + " dialogue focus")
		await settle()
		var dialogue_paper := bounds(dialogue)
		var portrait := bounds(dialogue._portrait)
		var tag := bounds(dialogue._tag)
		var line := bounds(dialogue._line)
		check(safe.encloses(dialogue_paper) and dialogue_paper.size.is_equal_approx(Vector2(464, 92) * k), label + " dialogue uses logical size and safe bottom")
		check(safe.encloses(portrait) and portrait.size.y >= 170 * k and portrait.end.y <= dialogue_paper.position.y + 2.01 * k, label + " large independent portrait in safe area")
		check(tag.position.y < dialogue_paper.position.y and tag.end.y > dialogue_paper.position.y and safe.encloses(tag), label + " name tag straddles only upper paper lip")
		var clear := INF
		for control: Control in [dialogue._line, dialogue._next, dialogue._close]:
			check(dialogue_paper.grow(-8 * k).encloses(bounds(control)), label + " dialogue content in intact paper area")
			clear = minf(clear, minf(gap(bounds(control), tag), gap(bounds(control), portrait)))
		check(clear >= 5 * k and not line.intersects(bounds(dialogue._next)), label + " dialogue content clears portrait and tag")
		check(is_equal_approx(em(dialogue._line), item_px) and is_equal_approx(em(dialogue._next), UI.AUX * k), label + " dialogue shares body and auxiliary metrics")
		if mode != "wide": save(label + "-dialogue")
		var dialogue_ink := await glyph_boxes([dialogue._line])
		check(line.encloses(Rect2(dialogue_ink[0])) and dialogue_ink[0].size.y >= 8 * k, label + " dialogue ink fits and is visible in final frame")
		print(label, " dialogue fraction=", dialogue_paper.size / Vector2(root.size), " em=", em(dialogue._line), " ink height=", dialogue_ink[0].size.y, " portrait height=", portrait.size.y, " content gap=", clear)
		await key(KEY_ESCAPE)
		await key(KEY_F2)
		check(book.opened and book._back.has_focus(), label + " settings focus")
		check(is_equal_approx(em(book._back), item_px) and safe.encloses(bounds(book._page)), label + " settings uses shared body and safe area")
		book._bindings.pressed.emit()
		await process_frame
		check(bindings.visible and bindings._close.has_focus() and safe.encloses(bounds(bindings._scroll)), label + " remapping uses same safe area and retains focus")
		await key(KEY_ESCAPE)
		await key(KEY_ESCAPE)
	for profile in [&"reed", &"linnet"]:
		main.get_node("CharacterTrial").select_hero(profile)
		await key(KEY_TAB)
		await settle()
		check(hud._portrait_model.profile == profile, "preview updates to " + profile)
		verify_doll(hud, layout.factor, str(profile))
		await key(KEY_ESCAPE)
	print("ui_layout_checks: ", failures, " failures")
	quit(failures)
