extends Node
## Scene-local combat driver; ActorStats is the only HP authority.
signal impact(target: Node3D, lost: int)
const Motion := preload("res://scripts/foundation/combat_motion.gd")
const Stats := preload("res://scripts/foundation/actor_stats.gd")
var actor: CharacterBody3D
var view: Node3D
var stats: Stats
var action: StringName = &"idle"
var elapsed := 0.0
var forward := Vector3.BACK
var weapon: StringName = &""
var drawn := false
var guard_held := false
var _connected_hit := false
var _receives_player_strikes := false

func install(body: CharacterBody3D, art: Node3D, health: Stats, target := false) -> void:
	actor = body
	view = art
	stats = health
	forward = body.global_basis.z.slide(Vector3.UP).normalized()
	_receives_player_strikes = target
	body.add_child(self)
	if target: add_to_group(&"prototype_combat_target")
	_render(0)

func reset() -> void:
	guard_held = false
	_set_action(&"idle" if stats.hp() > 0 else &"down")
	_render(0 if stats.hp() > 0 else 1)

func _set_action(next: StringName) -> void:
	action = next
	elapsed = 0
	_connected_hit = false

func available() -> bool:
	return action == &"idle" and stats.hp() > 0

func attack() -> bool:
	if not available(): return false
	_set_action((&"slash" if weapon == &"sword" else &"thrust") if drawn else &"jab")
	return true

func toggle_draw() -> bool:
	if weapon.is_empty() or not available(): return false
	_set_action(&"sheathe" if drawn else &"draw")
	return true

func roll(direction: Vector3) -> bool:
	if not available(): return false
	face(direction)
	_set_action(&"roll")
	return true

func face(direction: Vector3) -> void:
	if direction.length_squared() > .001:
		forward = direction.slide(Vector3.UP).normalized()

func set_guard(held: bool) -> void:
	guard_held = held
	if not held and action == &"guard":
		_set_action(&"idle")
		_render(0)
	if held and available():
		_set_action(&"guard")
		_render(0)

func movement(heading: Vector3) -> Vector3:
	match action:
		&"idle": return heading
		&"guard": return heading * .48
		&"roll": return forward * 2.45
	return Vector3.ZERO

func receive_damage(amount: int, from_direction: Vector3) -> int:
	if action == &"roll" and elapsed > .05 and elapsed < .31: return 0
	var guarded := action == &"guard" and forward.dot(from_direction.normalized()) > .25
	var lost := stats.take_physical_damage(amount, guarded)
	if lost > 0 and (not guarded or stats.hp() == 0):
		_set_action(&"hurt" if stats.hp() > 0 else &"down")
	return lost

func _physics_process(dt: float) -> void:
	if _receives_player_strikes: tick(dt)

func tick(dt: float) -> void:
	if not _receives_player_strikes and actor.get(&"artwork") != view:
		reset() # Alternate player looks may be swapped while running.
	if action == &"idle" or action == &"guard": return
	var duration: float = Motion.DURATIONS[action]
	elapsed = minf(elapsed + dt, duration)
	var progress := elapsed / duration
	if not _connected_hit and progress >= .43 and Motion.STRIKES.has(action):
		_connected_hit = true
		_strike(Motion.STRIKES[action])
	if progress >= .50:
		if action == &"draw": drawn = true
		if action == &"sheathe": drawn = false
	if progress >= 1.0 and action != &"down":
		_set_action(&"idle")
		set_guard(guard_held)
		progress = 0
	_render(progress)

func _render(progress: float) -> void:
	if not _receives_player_strikes:
		view = actor.get(&"artwork")
	view.call(&"drive_combat", action, progress, forward, weapon, drawn)

## Same spatial rule for both directions: foot height, footprint, committed facing,
## and a body/rail obstruction query in the active World3D. No animation event hits.
static func clear_melee(source: CharacterBody3D, target: CharacterBody3D, facing: Vector3, reach: float, arc_cos: float) -> bool:
	if target.get_world_3d() != source.get_world_3d(): return false
	var delta := target.global_position - source.global_position
	var plane := delta.slide(Vector3.UP)
	if absf(delta.y) > .62 or plane.length_squared() > reach * reach or facing.dot(plane.normalized()) < arc_cos: return false
	var ray := PhysicsRayQueryParameters3D.create(source.global_position + Vector3.UP * .62, target.global_position + Vector3.UP * .62, 1, [source.get_rid()])
	var hit := source.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.collider == target

func can_be_hit_by(_attacker: CharacterBody3D) -> bool:
	return stats.hp() > 0

func _strike(profile: Array) -> void:
	var closest: Node = null
	var reach: float = profile[1]
	for other in get_tree().get_nodes_in_group(&"prototype_combat_target"):
		if other == self or not other.can_be_hit_by(actor): continue
		if not clear_melee(actor, other.actor, forward, reach, profile[2]): continue
		closest = other
		reach = (other.actor.global_position - actor.global_position).slide(Vector3.UP).length()
	if closest != null:
		var lost: int = closest.receive_damage(profile[0], actor.global_position - closest.actor.global_position)
		impact.emit(closest.actor, lost)
