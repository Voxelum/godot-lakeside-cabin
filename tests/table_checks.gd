extends SceneTree

const State = preload("res://scripts/foundation/world_state.gd")
const Target = preload("res://scripts/interaction/stack_target.gd")
const Interior = preload("res://world/Interior.tscn")
const Pile = preload("res://world/targets/SamplePile.tscn")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _run() -> void:
	var cabin := Interior.instantiate()
	root.add_child(cabin)
	var bread := cabin.get_node("Dining/Tabletop/CabinSetting/BreadPickup") as Target
	var cup := cabin.get_node("Dining/Tabletop/CabinSetting/CupPickup") as Target
	var chest: Target
	var table_count := 0
	for target in get_nodes_in_group("test_stack_source"):
		if target.get_parent() == bread.get_parent(): table_count += 1
		if not target.is_pickup: chest = target
	check(table_count == 2, "exactly two authored tabletop sources")
	check(bread.get_child_count() == 4 and cup.get_child_count() == 3, "ornaments belong to their original item")
	check(bread.get_parent().has_node("BreadBoard"), "bread board remains")
	for id in ["item.sample", "item.bread", "item.cup"]:
		var definition: Resource = State.DEFINITIONS[id]
		check(definition.definition_id == id and definition.icon != null, "valid definition and icon: " + id)

	var state := State.new()
	var receiver := Node3D.new()
	cabin.add_child(receiver)
	# East aisle, clear of both end chairs and the table's east edge.
	var east := Vector3(-1.30, 0, -0.60)
	receiver.position = east
	check(bread.take(state, east, 1.55, receiver) == 1, "pick bread from east aisle")
	check(not bread.visible and state.inventory.get("item.bread") == 1, "bread rule updates immediately")
	check(bread.take(state, east, 1.55, receiver) == 0, "bread cannot be picked twice")
	var flight := bread.get_parent().get_node_or_null("PickupFlight") as Node3D
	check(flight != null and flight.get_child_count() == 4 and not flight.is_in_group("test_stack_source"), "whole loaf flies as presentation only")
	if flight != null:
		var start := flight.global_position
		await create_timer(0.10).timeout
		check(is_instance_valid(flight) and flight.global_position.distance_to(start) > 0.05, "loaf flight moves in 3D")
	bread.refresh(state)
	await process_frame
	check(not is_instance_valid(flight) and not bread.visible, "refresh cancels flight without restoring consumed bread")
	check(cup.take(state, east, 1.55) == 1 and not cup.visible, "pick cup from east aisle with original call")

	var slot := "user://table-check-" + Crypto.new().generate_random_bytes(12).hex_encode()
	var old := State.new()
	old.take_stack("legacy.sample", "item.sample", 2)
	var restored := State.new()
	check(old.save_slot(slot).is_empty() and restored.load_slot(slot).is_empty() and restored.inventory == old.inventory, "v1 sample-only slot still loads")
	check(state.save_slot(slot).is_empty() and restored.load_slot(slot).is_empty() and restored.inventory == state.inventory, "v1 roundtrip for tabletop inventory")
	check(restored.remaining(bread.instance_id, 1) == 0 and restored.remaining(cup.instance_id, 1) == 0, "individual consumed IDs persisted")
	check(restored.take_stack("bad", "item.unknown", 1) == 0, "unknown item rejected")
	DirAccess.remove_absolute(slot)

	check(chest != null, "chest present")
	if chest != null:
		var lid: Node3D = chest.get_node("LidHinge")
		var near := chest.global_position
		chest.update_proximity(state, near)
		check(is_zero_approx(lid.rotation.x), "lid does not snap open")
		await create_timer(0.30).timeout
		check(lid.rotation.x < -1.0 and not state.inventory.has("item.sample"), "lid opens without granting inventory")
		chest.update_proximity(state, near + Vector3(3, 0, 0))
		await create_timer(0.30).timeout
		check(is_zero_approx(lid.rotation.x), "full lid shuts away from chest")
		check(chest.take(state, near, 1.55, receiver) > 0, "chest transfers immediately")
		check(chest.get_parent().has_node("PickupFlight"), "chest transfer flies")
		chest.update_proximity(state, near + Vector3(3, 0, 0))
		await create_timer(0.38).timeout
		check(not chest.get_parent().has_node("PickupFlight") and lid.rotation.x < -1.0, "chest flight finishes and empty lid stays open")

	var pile := Pile.instantiate() as Target
	pile.instance_id = "test.floor.pile"
	cabin.add_child(pile)
	check(pile.take(state, pile.global_position, 1.55, receiver) == 1, "ground stack uses the same transfer")
	check(pile.get_parent().has_node("PickupFlight"), "ground sample uses the same flight")
	cabin.queue_free()
	await process_frame
	print("TABLE CHECKS: ", "PASS" if failures == 0 else str(failures) + " failures")
	quit(0 if failures == 0 else 1)
