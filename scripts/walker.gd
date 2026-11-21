extends CharacterBody3D
## Movement and collision are world-space; the input axes belong to the active camera.
signal stepped(previous: Vector3, current: Vector3)
@export_range(1.0, 8.0, 0.1) var walk_speed: float = 1.82
@onready var artwork: Node3D = $Appearance
var locked := false
var held_across_threshold := Vector2.ZERO

func settle_input() -> void:
	held_across_threshold = Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	velocity = Vector3.ZERO

func _physics_process(dt: float) -> void:
	if locked:
		return
	var axis := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	if held_across_threshold != Vector2.ZERO:
		if axis.is_equal_approx(held_across_threshold):
			axis = Vector2.ZERO
		else:
			held_across_threshold = Vector2.ZERO
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var right := camera.global_basis.x.slide(Vector3.UP).normalized()
	var heading := right * axis.x + right.cross(Vector3.UP) * axis.y
	velocity.x = heading.x * walk_speed
	velocity.z = heading.z * walk_speed
	# With a nonzero downward push, contacts on a shallow grade can steal part
	# of a stride. Let CharacterBody's floor snap retain the surface instead.
	velocity.y = 0.0 if is_on_floor() else maxf(-18.0, velocity.y - 20.0 * dt)
	var start := global_position
	move_and_slide()
	var stride := (global_position-start).slide(Vector3.UP)
	if artwork.has_method(&"pose_world"):
		artwork.call(&"pose_world", heading, stride.length(), dt)
	elif artwork.has_method(&"pose"):
		artwork.call(&"pose", axis, stride.length())
	stepped.emit(start, global_position)
