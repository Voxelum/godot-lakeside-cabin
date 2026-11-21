extends Node
## Don't dissolve whole trees or flatten a building's shadow. A sustained blocked
## sight line gets a depth-tested ink echo of JUST the hidden pieces of the walker.
const INK := preload("res://scripts/occlusion_ink.gdshader")
@onready var field := get_parent()
@onready var person: CharacterBody3D = field.get_node("Traveler")
@onready var cam: Camera3D = field.get_node("Camera")
var sources: Array[MeshInstance3D] = []
var character_parts: Array[MeshInstance3D] = []
var washed := false
var age := 0.0
var alpha := 0.0
var material := ShaderMaterial.new()

func _ready() -> void:
	material.shader = INK
	material.render_priority = 7
	for mesh: MeshInstance3D in person.find_children("*", "MeshInstance3D", true, false):
		character_parts.append(mesh)
	for house_part in ["Limewash_and_Plinth"]:
		var branch: Node = field.get_node("Cottage").get_node_or_null(house_part)
		if branch:
			for mesh: MeshInstance3D in branch.find_children("*", "MeshInstance3D", true, false): sources.append(mesh)
	for mesh: MeshInstance3D in field.get_node("Cottage").find_children("*Course*", "MeshInstance3D", true, false): sources.append(mesh)
	for tree_name in ["WestOak", "EastOak", "BackMaple", "NorthMaple", "FrameOak"]:
		for mesh: MeshInstance3D in field.get_node(tree_name).find_children("*", "MeshInstance3D", true, false): sources.append(mesh)
	process_priority = 15

func _process(dt: float) -> void:
	if cam.get("frozen"): return
	var tip := person.global_position + Vector3.UP * 1.28
	var eye := tip + cam.global_basis.z * 21.0
	var blocked := false
	for mesh in sources:
		var box := mesh.global_transform * mesh.get_aabb()
		if box.intersects_segment(tip,eye) != null:
			blocked = true
			break
	age = age+dt if blocked else 0.0
	alpha = move_toward(alpha, 0.51 if age>0.32 else 0.0, dt*2.2)
	if washed != (alpha>0.0):
		washed = alpha>0.0
		for mesh in character_parts: mesh.material_overlay = material if washed else null
	if washed: material.set_shader_parameter(&"strength",alpha)
