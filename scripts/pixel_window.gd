extends Control
## One pixel composer; two independent World3Ds. Inactive rooms never leak lights,
## water reflections, physics or HUD into the destination. The Guest actor persists across room layouts.
const ROOMS := preload("res://world/interiors/room_catalog.gd")
const UI := preload("res://scripts/ui/ui_layout.gd")
@export_enum("320 × 180", "480 × 270") var resolution_preset: int = 1
@export_range(0.25, 1.5, 0.05) var iris_seconds := 0.62
@export var developer_camera := false
@onready var session = $Session
@onready var field: SubViewport = $Pixels
@onready var room: SubViewport = $RoomPixels
@onready var field_actor = $Pixels/Clearing/Traveler
@onready var room_actor = $RoomPixels/Guest
@onready var field_door: Marker3D = $Pixels/Clearing/Cottage.marker("DoorAnchor")
@onready var field_entry: Marker3D = $Pixels/Clearing/Cottage.marker("Approach")
@onready var room_door: Marker3D = $RoomPixels/Interior/Structure/DoorAnchor
@onready var room_entry: Marker3D = $RoomPixels/Interior/Structure/Entry
@onready var shutter: ShaderMaterial = $Screen.material
@onready var orbit = $Pixels/Clearing/Camera
@onready var _room_layout: Node3D = $RoomPixels/Interior
var _layout_id := ROOMS.CABIN
var _lot_by_id := {}
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
	if not get_window().is_embedded() and not "--wid" in OS.get_cmdline_args():
		get_window().min_size = UI.MIN_WINDOW
	resized.connect(_fit)
	_fit()
	developer_camera = developer_camera or "--dev-camera" in OS.get_cmdline_user_args()
	field_actor.stepped.connect(_watch_threshold.bind(false))
	room_actor.stepped.connect(_watch_threshold.bind(true))
	for id: String in ROOMS.ROOMS:
		var lot := ROOMS.outdoor_lot($Pixels/Clearing, id)
		if ROOMS.outdoor_door(lot) and ROOMS.outdoor_return(lot): _lot_by_id[id] = lot
		else: push_error("室内门缺少室外挂点：" + id)
	session.start()
	sync_control()

func _fit() -> void:
	var base := Vector2(field.size)
	# Keep the entire field visible even in a small editor-embedded host.
	var k := minf(size.x / base.x, size.y / base.y)
	$Screen.size = base * k
	$Screen.position = (size - $Screen.size) * 0.5

func _physics_process(dt: float) -> void:
	if indoors: return
	for lot: Node3D in _lot_by_id.values():
		var hinge := ROOMS.outdoor_hinge(lot)
		if hinge != null: hinge.track_foot(field_actor.global_position, dt)

func _watch_threshold(previous: Vector3, current: Vector3, in_room: bool) -> void:
	if crossing or in_room != indoors or session.is_modal(): return
	session.stepped(current)
	if not in_room:
		for id: String in _lot_by_id:
			if ROOMS.crossed_outdoor(_lot_by_id[id], previous, current):
				_trip(id)
				return
		return
	var a := room_door.to_local(previous)
	var b := room_door.to_local(current)
	# Directed foot plane; a Walker on the upstairs deck cannot leave here.
	if a.z >= 0.0 or b.z < 0.0: return
	var hit := a.lerp(b, -a.z / (b.z - a.z))
	if absf(hit.x) > float(room_door.get_meta("passage_width")) * .5 or absf(hit.y) > .42: return
	_trip()

func _locate_iris(mark: Marker3D) -> float:
	var vp := room if indoors else field
	iris_center = vp.get_camera_3d().unproject_position(mark.global_position)
	shutter.set_shader_parameter(&"threshold_px", iris_center)
	var far_corner := Vector2(maxf(iris_center.x, vp.size.x - iris_center.x), maxf(iris_center.y, vp.size.y - iris_center.y))
	return ceilf(far_corner.length()) + 2.0

func _radius(value: float) -> void:
	iris_radius = value
	shutter.set_shader_parameter(&"radius_px", value)

func active_actor():
	return room_actor if indoors else field_actor

func sync_control(settle := false) -> void:
	var blocked: bool = crossing or session.is_modal()
	field_actor.locked = blocked or indoors
	room_actor.locked = blocked or not indoors
	if settle: active_actor().settle_input()
	if blocked or settle: session.clear_combat_input()
	if blocked or indoors: orbit.end_drag()
	orbit.frozen = blocked or indoors
	$Dial.set_available(not crossing and not session.is_modal())
	$FieldHUD.visible = not crossing and not $BindingPanel.visible and not $SettingsBook.opened
	$SettingsBook.launcher.visible = not blocked
	var fast_key := InputEventKey.new()
	fast_key.physical_keycode = KEY_T
	fast_key.keycode = KEY_T if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(KEY_T)
	$Pixels/Clearing/Almanac.allow_fast_key = not blocked and not session.is_mapped(fast_key)

