extends SceneTree
## godot --headless --path . --script res://tests/inventory_ui_checks.gd

const State = preload("res://scripts/foundation/world_state.gd")
const Hud = preload("res://scripts/ui/field_hud.gd")
var _failures := 0
var _close_requests := 0

class Definition extends Resource:
	var definition_id: String = "item.test"
	var title: String = "Test item"
	var description: String = "The definition's description."
	var rarity: int = 0
	var icon: Texture2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var surface := Control.new()
	root.add_child(surface)
	# A future scene needn't know FieldHUD's builder: the project theme supplies the paper.
	var unstyled_page := Panel.new()
	surface.add_child(unstyled_page)
	_check(unstyled_page.get_theme_stylebox("panel") == preload("res://scripts/ui/parchment_theme.tres").get_stylebox("panel", "Panel"), "new panels inherit the project vellum")
	unstyled_page.queue_free()
	var hud := Hud.new()
	hud.set_hint("First steps")
	hud.feedback("Feedback")
	surface.add_child(hud)
	var definition := Definition.new()
	var card := hud.get_node("InventoryOverlay/Parchment") as Panel
	var overlay := card.get_parent() as ColorRect
	var list := card.get_node("Items") as ItemList
	var details := card.get_node("Description") as RichTextLabel
	var close := card.get_node("Close") as Button
	_check(not hud.inventory_open and not overlay.visible, "closed by default")
	_check(hud.mouse_filter == Control.MOUSE_FILTER_IGNORE and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD and overlay do not intercept world mouse")
	for dimensions in [Vector2(960, 540), Vector2(480, 270), Vector2(320, 180)]:
		surface.size = dimensions
		await process_frame
		_check(hud.size == dimensions and overlay.size == dimensions, "full-window HUD: %s" % dimensions)
		var end := card.position + card.size * card.scale
		_check(card.position.x > 0 and card.position.y > 0 and end.x < dimensions.x and end.y < dimensions.y, "card inset: %s" % dimensions)
	hud.show_inventory({"item.other": 8}, definition)
	_check(hud.inventory_open and overlay.visible and list.item_count == 0 and list.has_focus(), "empty and undefined inventory keeps focus in its own region")
	hud.show_inventory({definition.definition_id: 3, "item.other": 8}, definition)
	_check(list.item_count == 1 and list.is_selected(0) and list.has_focus(), "one selected item")
	_check(list.get_item_metadata(0) == "×3" and details.text == definition.description, "quantity and description")
	_check(list.get_item_icon(0) == null, "iconless definition renders without a texture")
	definition.icon = GradientTexture2D.new()
	hud.show_inventory({definition.definition_id: 3}, definition)
	_check(list.get_item_icon(0) == definition.icon, "single custom definition supplies its icon")
	hud.close_requested.connect(func() -> void: _close_requests += 1)
	close.pressed.emit()
	_check(_close_requests == 1 and hud.inventory_open, "close request leaves visibility to scene")
	hud.hide_inventory()
	_check(not hud.inventory_open and not overlay.visible, "scene closes inventory")
	var stock := {"item.bread": 2, "item.cup": 1, "item.sample": 7}
	hud.show_inventory(stock, State.DEFINITIONS)
	_check(list.item_count == 3, "all three known definitions make rows")
	var expected_ids := ["item.bread", "item.cup", "item.sample"]
	for index in range(list.item_count):
		var expected_icon: Texture2D = State.DEFINITIONS[expected_ids[index]].icon
		_check(expected_icon != null and list.get_item_icon(index) == expected_icon, "row uses its own definition texture")
	list.select(1)
	list.item_selected.emit(1)
	_check(details.text == State.DEFINITIONS["item.cup"].description, "selection changes description")
	stock["item.cup"] = 4
	hud.show_inventory(stock, State.DEFINITIONS)
	_check(list.is_selected(1) and list.get_item_metadata(1) == "×4", "refresh preserves selection and updates quantity")
	hud.hide_inventory()
	var tip := hud.get_node("PickupTip") as Panel
	var rows := PackedStringArray(["优先物品 × 2", "另一物品 × 1"])
	for dimensions in [Vector2(960, 540), Vector2(480, 270), Vector2(320, 180)]:
		surface.size = dimensions
		await process_frame
		var bounds := Rect2(Vector2(8, 8), dimensions - Vector2(16, 16))
		for anchor in [bounds.position, bounds.end, Vector2(bounds.end.x, bounds.position.y), bounds.get_center()]:
			hud.show_pickup_tip(anchor, rows, "交互：拾取", bounds)
			_check(tip.visible and bounds.encloses(tip.get_global_transform() * Rect2(Vector2.ZERO, tip.size)), "tip stays within supplied bounds")
			_check((tip.get_child(0) as Label).text.begins_with("◆ " + rows[0]), "first row remains first")
	var crowded := rows.duplicate()
	for index in range(24):
		crowded.append("备用物品 %d" % index)
	var tight := Rect2(14, 14, 200, 75)
	hud.show_pickup_tip(Vector2(24, 24), crowded, "交互：拾取", tight)
	_check(tip.visible and tight.encloses(tip.get_global_transform() * Rect2(Vector2.ZERO, tip.size)), "crowded tip remains within bounds")
	var content := (tip.get_child(0) as Label).text
	_check(content.begins_with("◆ " + rows[0]) and content.contains("另有"), "crowded tip retains primary row and summarizes overflow")
	_check(tip.mouse_filter == Control.MOUSE_FILTER_IGNORE and (tip.get_child(0) as Label).mouse_filter == Control.MOUSE_FILTER_IGNORE, "tip does not capture mouse")
	hud.show_inventory(stock, State.DEFINITIONS)
	_check(not tip.visible, "inventory suppresses tip")
	hud.hide_inventory()
	hud.show_pickup_tip(Vector2(100, 100), rows, "交互：拾取", Rect2(Vector2.ZERO, hud.size))
	hud.hide_pickup_tip()
	_check(not tip.visible, "scene can clear tip for menus or transitions")
	var timer := hud.get_child(2) as Timer
	_check(not timer.is_stopped(), "feedback timer active")
	var feedback_label := hud.get_child(1) as Label
	hud.feedback("B 行囊  ·  F10 设置  ·  右下角可打开旅途手册  ·  这是一条较长的反馈")
	await process_frame
	var launcher_area := Rect2(Vector2(272, 154), Vector2(43, 22))
	_check(feedback_label.visible and not (feedback_label.get_global_transform() * Rect2(Vector2.ZERO, feedback_label.size)).intersects(launcher_area), "320px feedback leaves settings launcher clear")
	hud.feedback("")
	_check(timer.is_stopped(), "feedback can clear immediately")
	if _failures == 0:
		print("inventory_ui_checks: PASS")
	quit(_failures)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error("inventory_ui_checks: %s" % label)
