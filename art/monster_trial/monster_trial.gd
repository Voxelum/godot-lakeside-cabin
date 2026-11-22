extends Control
## Standalone presentation for the three in-place clips; the real game is not loaded.

const StudySet := preload("res://art/monster_trial/study_set.gd")
const PIXELS := Vector2i(480, 270)
const LOW_PIXELS := Vector2i(320, 180)
const WIDE := 13.4
const NEAR := 6.2
const YAW := 30.0
const PITCH := 36.0
const MODE_TIME := [2.75, 4.0, 2.88]
const MODE_NAME := ["待机", "移动", "招牌动作"]
const LABELS := ["史莱姆", "哥布林", "狼"]
const ACTIONS := [&"rebound", &"feint", &"pounce"]
const OFFSETS := [0.14, 0.40, 0.66]
const TURN_RADIUS := [0.46, 0.42, 0.64]
const LAP_STEPS := [5, 4, 5]

@onready var pixels: SubViewport = $Pixels
@onready var camera: Camera3D = $Pixels/World/Camera
@onready var world: Node3D = $Pixels/World
@onready var hud: Control = $Pixels/Notes
@onready var screen: TextureRect = $Screen
@onready var actors: Array[Node3D] = [$Pixels/World/Subjects/Slime, $Pixels/World/Subjects/Goblin, $Pixels/World/Subjects/Wolf]
var players: Array[AnimationPlayer] = []
var _marks: Array[Transform3D] = []
var _tags: Array[Panel] = []
var _surface_mats: Dictionary = {}
var _silhouette: StandardMaterial3D
var _readout: Label
var _auto := true
var _paused := false
var _dusk := false
var _is_silhouette := false
var _mode := 0
var _time := 0.0

func _ready() -> void:
	StudySet.new().build($Pixels/World/Set)
	_silhouette = StandardMaterial3D.new()
	_silhouette.albedo_color = Color("24212a")
	_silhouette.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for actor in actors:
		_marks.append(actor.transform)
		var player := actor.get_node("AnimationPlayer") as AnimationPlayer
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		players.append(player)
		for node in actor.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			_surface_mats[mesh] = mesh.material_override
	_build_notes()
	screen.texture = pixels.get_texture()
	resized.connect(_fit)
	var low := OS.get_cmdline_user_args().has("--320")
	set_framing(LOW_PIXELS if low else PIXELS, WIDE)
	set_dusk(false)
	pose_at(0, 0.0)

func _process(dt: float) -> void:
	if _paused:
		return
	_time += dt
	while _time >= MODE_TIME[_mode]:
		_time -= MODE_TIME[_mode]
		if _auto:
			_mode = (_mode + 1) % MODE_TIME.size()
	pose_at(_mode, _time)

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	match code:
		KEY_1, KEY_2, KEY_3:
			_auto = false
			_mode = code - KEY_1
			_time = 0.0
			pose_at(_mode, 0.0)
		KEY_A:
			_auto = true
			_mode = 0
			_time = 0.0
			pose_at(0, 0.0)
		KEY_Z:
			set_framing(pixels.size, NEAR if is_equal_approx(camera.size, WIDE) else WIDE)
		KEY_R:
			set_framing(LOW_PIXELS if pixels.size == PIXELS else PIXELS, camera.size)
		KEY_L: set_dusk(not _dusk)
		KEY_V: set_silhouette(not _is_silhouette)
		KEY_SPACE: _paused = not _paused
		_: return
	_refresh_readout(_mode)
	get_viewport().set_input_as_handled()

func pose_at(mode: int, elapsed: float) -> void:
	var lap := clampf(elapsed / MODE_TIME[1], 0.0, 1.0)
	for i in actors.size():
		var actor := actors[i]
		actor.transform = _marks[i]
		if mode == 1:
			var angle := lap * TAU
			var offset := Vector3(1.0 - cos(angle), 0.0, sin(angle)) * float(TURN_RADIUS[i])
			actor.position += _marks[i].basis * offset
			actor.rotate_y(angle)
			_clip(i, &"move", elapsed * float(LAP_STEPS[i]) * players[i].get_animation(&"move").length / MODE_TIME[1])
		elif mode == 2:
			var local := elapsed - float(OFFSETS[i])
			var length := players[i].get_animation(ACTIONS[i]).length
			if local >= 0.0 and local < length:
				_clip(i, ACTIONS[i], local)
			else:
				_clip(i, &"idle", maxf(0.0, local - length))
		else:
			_clip(i, &"idle", elapsed * (1.0 + 0.07 * i))
	_refresh_readout(mode)

func study_poses(mode: int, clip_phases: Array[float]) -> void:
	# Freeze a specified key for each specimen without changing the lens or physical scale.
	for i in actors.size():
		actors[i].transform = _marks[i]
		var clip: StringName = ACTIONS[i] if mode == 2 else (&"move" if mode == 1 else &"idle")
		_clip(i, clip, clip_phases[i] * players[i].get_animation(clip).length)
	_refresh_readout(mode)

func _clip(i: int, clip: StringName, seconds: float) -> void:
	var player := players[i]
	if player.current_animation != clip:
		player.play(clip)
	var animation := player.get_animation(clip)
	var phase := fposmod(seconds, animation.length) if animation.loop_mode != Animation.LOOP_NONE else clampf(seconds, 0.0, animation.length)
	player.seek(phase, true)

