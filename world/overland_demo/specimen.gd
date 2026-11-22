extends Node3D
## Ambient showcase only: one small loop on a pull-out, then a signature clip.
## No hitboxes, targets, pursuit or gameplay collision.

const LAP_START := 1.85
const SIGNATURE_START := 4.65
const PERIOD := 7.60

@export var caption: String
@export var signature: StringName
@export var phase_offset := 0.0
@export var radius := .57
@onready var model: Node3D = get_child(0)
@onready var animator: AnimationPlayer = model.get_node("AnimationPlayer")
var clock := 0.0
var home: Transform3D

func _ready() -> void:
	home = model.transform
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	clock = phase_offset
	pose_at(clock)

func _process(delta: float) -> void:
	clock = fposmod(clock + delta, PERIOD)
	pose_at(clock)

func pose_at(phase: float) -> void:
	model.transform = home
	var clip: StringName = &"idle"
	var elapsed := phase
	if phase >= LAP_START and phase < SIGNATURE_START:
		clip = &"move"
		elapsed = phase - LAP_START
		var angle := TAU * elapsed / (SIGNATURE_START - LAP_START)
		model.position += home.basis * (Vector3(1.0 - cos(angle), 0.0, sin(angle)) * radius)
		model.rotate_y(angle)
	elif phase >= SIGNATURE_START:
		elapsed = phase - SIGNATURE_START
		var duration := animator.get_animation(signature).length
		if elapsed < duration:
			clip = signature
		else:
			elapsed -= duration
	var animation := animator.get_animation(clip)
	if animator.current_animation != clip:
		animator.play(clip)
	animator.seek(fposmod(elapsed, animation.length) if animation.loop_mode != Animation.LOOP_NONE else elapsed, true)
