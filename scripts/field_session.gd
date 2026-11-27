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
const Combat := preload("res://scripts/foundation/field_combat.gd")
const ActorStats := preload("res://scripts/foundation/actor_stats.gd")
@onready var farm = $"../Pixels/Clearing/MonsterFarm"
var _dialogue_handler: Callable
var _dialogue_modal := false
var _last_combat_actor: CharacterBody3D
var _ctrl_roll_pending := false
var _guard_device := -1
var _guard_axis := -1
var _guard_direction := 0.0

func set_dialogue_handler(handler: Callable) -> void:
	_dialogue_handler = handler

func set_dialogue_modal(active: bool) -> void:
	if _dialogue_modal == active: return
	_dialogue_modal = active
	host.sync_control(not active)
	_refresh_nearby()

func clear_combat_input() -> void:
	_ctrl_roll_pending = false
	_guard_axis = -1
	if farm: farm.pause_bout()
	for actor in [host.field_actor, host.room_actor]:
		if actor.combat: actor.combat.set_guard(false)

func _install_combat() -> void:
	for person in get_tree().get_nodes_in_group(&"village_person"):
		if host.is_ancestor_of(person): state.entities.bind_resident(person.person_id, person)
	for fighter in farm.fighters:
		state.entities.bind_monster("%s.%d" % [fighter.definition.id, fighter.coat], fighter.actor, fighter.stats)
	for actor in [host.field_actor, host.room_actor]:
		var driver := Combat.new()
		driver.install(actor, actor.artwork, state.player_stats)
		driver.impact.connect(_combat_impact)
		actor.combat = driver
	for actor in get_tree().get_nodes_in_group(&"field_occupant"):
		if not host.field.is_ancestor_of(actor) or actor.get(&"combat_target") != true: continue
		var view: Node3D = actor.get_node_or_null("Model")
		if view != null and view.has_method(&"drive_combat"):
			var stats := ActorStats.new()
			if actor.has_meta(&"entity"): stats = actor.get_meta(&"entity").stats
			Combat.new().install(actor, view, stats, true)

func _combat_impact(target: Node3D, lost: int) -> void:
	var foe = target.get_node_or_null("Encounter")
	if foe != null:
		hud.feedback("%s · %s −%d　生命 %d/%d" % ["击倒" if foe.stats.hp() == 0 else "命中",foe.display_name,lost,foe.stats.hp(),foe.stats.max_hp()])
	else: hud.feedback("命中 · 造成 %d 点伤害" % lost)

func _is_ctrl(event: InputEvent) -> bool:
	return event is InputEventKey and (event.keycode == KEY_CTRL or event.physical_keycode == KEY_CTRL)

func _start_roll() -> void:
	var actor = host.active_actor()
	actor.combat.roll(actor.combat_heading())

func _combat_release(event: InputEvent) -> void:
	var combat: Combat = host.active_actor().combat
	if event is InputEventJoypadMotion:
		if event.device == _guard_device and event.axis == _guard_axis and event.axis_value * _guard_direction < .25:
			_guard_axis = -1
			combat.set_guard(false)
	elif not event.is_pressed() and _matches(event, &"guard"):
		combat.set_guard(false)

var field_map := preload("res://scripts/ui/field_map.gd").new()
var village_book := preload("res://scripts/ui/village_book.gd").new()

@onready var pasture = $"../Pixels/Clearing/Outskirts/VillageFarm"

func start() -> void:
	pasture.bind_session(self)
	host.get_node("Pixels/Clearing/Almanac").bind_time(state.village)
	village_book.install(self)
	field_map.install(self)
	_install_combat()
	farm.bind(self,host.field_actor)
	state.grant_test_weapons()
	hud.equipment_requested.connect(_change_equipment)
	var seen := {}
	for target: Target in get_tree().get_nodes_in_group(&"test_stack_source"):
		if host.field.is_ancestor_of(target):
			_field_targets.append(target)
			_validate_source(target, seen)
	hud.close_requested.connect(_close_inventory)
	hud.actor_sheet.bind(state.player_stats)
	hud.actor_sheet.open_requested.connect(_open_attributes)
	state.player_stats.changed.connect(hud.refresh_attributes)
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
	else: hud.feedback("%s 行囊  ·  %s 设置  ·  J 账册  ·  M 地图" % [_binding_name(&"inventory"), _binding_name(&"bindings")])

