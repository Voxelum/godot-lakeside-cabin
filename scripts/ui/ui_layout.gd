extends Node
## Single native-window → paper design-space transform. The world pixel composer
## is deliberately not an input. Full-window dimmers stay outside this transform.
signal changed

const REFERENCE := Vector2(640, 360)
const FRAME := Rect2(Vector2.ZERO, REFERENCE)
const SAFE := Rect2(12, 8, 616, 344)
const MIN_WINDOW := Vector2i(320, 180)
const TITLE := 17
const BODY := 14
const AUX := 11

var factor := 1.0
var origin := Vector2.ZERO

static func attach(control: Control) -> Node:
	var shared := control.get_node_or_null("../UILayout")
	if shared != null: return shared
	# Standalone previews/tests: use the same policy with the local surface.
	# A Panel already in design space must never call attach() again.
	var local: Node = load("res://scripts/ui/ui_layout.gd").new()
	control.add_child(local)
	return local

static func ink(control: Control, role: int) -> void:
	control.add_theme_font_size_override(&"normal_font_size" if control is RichTextLabel else &"font_size", role)

func _ready() -> void:
	var host := get_parent() as Control
	host.resized.connect(_fit.bind(host))
	_fit(host)

func _fit(host: Control) -> void:
	var next := maxf(0.001, minf(host.size.x / REFERENCE.x, host.size.y / REFERENCE.y))
	var start := (host.size - REFERENCE * next) * 0.5
	if next == factor and start == origin: return
	factor = next
	origin = start
	changed.emit()

func place(control: Control, rect: Rect2) -> void:
	# Only top-level UI islands are placed; children stay in logical units.
	control.position = origin + rect.position * factor
	control.scale = Vector2.ONE * factor
	control.size = rect.size

func to_logical(point: Vector2) -> Vector2:
	return (point - origin) / factor

func rect_to_logical(rect: Rect2) -> Rect2:
	return Rect2(to_logical(rect.position), rect.size / factor)
