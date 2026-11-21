extends CharacterBody3D
## Input is in screen space. Only the camera's horizontal heading is used;
## pitch must not shorten forward strides. Physics stays continuous.
@export_range(1.0, 8.0, 0.1) var walk_speed: float = 3.6
@onready var artwork: Node3D = $Appearance

func _physics_process(_dt: float) -> void:
	var axis := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var down := right.cross(Vector3.UP)
	velocity = (right * axis.x + down * axis.y) * walk_speed
	move_and_slide()
	if artwork.has_method(&"pose"):
		artwork.call(&"pose", axis, get_position_delta().length())
