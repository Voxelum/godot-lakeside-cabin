extends Node3D
## A presentation switch, never a physics switch. Both storeys stay in the
## same room World3D while crossing the stair, and save Y is the actual foot Y.
const CAMERA_TARGET := .79
@onready var structure: Node3D = $Structure
@onready var upper_view: MeshInstance3D = $Structure/LoftCutaway
@onready var upper_furnishing: Node3D = $Furnishing/Loft
@onready var camera: Camera3D = $Camera
@onready var guest := get_viewport().get_node_or_null("Guest") as Node3D
@onready var upper := float(structure.get_meta("upper_floor"))
@onready var window_light: OmniLight3D = $WindowBounce
var ground_pose: Transform3D
var loft_pose: Transform3D
var ground_light: Vector3
var loft_light: Vector3

func _process(dt: float) -> void:
	if guest == null or get_viewport().render_target_update_mode == SubViewport.UPDATE_DISABLED: return
	focus_foot(guest.global_position)
	var pose := loft_pose if upper_view.visible else ground_pose
	camera.transform = camera.transform.interpolate_with(pose, 1.0 - exp(-10.0 * dt))

func focus_foot(foot: Vector3, immediate := false) -> void:
	var show_upper := structure.to_local(foot).y >= upper - .54
	upper_view.visible = show_upper
	upper_furnishing.visible = show_upper
	window_light.position = loft_light if show_upper else ground_light
	if immediate: camera.transform = loft_pose if show_upper else ground_pose

func _ready() -> void:
	upper_furnishing.position.y = upper
	var oriel := structure.get_node_or_null("Opening_oriel_center") as Marker3D
	var high := oriel if oriel != null else structure.get_node("Opening_front_sash") as Marker3D
	var low := structure.get_node("Opening_front_sash" if oriel != null else "Opening_west_low") as Marker3D
	loft_light = high.transform * Vector3(0,.60,-.82)
	ground_light = low.transform * Vector3(0,.65,-.84)
	camera.look_at(Vector3(0, CAMERA_TARGET, 0), Vector3.UP)
	ground_pose = camera.transform
	loft_pose = ground_pose.translated(Vector3.UP*upper)
	if oriel != null:
		# Look down into the projecting nook over its front glass. Keep the
		# ground presentation and all physical rafters and walls unchanged.
		var position := loft_pose.origin + Vector3(0, 3.9, .51)
		var focus := Vector3(0, CAMERA_TARGET+upper, .51)
		loft_pose = Transform3D(Basis.looking_at(focus-position), position)
	focus_foot(Vector3.ZERO, true)
