extends Panel
## Scene-local smoke test. Use is dispatched only by FieldSession.
const Binding := preload("res://scripts/ui/dialogue_binding.gd")
const REACH := 1.65
@export var fallback_portrait: Texture2D
const UI := preload("res://scripts/ui/ui_layout.gd")
const PAGE := Vector2(464, 92)
const PORTRAIT := 176.0
@onready var host = get_parent()
@onready var session = $"../Session"
var _ui: UI
var _tag := PanelContainer.new()
var _name := Label.new()
var _line := Label.new()
var _next := Button.new()
var _close := Button.new()
var _portrait := TextureRect.new()
var _talk: PackedStringArray
var _page := 0

func _ready() -> void:
	hide()
	_ui = UI.attach(self)
	mouse_filter = MOUSE_FILTER_IGNORE
	UI.ink(_name, UI.TITLE)
	UI.ink(_line, UI.BODY)
	UI.ink(_next, UI.AUX)
	UI.ink(_close, UI.AUX)
	add_child(_portrait)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tag.theme_type_variation = &"PaperTag"
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tag)
	_tag.add_child(_name)
	add_child(_line)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_next)
	add_child(_close)
	_close.text = "离开"
	_next.pressed.connect(_advance)
	_close.pressed.connect(_dismiss)
	_next.focus_neighbor_right = _next.get_path_to(_close)
	_close.focus_neighbor_left = _close.get_path_to(_next)
	_ui.changed.connect(_layout)
	_layout()
	_register.call_deferred()

func _register() -> void:
	if not session.has_method(&"set_dialogue_handler") or not session.has_method(&"set_dialogue_modal"):
		push_warning("Field dialogue requires the FieldSession dialogue hooks.")
		return
	session.set_dialogue_handler(_try_use)

func _layout() -> void:
	_ui.place(self, Rect2(UI.SAFE.get_center().x - PAGE.x * .5, UI.SAFE.end.y - PAGE.y, PAGE.x, PAGE.y))
	# Transparent illustration remains an independent control above the paper.
	# Only the feet can bleed onto the lip; the name tag draws in front.
	_portrait.position = Vector2(18, 2 - PORTRAIT)
	_portrait.size = Vector2.ONE * PORTRAIT
	_tag.position = Vector2(19, -10)
	_line.position = Vector2(23, 24)
	_line.size = Vector2(PAGE.x - 46, 34)
	_next.position = Vector2(PAGE.x - 169, 60)
	_next.size = Vector2(68, 23)
	_close.position = Vector2(PAGE.x - 91, 60)
	_close.size = Vector2(68, 23)

func _try_use() -> bool:
	if visible:
		return true
	if host.crossing or session.is_modal():
		return false
	var player: Node3D = host.active_actor()
	var selected: Binding
	var best := REACH * REACH
	for child in get_children():
		var binding := child as Binding
		if binding == null or binding.lines.is_empty():
			continue
		var npc := binding.actor()
		if npc == null or not npc.is_visible_in_tree() or npc.get_world_3d() != player.get_world_3d():
			continue
		var distance := player.global_position.distance_squared_to(npc.global_position)
		if distance <= best and (selected == null or distance < best):
			best = distance
			selected = binding
	if selected == null:
		return false
	_talk = selected.lines
	_name.text = selected.speaker_name
	_tag.reset_size()
	_portrait.texture = selected.portrait if selected.portrait != null else fallback_portrait
	_page = 0
	_show_page()
	session.set_dialogue_modal(true)
	show()
	_next.grab_focus()
	return true

func _show_page() -> void:
	_line.text = _talk[_page]
	_next.text = "结束" if _page == _talk.size() - 1 else "继续"

func _advance() -> void:
	if not visible:
		return
	_page += 1
	if _page >= _talk.size():
		_dismiss()
	else:
		_show_page()

func _dismiss() -> void:
	if not visible:
		return
	hide()
	_portrait.texture = null
	session.set_dialogue_modal(false)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_dismiss()
