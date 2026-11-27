extends Node3D
## View/controller adapter only. One solid mesh rig per Walker, independent of
## every camera. Lighting and shadows come from the active 3D world.
const PROFILE := &"isaac"
const MODEL := preload("res://art/character_trial/isaac/IsaacModel.tscn")
var profile := PROFILE
var follow_sky := true # Legacy director hook; both worlds now use native scene lights.
var mode: StringName = &"idle"
var phase := 0.0
var facing: Node3D
var rig: Skeleton3D
var motion: AnimationPlayer
var _yaw := 0.0
@onready var _walker := get_parent() as CharacterBody3D

func _ready() -> void:
	facing = MODEL.instantiate() as Node3D
	facing.name = "Facing"
	add_child(facing)
	rig = facing.get_node("Rig")
	motion = facing.get_node("Motion")
	motion.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	reset_pose(Vector3.BACK)

func reset_pose(direction: Vector3) -> void:
	_heading(direction)
	facing.rotation.y = _yaw
	mode = &"idle"; phase = 0.0
	motion.play(&"idle",0.0); motion.seek(0.0,true); motion.advance(0.0)

var stroke_left := 0.0
var stroke_direction := Vector3.ZERO
var stroke_low := false
func stroke_animal(direction: Vector3, low: bool) -> void:
	stroke_direction=direction; stroke_low=low; stroke_left=.55

func pose_motion(direction: Vector3, travel: float, dt: float, sprinting: bool) -> void:
	stroke_left=0.0 if travel>.002 else maxf(0.,stroke_left-dt)
	_heading(stroke_direction if stroke_left>0 else direction)
	facing.rotation.y = lerp_angle(facing.rotation.y,_yaw,1.0-exp(-29.0*dt))
	var next := (&"run" if sprinting else &"walk") if travel > .00024 else &"idle"
	if next != mode:
		var aligned := phase if next != &"idle" and mode != &"idle" else 0.0
		mode = next
		motion.play(mode,.072)
		motion.seek(aligned*motion.get_animation(mode).length,false)
	# Advancing by actual XZ displacement respects an analog stick, a wall or
	# a partial step. The animation clips do not drive the capsule or save data.
	var elapsed := dt
	if mode != &"idle":
		var speed: float = _walker.get(&"sprint_speed" if sprinting else &"walk_speed")
		elapsed = travel / speed
	motion.advance(elapsed)
	if stroke_left>0:
		var w:=sin(PI*stroke_left/.55)
		_combat_bone("Trunk",Vector3((.65 if stroke_low else .32)*w,0,0))
		_combat_bone("ArmR",Vector3(-(1.25+.24*sin(TAU*stroke_left/.32))*w,0,-.12*w))
		_combat_bone("ElbowR",Vector3(-.18*w,0,0))
	phase = motion.current_animation_position/motion.current_animation_length

func _heading(direction: Vector3) -> void:
	if direction.slide(Vector3.UP).length_squared() > .00001:
		var here := global_basis.inverse()*direction
		_yaw = atan2(here.x,here.z)

const CombatMotion := preload("res://scripts/foundation/combat_motion.gd")
const CombatProps := preload("res://scripts/foundation/combat_props.gd")
var _combat_props: CombatProps

func drive_combat(action: StringName, progress: float, direction: Vector3, weapon: StringName, drawn: bool) -> void:
	if _combat_props == null:
		_combat_props = CombatProps.new()
		_combat_props.bind(rig.get_node("ElbowR"), rig.get_node("Hip"), Vector3(.025, -.24, .12))
	_combat_props.show_weapon(weapon, drawn)
	_heading(direction)
	facing.rotation.y = _yaw
	if action == &"idle":
		rig.rotation = Vector3.ZERO
		rig.position = Vector3.ZERO
		reset_pose(direction)
		return
	motion.stop()
	rig.reset_bone_poses()
	var pose := CombatMotion.sample(action, progress)
	var whole_body := action in [&"roll", &"down"]
	if whole_body:
		var pivot := Vector3.UP * .68
		var bend := Basis(Vector3.RIGHT, pose.x)
		rig.basis = bend
		rig.position = pivot - bend * pivot - Vector3.UP * (.39 * sin(PI * progress) if action == &"roll" else .42 * progress)
	else:
		rig.basis = Basis.IDENTITY
		rig.position = Vector3.ZERO
	_combat_bone("Trunk", Vector3(pose.x if not whole_body else 0.0, pose.y, 0))
	_combat_bone("ArmR", Vector3(pose.z, .55 * pose.y if action == &"slash" else 0.0, -.10))
	_combat_bone("ArmL", Vector3(pose.w, 0, .10))
	_combat_bone("ElbowR", Vector3(-.53 if action == &"guard" else -.22, 0, 0))
	_combat_bone("ElbowL", Vector3(-.75 if action == &"guard" else -.21, 0, 0))
	if action == &"slash" or action == &"thrust":
		var w := CombatMotion.weight(action, progress)
		rig.position = Vector3(.035*w, -.045*absf(w), .19*w)
		_combat_bone("HipR", Vector3(-.37*w, 0, 0))
		_combat_bone("KneeR", Vector3(.31*absf(w), 0, 0))
		_combat_bone("HipL", Vector3(.31*w, 0, 0))
		_combat_bone("KneeL", Vector3(.24*absf(w), 0, 0))
		_combat_props.aim(action, progress, rig.basis * rig.get_bone_global_pose(rig.find_bone("ElbowR")).basis)
	if action == &"roll":
		var tuck := sin(PI * progress)
		for side in ["L", "R"]:
			_combat_bone("Hip" + side, Vector3(-1.22 * tuck, 0, 0))
			_combat_bone("Knee" + side, Vector3(1.79 * tuck, 0, 0))

func _combat_bone(bone: String, euler: Vector3) -> void:
	rig.set_bone_pose_rotation(rig.find_bone(bone), Quaternion.from_euler(euler))
