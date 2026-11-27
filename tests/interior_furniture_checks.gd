extends SceneTree

const State = preload("res://scripts/foundation/world_state.gd")
const Cabin = preload("res://world/Interior.tscn")
const PlainTable = preload("res://world/interiors/DiningTable.tscn")
const Chair = preload("res://world/interiors/DiningChair.tscn")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _run() -> void:
	var cabin := Cabin.instantiate()
	root.add_child(cabin)
	var table: Node3D = cabin.get_node("Dining")
	var chair: Node3D = cabin.get_node("SouthChair")
	var marker: Marker3D = table.get_node("Tabletop")
	var bread = marker.get_node("CabinSetting/BreadPickup")
	var cup = marker.get_node("CabinSetting/CupPickup")
	var bread_local := table.to_local(bread.global_position)
	var cup_local := table.to_local(cup.global_position)
	var entry: Vector3 = cabin.get_node("Structure/Entry").global_position
	table.position += Vector3(3.1, 0, -0.75)
	table.rotate_y(PI * 0.5)
	chair.position = Vector3(2.4, 0, 0.2)
	chair.rotate_y(-PI * 0.5)
	await physics_frame
	await physics_frame
	check(bread.global_position.is_equal_approx(table.to_global(bread_local)), "bread follows the rotated tabletop")
	check(cup.global_position.is_equal_approx(table.to_global(cup_local)), "cup follows the rotated tabletop")
	check(cabin.get_node("Structure/Entry").global_position.is_equal_approx(entry), "furniture does not move the door landing")
	var space := table.get_world_3d().direct_space_state
	for item: Node3D in [table, chair]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(item.global_position + Vector3.UP * 1.6, item.global_position + Vector3.UP * 0.12))
		check(hit.has("collider") and item.is_ancestor_of(hit.get("collider")), "collision follows " + item.name)
	var state := State.new()
	state.location_id = "place.cabin"
	state.position = entry
	check(bread.take(state, bread.global_position, 1.55) == 1, "pick transformed bread")
	check(cup.take(state, cup.global_position, 1.55) == 1, "pick transformed cup")
	var slot := "user://interior-furniture-" + Crypto.new().generate_random_bytes(12).hex_encode()
	var restored := State.new()
	check(state.save_slot(slot).is_empty() and restored.load_slot(slot).is_empty(), "round-trip moved tabletop consumption")
	DirAccess.remove_absolute(slot)
	var again := Cabin.instantiate()
	root.add_child(again)
	for id in ["BreadPickup", "CupPickup"]:
		var target = again.get_node("Dining/Tabletop/CabinSetting/" + id)
		target.refresh(restored)
		check(not target.visible and target.take(restored, target.global_position, 1.55) == 0, id + " does not revive with the default layout")
	var plain := PlainTable.instantiate()
	var seat := Chair.instantiate()
	check(plain.has_node("Tabletop") and plain.get_node("Tabletop").get_child_count() == 0, "plain table has no baked cabin source IDs")
	check(seat is Node3D, "chair is independently instantiable")
	plain.free()
	seat.free()
	print("INTERIOR FURNITURE: ", "PASS" if failures == 0 else str(failures) + " failures")
	quit(0 if failures == 0 else 1)
