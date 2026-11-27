extends Control
## The scene owns input routing, state, and pausing.
signal close_requested
signal equipment_requested(slot: String, id: String)

const Paper = preload("res://scripts/ui/parchment.gd")
const UI = preload("res://scripts/ui/ui_layout.gd")
var _ui: UI
const ActorSheet = preload("res://scripts/ui/actor_sheet.gd")
var actor_sheet: ActorSheet
var _weight_kg := 0.0

const INK := Paper.INK
# Leave a clear gutter for the field's bottom-right settings launcher.
const LAUNCHER_CLEARANCE := 62.0
const CARD_SIZE := Vector2(544, 246)
const PREVIEW_SIZE := Vector2i(128, 192)
const STAT_WIDTH := 127.0
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
var _equip_action: Button
var _slot_buttons: Dictionary = {}
var _attributes: RichTextLabel
var _stat_values: Array[Label] = []
var _stat_fills: Array[ColorRect] = []
var _portrait: SubViewport
var _portrait_model: Node3D
var _portrait_profile: StringName
var _equipped: Dictionary = {}
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
	_hint = _label(self, "", Rect2(), UI.AUX)
	_notice = _label(self, "", Rect2(), UI.AUX)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label in [_hint, _notice]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.theme_type_variation = &"PaperFeedback"
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(func() -> void: feedback(""))
	add_child(_timer)
	_ui = UI.attach(self)
	_build_tip()
	_build_inventory()
	actor_sheet = ActorSheet.new()
	actor_sheet.name = "ActorSheet"
	actor_sheet.ui = _ui
	add_child(actor_sheet)
	_ui.changed.connect(_layout)
	_layout()
	feedback(_notice_text)
	_shade.hide()


func refresh_attributes() -> void:
	if not is_instance_valid(actor_sheet): return
	var stats := actor_sheet.current_stats()
	if stats == null: return
	_stat_values[0].text = "%d/%d" % [stats.hp(), stats.max_hp()]
	_stat_values[1].text = "+%d" % stats.strength_bonus()
	_stat_values[2].text = "%d" % (stats.base_toughness() + stats.toughness_bonus())
	var ratios := [float(stats.hp()) / stats.max_hp(), fmod(stats.load_metres(), ActorSheet.Stats.STRENGTH_STEP) / ActorSheet.Stats.STRENGTH_STEP,
		float(stats.damage_taken() % ActorSheet.Stats.TOUGHNESS_STEP) / ActorSheet.Stats.TOUGHNESS_STEP]
	for i in range(3): _stat_fills[i].size.x = roundf(STAT_WIDTH * ratios[i])
	_stat_values[1].get_parent().tooltip_text = "成长 %.1f / %.0f 加权米" % [fmod(stats.load_metres(), ActorSheet.Stats.STRENGTH_STEP), ActorSheet.Stats.STRENGTH_STEP]
	_stat_values[2].get_parent().tooltip_text = "成长 %d / %d 实际掉血" % [stats.damage_taken() % ActorSheet.Stats.TOUGHNESS_STEP, ActorSheet.Stats.TOUGHNESS_STEP]


func focus_attributes() -> void:
	_attributes.grab_focus()


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


func show_inventory(inventory: Dictionary, definitions: Variant, weight_kg := 0.0, equipment: Dictionary = {}, slots: Dictionary = {}) -> void:
	_weight_kg = weight_kg
	_equipped = equipment
	var was_open := inventory_open
	var selected_id := ""
	if not _list.get_selected_items().is_empty():
		selected_id = _entries[_list.get_selected_items()[0]].id
	_entries.clear()
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
		if definition == null or quantity == 0 or id.is_empty(): continue
		var title := String(definition.get("title"))
		_entries.append({"slot": String(definition.get("equipment_slot")) if "equipment_slot" in definition else "",
			"id": id, "title": id if title.is_empty() else title, "quantity": quantity,
			"description": String(definition.get("description")), "icon": definition.get("icon")})
	for slot in _slot_buttons:
		var button: Button = _slot_buttons[slot]
		var item: Resource = by_id.get(equipment.get(slot, ""))
		var label: String = slots.get(slot, SLOT_LAYOUT[slot][0])
		button.get_node("Caption").text = label
		button.get_node("Icon").texture = item.icon if item else null
		button.get_node("Mark").visible = item == null
		button.modulate.a = 1.0 if item else 0.78
		button.tooltip_text = "%s · 确认卸下" % item.title if item else "%s · 空" % label
	inventory_open = true
	hide_pickup_tip()
	_shade.show()
	_portrait.render_target_update_mode = SubViewport.UPDATE_ONCE
	_render_inventory(not was_open, selected_id)
	refresh_attributes()
	_update_hud()