func is_modal() -> bool:
	return village_book.visible or _dialogue_modal or hud.inventory_open or bindings.visible or book.opened

func _targets() -> Array[Target]:
	return _room_targets if host.indoors else _field_targets

func _index_room_targets() -> void:
	_room_targets.clear()
	var seen := {}
	for target: Target in _field_targets:
		seen[target.instance_id] = target
	for target: Target in get_tree().get_nodes_in_group(&"test_stack_source"):
		if host.room.is_ancestor_of(target):
			_room_targets.append(target)
			_validate_source(target, seen)

func _validate_source(target: Target, seen: Dictionary) -> void:
	var id := target.instance_id
	if State.Slots.PLACEMENTS.has(id) and (not target.is_pickup or target.initial_count != 1 or target.definition == null or not State.Slots.accepts(id, State.Slots.PLACE, target.definition.definition_id)):
		target.valid_source = false
		push_error("摆放位与物品定义或容量不匹配：" + id)
	if id.strip_edges().is_empty() or target.definition == null or State.DEFINITIONS.get(target.definition.definition_id) != target.definition or seen.has(id):
		target.valid_source = false
		if seen.has(id): seen[id].valid_source = false
		push_error("测试物件的实例 ID 重复/为空，或定义无效：%s" % id)
	seen[id] = target

func place_changed() -> void:
	state.location_id = host.place_id()
	_index_room_targets()
	var actor = host.active_actor()
	state.entities.bind_player(actor, state.player_stats, state.inventory)
	if _last_combat_actor and actor != _last_combat_actor:
		var other: Combat = _last_combat_actor.get(&"combat")
		actor.combat.weapon = other.weapon
		actor.combat.drawn = other.drawn
	_last_combat_actor = actor
	actor.combat.reset()
	var train := _train_stride.bind(actor)
	if not actor.walked.is_connected(train):
		actor.walked.connect(train)
	state.position = actor.global_position
	# Both World3Ds stay alive. Cancel flights in the departed world as well.
	for target in _field_targets: target.refresh(state)
	for target in _room_targets: target.refresh(state)
	_region_display(true)
	_refresh_nearby()

func _train_stride(metres: float, actor: Node3D) -> void:
	if not host.crossing and not is_modal() and actor == host.active_actor():
		state.player_stats.record_loaded_stride(metres, state.inventory_weight_kg())

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
	if village_book.is_inside_tree():
		village_book.refresh()
	_project_tip()

func _project_tip() -> void:
	var animal:StaticBody3D=pasture.nearby() if pasture else null
	if animal:
		var cam:Camera3D=host.field.get_camera_3d()
		var anchor:=animal.global_position+Vector3.UP*(.90 if int(animal.get_meta("species"))==0 else 1.45)
		if cam and cam.is_position_in_frustum(anchor):
			var bounds:=screen.get_rect()
			hud.show_pickup_tip(bounds.position+cam.unproject_position(anchor)/Vector2(host.field.size)*bounds.size,pasture.tip(animal),_use_binding_names()+" · 抚摸",bounds)
			return
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
	var bounds := screen.get_rect() # Physical composer coords; the HUD converts to UI design space.
	hud.show_pickup_tip(bounds.position + uv * bounds.size, _tip_rows, _tip_action, bounds)

