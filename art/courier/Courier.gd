extends Node3D
## Call once per physics tick after moving the parent; distance is actual XZ travel.
const U := 0.422
const L := 0.422
const CYCLE := 1.24
const STANCE := 0.60
const SOLE := 0.079
const HEEL := -0.084
const TOE := 0.158
var phase := 0.0
var clock := 0.0
var gait := 0.0
var heading := Vector3.FORWARD
var still_time := 0.0
var resting_z := [0.0, 0.0]
var last_z := [0.0, 0.0]
@onready var facing: Node3D = $Facing
@onready var hips: Node3D = $Facing/Hips
@onready var chest: Node3D = $Facing/Hips/Chest
@onready var head: Node3D = $Facing/Hips/Chest/Head
@onready var eyes: Node3D = $Facing/Hips/Chest/Head/Eyes
@onready var arms: Array[Node3D] = [$Facing/Hips/Chest/ShoulderL, $Facing/Hips/Chest/ShoulderR]
@onready var thighs: Array[Node3D] = [$Facing/Hips/ThighL, $Facing/Hips/ThighR]
@onready var calves: Array[Node3D] = [$Facing/Hips/ThighL/CalfL, $Facing/Hips/ThighR/CalfR]
@onready var boots: Array[Node3D] = [$Facing/Hips/ThighL/CalfL/BootL, $Facing/Hips/ThighR/CalfR/BootR]

func _ready() -> void:
	reset_pose(Vector3.BACK)

func reset_pose(direction: Vector3) -> void:
	_set_heading(direction)
	facing.global_rotation = Vector3(0, _yaw(), 0)
	phase = 0.0
	gait = 0.0
	still_time = 0.0
	resting_z = [0.0, 0.0]
	_apply()

func pose_world(direction: Vector3, horizontal_distance: float, dt: float) -> void:
	_set_heading(direction)
	var step := maxf(dt, 0.0)
	clock += step
	var rot := facing.global_rotation
	rot.y = lerp_angle(rot.y, _yaw(), 1.0 - exp(-step * 22.0))
	facing.global_rotation = rot
	if horizontal_distance > 0.00005:
		still_time = 0.0
		phase = fposmod(phase + horizontal_distance / CYCLE, 1.0)
		gait = move_toward(gait, 1.0, horizontal_distance / 0.20)
	else:
		if still_time == 0.0:
			resting_z = last_z.duplicate()
		still_time += step
		if still_time > 0.045:
			gait = move_toward(gait, 0.0, step * 4.3)
			if gait == 0.0:
				phase = 0.0
	_apply()

func _set_heading(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0, direction.z)
	if flat.length_squared() > 0.000001:
		heading = flat.normalized()

func _yaw() -> float:
	return atan2(heading.x, heading.z)

func _ease(t: float) -> float:
	var k := clampf(t, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)

func _apply() -> void:
	var stride := CYCLE * STANCE
	var wave := TAU * phase
	var weight := _ease(gait)
	var breath := sin(clock * 2.9)
	var span := maxf(absf(resting_z[0]), absf(resting_z[1]))
	var rest_height := minf(0.908, SOLE + sqrt(0.841 * 0.841 - span * span))
	hips.position.y = lerpf(rest_height, 0.844 - 0.065 * cos(2.0 * (wave + TAU * 0.05)), weight)
	hips.position.z = 0.025 * weight
	chest.rotation = Vector3(0.10 * weight, 0.12 * sin(wave) * weight, 0.032 * cos(wave) * weight + 0.016 * breath)
	chest.position.y = 0.006 * breath
	head.rotation = Vector3(-0.06 * weight, -0.07 * sin(wave) * weight, -0.018 * breath)
	var blink := absf(fposmod(clock + 2.1, 4.6) - 0.11)
	eyes.scale.y = lerpf(0.105, 1.0, _ease(blink / 0.085))
	for i in 2:
		var p := fposmod(phase + 0.5 * i + 0.05, 1.0)
		var z: float
		var lift := 0.0
		var roll: float
		if p < STANCE:
			var t := p / STANCE
			z = stride * (0.5 - t)
			roll = 0.26 * (1.0 - _ease(t / 0.22)) - 0.53 * _ease((t - 0.70) / 0.30)
		else:
			var t := (p - STANCE) / (1.0 - STANCE)
			# Hermite swing: matching backwards travel velocity at both contacts.
			z = stride * (_ease(t) - 0.5) - CYCLE * (1.0 - STANCE) * t * (1.0 - t) * (1.0 - 2.0 * t)
			lift = 0.172 * pow(sin(PI * t), 2)
			roll = lerpf(-0.53, 0.26, _ease(t))
		roll *= weight
		var pivot := HEEL if roll >= 0.0 else TOE
		last_z[i] = resting_z[i] if still_time > 0.0 else lerpf(resting_z[i], z, weight)
		var support := Vector3(0.0, 0.0, last_z[i] + pivot)
		var contact := Vector3(0.0, -SOLE, pivot).rotated(Vector3.RIGHT, -roll)
		var ankle := support - contact + Vector3.UP * lift * weight
		_solve(i, ankle - Vector3(0.0, hips.position.y, hips.position.z), -roll)
		arms[i].rotation.x = 0.37 * cos(TAU * p) * weight + 0.075 * breath

func _solve(i: int, target: Vector3, boot_pitch: float) -> void:
	var radius := clampf(Vector2(target.y, target.z).length(), 0.01, U + L - 0.001)
	var aim := atan2(target.z, -target.y)
	var hip_offset := acos(clampf((U * U + radius * radius - L * L) / (2.0 * U * radius), -1.0, 1.0))
	var bend := PI - acos(clampf((U * U + L * L - radius * radius) / (2.0 * U * L), -1.0, 1.0))
	thighs[i].rotation.x = -(aim + hip_offset)
	calves[i].rotation.x = bend
	boots[i].rotation.x = boot_pitch - thighs[i].rotation.x - bend

const CombatMotion := preload("res://scripts/foundation/combat_motion.gd")
const CombatProps := preload("res://scripts/foundation/combat_props.gd")
var _combat_props: CombatProps

func drive_combat(action: StringName, progress: float, direction: Vector3, weapon: StringName, drawn: bool) -> void:
	if _combat_props == null:
		_combat_props = CombatProps.new()
		_combat_props.bind(arms[1], hips, Vector3(.02, -.49, .10))
	_combat_props.show_weapon(weapon, drawn)
	hips.rotation = Vector3.ZERO
	reset_pose(direction)
	if action == &"idle": return
	var pose := CombatMotion.sample(action, progress)
	var whole_body := action in [&"roll", &"down"]
	if whole_body:
		hips.rotation.x = pose.x
		hips.position.y -= .35 * (sin(PI * progress) if action == &"roll" else progress)
	chest.rotation = Vector3(0.0 if whole_body else pose.x, pose.y, 0)
	arms[0].rotation.x = pose.w
	arms[1].rotation.x = pose.z
