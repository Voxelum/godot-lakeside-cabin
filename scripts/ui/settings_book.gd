extends Control
## FieldSession owns the slot. This page only emits explicit requests.
signal open_requested
signal close_requested
signal save_requested
signal load_requested
signal bindings_requested
const Paper := preload("res://scripts/ui/parchment.gd")
const UI := preload("res://scripts/ui/ui_layout.gd")
const PAGE := Vector2(320, 180)
const LAUNCHER := Vector2(49, 23)
var _ui: UI
const PAGE_INSET := Vector2(10, 10)
var opened := false
var launcher: Button
var _shade: ColorRect
var _page: Panel
var _status: Label
var _save: Button
var _load: Button
var _bindings: Button
var _back: Button
var _display: Button
var _restore_mode := Window.MODE_WINDOWED
var _restore_rect := Rect2i()
var _confirm := ""
var _has_slot := false

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = Paper.make_theme()
	_ui = UI.attach(self)
	launcher = Button.new(); launcher.name = "MenuTab"; launcher.text = "设置"; launcher.focus_mode = FOCUS_NONE
	launcher.tooltip_text = "旅途手册：保存、读取与操控"
	add_child(launcher)
	UI.ink(launcher, UI.AUX)
	launcher.pressed.connect(func(): open_requested.emit())
	_shade = ColorRect.new(); _shade.name = "Shade"; _shade.color = Color(0.04, 0.025, 0.015, 0.54)
	add_child(_shade); _shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_page = Panel.new(); _page.name = "Page"; _page.size = PAGE
	_shade.add_child(_page)
	_label("旅途手册", Rect2(15, 6, 148, 26), UI.TITLE)
	var folio := _label("设 置   /   01", Rect2(173, 12, 113, 18), UI.AUX)
	folio.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var rule := ColorRect.new(); rule.color = Paper.EDGE; rule.mouse_filter = MOUSE_FILTER_IGNORE
	_page.add_child(rule); rule.position = Vector2(14, 34); rule.size = Vector2(272, 1)
	_save = _button("Save", "保存进度", Rect2(15, 45, 130, 28), func(): _choose("save"))
	_load = _button("Load", "读取存档", Rect2(155, 45, 130, 28), func(): _choose("load"))
	_bindings = _button("Bindings", "操控与改绑", Rect2(15, 80, 130, 28), func(): bindings_requested.emit())
	_back = _button("Resume", "返回游戏", Rect2(155, 80, 130, 28), back)
	_display = _button("Display", "切换全屏", Rect2(15, 114, 130, 26), _toggle_display)
	_bindings.focus_neighbor_bottom = _bindings.get_path_to(_display)
	_back.focus_neighbor_bottom = _back.get_path_to(_display)
	_display.focus_neighbor_top = _display.get_path_to(_bindings)
	_status = _label("", Rect2(155, 112, 130, 43), UI.AUX)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Keep titles, controls and focus markers on solid vellum at every scale.
	for child: Control in _page.get_children(): child.position += PAGE_INSET
	_shade.hide(); _ui.changed.connect(_fit); _fit()

func _label(text: String, rect: Rect2, font_size: int) -> Label:
	var label := Label.new(); label.text = text; label.mouse_filter = MOUSE_FILTER_IGNORE
	_page.add_child(label); label.position = rect.position; label.size = rect.size
	UI.ink(label, font_size)
	return label

func _button(id: String, text: String, rect: Rect2, callback: Callable) -> Button:
	var b := Button.new(); b.name = id; b.text = text; _page.add_child(b)
	UI.ink(b, UI.BODY)
	b.position = rect.position; b.size = rect.size; b.pressed.connect(callback)
	return b

func _sync_display() -> void:
	var window := get_window()
	var fullscreen := window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	var embedded := window.is_embedded() or "--wid" in OS.get_cmdline_args()
	_display.disabled = embedded or DisplayServer.get_name() == "headless"
	_display.text = "嵌入预览" if embedded else ("退出全屏" if fullscreen else "切换全屏")
	_display.tooltip_text = "在编辑器关闭嵌入运行后可切换独立窗口全屏。" if embedded else "保持画面比例，不裁切"

func _toggle_display() -> void:
	if _display.disabled: return
	var window := get_window()
	if window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
		window.mode = Window.MODE_WINDOWED
		if _restore_rect.has_area():
			window.position = _restore_rect.position
			window.size = _restore_rect.size
		window.mode = _restore_mode
	else:
		_restore_mode = Window.MODE_MAXIMIZED if window.mode == Window.MODE_MAXIMIZED else Window.MODE_WINDOWED
		_restore_rect = Rect2i(window.position, window.size) if _restore_mode == Window.MODE_WINDOWED else Rect2i()
		window.mode = Window.MODE_FULLSCREEN
	_sync_display()

func _fit() -> void:
	_ui.place(_page, Rect2(UI.SAFE.get_center() - PAGE * .5, PAGE))
	_ui.place(launcher, Rect2(UI.SAFE.end - LAUNCHER, LAUNCHER))

func open_book(has_slot: bool, focus_bindings := false) -> void:
	opened = true; launcher.hide(); _shade.show()
	_sync_display()
	show_status("已有旅途记录。" if has_slot else "尚无存档。保存后可以在这里读回。", has_slot)
	if focus_bindings: _bindings.grab_focus()
	else: _back.grab_focus()

func hide_book() -> void:
	opened = false; _shade.hide(); _confirm = ""

func show_status(msg: String, has_slot: bool) -> void:
	_has_slot = has_slot; _confirm = ""; _status.text = msg
	_save.text = "保存进度"; _load.text = "读取存档"; _back.text = "返回游戏"
	_load.disabled = not has_slot

func back() -> void:
	if not _confirm.is_empty(): show_status("已取消，当前进度未变。", _has_slot)
	else: close_requested.emit()

func _choose(action: String) -> void:
	if _has_slot and _confirm != action:
		show_status("再次选择以覆盖此存档。" if action == "save" else "再次选择以读档；未保存的进度会丢失。", true)
		_confirm = action; _back.text = "取消"
		if action == "save": _save.text = "确认覆盖"
		else: _load.text = "确认读取"
		return
	if action == "save": save_requested.emit()
	else: load_requested.emit()
