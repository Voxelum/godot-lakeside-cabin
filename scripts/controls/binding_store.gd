extends RefCounted

const ACTIONS := [&"walk_left", &"walk_right", &"walk_up", &"walk_down", &"sprint", &"attack", &"use", &"inventory", &"bindings"]
const RESERVED := [KEY_ESCAPE, KEY_F5, KEY_F6, KEY_F9]
const SECTION := "s03_bindings_v1"
const PAD_LABELS := ["A / Cross", "B / Circle", "X / Square", "Y / Triangle", "Back", "Guide", "Start", "L3", "R3", "LB", "RB", "D-pad Up", "D-pad Down", "D-pad Left", "D-pad Right"]

static func pad_label(spec: Vector2i, compact := false) -> String:
	if spec.x in [5, 6]:
		var axes := ["左杆 X", "左杆 Y", "右杆 X", "右杆 Y", "LT", "RT"]
		var name: String = axes[spec.y] if spec.y < axes.size() else "轴 %d" % spec.y
		return name + (" −" if spec.x == 5 else " +")
	var text: String = PAD_LABELS[spec.y] if spec.y < PAD_LABELS.size() else "键 %d" % spec.y
	return text.get_slice(" / ", 0) if compact else text

static func is_pad(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion

static func encode(event: InputEvent) -> Vector2i:
	if event is InputEventKey:
		var physical: bool = event.physical_keycode != 0
		return Vector2i(1 if physical else 2, event.physical_keycode if physical else event.keycode)
	if event is InputEventMouseButton:
		return Vector2i(3, event.button_index)
	if event is InputEventJoypadButton:
		return Vector2i(4, event.button_index)
	if event is InputEventJoypadMotion:
		return Vector2i(5 if event.axis_value < 0 else 6, event.axis)
	return Vector2i.ZERO

static func decode(value: Variant) -> InputEvent:
	if not value is Vector2i:
		return null
	var id: int = value.y
	match value.x:
		1, 2:
			if id <= 0 or id in RESERVED or OS.get_keycode_string(id).is_empty():
				return null
			var key := InputEventKey.new()
			if value.x == 1:
				key.physical_keycode = id
			else:
				key.keycode = id
			return key
		3:
			if id not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
				return null
			var mouse := InputEventMouseButton.new()
			mouse.button_index = id
			return mouse
		4:
			if id < 0 or id >= JOY_BUTTON_MAX:
				return null
			var button := InputEventJoypadButton.new()
			button.device = -1
			button.button_index = id
			return button
		5, 6:
			if id < 0 or id >= JOY_AXIS_MAX:
				return null
			var axis := InputEventJoypadMotion.new()
			axis.device = -1
			axis.axis = id
			axis.axis_value = -1.0 if value.x == 5 else 1.0
			return axis
	return null

static func snapshot(project_defaults: bool = false) -> Dictionary:
	var result := {}
	for action in ACTIONS:
		var items := []
		var events: Array = ProjectSettings.get_setting("input/" + String(action))["events"] if project_defaults else InputMap.action_get_events(action)
		for event in events:
			items.append(encode(event))
		result[action] = items
	return result

static func identity(spec: Vector2i) -> Vector2i:
	if spec.x == 1:
		var logical := KEY_NONE if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(spec.y)
		return Vector2i(2, logical if logical != KEY_NONE else spec.y)
	return spec

static func valid(map: Dictionary) -> bool:
	var used := {}
	for action in ACTIONS:
		var items: Variant = map.get(action)
		if not items is Array or items.size() < 2 or items.size() > 3:
			return false
		var pad := 0
		for spec in items:
			var event := decode(spec)
			if event == null or used.has(identity(spec)):
				return false
			used[identity(spec)] = action
			pad += int(is_pad(event))
		if pad != 1:
			return false
	return true

static func apply(map: Dictionary) -> void:
	for action in ACTIONS:
		Input.action_release(action)
		InputMap.action_erase_events(action)
		for spec in map[action]:
			InputMap.action_add_event(action, decode(spec))

static func load_bindings(path: String) -> Error:
	var cfg := ConfigFile.new()
	var error := cfg.load(path)
	var map := snapshot(true)
	if error == OK:
		var saved := {}
		for action in ACTIONS:
			saved[action] = cfg.get_value(SECTION, action) if cfg.has_section_key(SECTION, action) else null
		if valid(saved):
			map = saved
		else:
			error = ERR_INVALID_DATA
	apply(map)
	return error

static func save_bindings(path: String, map: Dictionary) -> Error:
	if not valid(map):
		return ERR_INVALID_DATA
	var cfg := ConfigFile.new()
	for action in ACTIONS:
		cfg.set_value(SECTION, action, map[action])
	return cfg.save(path)
