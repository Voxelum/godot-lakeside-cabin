extends CharacterBody3D
## A solid outdoor actor. The visual is a child, not a second moving object
## beside an invisible blocker. Layer 1 is the existing Walker/world contract.

@export var combat_target := false
@export var body_shape: Shape3D
@export var body_center := Vector3.ZERO
@export var body_rotation_degrees := Vector3.ZERO

var solid: CollisionShape3D

func _ready() -> void:
	if not body_shape:
		push_error("Field actor without a body shape: " + str(get_path()))
		return
	collision_layer = 1
	collision_mask = 1
	safe_margin = .002
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group(&"field_occupant")
	solid = CollisionShape3D.new()
	solid.name = "SolidBody"
	solid.shape = body_shape
	solid.position = body_center
	solid.rotation_degrees = body_rotation_degrees
	add_child(solid)

func use_capsule(radius: float, height: float) -> void:
	# Configure before adding the actor to the tree. Height includes both caps.
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = height
	body_shape = capsule
	body_center = Vector3(0, height * .5, 0)

func fit_floor() -> void:
	# Initial placement only. Exclude occupants/Walker even though they share
	# the traversable world's collision layer.
	var at := global_position
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * .45, at - Vector3.UP * .44, collision_mask)
	var omit: Array[RID] = []
	for group in [&"field_occupant", &"traveler"]:
		for body in get_tree().get_nodes_in_group(group):
			if body is PhysicsBody3D:
				omit.append(body.get_rid())
	query.exclude = omit
	var support := get_world_3d().direct_space_state.intersect_ray(query)
	if not support.is_empty():
		global_position.y = support.position.y + .009

func move_to_mark(target: Vector3, limit: float) -> Vector3:
	# Sweep actual motion; do not teleport to the timetable's destination nor
	# push a stopped Walker out of the way. Report travel for foot animation.
	var before := global_position
	var delta := (target - before).limit_length(limit)
	if delta.length_squared() > .00000001:
		move_and_collide(delta)
	return global_position - before

func try_yaw(yaw: float) -> void:
	if absf(angle_difference(global_rotation.y, yaw)) < .001:
		return
	# A long body can sweep into the Walker while turning, even with no linear
	# travel. Check the proposed shape transform before applying a common yaw.
	var proposed := Transform3D(Basis(Vector3.UP, yaw), global_position)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body_shape
	query.transform = proposed * solid.transform
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		global_rotation.y = yaw