func hide_inventory() -> void:
	inventory_open = false
	_shade.hide()
	_update_hud()


# Slots surround a non-interactive silhouette; Main Hand includes 主武器.
const SLOT_LAYOUT := {
	"head": ["头部", Vector2(1, 0)], "main_hand": ["主手", Vector2(0, 1)],
	"off_hand": ["副手", Vector2(2, 1)], "clothes": ["衣服", Vector2(0, 0)],
	"pants": ["裤子", Vector2(2, 0)], "shoes": ["鞋", Vector2(1, 3)],
	"ring": ["戒指", Vector2(0, 2)], "pendant": ["吊坠", Vector2(2, 3)],
	"bracelet": ["手环", Vector2(2, 2)],
}

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
	_card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var vellum := ColorRect.new()
	vellum.name = "Vellum"
	vellum.mouse_filter = MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/ui/character_vellum.gdshader")
	vellum.material = material
	_card.add_child(vellum)
	vellum.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_close = _inventory_button("Close", "关闭", Rect2(476, 17, 46, 24))
	_close.pressed.connect(func() -> void: close_requested.emit())
	_label(_card, "装备", Rect2(22, 16, 104, 26), UI.TITLE).name = "EquipmentTitle"
	_label(_card, "行囊", Rect2(207, 16, 78, 24), UI.TITLE).name = "InventoryTitle"
	_label(_card, "属性", Rect2(390, 16, 64, 26), UI.TITLE).name = "AttributesTitle"
	_total = _label(_card, "", Rect2(207, 41, 145, 17), UI.AUX)
	_total.name = "CarriedWeight"
	_rule(_card, Rect2(190, 18, 1, 210), Color(0.35, 0.20, 0.12, 0.40))
	_rule(_card, Rect2(370, 18, 1, 210), Color(0.35, 0.20, 0.12, 0.40))
	_build_portrait()
	for slot in SLOT_LAYOUT:
		var coord: Vector2 = SLOT_LAYOUT[slot][1]
		var button := _inventory_button("Slot_" + slot, "", Rect2(Vector2(22, 51) + coord * Vector2(55, 47), Vector2(40, 36)))
		button.theme_type_variation = &"EquipmentSlot"
		button.size = Vector2(40, 36)
		var caption := _label(button, SLOT_LAYOUT[slot][0], Rect2(0, 18, 40, 16), UI.AUX)
		caption.name = "Caption"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(icon)
		icon.position = Vector2(12, 1)
		icon.size = Vector2(16, 16)
		var mark := SlotMark.new()
		mark.name = "Mark"
		mark.slot = slot
		mark.mouse_filter = MOUSE_FILTER_IGNORE
		button.add_child(mark)
		mark.position = Vector2(20, 10)
		button.pressed.connect(func() -> void: equipment_requested.emit(slot, ""))
		_slot_buttons[slot] = button

	_list = LedgerList.new()
	_list.name = "Items"
	_list.theme_type_variation = &"LedgerList"
	_list.position = Vector2(207, 62)
	_list.size = Vector2(145, 81)
	UI.ink(_list, UI.BODY)
	_list.add_theme_constant_override("h_separation", 3)
	_list.add_theme_constant_override("v_separation", 2)
	_list.fixed_icon_size = Vector2i(14, 14)
	_list.item_selected.connect(func(_index: int) -> void: _update_details())
	_list.item_activated.connect(func(_index: int) -> void: _activate_equipment())
	_card.add_child(_list)
	_empty = _label(_card, "行囊是空的", Rect2(_list.position, _list.size), UI.BODY)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rule(_card, Rect2(207, 148, 145, 1), Color(0.35, 0.20, 0.12, 0.25))
	_details = _paper_text("Description", Rect2(207, 154, 145, 43), UI.BODY)
	_details.focus_mode = FOCUS_ALL
	_equip_action = _inventory_button("EquipmentAction", "装备", Rect2(207, 204, 145, 25))
	_equip_action.pressed.connect(_activate_equipment)
	_attributes = _paper_text("Attributes", Rect2(391, 53, 131, 171), UI.BODY)
	_attributes.focus_mode = FOCUS_ALL
	_attributes.scroll_active = false
	_build_stats()
	_list.focus_neighbor_top = _list.get_path_to(_close)
	_list.focus_neighbor_left = _list.get_path_to(_slot_buttons.main_hand)
	_list.focus_neighbor_right = _list.get_path_to(_attributes)
	_list.focus_neighbor_bottom = _list.get_path_to(_details)
	_details.focus_neighbor_top = _details.get_path_to(_list)
	_details.focus_neighbor_right = _details.get_path_to(_attributes)
	_details.focus_neighbor_bottom = _details.get_path_to(_equip_action)
	_equip_action.focus_neighbor_top = _equip_action.get_path_to(_details)
	_equip_action.focus_neighbor_right = _equip_action.get_path_to(_attributes)
	_attributes.focus_neighbor_left = _attributes.get_path_to(_list)
	_attributes.focus_neighbor_top = _attributes.get_path_to(_close)
	_close.focus_neighbor_bottom = _close.get_path_to(_attributes)
	for slot in ["pants", "off_hand", "bracelet", "shoes", "pendant"]:
		var button: Button = _slot_buttons[slot]
		button.focus_neighbor_right = button.get_path_to(_list)
	_slot_buttons.main_hand.focus_neighbor_right = _slot_buttons.main_hand.get_path_to(_slot_buttons.off_hand)


