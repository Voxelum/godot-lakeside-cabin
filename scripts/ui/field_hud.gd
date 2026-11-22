extends Control
## The scene owns input routing, state, and pausing.
signal close_requested

const Paper = preload("res://scripts/ui/parchment.gd")
const INK := Paper.INK
# Leave a clear gutter for the field's bottom-right settings launcher.
const BOTTOM_LEFT_GUTTER := 8.0
const BOTTOM_RIGHT_GUTTER := 56.0
const CARD_SIZE := Vector2(308, 180)
const PAGE_INSET := Vector2(10, 10) # Working area sits inside the torn perimeter.
var inventory_open := false
var _hint_text := ""
var _notice_text := ""
var _entries: Array[Dictionary] = []
var _count := 0
var _hint: Label
var _notice: Label
var _timer: Timer
var _shade: ColorRect
var _card: Panel
var _list: ItemList
var _empty: Label
var _details: RichTextLabel
var _total: Label
var _close: Button
var _tip: PickupTip
var _tip_label: Label
var _tip_prompt: Label
var _tip_rows := PackedStringArray()
var _tip_action := ""
var _tip_area := Vector2.ZERO


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = Paper.make_theme()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_hint = _label(self, "", Rect2(), 12)
	_notice = _label(self, "", Rect2(), 12)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label in [_hint, _notice]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.theme_type_variation = &"PaperFeedback"
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(func() -> void: feedback(""))
	add_child(_timer)
	_build_tip()
	_build_inventory()
	resized.connect(_layout)
	_layout()
	feedback(_notice_text)
	_render_inventory(inventory_open)


func set_hint(text: String) -> void:
	_hint_text = text
	_update_hud()


func feedback(text: String) -> void:
	_notice_text = text
	_update_hud()
	if is_instance_valid(_timer):
		_timer.stop()
		if not text.is_empty():
			_timer.start(2.6)


func show_inventory(inventory: Dictionary, definitions: Variant) -> void:
	var was_open := inventory_open
	var had_entry := not _entries.is_empty()
	var selected_id := ""
	if is_instance_valid(_list) and not _list.get_selected_items().is_empty():
		selected_id = _entries[_list.get_selected_items()[0]].id
	_entries.clear()
	_count = 0
	var by_id: Dictionary = {}
	if definitions is Dictionary:
		by_id = definitions
	elif definitions is Resource:
		by_id[String(definitions.get("definition_id"))] = definitions
	var ids := by_id.keys()
	ids.sort()
	for key in ids:
		var id := String(key)
		var definition := by_id[key] as Resource
		var quantity := maxi(0, int(inventory.get(id, 0)))
		if definition == null or quantity == 0 or id.is_empty():
			continue
		var title := String(definition.get("title"))
		var icon: Texture2D = definition.get("icon") as Texture2D if "icon" in definition else null
		_entries.append({"id": id, "title": id if title.is_empty() else title,
			"description": String(definition.get("description")), "quantity": quantity, "icon": icon})
		_count += quantity
	inventory_open = true
	hide_pickup_tip()
	if is_instance_valid(_shade):
		_render_inventory(not was_open or had_entry != (not _entries.is_empty()), selected_id)
	_update_hud()


func hide_inventory() -> void:
	inventory_open = false
	if is_instance_valid(_shade):
		_shade.hide()
	_update_hud()


