extends SceneTree
## Run with a window: godot --path . --script res://tests/paper_edge_checks.gd

const Hud = preload("res://scripts/ui/field_hud.gd")
const Book = preload("res://scripts/ui/settings_book.gd")
var _failures := 0

class Sample extends Resource:
	var definition_id := "item.test"
	var title := "湖畔石"
	var description := "一块光滑的石头。"

func _initialize() -> void:
	if DisplayServer.get_name() == "headless" or "--headless" in OS.get_cmdline_args():
		printerr("paper_edge_checks: requires a window renderer")
		quit(2)
		return
	call_deferred("_run")

func _run() -> void:
	for dimensions in [Vector2i(960, 540), Vector2i(320, 180)]:
		await _page(dimensions, false)
		await _page(dimensions, true)
	if _failures == 0:
		print("paper_edge_checks: PASS")
	quit(0 if _failures == 0 else 1)

func _page(dimensions: Vector2i, settings: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = dimensions
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var ui: Control = Book.new() if settings else Hud.new()
	viewport.add_child(ui)
	if settings:
		ui.open_book(true)
	else:
		ui.show_inventory({"item.test": 2}, Sample.new())
	var panel := ui.get_node_or_null("Shade/Page" if settings else "InventoryOverlay/Parchment") as Control
	var context := "%s %sx%s" % ["settings" if settings else "inventory", dimensions.x, dimensions.y]
	if panel == null:
		_check(false, context + ": missing page")
		viewport.queue_free()
		return
	await process_frame
	var live := await _capture(viewport)
	panel.hide()
	var shade := await _capture(viewport)
	panel.show()
	await process_frame
	if live == null or shade == null or live.is_empty() or shade.is_empty():
		_check(false, context + ": missing viewport readback")
		viewport.queue_free()
		return
	var bounds := _bounds(panel)
	var frame := Rect2(Vector2.ZERO, Vector2(dimensions))
	var baseline := shade.get_pixel(1, 1).a
	_check(baseline > 0.1 and baseline < 0.85 and absf(live.get_pixel(1, 1).a - baseline) < 0.01,
		context + ": transparent viewport preserves dimmer outside paper")
	if frame.grow(-1).encloses(bounds):
		for edge in range(4):
			_edge(live, shade, bounds, edge, context)
		_check(_solid(live, bounds.grow_individual(-bounds.size.x * 0.18, -bounds.size.y * 0.20,
			-bounds.size.x * 0.18, -bounds.size.y * 0.20)), context + ": continuous opaque core")
		_controls(live, panel, bounds, settings, context)
	else:
		_check(false, context + ": page must fit inside viewport")
	viewport.queue_free()

func _capture(viewport: SubViewport) -> Image:
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func _bounds(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func _edge(live: Image, shade: Image, bounds: Rect2, edge: int, context: String) -> void:
	var horizontal := edge < 2
	var reverse := edge % 2 == 1
	var origin := bounds.position if not reverse else bounds.end
	var length := bounds.size.x if horizontal else bounds.size.y
	var normal_span := bounds.size.y if horizontal else bounds.size.x
	var depths: Array[int] = []
	# Skip each corner, where ordinary rounded rectangles also vary in depth.
	for t in range(ceili(length * 0.15), floori(length * 0.85)):
		var clear_depth := 0
		for d in range(ceili(normal_span * 0.12)):
			var along := (bounds.position.x if horizontal else bounds.position.y) + t + 0.5
			var inward := (origin.y if horizontal else origin.x) + (-1 if reverse else 1) * (d + 0.5)
			var p := Vector2i(Vector2(along, inward) if horizontal else Vector2(inward, along))
			var actual := live.get_pixelv(p)
			var base := shade.get_pixelv(p)
			# Both alpha AND color must match the dimmer; ink can be dark but is not clear.
			if absf(actual.a - base.a) > 0.012 or absf(actual.r - base.r) > 0.02 \
					or absf(actual.g - base.g) > 0.02 or absf(actual.b - base.b) > 0.02:
				break
			clear_depth += 1
		depths.append(clear_depth)
	depths.sort()
	var shallow := depths[floori(depths.size() * 0.10)]
	var deep := depths[floori(depths.size() * 0.90)]
	var minimum := maxi(1, roundi(normal_span * 0.004))
	var side: String = ["top", "bottom", "left", "right"][edge]
	print("paper_edge_checks: %s %s clear depth p10/p90=%d/%d px" % [context, side, shallow, deep])
	_check(deep - shallow >= minimum, context + ": varying transparent inset on " + side)

func _solid(image: Image, area: Rect2) -> bool:
	var gaps := 0
	var count := 0
	for y in range(ceili(area.position.y), floori(area.end.y)):
		for x in range(ceili(area.position.x), floori(area.end.x)):
			count += 1
			if image.get_pixel(x, y).a < 0.98:
				gaps += 1
	return count > 0 and gaps == 0

func _controls(image: Image, panel: Control, bounds: Rect2, settings: bool, context: String) -> void:
	var names := ["Save", "Load", "Bindings", "Resume"] if settings else ["Close", "Items", "Description"]
	for id in names:
		_check(panel.get_node_or_null(NodePath(id)) is Control, context + ": expected control " + id)
	for child in panel.get_children():
		if not child is Control or not child.is_visible_in_tree() or not (child is Label or child is Button or child is ItemList or child is RichTextLabel):
			continue
		var area := _bounds(child)
		_check(bounds.encloses(area) and _solid(image, area), context + ": paper supports " + str(child.name))
		if child is Button:
			_check(not child.disabled and child.mouse_filter != Control.MOUSE_FILTER_IGNORE,
				context + ": enabled clickable " + str(child.name))
		if child is Label or child is Button:
			var font: Font = child.get_theme_font("font")
			var font_size: int = child.get_theme_font_size("font_size")
			if not child is Label or child.autowrap_mode == TextServer.AUTOWRAP_OFF:
				_check(font.get_string_size(child.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= child.size.x + 1.0,
					context + ": text fits " + str(child.name))

func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error("paper_edge_checks: " + description)
