extends "res://art/field_cast/field_body.gd"
## Short, local habitat movements only. Neither player proximity nor an attack
## event starts a clip. The authored Rig translation belongs to the body here.
const Survey := preload("res://world/outskirts/outskirts_profile.gd")
const SIGNATURES := [&"rebound", &"feint", &"pounce"]
const MOVE_AT := 1.85
const SIGNATURE_AT := 4.65
const PERIOD := 8.0

@export_enum("Slime", "Goblin", "Wolf") var species := 0
@export var phase_offset := 0.0
@export var step_radius := .44
@onready var model: Node3D = get_child(0)
@onready var animator: AnimationPlayer = model.get_node("AnimationPlayer")
@onready var visual_rig: Node3D = model.get_node("Rig")
var clock := 0.0
var home: Transform3D

func _ready() -> void:
	super._ready()
	home = global_transform
	_ground_facing_pigments()
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	clock = phase_offset
	pose_at(clock)

func _physics_process(delta: float) -> void:
	var vp := get_viewport() as SubViewport
	if vp and vp.render_target_update_mode == SubViewport.UPDATE_DISABLED:
		return
	clock = fposmod(clock + delta, PERIOD)
	var target := _sample(clock)
	try_yaw(lerp_angle(global_rotation.y, target.basis.get_euler().y, minf(1., delta * 8.)))
	move_to_mark(target.origin, delta * 3.8)

func pose_at(phase: float) -> void:
	# Explicit frame placement for startup and the existing render review only.
	global_transform = _sample(phase)

func _sample(phase: float) -> Transform3D:
	var facing := home.basis
	var point := home.origin
	var clip := &"idle"
	var elapsed := phase
	if phase >= MOVE_AT and phase < SIGNATURE_AT:
		clip = &"move"
		elapsed = phase - MOVE_AT
		var a := TAU * elapsed / (SIGNATURE_AT - MOVE_AT)
		point += home.basis * Vector3((1.0 - cos(a)) * .63, 0., sin(a)) * step_radius
		facing = facing.rotated(Vector3.UP, a)
	elif phase >= SIGNATURE_AT:
		elapsed = phase - SIGNATURE_AT
		var signature: StringName = SIGNATURES[species]
		var duration := animator.get_animation(signature).length
		if elapsed < duration:
			clip = signature
		else:
			elapsed -= duration
	var animation := animator.get_animation(clip)
	var timestamp := fposmod(elapsed, animation.length) if animation.loop_mode != Animation.LOOP_NONE else elapsed
	if animator.current_animation != clip:
		animator.play(clip)
	animator.seek(timestamp, true)
	var authored_motion := facing * visual_rig.position
	# The same swept transform raises the collision and the visible jelly (or
	# advances the wolf). Local squash/limb/tilt tracks stay on the visual rig.
	visual_rig.position = Vector3.ZERO
	point += authored_motion.slide(Vector3.UP)
	point.y = Survey.surface(Survey.xz(point)) + .014 + authored_motion.y
	return Transform3D(facing,point)

func _ground_facing_pigments() -> void:
	# Only the Clearing instances get the matte reed glaze, fern skin and stone
	# fur. Keep eye highlights, warm lining and the original vertex brushwork.
	var copies := {}
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var base := mesh.get_active_material(0) as StandardMaterial3D
		if not base:
			continue
		if not copies.has(base):
			var paint := base.duplicate() as StandardMaterial3D
			var col := base.albedo_color
			match species:
				0:
					paint.roughness = maxf(.67,paint.roughness)
					paint.metallic_specular *= .44
					if base.vertex_color_use_as_albedo:
						paint.albedo_color = Color("bdebd5")
					elif col.g > .30:
						paint.albedo_color = col.lerp(Color("638d82"),.27)
				1:
					if base.vertex_color_use_as_albedo:
						paint.albedo_color = Color("e8d8ba")
					elif col.g > col.r*1.065:
						paint.albedo_color = col.lerp(Color("748a52"),.32)
					elif col.r > .49 and col.b < col.r*.50:
						paint.albedo_color = col.lerp(Color("a75d44"),.22)
				2:
					if base.vertex_color_use_as_albedo:
						paint.albedo_color = Color("e4c4ae")
					elif col.r < .52 and col.b > col.r*.75:
						paint.albedo_color = col.lerp(Color("594544"),.30)
			copies[base] = paint
		mesh.material_override = copies[base]