func _use() -> void:
	if pasture.pet_nearby(): return # Same target as the visible petting tip, even beside a farmhand.
	if _dialogue_handler.is_valid() and _dialogue_handler.call(): return
	if farm.rest_if_near(): return
	var actor: Node3D = host.active_actor()
	var options := Choice.options(_targets(), state, actor.global_position)
	if options.size() == 1:
		var target := options[0]
		var count := target.take(state, actor.global_position, Choice.REACH, actor)
		hud.feedback("已放入行囊：%s ×%d" % [target.definition.title, count] if count > 0 else "未转移：目标已不可用。")
	elif options.size() > 1: hud.feedback("未转移：请移近一个目标。")
	else: hud.feedback("箱中没有物品。" if _near_empty_box() else "附近没有可用物件。")
	_refresh_nearby()

func _place_nearby() -> bool:
	var origin: Vector3 = host.active_actor().global_position
	for target in _targets():
		if target.place(state, origin, Choice.REACH):
			hud.feedback("已放回原位：%s" % target.definition.title)
			_refresh_nearby()
			return true
	return false

func _show_inventory() -> void:
	hud.set_portrait_look(host.active_actor().artwork)
	hud.show_inventory(state.inventory, State.DEFINITIONS, state.inventory_weight_kg(), state.equipment, State.EQUIPMENT_SLOTS)

func _sync_equipped_weapon() -> void:
	var definition: Resource = State.DEFINITIONS.get(state.equipment.get("main_hand", ""))
	for actor in [host.field_actor, host.room_actor]:
		actor.combat.weapon = definition.combat_weapon if definition else &""
		actor.combat.drawn = false
		actor.combat.reset()

func _change_equipment(slot: String, id: String) -> void:
	if not hud.inventory_open or _dialogue_modal or host.crossing: return
	var changed := state.unequip(slot) if id.is_empty() else state.equip(slot, id)
	if not changed: return
	if slot == "main_hand": _sync_equipped_weapon()
	_show_inventory()

func _close_inventory() -> void:
	hud.hide_inventory()
	host.sync_control(true)
	_refresh_nearby()

func _open_attributes() -> void:
	if host.crossing or (is_modal() and not hud.inventory_open): return
	if not hud.inventory_open:
		_show_inventory()
		host.sync_control()
	hud.focus_attributes()

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
	var structure: Node3D = host.building_structure()
	var error: String
	if structure == null:
		error = state.save_slot(slot_path)
	else:
		error = state.save_slot(slot_path, str(structure.get_meta("building_revision")), structure.to_local(state.position))
	var msg := "已保存角色、行囊、装备和世界变化。" if error.is_empty() else error
	if book.opened: book.show_status(msg, FileAccess.file_exists(slot_path))
	else: hud.feedback(msg)

func _read_slot() -> void:
	var error := state.load_slot(slot_path)
	if not error.is_empty():
		if book.opened: book.show_status(error, FileAccess.file_exists(slot_path))
		else: hud.feedback(error)
		return
	host.get_node("Pixels/Clearing/Almanac").sync_time()
	state.grant_test_weapons()
	_sync_equipped_weapon()
	book.hide_book()
	var stored_foot := state.position
	farm.reset_encounters()
	var safe_foot: Vector3 = farm.safe_loaded_foot(stored_foot) if state.location_id == "place.clearing" else stored_foot
	var farm_foot:=safe_foot
	if state.location_id=="place.clearing":
		safe_foot=host.field.get_node("Clearing/Outskirts").safe_village_foot(safe_foot,host.field_actor)
	var relocated: bool = host.restore_place(state.location_id, safe_foot, state.loaded_building_revision)
	host.sync_control(true)
	if safe_foot != farm_foot: hud.feedback("已恢复存档 · 原落点现为村舍或设施，已移至门前或乡道")
	elif safe_foot != stored_foot: hud.feedback("已恢复存档 · 原落点正好是魔物窝，已移至本栏步道")
	else: hud.feedback("已恢复存档；房屋结构已更新，从一楼入口继续。" if relocated else "已恢复地点、角色、行囊、装备和世界变化。")

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

func _attribute_shortcut(event: InputEvent) -> bool:
	# Do not steal a saved binding from existing keyboard/gamepad maps.
	if is_mapped(event): return false
	if event is InputEventKey: return event.keycode == KEY_F7
	return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_Y