func _trip(outdoor_room_id := ROOMS.CABIN) -> void:
	var id: String = _layout_id if indoors else outdoor_room_id
	var lot: Node3D = _lot_by_id.get(id)
	var exterior_door := ROOMS.outdoor_door(lot) if lot != null else field_door
	var exterior_return := ROOMS.outdoor_return(lot) if lot != null else field_entry
	crossing = true
	sync_control()
	shutter_phase = "close"
	var far_radius := _locate_iris(room_door if indoors else exterior_door)
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
	var entering := not indoors
	if entering: _mount_room(id)
	var mark := room_entry if entering else exterior_return
	show_place(entering, mark.global_position, true, exterior_door)
	shutter_phase = "black_destination"
	far_radius = _locate_iris(room_door if indoors else exterior_door)
	# Destination and reflection pass must have rendered before the reveal.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await get_tree().create_timer(0.06).timeout
	shutter_phase = "open"
	var opening := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	opening.tween_method(_radius, 0.0, far_radius, iris_seconds)
	await opening.finished
	shutter.set_shader_parameter(&"shutter", false)
	crossing = false
	shutter_phase = "idle"
	sync_control(true)

func place_id() -> String:
	return _layout_id if indoors else ROOMS.FIELD

func building_structure() -> Node3D:
	return _room_layout.get_node("Structure") as Node3D if indoors else null

func restore_place(id: String, foot: Vector3, revision := "") -> bool:
	var relocated := false
	if id != ROOMS.FIELD:
		_mount_room(id)
		var structure := _room_layout.get_node("Structure") as Node3D
		relocated = revision != str(structure.get_meta("building_revision"))
		foot = room_entry.global_position if relocated else structure.to_global(foot)
		if not relocated and _room_layout.has_method(&"saved_foot_obstructed"):
			relocated = _room_layout.saved_foot_obstructed(foot, room_actor.get_node("Body").shape)
			if relocated: foot = room_entry.global_position
		show_place(true, foot, false)
		return relocated
	# Outdoor saves still use their exact world feet, except if the old
	# position has been covered by a rebuilt closed structure.
	for lot: Node3D in _lot_by_id.values():
		if lot.covers_outdoor_foot(foot):
			show_place(false, ROOMS.outdoor_return(lot).global_position, true)
			return false # The caller's indoor relocation message doesn't apply.
	show_place(false, foot, false)
	return false

func _mount_room(id: String) -> void:
	if id == _layout_id: return
	var scene := ROOMS.layout(id)
	assert(scene != null, "Missing room layout: " + id)
	var next := scene.instantiate() as Node3D
	room.remove_child(_room_layout)
	_room_layout.queue_free()
	_room_layout = next
	next.name = "Interior"
	room.add_child(next)
	var anchors := next.get_node("Structure")
	room_door = anchors.get_node("DoorAnchor")
	room_entry = anchors.get_node("Entry")
	_layout_id = id

func show_place(in_room: bool, foot: Vector3, snap_to_entry: bool, crossing_door: Marker3D = null) -> void:
	indoors = in_room
	$Dial.set_available(not crossing and not session.is_modal())
	# The shared clock keeps driving indoor window light even when the field is hidden.
	for ambience in [$Pixels/Clearing/Sunbreak, $Pixels/Clearing/ForestLife]:
		ambience.process_mode = Node.PROCESS_MODE_DISABLED if indoors else Node.PROCESS_MODE_INHERIT
	var arrival = active_actor()
	arrival.global_position = foot
	if snap_to_entry:
		# Door arrivals ground under the shutter; loading keeps the saved feet.
		var query := PhysicsRayQueryParameters3D.create(foot+Vector3.UP*0.32,foot-Vector3.UP*0.38)
		query.exclude = [arrival.get_rid()]
		var hit: Dictionary = arrival.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): arrival.global_position.y = hit.position.y + 0.002
	arrival.velocity = Vector3.ZERO
	arrival.reset_physics_interpolation()
	if arrival.artwork.has_method(&"reset_pose"):
		var heading := -room_door.global_basis.z if indoors else (crossing_door.global_basis.z if crossing_door else Vector3.BACK)
		arrival.artwork.reset_pose(heading)
		if arrival.combat: arrival.combat.face(heading)
	if not indoors: orbit.align_at_subject()
	field.render_target_update_mode = SubViewport.UPDATE_DISABLED if indoors else SubViewport.UPDATE_ALWAYS
	$Pixels/Clearing/Pool/MirrorViewport.render_target_update_mode = field.render_target_update_mode
	room.render_target_update_mode = SubViewport.UPDATE_ALWAYS if indoors else SubViewport.UPDATE_DISABLED
	$Screen.texture = room.get_texture() if indoors else field.get_texture()
	if indoors and _room_layout.has_method(&"focus_foot"):
		var from_door := crossing_door if crossing_door else ROOMS.outdoor_door(_lot_by_id.get(_layout_id))
		if from_door != null:
			var right: Vector3 = room_door.global_basis * (from_door.global_basis.inverse() * orbit.global_basis.x)
			_room_layout.set_entry_view(right)
		_room_layout.focus_foot(arrival.global_position, true)
	session.place_changed()

func _input(event: InputEvent) -> void:
	if is_node_ready() and session.handle_event(event):
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_node_ready():
		orbit.end_drag()
		session.clear_combat_input()

func _unhandled_key_input(event: InputEvent) -> void:
	if indoors or crossing or session.is_modal() or session.is_mapped(event): return
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo: return
	if key.keycode == KEY_B:
		var sunbreak = $Pixels/Clearing/Sunbreak
		sunbreak.shown = not sunbreak.shown
		get_viewport().set_input_as_handled()
	elif $Pixels/Clearing/Almanac.handle_key(key.keycode):
		get_viewport().set_input_as_handled()