func _build_inventory() -> void:
	_shade = ColorRect.new()
	_shade.name = "InventoryOverlay"
	_shade.color = Color(0, 0, 0, 0.52)
	_shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_card = Panel.new()
	_card.name = "Parchment"
	_card.mouse_filter = MOUSE_FILTER_IGNORE
	_shade.add_child(_card)
	_card.size = CARD_SIZE
	_label(_card, "随身行囊", Rect2(11, 6, 90, 22), 16)
	_total = _label(_card, "", Rect2(103, 10, 119, 17), 11)
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_close = Button.new()
	_close.name = "Close"
	_close.text = "关闭"
	_close.position = Vector2(233, 7)
	_close.size = Vector2(44, 21)
	_close.add_theme_font_size_override("font_size", 12)
	_close.pressed.connect(func() -> void: close_requested.emit())
	_card.add_child(_close)

	var satchel := TextureRect.new()
	satchel.mouse_filter = MOUSE_FILTER_IGNORE
	satchel.texture = preload("res://art/ui/satchel.svg")
	satchel.position = Vector2(7, 27)
	_card.add_child(satchel)

	_list = ItemList.new()
	_list.name = "Items"
	_list.position = Vector2(95, 32)
	_list.size = Vector2(182, 73)
	_list.add_theme_font_size_override("font_size", 13)
	_list.fixed_icon_size = Vector2i(19, 19)
	_list.item_selected.connect(func(_index: int) -> void: _update_details())
	_card.add_child(_list)
	_empty = _label(_card, "行囊是空的", Rect2(_list.position, _list.size), 13)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_details = RichTextLabel.new()
	_details.name = "Description"
	_details.position = Vector2(10, 110)
	_details.size = Vector2(267, 40)
	_details.mouse_filter = MOUSE_FILTER_PASS
	_details.focus_mode = FOCUS_NONE
	_details.add_theme_font_size_override("normal_font_size", 12)
	_details.add_theme_color_override("default_color", INK)
	_details.theme_type_variation = &"PaperDescription"
	_card.add_child(_details)
	for child: Control in _card.get_children(): child.position += PAGE_INSET
	_list.focus_neighbor_top = _list.get_path_to(_close)


func _render_inventory(move_focus: bool, selected_id := "") -> void:
	_list.clear()
	_total.text = "合计 × %d" % _count
	_empty.visible = _count == 0
	_list.focus_mode = FOCUS_ALL if _count > 0 else FOCUS_NONE
	_close.focus_neighbor_bottom = _close.get_path_to(_list) if _count > 0 else NodePath()
	var selected := 0
	for entry in _entries:
		var index := _list.add_item("%s  × %d" % [entry.title, entry.quantity], entry.icon)
		_list.set_item_tooltip(index, entry.title)
		if entry.id == selected_id:
			selected = index
	if _count > 0:
		_list.select(selected)
		_list.ensure_current_is_visible()

	_update_details()
	_shade.visible = inventory_open
	if inventory_open and move_focus:
		if _count > 0:
			_list.grab_focus()
		else:
			_close.grab_focus()


func _update_details() -> void:
	var selected := _list.get_selected_items()
	if not selected.is_empty():
		var description: String = _entries[selected[0]].description
		_details.text = description if not description.is_empty() else "暂无物品说明。"
	else:
		_details.text = "拾取物品后，会在此显示说明。"
	_details.scroll_to_line(0)


func _layout() -> void:
	var card_scale := minf(2.4, minf((size.x - 16.0) / CARD_SIZE.x, (size.y - 16.0) / CARD_SIZE.y))
	_card.scale = Vector2.ONE * maxf(0.01, card_scale)
	_card.position = ((size - CARD_SIZE * _card.scale) * 0.5).round()
	_update_hud()


func _update_hud() -> void:
	if not is_instance_valid(_notice):
		return
	var y := size.y - 6.0
	var usable_width := maxf(1, size.x - BOTTOM_LEFT_GUTTER - BOTTOM_RIGHT_GUTTER)
	for label in [_hint, _notice]:
		label.text = _hint_text if label == _hint else _notice_text
		label.visible = not inventory_open and not label.text.is_empty() and (label != _hint or not _tip.visible)
		if not label.visible:
			continue
		var font_size := clampi(roundi(size.y / 30.0), 12, 18)
		label.add_theme_font_size_override("font_size", font_size)
		var width: float = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 18.0
		label.size = Vector2(minf(width, usable_width), 0)
		y -= label.size.y
		label.position = Vector2(roundf(BOTTOM_LEFT_GUTTER + (usable_width - label.size.x) * 0.5), y)
		y -= 3.0


func _label(parent: Control, text: String, rect: Rect2, font_size: int, color: Color = INK) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	label.position = rect.position
	label.size = rect.size
	return label