func _paper_text(node_name: String, rect: Rect2, font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.name = node_name
	label.position = rect.position
	label.size = rect.size
	UI.ink(label, font_size)
	label.add_theme_constant_override("line_separation", -2)
	label.add_theme_color_override("default_color", INK)
	label.theme_type_variation = &"LedgerNote"
	_card.add_child(label)
	_compact_box(label, "normal", 2.0, 1.0)
	label.add_theme_stylebox_override("focus", _list.get_theme_stylebox("focus"))
	return label


func _compact_box(control: Control, style_name: String, x: float, y: float) -> void:
	var compact: StyleBox = control.get_theme_stylebox(style_name).duplicate()
	compact.content_margin_left = x
	compact.content_margin_right = x
	compact.content_margin_top = y
	compact.content_margin_bottom = y
	control.add_theme_stylebox_override(style_name, compact)


func _inventory_button(button_name: String, text: String, rect: Rect2) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	UI.ink(button, UI.AUX)
	_card.add_child(button)
	if not text.is_empty():
		for state in ["normal", "hover", "pressed", "disabled"]:
			_compact_box(button, state, 4.0, 1.0)
	button.position = rect.position
	button.size = rect.size
	return button


func _activate_equipment() -> void:
	var selected := _list.get_selected_items()
	if selected.is_empty() or _equip_action.disabled: return
	var entry := _entries[selected[0]]
	equipment_requested.emit(entry.slot, "" if _equipped.get(entry.slot) == entry.id else entry.id)


func _render_inventory(move_focus: bool, selected_id := "") -> void:
	_list.clear()
	_total.text = "负重 %.2f kg" % _weight_kg
	_empty.visible = _entries.is_empty()
	var selected := 0
	for entry in _entries:
		var font := _list.get_theme_font("font")
		var pt := _list.get_theme_font_size("font_size")
		var count := "×%d" % entry.quantity
		# Reserve icon, gutter, and scrollbar even before the list starts scrolling.
		var room := _list.size.x - _list.get_v_scroll_bar().get_combined_minimum_size().x - 26.0
		room -= font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, pt).x
		var title: String = entry.title
		while title.length() > 1 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, pt).x > room:
			title = title.left(-1)
		if title != entry.title: title = title.left(-1) + "…"
		var index := _list.add_item(title, entry.icon)
		_list.set_item_metadata(index, count)
		_list.set_item_tooltip(index, entry.title)
		if entry.id == selected_id: selected = index
	if not _entries.is_empty():
		_list.select(selected)
		_list.ensure_current_is_visible()
	_update_details()
	if move_focus: _list.grab_focus()


