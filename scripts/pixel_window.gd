extends Control
## One pixel composer; two independent World3Ds. Inactive rooms never leak lights,
## water reflections, physics or HUD into the destination. Both cameras persist.
@export_enum("320 × 180", "480 × 270") var resolution_preset: int = 1
@export_range(0.25, 1.5, 0.05) var iris_seconds := 0.62
@onready var field: SubViewport = $Pixels
@onready var room: SubViewport = $RoomPixels
@onready var field_actor = $Pixels/Clearing/Traveler
@onready var room_actor = $RoomPixels/Guest
@onready var field_door: Marker3D = $Pixels/Clearing/Cottage/DoorAnchor
@onready var room_door: Marker3D = $RoomPixels/Interior/DoorAnchor
@onready var field_entry: Marker3D = $Pixels/Clearing/Cottage/Entry
@onready var room_entry: Marker3D = $RoomPixels/Interior/Entry
@onready var shutter: ShaderMaterial = $Screen.material
@onready var orbit = $Pixels/Clearing/Camera
var indoors := false
var crossing := false
var shutter_phase := "idle"
var iris_center := Vector2.ZERO
var iris_radius := 0.0

func _ready() -> void:
	if "--320" in OS.get_cmdline_user_args(): resolution_preset = 0
	var base := Vector2i(480, 270) if resolution_preset == 1 else Vector2i(320, 180)
	field.size = base
	room.size = base
	$Screen.texture = field.get_texture()
	shutter.set_shader_parameter(&"buffer_size", Vector2(base))
	get_window().min_size = base
	resized.connect(_fit)
	_fit()
	room_actor.locked = true
	field_actor.stepped.connect(_watch_threshold.bind(false))
	room_actor.stepped.connect(_watch_threshold.bind(true))

func _fit() -> void:
	var base := Vector2(field.size)
	var k := maxi(1, floori(minf(size.x / base.x, size.y / base.y)))
	$Screen.size = base * k
	$Screen.position = ((size - $Screen.size) * 0.5).floor()

func _watch_threshold(previous: Vector3, current: Vector3, in_room: bool) -> void:
	if crossing or in_room != indoors: return
	var marker := room_door if in_room else field_door
	var a := marker.to_local(previous)
	var b := marker.to_local(current)
	# A directed plane crossing by the feet, not a proximity timer or a key.
	var direction := 1.0 if in_room else -1.0
	if a.z * direction >= 0.0 or b.z * direction < 0.0: return
	var along := lerpf(a.x, b.x, -a.z / (b.z - a.z))
	if absf(along) > (0.76 if in_room else 0.63): return
	_trip()

func _locate_iris() -> float:
	var vp := room if indoors else field
	var mark := room_door if indoors else field_door
	iris_center = vp.get_camera_3d().unproject_position(mark.global_position)
	shutter.set_shader_parameter(&"threshold_px", iris_center)
	var far_corner := Vector2(maxf(iris_center.x, vp.size.x - iris_center.x), maxf(iris_center.y, vp.size.y - iris_center.y))
	return ceilf(far_corner.length()) + 2.0

func _radius(value: float) -> void:
	iris_radius = value
	shutter.set_shader_parameter(&"radius_px", value)

func _trip() -> void:
	crossing = true
	field_actor.locked = true
	room_actor.locked = true
	orbit.end_drag()
	orbit.frozen = true
	shutter_phase = "close"
	var far_radius := _locate_iris()
	_radius(far_radius)
	shutter.set_shader_parameter(&"shutter", true)
	var closing := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	closing.tween_method(_radius, far_radius, 0.0, iris_seconds)
	await closing.finished
	_radius(0.0)
	shutter_phase = "black_source"
	# Radius zero has actually been presented before any world/actor changes.
	await RenderingServer.frame_post_draw
	await get_tree().create_timer(0.09).timeout
	indoors = not indoors
	for ambience in [$Pixels/Clearing/Sunbreak, $Pixels/Clearing/ForestLife, $Pixels/Clearing/Almanac]:
		ambience.process_mode = Node.PROCESS_MODE_DISABLED if indoors else Node.PROCESS_MODE_INHERIT
	var arrival = room_actor if indoors else field_actor
	var mark := room_entry if indoors else field_entry
	arrival.global_position = mark.global_position
	# Ground a new arrival under the shutter (including the outdoor paving).
	var foot: Vector3 = mark.global_position
	var query := PhysicsRayQueryParameters3D.create(foot+Vector3.UP*0.32,foot-Vector3.UP*0.38)
	query.exclude = [arrival.get_rid()]
	var hit: Dictionary = arrival.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): arrival.global_position.y = hit.position.y + 0.002
	arrival.velocity = Vector3.ZERO
	arrival.reset_physics_interpolation()
	if arrival.artwork.has_method(&"reset_pose"):
		arrival.artwork.reset_pose(Vector3.FORWARD if indoors else Vector3.BACK)
	if not indoors: orbit.align_at_subject()
	field.render_target_update_mode = SubViewport.UPDATE_DISABLED if indoors else SubViewport.UPDATE_ALWAYS
	$Pixels/Clearing/Pool/MirrorViewport.render_target_update_mode = field.render_target_update_mode
	room.render_target_update_mode = SubViewport.UPDATE_ALWAYS if indoors else SubViewport.UPDATE_DISABLED
	$Screen.texture = room.get_texture() if indoors else field.get_texture()
	shutter_phase = "black_destination"
	far_radius = _locate_iris()
	# Destination and reflection pass must have rendered before the reveal.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await get_tree().create_timer(0.06).timeout
	shutter_phase = "open"
	var opening := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	opening.tween_method(_radius, 0.0, far_radius, iris_seconds)
	await opening.finished
	shutter.set_shader_parameter(&"shutter", false)
	arrival.settle_input()
	arrival.locked = false
	orbit.frozen = indoors
	crossing = false
	shutter_phase = "idle"

func _input(event: InputEvent) -> void:
	if not is_node_ready() or indoors or crossing or not (event is InputEventMouse): return
	var screen: TextureRect = $Screen
	if orbit.camera_input(event, screen.get_rect(), screen.size.x/field.size.x):
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_node_ready(): orbit.end_drag()

func _unhandled_key_input(event: InputEvent) -> void:
	if indoors or crossing: return
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo: return
	if key.keycode == KEY_B:
		var sunbreak = $Pixels/Clearing/Sunbreak
		sunbreak.shown = not sunbreak.shown
		get_viewport().set_input_as_handled()
	elif $Pixels/Clearing/Almanac.handle_key(key.keycode):
		get_viewport().set_input_as_handled()
