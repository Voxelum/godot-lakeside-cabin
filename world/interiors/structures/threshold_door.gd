extends Node3D
## The moving collision and art share their hinge. The black reveal is scenery only.
@export var passage_width := 1.0
var _openness := 0.0
var _requested := false

func track_foot(foot: Vector3, dt: float) -> void:
	var p := to_local(foot)
	var margin := .25 if _requested else 0.0
	_requested = absf(p.x) < passage_width * .5 + .55 + margin and p.y > -.95 and p.y < .65 and p.z > -.40 and p.z < 1.68 + margin
	_openness = move_toward(_openness, 1.0 if _requested else 0.0, dt * 4.5)
	for leaf: Node3D in get_children():
		leaf.rotation.y = float(leaf.get_meta("swing")) * PI * .5 * smoothstep(0.0, 1.0, _openness)

func is_clear() -> bool:
	return _openness >= .98