func _update_details() -> void:
	var selected := _list.get_selected_items()
	var entry := {} if selected.is_empty() else _entries[selected[0]]
	_details.text = entry.get("description", "拾取后显示说明。")
	_details.scroll_to_line(0)
	_equip_action.disabled = entry.get("slot", "").is_empty()
	_equip_action.text = "卸下" if not _equip_action.disabled and _equipped.get(entry.slot) == entry.id else "装备"
	_list.queue_redraw()
	if _equip_action.disabled and _equip_action.has_focus(): _list.grab_focus()


func _rule(parent: Control, rect: Rect2, color: Color) -> ColorRect:
	var rule := ColorRect.new()
	rule.color = color
	rule.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(rule)
	rule.position = rect.position
	rule.size = rect.size
	return rule


const IsaacLook := preload("res://art/character_trial/isaac/isaac_look.gd")
const CastRig := preload("res://art/character_trial/cast_rig.gd")
const Courier := preload("res://art/courier/Courier.tscn")

func set_portrait_look(appearance: Node3D) -> void:
	var profile: StringName = appearance.profile if appearance is IsaacLook or appearance is CastRig else &"courier"
	if _portrait_model != null and _portrait_profile == profile: return
	if _portrait_model != null:
		_portrait.remove_child(_portrait_model)
		_portrait_model.queue_free()
	_portrait_profile = profile
	if appearance is IsaacLook:
		_portrait_model = IsaacLook.new()
	elif appearance is CastRig:
		var rig := CastRig.new()
		rig.profile = profile
		_portrait_model = rig
	else:
		_portrait_model = Courier.instantiate() as Node3D
	_portrait.add_child(_portrait_model)
	_portrait_model.call(&"reset_pose", Vector3.BACK)


func _build_portrait() -> void:
	_portrait = SubViewport.new()
	_portrait.name = "CourierPortrait"
	_portrait.size = PREVIEW_SIZE
	_portrait.own_world_3d = true
	_portrait.transparent_bg = true
	_portrait.gui_disable_input = true
	_portrait.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_card.add_child(_portrait)
	set_portrait_look(null)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 2.45
	_portrait.add_child(camera)
	camera.position = Vector3(1.0, 1.38, 4.0)
	camera.look_at(Vector3(0, 0.92, 0))
	camera.current = true
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-36, 27, 0)
	key.light_energy = 1.1
	_portrait.add_child(key)
	var world_light := WorldEnvironment.new()
	world_light.environment = Environment.new()
	world_light.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_light.environment.ambient_light_color = Color("efd9b7")
	world_light.environment.ambient_light_energy = 0.65
	_portrait.add_child(world_light)
	var view := TextureRect.new()
	view.name = "Preview"
	view.mouse_filter = MOUSE_FILTER_IGNORE
	view.texture_filter = TEXTURE_FILTER_LINEAR
	# The texture resolution must not become a Control minimum size.
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.texture = _portrait.get_texture()
	_card.add_child(view)
	view.position = Vector2(65, 92)
	view.size = Vector2(PREVIEW_SIZE) * .5


