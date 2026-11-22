extends Node
## Local coordinator. Neither Walker, the UI nor a loaded region owns a second inventory or clock.
signal attack_requested
const State := preload("res://scripts/foundation/world_state.gd")
const Target := preload("res://scripts/interaction/stack_target.gd")
const Choice := preload("res://scripts/interaction/target_choice.gd")
const REGION_VIEW := preload("res://world/RegionReadout.tscn")
const Bindings := preload("res://scripts/controls/binding_store.gd")
var state := State.new()
var slot_path: String = State.SLOT
@onready var host = get_parent()
@onready var hud = $"../FieldHUD"
@onready var bindings = $"../BindingPanel"
@onready var book = $"../SettingsBook"
@onready var screen: TextureRect = $"../Screen"
@onready var region_layer: Node3D = $"../Pixels/Clearing/RegionViews"
@onready var bank_anchor: Marker3D = $"../Pixels/Clearing/BankDisplayAnchor"
@onready var rise_anchor: Marker3D = $"../Pixels/Clearing/RiseDisplayAnchor"
@onready var seam: Marker3D = $"../Pixels/Clearing/TestRegionSeam"
var region_view
var _field_targets: Array[Target] = []
var _room_targets: Array[Target] = []
var _tip_source: Target
var _tip_rows := PackedStringArray()
var _tip_action := ""
var _axis_held := {}

func start() -> void:
	var seen := {}
	for target: Target in get_tree().get_nodes_in_group(&"test_stack_source"):
		if host.field.is_ancestor_of(target): _field_targets.append(target)
		elif host.room.is_ancestor_of(target): _room_targets.append(target)
		else: continue
		var id := target.instance_id
		if id.strip_edges().is_empty() or target.definition == null or State.DEFINITIONS.get(target.definition.definition_id) != target.definition or seen.has(id):
			target.valid_source = false
			if seen.has(id): seen[id].valid_source = false
			push_error("测试物件的实例 ID 重复/为空，或定义无效：%s" % id)
		seen[id] = target
	hud.close_requested.connect(_close_inventory)
	book.open_requested.connect(_open_settings)
	book.close_requested.connect(_close_settings)
	book.save_requested.connect(_save_slot)
	book.load_requested.connect(_read_slot)
	book.bindings_requested.connect(_open_bindings)
	bindings.closed.connect(_back_to_settings)
	# The display camera follows in _process at priority 10; project the tag after it.
	process_priority = 20
	place_changed()
	if FileAccess.file_exists(slot_path): _read_slot()
	else: hud.feedback("%s 行囊  ·  %s 设置  ·  右下角可打开旅途手册" % [_binding_name(&"inventory"), _binding_name(&"bindings")])

func is_modal() -> bool:
	return hud.inventory_open or bindings.visible or book.opened

func _targets() -> Array[Target]:
	return _room_targets if host.indoors else _field_targets

func place_changed() -> void:
	state.location_id = "place.cabin" if host.indoors else "place.clearing"
	state.position = host.active_actor().global_position
	# Both World3Ds stay alive. Cancel flights in the departed world as well.
	for target in _field_targets: target.refresh(state)
	for target in _room_targets: target.refresh(state)
	_region_display(true)
	_refresh_nearby()

func stepped(at: Vector3) -> void:
	if state.position == at: return
	state.position = at
	_region_display()
	_refresh_nearby()

func _region_display(refresh := false) -> void:
	var id: String = "" if host.indoors else (State.BANK if state.position.z >= seam.global_position.z else State.RISE)
	if region_view != null and region_view.region_id == id:
		if refresh: region_view.display(id, state)
		return
	if region_view != null:
		region_layer.remove_child(region_view)
		region_view.queue_free()
		region_view = null
	if not id.is_empty():
		region_view = REGION_VIEW.instantiate()
		region_layer.add_child(region_view)
		region_view.global_position = (bank_anchor if id == State.BANK else rise_anchor).global_position
		region_view.display(id, state)

func _near_empty_box() -> Target:
	for target in _targets():
		if not target.is_pickup and target.valid_source and target.amount(state) == 0 and target.global_position.distance_squared_to(state.position) <= Choice.REACH * Choice.REACH:
			return target
	return null

func _binding_name(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key: Key = event.keycode
			if not key: key = event.physical_keycode if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)
			return OS.get_keycode_string(key)
		if event is InputEventMouseButton:
			return {MOUSE_BUTTON_LEFT:"左键", MOUSE_BUTTON_RIGHT:"右键", MOUSE_BUTTON_MIDDLE:"中键"}.get(event.button_index, event.as_text())
	return String(action)

func _use_binding_names() -> String:
	var names := _binding_name(&"use")
	for event in InputMap.action_get_events(&"use"):
		if Bindings.is_pad(event): return names + " / " + Bindings.pad_label(Bindings.encode(event), true)
	return names

func _refresh_nearby() -> void:
	for target in _targets(): target.update_proximity(state, state.position)
	var nearby := Choice.nearby(_targets(), state, state.position)
	_tip_source = null
	_tip_rows.clear()
	_tip_action = ""
	if not nearby.is_empty():
		_tip_source = nearby[0]
		var ambiguous := false
		for target in nearby:
			_tip_rows.append("%s  ×%d" % [target.definition.title, target.amount(state)])
			if target != _tip_source and not target.is_pickup: ambiguous = true
		_tip_action = "靠近其中一处再使用" if ambiguous else "%s · %s" % [_use_binding_names(), "拾取" if _tip_source.is_pickup else "从箱中取出"]
	else:
		_tip_source = _near_empty_box()
		if _tip_source: _tip_rows.append("箱子已空")
	_project_tip()

