extends Node3D
## Map-authored seed for a persistent source. The inventory stacks by definition.
const ItemDefinition := preload("res://scripts/foundation/item_definition.gd")
const State := preload("res://scripts/foundation/world_state.gd")
const OPEN_ANGLE := -70.0 * PI / 180.0
const FLIGHT_DURATION := 0.30
@export var instance_id: String
@export var definition: ItemDefinition = State.SAMPLE
@export_range(1, 99) var initial_count := 1
@export var is_pickup := true
## Lower the reach anchor for elevated props when the caller uses its feet.
@export var reach_drop := 0.0
@export var contents_mesh: Mesh
var valid_source := true
var _lid_goal := 0.0
var _lid_tween: Tween
var _flight_tween: Tween
var _flight: Node3D

func amount(state: State) -> int:
	return state.remaining(instance_id, initial_count)

func eligible(state: State, origin: Vector3, reach: float) -> bool:
	var anchor := global_position - Vector3.UP * reach_drop
	return valid_source and anchor.distance_squared_to(origin) <= reach * reach and amount(state) > 0

func take(state: State, origin: Vector3, reach: float, receiver: Node3D = null) -> int:
	# Recheck at dispatch, not just when the HUD last painted its prompt.
	if not eligible(state, origin, reach): return 0
	var count := state.take_stack(instance_id, definition.definition_id, initial_count)
	if count == 0: return 0
	# The transfer has already happened; everything below is presentation only.
	if receiver != null and receiver.is_inside_tree() and is_inside_tree():
		_start_flight(receiver)
	visible = not (is_pickup and amount(state) == 0)
	_set_lid(OPEN_ANGLE, receiver != null)
	return count

func place(state: State, origin: Vector3, reach: float) -> bool:
	var anchor := global_position - Vector3.UP * reach_drop
	if not valid_source or definition == null or reach < 0 or origin.distance_squared_to(anchor) > reach * reach: return false
	if not state.return_to_slot(instance_id, definition.definition_id): return false
	refresh(state)
	return true

func update_proximity(state: State, origin: Vector3) -> void:
	if not is_pickup:
		var nearby := global_position.distance_squared_to(origin) <= 1.65 * 1.65
		_set_lid(OPEN_ANGLE if nearby or amount(state) == 0 else 0.0, true)

func refresh(state: State) -> void:
	_cancel_flight()
	var empty := amount(state) == 0
	visible = not (is_pickup and empty)
	_set_lid(OPEN_ANGLE if empty else 0.0, false)

func _set_lid(goal: float, animate: bool) -> void:
	var lid := get_node_or_null("LidHinge") as Node3D
	if lid == null or (animate and is_equal_approx(goal, _lid_goal)): return
	_lid_goal = goal
	if _lid_tween != null: _lid_tween.kill()
	if not animate or not is_inside_tree():
		lid.rotation.x = goal
	else:
		_lid_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_lid_tween.tween_property(lid, "rotation:x", goal, 0.24)

func _start_flight(receiver: Node3D) -> void:
	_cancel_flight()
	_flight = Node3D.new()
	_flight.name = "PickupFlight"
	# Top-level transform avoids inheriting source movement. Visibility must not
	# inherit the consumed stack, so attach beside it rather than beneath it.
	_flight.top_level = true
	get_parent().add_child(_flight)
	_flight.global_transform = global_transform
	if is_pickup:
		# Copy only the visible geometry, including nested details. Never copy
		# target scripts, groups or collision into the flying presentation.
		var to_source := global_transform.affine_inverse()
		for piece: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
			if not piece.mesh or not piece.is_visible_in_tree(): continue
			var model := MeshInstance3D.new()
			model.mesh = piece.mesh
			model.material_override = piece.material_override
			model.material_overlay = piece.material_overlay
			model.layers = piece.layers
			for i in piece.get_surface_override_material_count():
				model.set_surface_override_material(i, piece.get_surface_override_material(i))
			model.transform = to_source * piece.global_transform
			_flight.add_child(model)
	else:
		var model := MeshInstance3D.new()
		model.mesh = contents_mesh
		model.position.y = 0.52
		_flight.add_child(model)
	var start := _flight.global_position
	_flight_tween = create_tween()
	_flight_tween.tween_method(_fly.bind(start, _flight.rotation.y, weakref(receiver)), 0.0, 1.0, FLIGHT_DURATION)
	_flight_tween.tween_callback(_cancel_flight)

func _fly(t: float, start: Vector3, yaw_at_start: float, receiver_ref: WeakRef) -> void:
	var receiver := receiver_ref.get_ref() as Node3D
	if receiver == null or not receiver.is_inside_tree():
		_cancel_flight()
		return
	var chest := receiver.to_global(Vector3(0, 1.05, 0))
	_flight.global_position = start.lerp(chest, t) + Vector3.UP * sin(PI * t) * 0.38
	_flight.rotation.y = yaw_at_start + 1.6 * t
	_flight.scale = Vector3.ONE * lerpf(1.0, 0.18, t * t)

func _cancel_flight() -> void:
	if _flight_tween != null:
		_flight_tween.kill()
		_flight_tween = null
	if is_instance_valid(_flight):
		_flight.hide()
		_flight.queue_free()
	_flight = null

func _exit_tree() -> void:
	_cancel_flight()