func _build_stats() -> void:
	for i in range(3):
		var y := 1.0 + 26.0 * i
		var row := Control.new()
		_attributes.add_child(row)
		row.position = Vector2(2, y)
		row.size = Vector2(STAT_WIDTH, 24)
		row.mouse_filter = MOUSE_FILTER_PASS
		_label(row, ["生命", "力量", "韧性"][i], Rect2(0, 0, 46, 20), UI.BODY)
		var value := _label(row, "—", Rect2(46, 0, STAT_WIDTH - 46, 20), UI.BODY)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stat_values.append(value)
		var bar := _rule(row, Rect2(0, 21, STAT_WIDTH, 2), Color(0.35, 0.20, 0.12, 0.25))
		_stat_fills.append(_rule(bar, Rect2(0, 0, 0, bar.size.y), Color("842f2b" if i == 0 else "ad7827")))
	for i in range(4):
		_label(_attributes, ["敏捷", "感知", "意志", "法力"][i], Rect2(2, 86 + i * 20, 46, 18), UI.BODY, Color("624834"))
		var state := _label(_attributes, "未开放" if i == 3 else "未启用", Rect2(50, 86 + i * 20, STAT_WIDTH - 48, 18), UI.AUX, Color("624834"))
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


class SlotMark extends Control:
	var slot: String
	func _draw() -> void:
		var color := Color("806149")
		match slot:
			"head": draw_polyline(PackedVector2Array([Vector2(-4, 3), Vector2(-4, -1), Vector2(-2, -4), Vector2(2, -4), Vector2(4, -1), Vector2(4, 3), Vector2(0, 0), Vector2(-4, 3)]), color)
			"main_hand":
				draw_line(Vector2(-4, 4), Vector2(4, -4), color, 2)
				draw_line(Vector2(-4, 0), Vector2(0, 4), color, 1)
			"off_hand": draw_colored_polygon(PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(3, 1), Vector2(0, 5), Vector2(-3, 1)]), color)
			"clothes": draw_colored_polygon(PackedVector2Array([Vector2(-2, -4), Vector2(2, -4), Vector2(5, -2), Vector2(4, 1), Vector2(2, 0), Vector2(2, 4), Vector2(-2, 4), Vector2(-2, 0), Vector2(-4, 1), Vector2(-5, -2)]), color)
			"pants":
				draw_rect(Rect2(-4, -4, 8, 3), color)
				draw_rect(Rect2(-4, -2, 3, 6), color)
				draw_rect(Rect2(1, -2, 3, 6), color)
			"shoes":
				draw_rect(Rect2(-3, -4, 4, 7), color)
				draw_rect(Rect2(-3, 1, 8, 3), color)
			"ring":
				draw_arc(Vector2(0, 1), 3, 0, TAU, 12, color, 1)
				draw_circle(Vector2(0, -3), 1.6, color)
			"pendant":
				draw_line(Vector2(-3, -4), Vector2(0, 1), color, 1)
				draw_line(Vector2(3, -4), Vector2(0, 1), color, 1)
				draw_circle(Vector2(0, 2), 2.2, color)
			"bracelet": draw_arc(Vector2.ZERO, 4, 0.4, TAU - 0.4, 16, color, 2)


class LedgerList extends ItemList:
	func _ready() -> void:
		clip_contents = true
		get_v_scroll_bar().value_changed.connect(func(_value: float): queue_redraw())

	func _draw() -> void:
		var font := get_theme_font("font")
		var pt := get_theme_font_size("font_size")
		var scroll := get_v_scroll_bar()
		var right := size.x - (scroll.size.x if scroll.visible else 0.0) - 4.0
		for i in range(item_count):
			var rect := get_item_rect(i)
			rect.position.y -= scroll.value
			if rect.end.y < 0 or rect.position.y > size.y: continue
			var count := String(get_item_metadata(i))
			var width := font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, pt).x
			var baseline := rect.position.y + (rect.size.y - font.get_height(pt)) * 0.5 + font.get_ascent(pt)
			draw_string(font, Vector2(right - width, baseline), count, HORIZONTAL_ALIGNMENT_LEFT, -1, pt,
				get_theme_color("font_selected_color" if is_selected(i) else "font_color"))


