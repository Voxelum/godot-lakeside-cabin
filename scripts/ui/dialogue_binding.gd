extends Node
## Attach presentation data to an existing speaker without replacing its 3D model.
@export var actor_path: NodePath
@export var speaker_name: String
@export var portrait: Texture2D
@export var lines: PackedStringArray

func actor() -> Node3D:
	return get_node_or_null(actor_path) as Node3D