func set_framing(resolution: Vector2i, lens: float) -> void:
	pixels.size = resolution
	get_window().min_size = resolution
	camera.size = lens
	# Match orbit_camera.gd's projection and view-plane texel snap, with a fixed study target.
	var basis := Basis.from_euler(Vector3(-deg_to_rad(PITCH), deg_to_rad(YAW), 0))
	var aim := Vector3(0, 0.58, 0)
	var texel := lens / float(resolution.y)
	var u := aim.dot(basis.x)
	var v := aim.dot(basis.y)
	var snap := aim + basis.x * (snappedf(u, texel) - u) + basis.y * (snappedf(v, texel) - v)
	camera.global_transform = Transform3D(basis, snap + basis.z * 23.0)
	_fit()
	_place_tags()
	_refresh_readout(_mode)

func _fit() -> void:
	var base := Vector2(pixels.size)
	var k := maxi(1, floori(minf(size.x / base.x, size.y / base.y)))
	screen.size = base * k
	screen.position = ((size - screen.size) * 0.5).floor()

func set_dusk(value: bool) -> void:
	_dusk = value
	# Outdoor daytime/dusk samples from clockwork.gd, applied only to this viewport.
	var hour := 18.66667 if value else 14.0
	var h := sin((hour - 6.0) * TAU / 24.0)
	var high := clampf(h, 0.0, 1.0)
	var daylight := smoothstep(-0.205, 0.275, h)
	var honey := 1.0 - smoothstep(0.02, 0.55, high)
	var environment: Environment = $Pixels/World/Air.environment
	environment.background_color = Color("141e37").lerp(Color("94c7cf").lerp(Color("eb9d87"), honey * 0.87), daylight)
	environment.ambient_light_color = Color("92a6d8").lerp(Color("c4d2dd").lerp(Color("c1a4bb"), honey * 0.68), daylight)
	environment.ambient_light_energy = lerpf(0.285, 0.69, daylight)
	var sun: DirectionalLight3D = $Pixels/World/Sun
	sun.rotation_degrees = Vector3(-lerpf(18.0, 59.0, high), 80.0 - (hour - 6.0) * 14.9, 0.0)
	sun.shadow_bias = lerpf(0.39, 0.12, smoothstep(0.06, 0.52, high))
	sun.shadow_normal_bias = lerpf(1.95, 1.3, smoothstep(0.06, 0.52, high))
	sun.light_color = Color("ff9168").lerp(Color("fff4d9"), smoothstep(0.01, 0.50, high))
	sun.light_energy = smoothstep(-0.12, 0.11, h) * lerpf(0.71, 1.03, smoothstep(0.0, 0.64, high))
	sun.visible = sun.light_energy > 0.003
	var moon: DirectionalLight3D = $Pixels/World/Moon
	moon.rotation_degrees = Vector3(-lerpf(17.0, 51.0, clampf(-h, 0.0, 1.0)), -78.0 + 43.0 * sin((hour - 19.0) * TAU / 24.0), 0.0)
	moon.light_energy = (1.0 - smoothstep(-0.27, 0.16, h)) * 0.205
	moon.visible = moon.light_energy > 0.002
	_refresh_readout(_mode)

func set_silhouette(value: bool) -> void:
	_is_silhouette = value
	for mesh: MeshInstance3D in _surface_mats:
		mesh.material_override = _silhouette if value else _surface_mats[mesh]
	_refresh_readout(_mode)

func _build_notes() -> void:
	# PaperSlip / PaperTag resolve to the existing shared theme. This is a read-only legend.
	var heading := _paper(hud, &"PaperSlip", Vector2(126, 28), "林间图鉴  ·  01", 13)
	heading.position = Vector2(8, 7)
	var state := _paper(hud, &"PaperSlip", Vector2(125, 28), "", 11)
	state.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	state.position = Vector2(pixels.size.x - 132, 7)
	_readout = state.get_child(0) as Label
	for i in LABELS.size():
		_tags.append(_paper(hud, &"PaperTag", Vector2(44 if i < 2 else 32, 18), LABELS[i], 11))
	var help := Label.new()
	hud.add_child(help)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help.text = "1 待机    2 移动    3 招牌    A 连播    空格 暂停\nZ 远/近    R 像素档    L 光照    V 剪影"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override(&"font_size", 11)
	help.add_theme_color_override(&"font_color", Color("f5dfb9"))
	help.add_theme_color_override(&"font_outline_color", Color("382e25"))
	help.add_theme_constant_override(&"outline_size", 3)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 5)

func _paper(parent: Control, style: StringName, dim: Vector2, text: String, font_size: int) -> Panel:
	var panel := Panel.new()
	panel.theme_type_variation = style
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	panel.size = dim
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return panel

func _place_tags() -> void:
	for i in actors.size():
		var world_mark: Vector3 = (actors[i].get_parent() as Node3D).to_global(_marks[i].origin)
		var offset := Vector2(-_tags[i].size.x * 0.5, 10 + 3.3 / camera.size * 29.0)
		_tags[i].position = (camera.unproject_position(world_mark) + offset).round()

func _refresh_readout(mode: int) -> void:
	if not is_instance_valid(_readout):
		return
	var text := "%s  ·  %d" % [MODE_NAME[mode], pixels.size.x]
	text += "  ·  " + ("剪影" if _is_silhouette else ("暮" if _dusk else "昼"))
	if _paused:
		text += "  ‖"
	if text != _readout.text:
		_readout.text = text
