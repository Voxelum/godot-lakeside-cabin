extends Control
## Resting health tag for the unified character panel. FieldHUD lends us its UI frame.
signal open_requested

const Paper = preload("res://scripts/ui/parchment.gd")
const UI = preload("res://scripts/ui/ui_layout.gd")
const Stats = preload("res://scripts/foundation/actor_stats.gd")
const TAG := Vector2(151, 37)
const TRACK_WIDTH := 90.0
var launcher: Button
var ui: UI
var _stats: Stats
var _tag: Panel
var _health: Label
var _fill: ColorRect

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_tag = Panel.new()
	_tag.theme_type_variation = &"PaperTag"
	_tag.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_tag)
	_health = Label.new()
	_health.mouse_filter = MOUSE_FILTER_IGNORE
	_health.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_health.clip_text = true
	_health.add_theme_color_override("font_color", Paper.INK)
	UI.ink(_health, UI.BODY)
	_tag.add_child(_health)
	_health.position = Vector2(10, 4)
	_health.size.x = TRACK_WIDTH
	var track := ColorRect.new()
	track.mouse_filter = MOUSE_FILTER_IGNORE
	track.color = Color("604333")
	_tag.add_child(track)
	track.position = Vector2(10, 27)
	track.size = Vector2(TRACK_WIDTH, 4)
	_fill = ColorRect.new()
	_fill.mouse_filter = MOUSE_FILTER_IGNORE
	_fill.color = Color("a64134")
	track.add_child(_fill)
	launcher = Button.new()
	launcher.text = "属性"
	launcher.focus_mode = FOCUS_NONE
	launcher.tooltip_text = "角色面板（未被改绑的 F7 / 手柄 Y）"
	UI.ink(launcher, UI.AUX)
	_tag.add_child(launcher)
	launcher.position = Vector2(104, 7)
	launcher.size = Vector2(40, 23)
	launcher.pressed.connect(func() -> void: open_requested.emit())
	ui.changed.connect(_layout)
	_layout()

func bind(stats: Stats) -> void:
	if _stats != null:
		_stats.changed.disconnect(_refresh)
	_stats = stats
	_stats.changed.connect(_refresh)
	_refresh()

func set_launcher_visible(value: bool) -> void:
	_tag.visible = value

func _refresh() -> void:
	_health.text = "生命 %d/%d" % [_stats.hp(), _stats.max_hp()]
	_fill.size = Vector2(roundf(TRACK_WIDTH * _stats.hp() / _stats.max_hp()), 4)

func current_stats() -> Stats:
	return _stats

func _layout() -> void:
	ui.place(_tag, Rect2(Vector2(UI.SAFE.get_center().x - TAG.x * .5, UI.SAFE.position.y), TAG))
