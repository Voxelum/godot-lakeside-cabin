extends SceneTree
## Run with a real display: godot --path . --script res://tests/display_checks.gd [-- --320]
const MAIN := preload("res://Main.tscn")
const UI := preload("res://scripts/ui/ui_layout.gd")
var failures := 0
var main: Control

func _initialize() -> void:
	call_deferred(&"_run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func settle() -> void:
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw

func verify_fit(label: String) -> void:
	var source: Vector2 = Vector2(main.get_node("Pixels").size)
	var screen := main.get_node("Screen") as TextureRect
	var factor := minf(main.size.x / source.x, main.size.y / source.y)
	check(screen.size.is_equal_approx(source * factor), label + " maximal aspect-preserving area")
	check(Rect2(Vector2.ZERO, main.size).grow(0.01).encloses(screen.get_rect()), label + " no crop")
	check(screen.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, label + " nearest filter")
	check(source == (Vector2(320, 180) if "--320" in OS.get_cmdline_user_args() else Vector2(480, 270)), label + " unchanged internal resolution")
	print(label, " native=", root.size, " image=", screen.size, " scale=", factor)

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func click(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func quantity_pixels(list: ItemList, index: int) -> int:
	var row := list.get_item_rect(index)
	var scroll := list.get_v_scroll_bar()
	row.position.y -= scroll.value
	var right := list.size.x - (scroll.size.x if scroll.visible else 0.0)
	var frame := root.get_texture().get_image()
	var light_pixels := 0
	var t := list.get_global_transform()
	var a := Vector2i(t * Vector2(right - 19, maxf(0, row.position.y + 3)))
	var b := Vector2i(t * Vector2(right - 4, minf(list.size.y, row.end.y - 2)))
	for y in range(a.y, b.y):
		for x in range(a.x, b.x):
			if frame.get_pixel(x, y).get_luminance() > 0.72: light_pixels += 1
	return light_pixels

func _capture(hud: Control, label: String) -> void:
	var card: Panel = hud.get_node("InventoryOverlay/Parchment")
	var title: Label = card.get_node("InventoryTitle")
	var list: ItemList = card.get_node("Items")
	var description: RichTextLabel = card.get_node("Description")
	var k := card.get_global_transform().get_scale().x
	var coverage := card.size * k / Vector2(root.size)
	print(label, " paper=", coverage, " title/list/description px=", Vector3(
		title.get_theme_font_size("font_size"), list.get_theme_font_size("font_size"), description.get_theme_font_size("normal_font_size")) * k)
	check(coverage.x <= 0.851 and coverage.y <= 0.691, label + " paper fits normalized bounds")
	var expected := minf(root.size.x / UI.REFERENCE.x, root.size.y / UI.REFERENCE.y)
	check(list.get_theme_font_size("font_size") == UI.BODY and is_equal_approx(k, expected), label + " item text uses shared body and native-window scale")
	check(description.get_content_height() >= description.get_theme_font_size("normal_font_size"), label + " description shaped")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			var path := arg.trim_prefix("--capture=").path_join(label + ".png")
			check(not FileAccess.file_exists(path) and root.get_texture().get_image().save_png(path) == OK, "save new screenshot " + path)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Display checks require a real desktop")
		quit(1)
		return
	main = MAIN.instantiate()
	var id := Crypto.new().generate_random_bytes(12).hex_encode()
	var session = main.get_node("Session")
	session.slot_path = "user://display_%s.slot" % id
	main.get_node("BindingPanel").settings_path = "user://display_%s.cfg" % id
	root.add_child(main)
	var book = main.get_node("SettingsBook")
	var hud = main.get_node("FieldHUD")
	await settle()
	check(root.mode == Window.MODE_FULLSCREEN, "cold standalone launch starts in fullscreen")
	verify_fit("cold fullscreen")
	key(KEY_TAB)
	await settle()
	check(hud.inventory_open, "Tab opens character menu on cold fullscreen launch")
	_capture(hud, "fullscreen-%s" % main.get_node("Pixels").size.x)
	key(KEY_ESCAPE)
	key(KEY_F2)
	await process_frame
	click(book._display)
	await settle()
	check(root.mode == Window.MODE_WINDOWED and book.opened, "settings exits cold fullscreen without closing menu")
	key(KEY_ESCAPE)
	root.size = Vector2i(320, 180) if "--320" in OS.get_cmdline_user_args() else Vector2i(480, 270)
	await settle()
	var regular := Rect2i(root.position, root.size)
	verify_fit("windowed")
	key(KEY_TAB)
	await settle()
	check(hud.inventory_open, "Tab opens character menu in window")
	_capture(hud, "window-%s" % main.get_node("Pixels").size.x)
	check(hud._portrait_model.profile == main.field_actor.artwork.profile, "3D portrait matches live hero profile")
	var image: Image = hud._portrait.get_texture().get_image()
	var used := image.get_used_rect()
	check(used.size.y > 30 and used.position.y > 0 and used.end.y < image.get_height(), "3D portrait has actual pixels, transparent margins and no head/foot crop")
	var list: ItemList = hud._list
	check(quantity_pixels(list, 0) > 8, "quantity glyphs rendered in right column over selected row")
	for item in ["item.bread", "item.cup", "item.sample"]:
		session.state.inventory[item] = 4
	session._show_inventory()
	await settle()
	var last := list.item_count - 1
	list.select(last)
	list.ensure_current_is_visible()
	await settle()
	check(list.get_v_scroll_bar().value > 0.0, "crowded list scrolls")
	check(quantity_pixels(list, last) > 8, "quantity stays aligned with selected row after scrolling")
	click(hud._close)
	check(not hud.inventory_open, "mouse closes character menu in window")
	key(KEY_F2)
	await process_frame
	check(book.opened and not book._display.disabled, "standalone display button enabled")
	click(book._display)
	await settle()
	check(root.mode == Window.MODE_FULLSCREEN and book.opened, "mouse switches to fullscreen without closing menu")
	verify_fit("fullscreen")
	pad(JOY_BUTTON_B)
	pad(JOY_BUTTON_BACK)
	check(hud.inventory_open, "handheld input opens character menu in fullscreen")
	pad(JOY_BUTTON_B)
	key(KEY_F2)
	await process_frame
	click(book._display)
	await settle()
	check(root.mode == Window.MODE_WINDOWED and Rect2i(root.position, root.size) == regular, "restores window size and position")
	key(KEY_ESCAPE)
	root.mode = Window.MODE_MAXIMIZED
	await settle()
	check(root.mode == Window.MODE_MAXIMIZED, "native maximize")
	verify_fit("maximized")
	key(KEY_F2)
	await process_frame
	click(book._display)
	await settle()
	check(root.mode == Window.MODE_FULLSCREEN, "fullscreen from maximized")
	click(book._display)
	await settle()
	check(root.mode == Window.MODE_MAXIMIZED, "returns to maximized window")
	verify_fit("restored maximized")
	key(KEY_ESCAPE)
	print("display_checks: ", failures, " failures")
	quit(failures)
