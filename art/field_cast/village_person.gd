extends "res://art/field_cast/field_body.gd"
## The stable person owns both the visible model and its Walker-solid shape.
@export var person_id := ""
var activity := ""
var meal:MeshInstance3D
var bite_time:=0.

func meal_pose(food:String, dt:float) -> void:
	if food.is_empty():
		if meal: meal.hide()
		bite_time=0.; return
	if not meal:
		meal=MeshInstance3D.new(); meal.name="HeldMeal"
		var roll:=SphereMesh.new(); roll.radius=.11; roll.height=.16; roll.radial_segments=8; roll.rings=4
		var paint:=StandardMaterial3D.new(); paint.roughness=.94; roll.material=paint; meal.mesh=roll; add_child(meal)
	var mat:=meal.mesh.material as StandardMaterial3D
	mat.albedo_color=Color("d79552") if food=="bread" else Color("e9dfbe")
	bite_time+=dt; meal.show()
	var up:=.5-.5*cos(TAU*bite_time/.8)
	var model:=get_node("Model") as Node3D
	meal.position=model.basis*Vector3(.22*(1.-up),body_center.y*(1.25+.40*up),.36-.16*up)

func _ready() -> void:
	if person_id.is_empty(): person_id = str(name)
	super._ready()
	add_to_group(&"village_person")

func present(active: bool) -> void:
	visible = active
	collision_layer = 1 if active else 0
	collision_mask = collision_layer

func rest_on(bed:Node3D) -> void:
	var model := get_node("Model") as Node3D
	if bed == null:
		model.position = Vector3.ZERO; model.rotation.x = 0.; model.rotation.z = 0.
		solid.position = body_center; solid.rotation = Vector3.ZERO
		return
	# Keep the same shape as the sleeping model, along the bed rather than
	# upright in the bedside aisle. Cots share their local pillow (-Z) axis.
	var local := global_transform.affine_inverse() * bed.global_transform
	model.transform = local * Transform3D(Basis(Vector3.RIGHT,-PI*.5),Vector3(0,.77,.79))
	solid.transform = model.transform * Transform3D(Basis.IDENTITY,body_center)

static func make(id: String, look: int) -> CharacterBody3D:
	var body = load("res://art/field_cast/village_person.gd").new()
	body.name = id; body.person_id = id; body.use_capsule(.29,1.65)
	var model := preload("res://art/field_cast/field_looks.gd").new()
	model.name = "Model"; model.look = look; body.add_child(model)
	return body
