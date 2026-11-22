extends Control

signal closed

const Store = preload("res://scripts/controls/binding_store.gd")
const Paper := preload("res://scripts/ui/parchment.gd")
const LABELS := ["左移", "右移", "前进", "后退", "奔跑", "攻击", "使用", "背包", "绑定设置"]
const AXIS_CAPTURE := 0.65
const AXIS_NEUTRAL := 0.25

var settings_path: String = "user://input_bindings.cfg"
var _action: StringName = &""
var _pad := false
var _blocked := {}
var _buttons := {}
var _status: Label
var _close: Button
var _notice := ""
var _capture_timeout: Timer
var _last_capture: InputEvent

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var error := Store.load_bindings(settings_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		_notice = "绑定配置无效或无法读取；已使用默认绑定。"
	_capture_timeout = Timer.new()
	_capture_timeout.one_shot = true
	_capture_timeout.timeout.connect(_cancel_capture)
	add_child(_capture_timeout)
	_build()
	_refresh()
	hide()

func open_panel() -> void:
	if visible:
		return
	_action = &""
	show()
	_refresh()
	_status.text = _notice if not _notice.is_empty() else "选择要改绑的设备列，修改后自动保存。Esc 返回手册。"
	_close.grab_focus()

func close_panel() -> void:
	if not visible:
		return
	_action = &""
	_blocked.clear()
	_last_capture = null
	_capture_timeout.stop()
	hide()
	closed.emit()

func _build() -> void:
	var shade := ColorRect.new()
	theme = Paper.make_theme()
	shade.color = Color(0.04, 0.025, 0.015, 0.54)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var paper_page := PanelContainer.new()
	center.add_child(paper_page)
	var box := VBoxContainer.new()
	paper_page.add_child(box)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 17)
	title.text = "旅途手册   /   操控改绑"
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	box.add_child(grid)
	for text in ["动作", "键鼠", "手柄"]:
		var heading := Label.new()
		heading.text = text
		grid.add_child(heading)
	for i in Store.ACTIONS.size():
		var action: StringName = Store.ACTIONS[i]
		var label := Label.new()
		label.text = LABELS[i]
		grid.add_child(label)
		var pair := []
		for pad in [false, true]:
			var button := Button.new()
			button.custom_minimum_size.x = 96
			button.pressed.connect(_begin.bind(action, pad))
			grid.add_child(button)
			pair.append(button)
		_buttons[action] = pair
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	var tools := HBoxContainer.new()
	box.add_child(tools)
	var reset := Button.new()
	reset.text = "恢复默认"
	reset.pressed.connect(_restore)
	tools.add_child(reset)
	_close = Button.new()
	_close.text = "返回手册"
	_close.pressed.connect(close_panel)
	tools.add_child(_close)

func _refresh() -> void:
	for action in Store.ACTIONS:
		var labels := [PackedStringArray(), PackedStringArray()]
		for event in InputMap.action_get_events(action):
			var spec: Vector2i = Store.encode(event)
			var text: String = event.as_text().trim_suffix(" (Physical)")
			if Store.is_pad(event): text = Store.pad_label(spec)
			labels[int(Store.is_pad(event))].append(text)
		for i in 2:
			_buttons[action][i].text = " / ".join(labels[i])

func _begin(action: StringName, pad: bool) -> void:
	_action = action
	_pad = pad
	_capture_timeout.start(10.0)
	_blocked.clear()
	if pad:
		for device in Input.get_connected_joypads():
			for axis in JOY_AXIS_MAX:
				if absf(Input.get_joy_axis(device, axis)) > AXIS_NEUTRAL:
					_blocked[Vector3i(device, 0, axis)] = true
			for button in JOY_BUTTON_MAX:
				if Input.is_joy_button_pressed(device, button):
					_blocked[Vector3i(device, 1, button)] = true
	_status.text = "拨动摇杆或按手柄键；Esc 取消，10 秒后自动取消。" if pad else "按下键盘键或鼠标键；Esc 取消，10 秒后自动取消。"

func _cancel_capture() -> void:
	_action = &""
	_capture_timeout.stop()
	_status.text = "已取消改绑。"

func _consume_capture_release(event: InputEvent) -> bool:
	if _last_capture == null or _last_capture.device != event.device:
		return false
	var captured := Store.encode(_last_capture)
	var incoming := Store.encode(event)
	if _last_capture is InputEventJoypadMotion and event is InputEventJoypadMotion and captured.y == incoming.y:
		if absf(event.axis_value) <= AXIS_NEUTRAL:
			_last_capture = null
		return true
	if captured == incoming:
		if not event.is_pressed():
			_last_capture = null
		return true
	return false

func _restore() -> void:
	var map := Store.snapshot(true)
	var error := Store.save_bindings(settings_path, map)
	if error != OK:
		_status.text = "无法保存：%s。" % error_string(error)
		return
	Store.apply(map)
	_notice = ""
	_refresh()
	_status.text = "已恢复默认并保存。"

## Called from root _input before gameplay routing, only while visible.
## Return false to allow normal GUI delivery, never to authorize gameplay.
func handle_modal_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if event is InputEventKey and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		if event.pressed and not event.echo:
			if _action == &"":
				close_panel()
			else:
				_cancel_capture()
		return true
	if _consume_capture_release(event):
		return true
	if _action == &"":
		if event.is_action_pressed(&"ui_cancel"):
			close_panel()
			return true
		return false
	if event is InputEventKey:
		if event.keycode in Store.RESERVED or event.physical_keycode in Store.RESERVED:
			if event.pressed and not event.echo:
				_status.text = "F5、F6、F9 为固定快捷键，不能改绑。"
			return true
	if Store.is_pad(event) != _pad:
		return true
	if event is InputEventJoypadMotion:
		var key := Vector3i(event.device, 0, event.axis)
		if absf(event.axis_value) <= AXIS_NEUTRAL:
			_blocked.erase(key)
		if _blocked.has(key) or absf(event.axis_value) < AXIS_CAPTURE:
			return true
	elif event is InputEventJoypadButton:
		var key := Vector3i(event.device, 1, event.button_index)
		if not event.pressed:
			_blocked.erase(key)
			return true
		if _blocked.has(key):
			return true
	elif not event.is_pressed() or event.is_echo():
		return true
	var spec: Vector2i = Store.encode(event)
	if Store.decode(spec) == null:
		_status.text = "不支持此输入，请换一个键。"
		return true
	var map := Store.snapshot()
	var replacement := []
	for previous in map[_action]:
		if Store.is_pad(Store.decode(previous)) != _pad:
			replacement.append(previous)
	replacement.append(spec)
	map[_action] = replacement
	for other in Store.ACTIONS:
		if other == _action:
			continue
		for existing in map[other]:
			if Store.identity(existing) == Store.identity(spec):
				_status.text = "已绑定至「%s」，请选择其它输入。" % LABELS[Store.ACTIONS.find(other)]
				return true
	var error := Store.save_bindings(settings_path, map)
	if error != OK:
		_status.text = "无法保存：%s。" % error_string(error)
		return true
	Store.apply(map)
	_last_capture = event.duplicate()
	_capture_timeout.stop()
	_action = &""
	_notice = ""
	_refresh()
	_status.text = "已改绑并保存。"
	return true