func _build_tip() -> void:
	_tip = PickupTip.new()
	_tip.name = "PickupTip"
	_tip.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_tip)
	_tip_label = _label(_tip, "", Rect2(), 13)
	_tip_prompt = _label(_tip, "", Rect2(), 12, Paper.CREAM)
	_tip_prompt.theme_type_variation = &"LeatherCaption"
	_tip.theme_type_variation = &"PaperSlip"
	_tip.hide()


func show_pickup_tip(anchor: Vector2, rows: PackedStringArray, action_text: String, bounds: Rect2) -> void:
	if not is_instance_valid(_tip):
		return
	var area := bounds.intersection(Rect2(Vector2.ZERO, size)).grow(-7.0)
	if inventory_open or rows.is_empty() or area.size.x < 52 or area.size.y < 44 or not anchor.is_finite():
		hide_pickup_tip()
		return
	if _tip_rows != rows or _tip_action != action_text or _tip_area != area.size:
		_tip_rows = rows.duplicate()
		_tip_action = action_text
		_tip_area = area.size
		var has_action := not action_text.is_empty()
		var font := _tip_label.get_theme_font("font")
		var line_height := ceilf(font.get_height(13))
		var spacing := float(_tip_label.get_theme_constant("line_spacing"))
		var decoration_height := 13.0
		if has_action:
			decoration_height = 21.0 + ceilf(_tip_prompt.get_theme_font("font").get_height(12))
		var capacity := maxi(1, floori((area.size.y - decoration_height + spacing) / (line_height + spacing)))
		var lines := rows.slice(0, mini(capacity, rows.size()))
		if rows.size() > capacity:
			if capacity > 1:
				lines.resize(capacity - 1)
				lines.append("另有 %d 项" % (rows.size() - lines.size()))
			else:
				lines[0] += "  +%d" % (rows.size() - 1)
		lines[0] = "◆ " + lines[0]
		for i in range(1, lines.size()):
			lines[i] = "· " + lines[i]
		var width := 112.0
		for line in lines:
			width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 20)
		width = maxf(width, font.get_string_size(action_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 30)
		width = minf(width, minf(270.0, area.size.x))
		_tip_label.text = "\n".join(lines)
		_tip_label.position = Vector2(10, 6)
		_tip_label.size = Vector2(width - 20, 0)
		_tip_prompt.visible = has_action
		_tip_prompt.text = action_text
		_tip_prompt.position = Vector2(9, _tip_label.size.y + 9)
		_tip_prompt.size = Vector2(width - 18, 0)
		_tip.size = Vector2(width, _tip_prompt.position.y + (_tip_prompt.size.y + 8.0 if has_action else 4.0))
	if _tip.size.y > area.size.y:
		hide_pickup_tip()
		return
	var y := anchor.y - _tip.size.y - 14.0
	if y < area.position.y and anchor.y + 14.0 + _tip.size.y <= area.end.y:
		y = anchor.y + 14.0
	_tip.position = Vector2(
		clampf(anchor.x - _tip.size.x * 0.5, area.position.x, area.end.x - _tip.size.x),
		clampf(y, area.position.y, maxf(area.position.y, area.end.y - _tip.size.y))).round()
	var pointer_x := clampf(anchor.x - _tip.position.x, 15, _tip.size.x - 15)
	var points_down := anchor.y >= _tip.position.y + _tip.size.y * 0.5
	var was_visible := _tip.visible
	_tip.point_at(pointer_x, points_down)
	_tip.show()
	if not was_visible:
		_update_hud()


func hide_pickup_tip() -> void:
	if is_instance_valid(_tip) and _tip.visible:
		_tip.hide()
		_update_hud()


class PickupTip extends Panel:
	var pointer_x := 0.0
	var down := true

	func point_at(x: float, points_down: bool) -> void:
		if x != pointer_x or down != points_down:
			pointer_x = x
			down = points_down
			queue_redraw()

	func _draw() -> void:
		var y := size.y - 4.0 if down else 2.0
		var left := Vector2(pointer_x - 6, y)
		var vertex := Vector2(pointer_x, y + (9.0 if down else -8.0))
		var right := Vector2(pointer_x + 6, y)
		draw_colored_polygon(PackedVector2Array([left, vertex, right]), Color("d5ad76"))
		draw_polyline(PackedVector2Array([left, vertex, right]), Color("865b36"), 1.0, true)
