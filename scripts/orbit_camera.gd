extends Camera3D
## Tilted, orthographic orbit. Quantize only translation in the two view axes:
## a stationary roof can move an integer texel without its pattern crawling.
@export_range(-180,180,0.5) var yaw_degrees := 30.0
@export_range(29,49,0.5) var pitch_degrees := 36.0
@export var sizes := PackedFloat32Array([6.2, 7.55, 8.95, 10.85, 13.4, 15.0])
@export_range(0,5,1) var zoom_step := 4
@onready var subject: CharacterBody3D = $"../Traveler"
@onready var cottage: Node3D = $"../Cottage"
var frozen := false
var focus := Vector3.ZERO
var aim := Vector3.ZERO
var dragging := false
var press_position := Vector2.ZERO
const RADIUS := 23.0

func _ready() -> void:
	process_priority = 10
	projection = PROJECTION_ORTHOGONAL
	size = sizes[zoom_step]
	align_at_subject()

func wanted_focus() -> Vector3:
	var p := subject.global_position
	# Bias the wide view toward the cottage; a close inspection centres the person.
	var wide := clampf((size-6.2)/7.2,0.0,1.0)
	var bias := ((cottage.global_position-p).slide(Vector3.UP)*0.49).limit_length(3.7*wide)
	var framed_height := lerpf(0.95, 1.89 + maxf(0.0, cottage.global_position.y-p.y), wide)
	return p + bias + Vector3.UP*framed_height

func _process(dt: float) -> void:
	if frozen: return
	aim = aim.lerp(wanted_focus(), 1.0-exp(-10.5*dt))
	_apply()

func align_at_subject() -> void:
	aim = wanted_focus()
	_apply()

func _apply() -> void:
	var basis := Basis.from_euler(Vector3(-deg_to_rad(pitch_degrees),deg_to_rad(yaw_degrees),0.0))
	var texel := size / get_viewport().get_visible_rect().size.y
	var u := aim.dot(basis.x)
	var v := aim.dot(basis.y)
	focus = aim + basis.x*(snappedf(u,texel)-u) + basis.y*(snappedf(v,texel)-v)
	global_transform = Transform3D(basis, focus + basis.z*RADIUS)

func end_drag() -> void:
	if not dragging: return
	dragging = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func camera_input(event: InputEvent, fitted: Rect2, scale_factor: float) -> bool:
	if frozen: return false
	var button := event as InputEventMouseButton
	if button:
		if button.button_index == MOUSE_BUTTON_RIGHT:
			if button.pressed and fitted.has_point(button.position):
				press_position = button.position
				dragging = true
				Input.mouse_mode = Input.MOUSE_MODE_CONFINED
				return true
			elif not button.pressed and dragging:
				end_drag()
				return true
		if button.pressed and (dragging or fitted.has_point(button.position)) and button.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_step = clampi(zoom_step+(-1 if button.button_index==MOUSE_BUTTON_WHEEL_UP else 1),0,sizes.size()-1)
			size = sizes[zoom_step]
			_apply()
			return true
	var motion := event as InputEventMouseMotion
	if motion and dragging:
		yaw_degrees = wrapf(yaw_degrees-motion.relative.x*0.58/scale_factor,-180.0,180.0)
		pitch_degrees = clampf(pitch_degrees+motion.relative.y*0.38/scale_factor,29.0,49.0)
		_apply()
		return true
	return false
