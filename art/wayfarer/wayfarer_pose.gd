extends Node3D
## axis is screen-space; distance is actual displacement in metres this physics tick.

@onready var facing: Node3D = $Facing
@onready var torso: Node3D = $Facing/Torso
@onready var left_leg: Node3D = $Facing/LeftLeg
@onready var right_leg: Node3D = $Facing/RightLeg
@onready var left_arm: Node3D = $Facing/Torso/LeftArm
@onready var right_arm: Node3D = $Facing/Torso/RightArm
@onready var scarf_tail: Node3D = $Facing/Torso/ScarfTail

var phase := 0.0
var blend := 0.0
var heading := deg_to_rad(13.0)

func pose(axis: Vector2, distance: float) -> void:
	var dt := get_physics_process_delta_time()
	var walking := distance > 0.00001 and axis.length_squared() > 0.00001
	if walking:
		var angle := snappedf(atan2(axis.y, axis.x), PI / 4.0)
		var world := Vector3(0.8660254, 0, -0.5) * cos(angle) + Vector3(0.5, 0, 0.8660254) * sin(angle)
		heading = atan2(world.x, world.z)
		phase = fposmod(phase + distance * TAU / 0.68, TAU)
	facing.rotation.y = lerp_angle(facing.rotation.y, heading, 1.0 - exp(-19.0 * dt))
	blend = move_toward(blend, 1.0 if walking else 0.0, dt * 8.0)
	var stride := sin(phase) * blend
	left_leg.rotation.x = stride * 0.50
	right_leg.rotation.x = -stride * 0.50
	left_leg.position.y = 0.65 + maxf(0.0, -cos(phase)) * blend * 0.065
	right_leg.position.y = 0.65 + maxf(0.0, cos(phase)) * blend * 0.065
	left_arm.rotation.x = -stride * 0.43
	right_arm.rotation.x = stride * 0.43
	torso.position.y = absf(cos(phase)) * blend * 0.026
	torso.rotation.z = stride * 0.045
	scarf_tail.rotation.x = stride * 0.14 - blend * 0.13
