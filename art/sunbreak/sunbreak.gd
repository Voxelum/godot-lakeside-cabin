extends Node3D
## Source markers sit in specific canopy gaps. Only update meshes while needed.
## The old sun & clock are the sole authority for both ray direction and time.
@export_range(0.0,24.0,0.01667) var starts := 16.50
@export_range(0.0,24.0,0.01667) var ends := 17.00
@export_range(0.01,0.18,0.01) var feather_hours := 0.10
@export_range(0.1,2.0,0.1) var preset_fade_seconds := 0.85
@onready var clock = $"../Almanac"
@onready var sun: DirectionalLight3D = $"../Sun"
@onready var traveler: CharacterBody3D = $"../Traveler"
var gain := 0.0
var last_angle := Vector3.ZERO
var shown := true
var apertures: Array[Marker3D] = []
var bodies: Array[MeshInstance3D] = []
var inks: Array[ShaderMaterial] = []

func _ready() -> void:
	for child in get_children():
		if not child is Marker3D: continue
		var body: MeshInstance3D = child.get_node("Dust")
		var ink := body.material_override.duplicate() as ShaderMaterial
		body.material_override = ink
		body.visible = false
		apertures.append(child);bodies.append(body);inks.append(ink)

func _physics_process(dt: float) -> void:
	var h: float = clock.hour
	var target := smoothstep(starts,starts+feather_hours,h)*(1.0-smoothstep(ends-feather_hours,ends,h)) if shown else 0.0
	gain = move_toward(gain,target,dt/preset_fade_seconds)
	var down := -sun.global_basis.z.normalized()
	if target>0.0 and down.distance_to(last_angle)>0.00020:
		last_angle = down
		for i in bodies.size(): _align(i,down)
	for i in bodies.size():
		bodies[i].visible = gain>0.0001
		if bodies[i].visible: inks[i].set_shader_parameter(&"optical_density",gain*float(apertures[i].get_meta(&"density")))

func _align(i: int, down: Vector3) -> void:
	var mark := apertures[i]
	var from := mark.global_position
	var query := PhysicsRayQueryParameters3D.create(from,from+down*18.0)
	query.exclude = [traveler.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var to: Vector3 = hit.position if not hit.is_empty() else from+down*(from.y/maxf(0.1,-down.y))
	var span := maxf(0.1,from.distance_to(to)-0.025)
	var across := down.cross(Vector3.UP).normalized()
	var high := -down
	var lateral := across.cross(high).normalized()
	var radii: Vector2 = mark.get_meta(&"radii")
	bodies[i].global_transform=Transform3D(Basis(across*radii.x,high*span,lateral*radii.y),from+down*(span*0.5))
