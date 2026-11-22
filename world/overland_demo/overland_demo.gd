extends Control
## Independent pixel-window host. No Main/FieldSession, bindings disk I/O, or transitions.
const Camera := preload("res://world/overland_demo/overland_camera.gd")
const Trail := preload("res://world/overland_demo/overland_map.gd")
const FULL := Vector2i(480, 270)
const LOW := Vector2i(320, 180)
const STOP_NAMES := ["木屋", "井边村", "林间兽径", "石街镇"]
const STOP_HINTS := ["从拱门前的土路向画面右侧走，跟着琥珀路牌。", "过井继续沿有车辙的土路，谷仓后入林。", "看路旁的三处浅色砾石空地；沿土路走到石铺路。", "沿石铺主街到面包铺；镇屋之间有横巷。"]

@onready var pixels: SubViewport = $Pixels
@onready var map: Trail = $Pixels/Trail
@onready var camera: Camera = $Pixels/Trail/Camera
@onready var notes: Control = $Pixels/Notes
@onready var screen: TextureRect = $Screen
@onready var player: CharacterBody3D = $Pixels/Trail/Traveler
var route_name: Label
var route_hint: Label
var tags: Array[Panel] = []
var zone := -1
var _retreat := false

func _ready() -> void:
	process_priority = 20 # Project the tags after the follow camera's priority-10 update.
	get_window().title = "林边小屋 · 从木屋到石街镇"
	screen.texture = pixels.get_texture()
	resized.connect(_fit)
	_build_notes()
	set_pixels(LOW if OS.get_cmdline_user_args().has("--320") else FULL)
	_refresh_guide()

func set_pixels(resolution: Vector2i) -> void:
	pixels.size = resolution
	get_window().min_size = resolution
	notes.size = Vector2(resolution)
	_fit()
	camera.align_at_subject()
	_place_tags()

func _fit() -> void:
	var native := Vector2(pixels.size)
	var scale_value := maxi(1, floori(minf(size.x / native.x, size.y / native.y)))
	screen.size = native * scale_value
	screen.position = ((size - screen.size) * .5).floor()

func _process(_delta: float) -> void:
	_refresh_guide()
	_place_tags()

func _unhandled_input(event: InputEvent) -> void:
	if camera.zoom_input(event, screen.get_rect()):
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
		if code == KEY_V:
			set_pixels(LOW if pixels.size == FULL else FULL)
			get_viewport().set_input_as_handled()

func _refresh_guide() -> void:
	var x := player.position.x
	var next := 0 if x < -58.9 else (1 if x < -21.0 else (2 if x < 36.0 else 3))
	var at_end := x >= Trail.RETURN_MARK.x - .6
	if next == zone and at_end == _retreat:
		return
	zone = next
	_retreat = at_end
	route_name.text = "%d / %d  ·  %s" % [zone + 1, STOP_NAMES.size(), STOP_NAMES[zone]]
	route_hint.text = "琥珀路牌是本次终点标记；原路可步行返回。" if at_end else STOP_HINTS[zone]

func _place_tags() -> void:
	var inner := Rect2(Vector2(5, 58), Vector2(pixels.size) - Vector2(10, 78))
	for i in tags.size():
		var specimen := map.specimens[i]
		var tag := tags[i]
		var foot := specimen.model.global_position
		var shot := camera.unproject_position(foot)
		var place := (shot + Vector2(-tag.size.x / 2.0, 7)).round()
		tag.visible = player.global_position.distance_squared_to(specimen.global_position) <= 7.5 * 7.5 and inner.encloses(Rect2(place, tag.size))
		tag.position = place

func _build_notes() -> void:
	# Intentionally lightweight and click-through: only the shared irregular paper slips.
	var guide := _paper(&"PaperSlip", Vector2(278, 48))
	guide.position = Vector2(8, 7)
	route_name = _label(guide, "", 13)
	route_name.position = Vector2(12, 5)
	route_hint = _label(guide, "", 11)
	route_hint.position = Vector2(12, 24)
	for stop in map.specimens:
		var tag := _paper(&"PaperTag", Vector2(92, 20))
		var name_label := _label(tag, stop.caption, 11)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tags.append(tag)
	var keys := _label(notes, "WASD / 方向键 走   Shift 跑   滚轮 缩放   V 像素档", 11)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.add_theme_color_override(&"font_color", Color("f5dfb9"))
	keys.add_theme_color_override(&"font_outline_color", Color("382e25"))
	keys.add_theme_constant_override(&"outline_size", 4)
	keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 5)

func _paper(style: StringName, dim: Vector2) -> Panel:
	var paper := Panel.new()
	paper.theme_type_variation = style
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes.add_child(paper)
	paper.size = dim
	return paper

func _label(parent: Control, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", font_size)
	parent.add_child(label)
	return label