func _layout() -> void:
	_ui.place(_card, Rect2(UI.SAFE.get_center() - CARD_SIZE * .5, CARD_SIZE))
	# The next projection from FieldSession will place any live world-space tip.
	hide_pickup_tip()
	_update_hud()


func _update_hud() -> void:
	if not is_instance_valid(_notice):
		return
	if is_instance_valid(actor_sheet) and is_instance_valid(actor_sheet.launcher):
		actor_sheet.set_launcher_visible(not inventory_open)
	var y := UI.SAFE.end.y
	var usable_width := UI.SAFE.size.x - LAUNCHER_CLEARANCE
	for label in [_hint, _notice]:
		label.text = _hint_text if label == _hint else _notice_text
		label.visible = not inventory_open and not label.text.is_empty() and (label != _hint or not _tip.visible)
		if not label.visible:
			continue
		# Measure the actual PaperFeedback margins and reserve a complete text
		# line even while Autowrap recalculates after a hit. A zero-height strip
		# could otherwise hide the damage feedback; +18 was less than the paper inset.
		var font: Font = label.get_theme_font("font")
		var pt: int = label.get_theme_font_size("font_size")
		var margin: Vector2 = label.get_theme_stylebox("normal").get_minimum_size()
		var full := font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,pt)
		var w := minf(usable_width,ceilf(full.x)+margin.x+8.0)
		var wrapped := font.get_multiline_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,maxf(1.0,w-margin.x),pt)
		var h := ceilf(maxf(full.y,wrapped.y))+margin.y+2.0
		y -= h
		_ui.place(label, Rect2(UI.SAFE.position.x + (usable_width - w) * .5, y, w, h))
		y -= 3.0


func _label(parent: Control, text: String, rect: Rect2, font_size: int, color: Color = INK) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.text = text
	UI.ink(label, font_size)
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
	_tip_label = _label(_tip, "", Rect2(), UI.BODY)
	_tip_prompt = _label(_tip, "", Rect2(), UI.AUX, Paper.CREAM)
	_tip_prompt.theme_type_variation = &"LeatherCaption"
	_tip.theme_type_variation = &"PaperSlip"
	_tip.hide()


func show_pickup_tip(anchor: Vector2, rows: PackedStringArray, action_text: String, bounds: Rect2) -> void:
	if not is_instance_valid(_tip):
		return
	var area := _ui.rect_to_logical(bounds).intersection(UI.SAFE).grow(-8.0)
	anchor = _ui.to_logical(anchor)
	if inventory_open or rows.is_empty() or area.size.x < 52 or area.size.y < 44 or not anchor.is_finite():
		hide_pickup_tip()
		return
	if _tip_rows != rows or _tip_action != action_text or _tip_area != area.size:
		_tip_rows = rows.duplicate()
		_tip_action = action_text
		_tip_area = area.size
		var has_action := not action_text.is_empty()
		var font := _tip_label.get_theme_font("font")
		var line_height := ceilf(font.get_height(UI.BODY))
		var spacing := float(_tip_label.get_theme_constant("line_spacing"))
		var decoration_height := 13.0
		if has_action:
			decoration_height = 21.0 + ceilf(_tip_prompt.get_theme_font("font").get_height(UI.AUX))
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
			width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.BODY).x + 20)
		width = maxf(width, font.get_string_size(action_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.AUX).x + 30)
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
	var location := Vector2(
		clampf(anchor.x - _tip.size.x * 0.5, area.position.x, area.end.x - _tip.size.x),
		clampf(y, area.position.y, maxf(area.position.y, area.end.y - _tip.size.y)))
	_ui.place(_tip, Rect2(location, _tip.size))
	var pointer_x := clampf(anchor.x - location.x, 15, _tip.size.x - 15)
	var points_down := anchor.y >= location.y + _tip.size.y * 0.5
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
