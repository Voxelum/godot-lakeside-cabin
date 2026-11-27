extends "res://art/field_cast/field_body.gd"
## Reusable habitat actor: a shared body and presentation API, no AI/attacks.
const Brush := preload("res://art/monster_trial/source/brush.gd")
const Familiar := preload("res://art/monster_variants/familiar_looks.gd")
const Humanoid := preload("res://art/monster_variants/humanoid.gd")
const FieldLooks := preload("res://art/field_cast/field_looks.gd")
const MODELS := [
	preload("res://art/monster_trial/Slime.tscn"),
	preload("res://art/monster_trial/Goblin.tscn"),
	preload("res://art/monster_trial/Wolf.tscn"),
	preload("res://art/content_batch/creatures/GiantRat.tscn"),
	preload("res://art/content_batch/creatures/SkeletonSentry.tscn"),
]
const SIGNATURES := [&"rebound",&"feint",&"pounce",&"rear_and_sniff",&"rattle_guard",&"bloom",&"signature",&"signature"]
const MOVE_AT := 2.2
const SIGNATURE_AT := 5.3
const PERIOD := 9.0

@export_storage var species := 0
@export_enum("Base", "Variant I", "Variant II") var variant := 0
@export_enum("Preset", "None", "Club", "Spear", "Cleaver", "Axe", "Mace", "Saber", "Sickle") var weapon := 0
@export_range(0.0, .6, .01) var roam_radius := 0.0
@export_range(0.0, 9.0, .01) var phase_offset := 0.0
var model: Node3D
var animator: AnimationPlayer
var main_grip: Marker3D
var current_clip := &"idle"
var clock := 0.0
var _rig: Node3D
var _jaw: Node3D
var _home: Transform3D
var _ground: Callable

# Optional host survey (global XZ -> Y). Otherwise use the host's world geometry.
func set_ground_sampler(sampler: Callable) -> void:
	_ground = sampler

func _ready() -> void:
	if species < 5:
		model = MODELS[species].instantiate() as Node3D
	elif species == 5:
		model = Node3D.new()
		model.set_script(FieldLooks)
		model.set("look",2)
	else:
		model = Humanoid.build(species==6,variant,weapon)
	model.name = "Model"
	add_child(model)
	if species == 5:
		# Newly added child runs _ready before the parent continues.
		model.set_physics_process(false)
		_jaw = model.get_node("UpperPetals")
	else:
		_rig = model.get_node("Rig")
		animator = model.get_node("AnimationPlayer")
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var b := Brush.new()
	match species:
		0: Familiar.slime(model,variant,b)
		1: main_grip = Familiar.goblin(model,variant,weapon,b)
		2: Familiar.wolf(model,variant,b)
		3: Familiar.rat(model,variant,b)
		4: main_grip = Familiar.skeleton(model,variant,weapon,b)
		5: Familiar.maw(model,variant,b)
		6,7: main_grip = model.find_child("HandLSocket" if species==6 else "HandRSocket",true,false) as Marker3D
	super._ready()
	add_to_group(&"monster_variant")
	_home = global_transform
	clock = phase_offset
	_update_pose(0.0)

func signature() -> StringName:
	return SIGNATURES[species]

func duration(clip: StringName) -> float:
	if animator:
		return animator.get_animation(clip).length if animator.has_animation(clip) else 0.
	if clip == signature(): return 1.8
	return 3.2 if clip == &"idle" else 0.

func set_display_pose(clip: StringName, normalized: float) -> bool:
	# Preview or external behavior: the body itself is not moved here.
	var length := duration(clip)
	if length <= 0.: return false
	_sample_visual(clip, clampf(normalized,0.,1.) * length)
	return true

func _physics_process(delta: float) -> void:
	var vp := get_viewport() as SubViewport
	if vp and vp.render_target_update_mode == SubViewport.UPDATE_DISABLED:
		return
	clock = fposmod(clock+delta,PERIOD)
	_update_pose(delta)

func _update_pose(delta: float) -> void:
	var clip := &"idle"
	var at := clock
	var elapsed := clock - SIGNATURE_AT
	var target := _home.origin
	var yaw := _home.basis.get_euler().y
	if elapsed >= 0.0:
		var length := duration(signature())
		if elapsed < length:
			clip = signature()
			at = elapsed
		else:
			at = elapsed-length
	elif clock > MOVE_AT and roam_radius > 0. and species != 5:
		clip = &"move"
		at = clock - MOVE_AT
		var w := TAU*at/(SIGNATURE_AT-MOVE_AT)
		# Small track within the home shoulder rather than pursuit. The path
		# returns to the same point before the signature starts.
		target += _home.basis * Vector3((1.-cos(w))*.44,0.,sin(w)*.66) * roam_radius
		yaw += .52*sin(w)
	var sample := _sample_visual(clip,at)
	if delta <= 0.:
		return
	if roam_radius == 0. or species == 5:
		return
	try_yaw(lerp_angle(global_rotation.y,yaw,minf(1.,delta*8.)))
	var motion := global_basis * sample
	target += motion.slide(Vector3.UP)
	target.y = _floor_at(target) + motion.y
	move_to_mark(target,delta*3.8)

func _sample_visual(clip: StringName, time: float) -> Vector3:
	current_clip = clip
	if animator:
		var a := animator.get_animation(clip)
		if animator.current_animation != clip:
			animator.play(clip)
		animator.seek(fposmod(time,a.length) if a.loop_mode != Animation.LOOP_NONE else minf(time,a.length),true)
		var motion := _rig.position * model.scale
		_rig.position = Vector3.ZERO
		return motion
	var opening := sin(PI * clampf(time / 1.8, 0., 1.)) if clip == signature() else sin(TAU*time/3.2)*.049
	_jaw.rotation.x = -.13 - .63 * opening
	return Vector3.ZERO

func _floor_at(at: Vector3) -> float:
	if _ground.is_valid():
		return _ground.call(Vector2(at.x,at.z)) + .014
	var q := PhysicsRayQueryParameters3D.create(at+Vector3.UP*.66,at-Vector3.UP*.68,collision_mask)
	var excluded: Array[RID] = []
	for group in [&"field_occupant",&"traveler"]:
		for actor in get_tree().get_nodes_in_group(group):
			if actor is PhysicsBody3D and actor.get_world_3d() == get_world_3d():
				excluded.append(actor.get_rid())
	q.exclude = excluded
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return _home.origin.y if hit.is_empty() else hit.position.y + .014
