@tool
extends Node3D
## The editor preview and F5 use the identical land register.
func _enter_tree() -> void:
	preload("res://world/outskirts/settlement_space.gd").place(self)
