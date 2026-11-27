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
# Rotation is an explicit development chord; zoom remains a normal player control.
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
	# Keep the original lens and orbit. Beyond the new smith-side gateway, gently
	# stop aiming metres back at the distant cottage: both rows fit from the aisle.
	const Park := preload("res://world/farm/farm_layout.gd")
	var park_weight := smoothstep(26.9, Park.START+.7, p.x) * (1.0-smoothstep(Park.HALF_AISLE+Park.DEPTH, Park.HALF_AISLE+Park.DEPTH+3.0, absf(p.z-Park.AISLE)))
	# The roadside paddock is below the old cottage-biased frame at the bend.
	park_weight = maxf(park_weight,1.0-smoothstep(3.,8.,Vector2(p.x,p.z).distance_to(Vector2(4.,22.))))
	return p + bias*(1.0-park_weight) + Vector3.UP*lerpf(framed_height,lerpf(.95,1.24,wide),park_weight)

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

func drag_input(event: InputEvent, fitted: Rect2, scale_factor: float) -> bool:
	if frozen: return false
	var key := event as InputEventKey
	if dragging and key and (key.keycode == KEY_CTRL or key.physical_keycode == KEY_CTRL) and not key.pressed:
		end_drag()
		return true
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed and button.ctrl_pressed and fitted.has_point(button.position):
			dragging = true
			Input.mouse_mode = Input.MOUSE_MODE_CONFINED
			return true
		if dragging and not button.pressed:
			end_drag()
			return true
	var motion := event as InputEventMouseMotion
	if dragging and motion:
		if motion.ctrl_pressed:
			yaw_degrees = wrapf(yaw_degrees-motion.relative.x*0.58/scale_factor,-180.0,180.0)
			pitch_degrees = clampf(pitch_degrees+motion.relative.y*0.38/scale_factor,29.0,49.0)
			_apply()
		else:
			end_drag()
		return true
	return false

func zoom_input(event: InputEvent, fitted: Rect2) -> bool:
	var button := event as InputEventMouseButton
	if frozen or not button or not button.pressed or not fitted.has_point(button.position): return false
	if button.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]: return false
	zoom_step = clampi(zoom_step+(-1 if button.button_index==MOUSE_BUTTON_WHEEL_UP else 1),0,sizes.size()-1)
	size = sizes[zoom_step]
	_apply()
	return true
