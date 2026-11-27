extends Node
## Attach presentation data to an existing speaker without replacing its 3D model.
@export var actor_path: NodePath
@export var speaker_name: String
@export var portrait: Texture2D
@export var lines: PackedStringArray

func actor() -> Node3D:
	if not actor_path.is_empty():
		var original := get_node_or_null(actor_path) as Node3D
		if original: return original
	var host := get_parent().get_parent()
	for person in get_tree().get_nodes_in_group(&"village_person"):
		if host.is_ancestor_of(person) and person.person_id == person_id: return person
	return null

@export var person_id := ""
