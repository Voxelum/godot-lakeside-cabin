extends RefCounted
## List every reachable source for the paper tooltip. Rarity only orders pickups,
## never gives one kind of interaction precedence over a different kind.
const Target := preload("res://scripts/interaction/stack_target.gd")
const State := preload("res://scripts/foundation/world_state.gd")
const REACH := 1.55

static func nearby(targets: Array, state: State, origin: Vector3) -> Array[Target]:
	var items: Array[Target] = []
	var containers: Array[Target] = []
	for candidate: Target in targets:
		if not candidate.eligible(state, origin, REACH): continue
		if candidate.is_pickup: items.append(candidate)
		else: containers.append(candidate)
	items.sort_custom(func(a: Target, b: Target) -> bool: return _before(a, b, origin))
	items.append_array(containers)
	return items

static func options(targets: Array, state: State, origin: Vector3) -> Array[Target]:
	var choices: Array[Target] = []
	for candidate in nearby(targets, state, origin):
		if choices.is_empty() or not candidate.is_pickup: choices.append(candidate)
	return choices

static func _before(a: Target, b: Target, origin: Vector3) -> bool:
	if a.definition.rarity != b.definition.rarity:
		return a.definition.rarity > b.definition.rarity
	var a_sq := a.global_position.distance_squared_to(origin)
	var b_sq := b.global_position.distance_squared_to(origin)
	if a_sq != b_sq: return a_sq < b_sq
	return a.instance_id < b.instance_id