func _process(_dt: float) -> void:
	_project_tip()

func _project_tip() -> void:
	if not _tip_source or host.crossing or is_modal():
		hud.hide_pickup_tip()
		return
	var vp: SubViewport = host.room if host.indoors else host.field
	var camera := vp.get_camera_3d()
	var point := _tip_source.global_position + Vector3.UP * (0.18 if _tip_source.is_pickup else 0.70)
	if camera == null or camera.is_position_behind(point):
		hud.hide_pickup_tip(); return
	var uv := camera.unproject_position(point) / Vector2(vp.size)
	if not Rect2(Vector2.ZERO, Vector2.ONE).has_point(uv):
		hud.hide_pickup_tip(); return
	var bounds := screen.get_rect() # Screen and the full-window HUD are siblings.
	hud.show_pickup_tip(bounds.position + uv * bounds.size, _tip_rows, _tip_action, bounds)

func _use() -> void:
	var actor: Node3D = host.active_actor()
	var options := Choice.options(_targets(), state, actor.global_position)
	if options.size() == 1:
		var target := options[0]
		var count := target.take(state, actor.global_position, Choice.REACH, actor)
		hud.feedback("已放入行囊：%s ×%d" % [target.definition.title, count] if count > 0 else "未转移：目标已不可用。")
	elif options.size() > 1: hud.feedback("未转移：请移近一个目标。")
	else: hud.feedback("箱中没有物品。" if _near_empty_box() else "附近没有可用物件。")
	_refresh_nearby()

func _close_inventory() -> void:
	hud.hide_inventory()
	host.sync_control(true)
	_refresh_nearby()

func _open_settings() -> void:
	book.open_book(FileAccess.file_exists(slot_path))
	host.sync_control()

func _close_settings() -> void:
	book.hide_book()
	host.sync_control(true)
	_refresh_nearby()

func _open_bindings() -> void:
	book.hide_book()
	bindings.open_panel()
	host.sync_control()

func _back_to_settings() -> void:
	book.open_book(FileAccess.file_exists(slot_path), true)
	host.sync_control()

func _save_slot() -> void:
	state.position = host.active_actor().global_position
	var error := state.save_slot(slot_path)
	var msg := "已保存行囊和世界变化。" if error.is_empty() else error
	if book.opened: book.show_status(msg, FileAccess.file_exists(slot_path))
	else: hud.feedback(msg)

func _read_slot() -> void:
	var error := state.load_slot(slot_path)
	if not error.is_empty():
		if book.opened: book.show_status(error, FileAccess.file_exists(slot_path))
		else: hud.feedback(error)
		return
	book.hide_book()
	host.show_place(state.location_id == "place.cabin", state.position, false)
	host.sync_control(true)
	hud.feedback("已恢复地点、行囊和世界变化。")

func _sample_interval() -> void:
	var before := state.simulated_until
	state.advance_interval(0, 1)
	_region_display(true)
	hud.feedback("测试段 [0,1) 已推进。沿石路上坡查看库存。" if state.simulated_until > before else "测试段 [0,1) 已处理，库存不变。")

func _discrete_edge(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		var axis := Vector2i(event.device, event.axis)
		if absf(event.axis_value) < 0.25: _axis_held.erase(axis)
		if absf(event.axis_value) < 0.55: return false
		var direction := signf(event.axis_value)
		if _axis_held.get(axis) == direction: return false
		_axis_held[axis] = direction
		return true
	return event.is_pressed() and not event.is_echo()

func _matches(event: InputEvent, action: StringName) -> bool:
	return event.is_action(action, event is InputEventJoypadMotion)

func is_mapped(event: InputEvent) -> bool:
	for action in Bindings.ACTIONS:
		if _matches(event, action): return true
	return false

func handle_event(event: InputEvent) -> bool:
	var edge := _discrete_edge(event)
	if host.crossing: return true
	if bindings.visible: return bindings.handle_modal_input(event)
	if book.opened:
		if edge and (_matches(event, &"ui_cancel") or _matches(event, &"bindings")):
			book.back(); return true
		return false
	if hud.inventory_open:
		if edge and (_matches(event, &"inventory") or _matches(event, &"ui_cancel")):
			_close_inventory(); return true
		return false
	# _input normally runs before GUI. A click on the visible tab belongs to the GUI.
	if event is InputEventMouseButton and not host.orbit.dragging and book.launcher.is_visible_in_tree() and book.launcher.get_global_rect().has_point(event.position): return false
	if host.developer_camera:
		if not host.indoors and host.orbit.drag_input(event, screen.get_rect(), screen.size.x / host.field.size.x): return true
		if event is InputEventMouseButton and event.ctrl_pressed and event.button_index == MOUSE_BUTTON_LEFT: return true
	if event is InputEventMouseButton and not screen.get_rect().has_point(event.position): return false
	if edge:
		if _matches(event, &"inventory"):
			hud.show_inventory(state.inventory, State.DEFINITIONS)
			host.sync_control(); return true
		if _matches(event, &"bindings") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
			_open_settings(); return true
		if _matches(event, &"use"):
			_use(); return true
		if _matches(event, &"attack"):
			attack_requested.emit(); return true
		if event is InputEventKey:
			match event.keycode:
				KEY_F5: _save_slot(); return true
				KEY_F9: _read_slot(); return true
				KEY_F6: _sample_interval(); return true
	return not host.indoors and host.orbit.zoom_input(event, screen.get_rect())
