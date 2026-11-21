@tool
extends Node3D
## The mirror belongs to the pool, but renders the enclosing Pixels World3D.

const WATER_HEIGHT := 0.052
var _mirror: SubViewport
var _camera: Camera3D
var _water: ShaderMaterial
var _day := 1.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_water = $Water.material_override.duplicate() as ShaderMaterial
	$Water.material_override = _water
	_water.set_shader_parameter("day_amount", _day)
	_mirror = SubViewport.new()
	_mirror.name = "MirrorViewport"
	_mirror.world_3d = get_viewport().find_world_3d()
	_mirror.disable_3d = false
	_mirror.transparent_bg = true
	_mirror.gui_disable_input = true
	_mirror.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_mirror)
	_camera = Camera3D.new()
	_camera.name = "MirrorCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.cull_mask = 1
	_mirror.add_child(_camera)
	_camera.make_current()
	_water.set_shader_parameter("mirror_tex", _mirror.get_texture())
	# Run after normal camera/player updates.
	process_priority = 100
	_sync_mirror()

func set_time_of_day(day_amount: float, _hour: float) -> void:
	_day = clampf(day_amount, 0.0, 1.0)
	if is_instance_valid(_water):
		_water.set_shader_parameter("day_amount", _day)

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_sync_mirror()

func _sync_mirror() -> void:
	var source := get_viewport().get_camera_3d()
	if source == null or source.projection != Camera3D.PROJECTION_ORTHOGONAL:
		_water.set_shader_parameter("mirror_ready", false)
		return
	var resolution := Vector2i(get_viewport().get_visible_rect().size)
	if resolution.x < 2 or resolution.y < 2:
		return
	if _mirror.size != resolution:
		_mirror.size = resolution
	var pose := source.get_camera_transform()
	var plane_y := to_global(Vector3(0, WATER_HEIGHT, 0)).y
	var flip := Vector3(1, -1, 1)
	var origin := pose.origin * flip + Vector3(0, 2.0 * plane_y, 0)
	# Reflect the view, then reverse camera up to restore a proper basis.
	# X stays aligned; mirror image is vertically flipped when viewed alone.
	var basis := Basis(pose.basis.x * flip, -pose.basis.y * flip, pose.basis.z * flip)
	_camera.global_transform = Transform3D(basis, origin)
	_camera.keep_aspect = source.keep_aspect
	_camera.size = source.size
	_camera.near = source.near
	_camera.far = source.far
	_camera.environment = source.environment
	_camera.attributes = source.attributes
	var aspect := float(resolution.x) / float(resolution.y)
	var extent := Vector2(source.size * aspect, source.size) if source.keep_aspect == Camera3D.KEEP_HEIGHT else Vector2(source.size, source.size / aspect)
	_water.set_shader_parameter("mirror_origin", origin)
	_water.set_shader_parameter("mirror_right", basis.x / extent.x)
	_water.set_shader_parameter("mirror_up", basis.y / extent.y)
	_water.set_shader_parameter("mirror_resolution", Vector2(resolution))
	_water.set_shader_parameter("mirror_ready", true)
