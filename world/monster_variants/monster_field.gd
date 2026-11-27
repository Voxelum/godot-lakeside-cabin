extends Node3D
## The only terrain coupling. Reusable art scenes know nothing about Clearing.
const Survey := preload("res://world/outskirts/outskirts_profile.gd")

func _enter_tree() -> void:
	for pocket in get_children():
		for specimen in pocket.get_children():
			var here: Vector3 = to_global(pocket.transform * specimen.position)
			specimen.position.y = Survey.surface(Survey.xz(here)) + .014 - global_position.y - pocket.position.y
			specimen.set_ground_sampler(Survey.surface)
