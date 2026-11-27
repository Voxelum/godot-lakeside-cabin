@tool
extends Node3D
## Switching the authored mesh set never changes the pose or restarts a clip.
@export_range(0, 2, 1) var variant_index: int = 0:
	set(value):
		variant_index = clampi(value, 0, 2)
		if is_node_ready(): _dress()

var _skins: Array[Node] = []

func _ready() -> void:
	_skins = find_children("Skin", "MeshInstance3D", true, false)
	_dress()

func _dress() -> void:
	for skin: MeshInstance3D in _skins:
		var looks: Array = skin.get_meta(&"looks")
		skin.mesh = looks[variant_index]
