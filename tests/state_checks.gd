extends SceneTree

const State = preload("res://scripts/foundation/world_state.gd")
const CHEST := "cabin.entry_chest"
const ITEM := "item.sample"
var failures := 0
var checks := 0


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", label)


func _initialize() -> void:
	var state := State.new()
	check(State.SAMPLE.definition_id == ITEM and State.SAMPLE.rarity == 1, "sample definition")
	check(state.inventory.is_empty() and state.location_id == "place.clearing" and state.position == Vector3.ZERO, "initial player")
	check(state.remaining(CHEST, 3) == 3, "map initial stock")
	check(state.take_stack(CHEST, "item.unknown", 3) == 0 and state.take_stack("", ITEM, 3) == 0 and state.take_stack(CHEST, ITEM, -1) == 0, "invalid transfers")
	check(state.inventory.is_empty() and state.remaining(CHEST, 3) == 3, "invalid transfer unchanged")
	check(state.take_stack(CHEST, ITEM, 3) == 3 and state.inventory[ITEM] == 3, "whole stack transfer")
	check(state.take_stack(CHEST, ITEM, 9) == 0 and state.remaining(CHEST, 9) == 0 and state.inventory[ITEM] == 3, "empty survives map reset")
	check(state.stock(State.BANK) == 12 and state.stock(State.RISE) == 0 and state.simulated_until == 0, "initial simulation")
	check(not state.advance_interval(1, 1) and not state.advance_interval(-1, 1) and not state.advance_interval(0, 0), "invalid intervals")
	check(state.advance_interval(0, 3) and state.stock(State.RISE) == 3, "first advance")
	check(state.advance_interval(0, 3) and state.stock(State.RISE) == 3, "full replay")
	check(state.advance_interval(1, 4) and state.stock(State.BANK) == 7, "overlap only counts suffix")
	check(state.advance_interval(5, 2, false) and state.advance_interval(5, 2) and state.simulated_until == 7 and state.stock(State.RISE) == 5, "closed route consumes progress")
	check(not state.advance_interval(1, State.MAX_INT), "interval overflow")
	state.location_id = "place.cabin"
	state.position = Vector3(1.25, 2, -3)

	var path := "user://state-check-" + Crypto.new().generate_random_bytes(16).hex_encode() + ".slot"
	check(not FileAccess.file_exists(path), "isolated slot")
	check(state.save_slot(path).is_empty(), "first save")
	state.position.y = 4
	check(state.save_slot(path).is_empty(), "replace slot")
	var original := FileAccess.get_file_as_bytes(path)
	state.position.x = INF
	check(not state.save_slot(path).is_empty() and FileAccess.get_file_as_bytes(path) == original, "failed save preserves slot")
	var restored := State.new()
	check(restored.load_slot(path).is_empty(), "load replaced slot")
	check(restored.location_id == "place.cabin" and restored.position == Vector3(1.25, 4, -3) and restored.inventory.get(ITEM) == 3, "player round trip")
	check(restored.remaining(CHEST, 3) == 0 and restored.simulated_until == 7 and restored.stock(State.BANK) == 7 and restored.stock(State.RISE) == 5, "world round trip")
	var baseline: Variant = bytes_to_var(original)
	if baseline is Dictionary:
		check(baseline.world_changes == {CHEST: {"remaining": 0}}, "persist instance field patch")
		check(baseline.stocks == {State.BANK: 7, State.RISE: 5}, "persist both route endpoints")
		for version in [1, State.VERSION]:
			var legacy: Dictionary = baseline.duplicate(true)
			legacy.erase("equipment")
			legacy.version = version
			if version == 1: legacy.erase("player_stats")
			var migrated := State.new()
			_write(path, var_to_bytes(legacy))
			check(migrated.load_slot(path).is_empty() and migrated.equipment.is_empty(), "old slot loads with empty equipment")
			migrated.grant_test_weapons()
			check(migrated.equip("main_hand", "item.sword") and migrated.equip("main_hand", "item.spear"), "weapon replacement succeeds")
			migrated.grant_test_weapons()
			check(migrated.inventory.get("item.sword") == 1 and not migrated.inventory.has("item.spear"), "migration preserves ownership")
		var invalid := [
			{"equipment": {"off_hand": "item.sword"}}, {"equipment": {"main_hand": "item.cup"}}, {"equipment": []},
			{"version": 99}, {"position": Vector3(INF, 0, 0)}, {"inventory": {ITEM: 3.0}},
			{"extra": 1}, {"location_id": "place.other"},
			{"world_changes": {CHEST: {"remaining": -1}}},
			{"world_changes": {CHEST: 0}},
			{"world_changes": {CHEST: {}}},
			{"world_changes": {CHEST: {"remaining": 0, "extra": 1}}},
			{"world_changes": {CHEST: {"remaining": 0.0}}},
			{"stocks": {State.BANK: -1, State.RISE: 5}},
			{"stocks": {State.BANK: 7, State.RISE: 4}},
			{"stocks": {State.BANK: 7, "region.unknown": 5}},
			{"stocks": {State.BANK: 7}},
			{"stocks": {State.BANK: 7, State.RISE: 5.0}},
			{"simulated_until": 4},
		]
		for patch in invalid:
			var malformed: Dictionary = baseline.duplicate(true)
			malformed.merge(patch, true)
			_write(path, var_to_bytes(malformed))
			check(not restored.load_slot(path).is_empty(), "reject " + str(patch))
		_write(path, original + PackedByteArray([0]))
		check(not restored.load_slot(path).is_empty(), "reject trailing bytes")
		_write(path, PackedByteArray())
		check(not restored.load_slot(path).is_empty(), "reject empty file")
	else:
		check(false, "saved fixture could not be decoded")
	check(restored.location_id == "place.cabin" and restored.position == Vector3(1.25, 4, -3) and restored.inventory.get(ITEM) == 3 and restored.remaining(CHEST, 3) == 0 and restored.simulated_until == 7 and restored.stock(State.BANK) == 7, "bad loads preserve state")
	check(restored.advance_interval(0, 7) and restored.stock(State.RISE) == 5, "replay after load")
	check(restored.advance_interval(7, 100) and restored.simulated_until == 107 and restored.stock(State.BANK) == 0 and restored.stock(State.RISE) == 12, "source caps shipment and conserves stock")
	check(DirAccess.remove_absolute(path) == OK, "remove isolated slot")
	print("state_checks: %d checks, %d failures" % [checks, failures])
	quit(int(failures != 0))


func _write(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null and file.store_buffer(data), "write isolated bad fixture")
