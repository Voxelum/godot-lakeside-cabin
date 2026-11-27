extends Node3D
## View layers and daylight are separate from physical walls and saved feet.
@onready var structure := get_node_or_null("Structure") as Node3D
@onready var camera: Camera3D = $Camera
@onready var ground_view := get_node_or_null("Structure/GroundCutaway") as Node3D
@onready var upper_view := get_node_or_null("Structure/LoftCutaway") as Node3D
@onready var upper_furnishing := get_node_or_null("Furnishing/Loft") as Node3D
@onready var guest := get_viewport().get_node_or_null("Guest") as Node3D
@onready var clock := get_tree().get_first_node_in_group(&"solar_clock")
var upper := 0.0
var _ground_pose: Transform3D
var _loft_pose: Transform3D
var _ground_size := 7.3
var _loft_size := 7.3
var _show_upper := false

func _ready() -> void:
	if structure == null: # the reusable view-only template, not a loaded room
		set_process(false)
		return
	upper = float(structure.get_meta("upper_floor"))
	if upper_furnishing: upper_furnishing.position.y = upper
	_fit_wall_furnishings()
	set_entry_view(Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(30)))
	focus_foot(Vector3.ZERO, true)

## Bring a perimeter furnishing's complete visible footprint inside the shared
## walls without scaling it. Nested props and colliders follow the instance.
## Loft layouts and non-furniture fixtures are authored in structural metres.
func _fit_wall_furnishings() -> void:
	var furnishing := get_node_or_null("Furnishing")
	if furnishing == null: return
	var half: Vector2 = structure.get_meta("net_footprint") * .5 - Vector2.ONE * .035
	for item: Node3D in furnishing.get_children():
		if item == upper_furnishing: continue
		var footprint := AABB()
		var first := true
		for mesh: MeshInstance3D in item.find_children("*", "MeshInstance3D", true, false):
			var bounds := structure.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			footprint = bounds if first else footprint.merge(bounds)
			first = false
		if first: continue
		var delta := Vector3.ZERO
		delta.x = maxf(0.0, -half.x - footprint.position.x) - maxf(0.0, footprint.end.x - half.x)
		delta.z = maxf(0.0, -half.y - footprint.position.z) - maxf(0.0, footprint.end.z - half.y)
		item.global_position += structure.global_basis * delta

func set_entry_view(world_right: Vector3) -> void:
	# Only the pitch and framing are composed for the room. Camera-right (and
	# therefore the screen/control side of the door normal) comes from outdoors.
	var right := structure.global_basis.inverse() * world_right
	right = right.slide(Vector3.UP).normalized()
	var yaw := atan2(-right.z, right.x)
	var eye := Vector3.BACK.rotated(Vector3.UP, yaw)
	for layer in [ground_view, upper_view]:
		if layer == null: continue
		for wall: Node3D in layer.get_children():
			var section: bool = Vector3(wall.get_meta("normal")).dot(eye) > .0001
			wall.get_node("Section").visible = section
			wall.get_node("Full").visible = not section
	_ground_pose = _frame(yaw, 39.0, false)
	_loft_pose = _frame(yaw, 53.0 if structure.has_node("Opening_oriel_center") else 45.0, true) if upper_view else _ground_pose

func _frame(yaw: float, pitch: float, is_upper: bool) -> Transform3D:
	var basis := Basis.from_euler(Vector3(-deg_to_rad(pitch), yaw, 0))
	var inverse := basis.transposed()
	var bounds := Rect2()
	var first := true
	for layer in [ground_view, upper_view if is_upper else null]:
		if layer == null: continue
		var meshes: Array[Node] = [layer]
		for wall in layer.get_children():
			meshes.append(wall.get_node("Full") if wall.get_node("Full").visible else wall.get_node("Section"))
		for part: MeshInstance3D in meshes:
			for surface in part.mesh.get_surface_count():
				for v: Vector3 in part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					var local := inverse*v
					var screen := Vector2(local.x,local.y)
					bounds = Rect2(screen, Vector2.ZERO) if first else bounds.expand(screen)
					first = false
	var needed := maxf(bounds.size.y, bounds.size.x * 9.0/16.0) + .47
	if is_upper: _loft_size = maxf(4.6, needed)
	else: _ground_size = maxf(4.6, needed)
	var center := bounds.get_center()
	return Transform3D(basis, basis * Vector3(center.x, center.y, 23.0))

func _process(dt: float) -> void:
	if get_viewport() is SubViewport and get_viewport().render_target_update_mode == SubViewport.UPDATE_DISABLED: return
	if guest: focus_foot(guest.global_position)
	var blend := 1.0 - exp(-10.0 * dt)
	camera.transform = camera.transform.interpolate_with(_loft_pose if _show_upper else _ground_pose, blend)
	camera.size = lerpf(camera.size, _loft_size if _show_upper else _ground_size, blend)
	_update_windows()

func focus_foot(foot: Vector3, immediate := false) -> void:
	_show_upper = upper_view != null and structure.to_local(foot).y >= upper - .54
	if upper_view: upper_view.visible = _show_upper
	if upper_furnishing: upper_furnishing.visible = _show_upper
	if immediate:
		camera.transform = _loft_pose if _show_upper else _ground_pose
		camera.size = _loft_size if _show_upper else _ground_size
		_update_windows()

func _update_windows() -> void:
	var sky := 1.0 if clock == null else smoothstep(.08, .95, float(clock.daylight)) * (1.0 - .88 * float(clock.sundown))
	for lamp: SpotLight3D in $Structure/WindowDaylight.get_children():
		lamp.light_energy = float(lamp.get_meta("day_energy")) * sky
		lamp.visible = int(lamp.get_meta("storey")) == int(_show_upper) and lamp.light_energy > .007
