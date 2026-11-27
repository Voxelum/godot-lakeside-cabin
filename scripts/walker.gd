extends CharacterBody3D
## Movement and collision are world-space; the input axes belong to the active camera.
signal stepped(previous: Vector3, current: Vector3)
signal walked(metres: float)
@export_range(1.0, 8.0, 0.1) var walk_speed: float = 2.45
@export_range(1.0, 12.0, 0.1) var sprint_speed: float = 4.1
@onready var artwork: Node3D = $Appearance
const MOVE_ACTIONS := [&"walk_left", &"walk_right", &"walk_up", &"walk_down", &"sprint"]
var _wait_for_neutral := false
var combat: Node
var locked := false:
	set(value):
		if locked != value:
			settle_input()
		locked = value

func settle_input() -> void:
	_wait_for_neutral = true
	velocity = Vector3.ZERO
	if combat: combat.reset()

func _controls_neutral(axis: Vector2) -> bool:
	if not axis.is_zero_approx():
		return false
	# Opposing held controls can cancel the vector. Also poll mapped controls
	# because changing InputMap clears actions without releasing physical inputs.
	for action in MOVE_ACTIONS:
		var deadzone := InputMap.action_get_deadzone(action)
		if Input.is_action_pressed(action) or Input.get_action_raw_strength(action) > deadzone:
			return false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				if event.physical_keycode != 0 and Input.is_physical_key_pressed(event.physical_keycode):
					return false
				if event.keycode != 0 and Input.is_key_pressed(event.keycode):
					return false
			elif event is InputEventMouseButton and Input.is_mouse_button_pressed(event.button_index):
				return false
			elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
				for device in Input.get_connected_joypads():
					if event is InputEventJoypadButton and Input.is_joy_button_pressed(device, event.button_index):
						return false
					if event is InputEventJoypadMotion and Input.get_joy_axis(device, event.axis) * event.axis_value > deadzone:
						return false
	return true

func combat_heading() -> Vector3:
	if _wait_for_neutral: return Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	if camera == null: return Vector3.ZERO
	var axis := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	var right := camera.global_basis.x.slide(Vector3.UP).normalized()
	return right * axis.x + right.cross(Vector3.UP) * axis.y

func _physics_process(dt: float) -> void:
	if locked:
		return
	var axis := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	if _wait_for_neutral:
		_wait_for_neutral = not _controls_neutral(axis)
		axis = Vector2.ZERO
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var right := camera.global_basis.x.slide(Vector3.UP).normalized()
	var heading := right * axis.x + right.cross(Vector3.UP) * axis.y
	if combat:
		combat.tick(dt)
		if combat.action == &"idle": combat.face(heading)
		heading = combat.movement(heading)
	var combat_pose: bool = combat != null and combat.action != &"idle"
	var sprinting := Input.is_action_pressed(&"sprint") and not combat_pose
	var speed := sprint_speed if sprinting else walk_speed
	velocity.x = heading.x * speed
	velocity.z = heading.z * speed
	# With a nonzero downward push, contacts on a shallow grade can steal part
	# of a stride. Let CharacterBody's floor snap retain the surface instead.
	velocity.y = 0.0 if is_on_floor() else maxf(-18.0, velocity.y - 20.0 * dt)
	var start := global_position
	move_and_slide()
	var stride := (global_position-start).slide(Vector3.UP)
	if combat_pose:
		pass # The combat driver owns the view during a combat action.
	elif artwork.has_method(&"pose_motion"):
		artwork.call(&"pose_motion", heading, stride.length(), dt, sprinting)
	elif artwork.has_method(&"pose_world"):
		artwork.call(&"pose_world", heading, stride.length(), dt)
	elif artwork.has_method(&"pose"):
		artwork.call(&"pose", axis, stride.length())
	# Only the movement solver can produce training distance. No distance across
	# spawn/door/load transforms, idle snap, or locked/inactive actors.
	if not combat_pose and not heading.is_zero_approx() and stride.dot(heading) > 0.00001:
		walked.emit(minf(stride.length(), speed * dt * heading.length()))
	stepped.emit(start, global_position)
