@tool
extends "res://art/building_trial/building_lot.gd"
## Same structure and walkable landing as the kit, but a Clearing-specific
## palette and sun response. F6 trial resources are not edited at runtime.
const SOUTH_INK := preload("res://world/outskirts/outskirts_shell.gdshader")

# Limewash, aged timber, tile, door/cloth, local stone.
@export var field_inks := PackedStringArray():
	set(value):
		field_inks = value
		_queue_build()

func _resolve() -> Dictionary:
	var recipe := super._resolve()
	if recipe.valid and field_inks.size() == 5:
		recipe.ink = Array(field_inks)
	return recipe

func _rebuild() -> void:
	super._rebuild()
	if not is_instance_valid(mesh_view):
		return
	pigment.shader = SOUTH_INK
	mesh_view.add_to_group(&"clearing_extension_occluder")
	_lamp.add_to_group(&"night_omni")
	_lamp.light_color = Color("ffd495")
	_lamp.light_energy = 1.10
	_lamp.omni_range = 3.25