func handle_event(event: InputEvent) -> bool:
	var edge := _discrete_edge(event)
	if host.crossing: return true
	if village_book.visible:
		if edge and event is InputEventKey:
			if event.keycode in [KEY_J,KEY_ESCAPE]:
				village_book.hide(); host.sync_control(true)
			else: village_book.key(event.keycode)
		return true
	if not is_modal() and edge and event is InputEventKey and event.keycode == KEY_M:
		if not host.indoors: field_map.enabled = not field_map.enabled
		else: hud.feedback("乡道图仅在室外使用。")
		return true
	if not is_modal() and edge and event is InputEventKey and event.keycode == KEY_J:
		village_book.show(); village_book.refresh(); host.sync_control(false); return true
	if _dialogue_modal: return false # Dialogue GUI retains normal keyboard/pad/mouse input.
	_combat_release(event)
	if bindings.visible: return bindings.handle_modal_input(event)
	if book.opened:
		if edge and (_matches(event, &"ui_cancel") or _matches(event, &"bindings")):
			book.back(); return true
		return false
	if hud.inventory_open:
		if edge and _attribute_shortcut(event):
			hud.focus_attributes(); return true
		if edge and (_matches(event, &"inventory") or _matches(event, &"ui_cancel")):
			_close_inventory(); return true
		return false
	# The Ctrl roll is committed at release, so Ctrl+left can cancel it
	# before movement, even when the mouse is still outside the play area.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.ctrl_pressed:
		_ctrl_roll_pending = false
	if _is_ctrl(event):
		if edge and _matches(event, &"roll"):
			_ctrl_roll_pending = true
			return true
		if not event.is_pressed() and _ctrl_roll_pending:
			_ctrl_roll_pending = false
			_start_roll()
			return true
	# _input normally runs before GUI. A click on the visible tab belongs to the GUI.
	if event is InputEventMouseButton and not host.orbit.dragging and book.launcher.is_visible_in_tree() and book.launcher.get_global_rect().has_point(event.position): return false
	if event is InputEventMouseButton and not host.orbit.dragging and hud.actor_sheet.launcher.is_visible_in_tree() and hud.actor_sheet.launcher.get_global_rect().has_point(event.position): return false
	if host.developer_camera and not host.indoors and host.orbit.drag_input(event, screen.get_rect(), screen.size.x / host.field.size.x): return true
	if event is InputEventMouseButton and event.ctrl_pressed and event.button_index == MOUSE_BUTTON_LEFT: return true
	if event is InputEventMouseButton and not screen.get_rect().has_point(event.position): return false
	if edge:
		if _attribute_shortcut(event):
			_open_attributes(); return true
		if event is InputEventKey and event.keycode == KEY_F8 and not is_mapped(event):
			var combat: Combat = host.active_actor().combat
			var lost := combat.receive_damage(5, combat.forward)
			hud.feedback("成长原型 · 测试伤害：实际失去 %d 点生命" % lost)
			return true
		if _matches(event, &"inventory"):
			_show_inventory()
			host.sync_control(); return true
		if _matches(event, &"bindings") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
			_open_settings(); return true
		if _matches(event, &"use"):
			_use(); return true
		var combat: Combat = host.active_actor().combat
		if _matches(event, &"guard"):
			if event is InputEventJoypadMotion:
				_guard_device = event.device
				_guard_axis = event.axis
				_guard_direction = signf(event.axis_value)
			combat.set_guard(true)
			return true
		if _matches(event, &"draw_weapon"):
			combat.toggle_draw(); return true
		if _matches(event, &"roll"):
			_start_roll(); return true
		if _matches(event, &"attack"):
			if combat.attack(): attack_requested.emit()
			return true
		if event is InputEventKey:
			match event.keycode:
				KEY_K:
					if not is_mapped(event): return _place_nearby()
				KEY_F5: _save_slot(); return true
				KEY_F9: _read_slot(); return true
				KEY_F6: _sample_interval(); return true
	return not host.indoors and host.orbit.zoom_input(event, screen.get_rect())
