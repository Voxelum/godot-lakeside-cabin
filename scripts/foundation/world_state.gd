extends RefCounted

const Rooms := preload("res://world/interiors/room_catalog.gd")

const SAMPLE = preload("res://scripts/foundation/sample.tres")
const EQUIPMENT_SLOTS := {"head":"头部", "main_hand":"主手", "off_hand":"副手", "clothes":"衣服", "pants":"裤子", "shoes":"鞋", "ring":"戒指", "pendant":"吊坠", "bracelet":"手环"}
const STARTER_WEAPONS := ["item.sword", "item.spear"]
const DEFINITIONS := {
	"item.sword": preload("res://scripts/foundation/sword.tres"),
	"item.spear": preload("res://scripts/foundation/spear.tres"),
	"item.sample": SAMPLE,
	"item.bread": preload("res://scripts/foundation/bread.tres"),
	"item.cup": preload("res://scripts/foundation/cup.tres"),
}
const SLOT := "user://foundation.slot"
const ActorStats := preload("res://scripts/foundation/actor_stats.gd")
const VERSION := 2
const BUILDING_VERSION := 3 # Tagged building-local feet; outdoors stays on v2.
const BANK := "region.bank"
const RISE := "region.rise"
const TEST_ROUTE := {"source": BANK, "destination": RISE}
const TOTAL := 12
const MAX_INT := 9223372036854775807
const MAX_SAVE_BYTES := 1024 * 1024

const Ledger := preload("res://scripts/foundation/village_ledger.gd")
var village := Ledger.new()
var player_stats := ActorStats.new()
var inventory: Dictionary = {}
var equipment: Dictionary = {}
var location_id: String = "place.clearing"
var position: Vector3 = Vector3.ZERO
var loaded_building_revision := ""
var simulated_until: int = 0
var _world_changes: Dictionary = {}
var _stocks: Dictionary = {TEST_ROUTE.source: TOTAL, TEST_ROUTE.destination: 0}


func _init() -> void:
	player_stats.growth_enabled = true


# Carried load includes bag stacks and equipped units, which are disjoint.
func inventory_weight_kg() -> float:
	var kg := 0.0
	for id in inventory:
		if DEFINITIONS.has(id):
			kg += float(inventory[id]) * DEFINITIONS[id].unit_weight_kg
	for id in equipment.values():
		kg += DEFINITIONS[id].unit_weight_kg
	return kg


func grant_test_weapons() -> void:
	for id in STARTER_WEAPONS:
		var source := "starter." + String(id)
		# Respect ownership in snapshots even without the starter source marker.
		if inventory.has(id) or id in equipment.values():
			_world_changes[source] = {"remaining": 0}
		else:
			take_stack(source, id, 1)


func equip(slot: String, id: String) -> bool:
	if not _fits(slot, id) or not inventory.has(id) or equipment.get(slot) == id:
		return false
	var previous: String = equipment.get(slot, "")
	if not previous.is_empty() and inventory.get(previous, 0) == MAX_INT:
		return false
	inventory[id] -= 1
	if inventory[id] == 0:
		inventory.erase(id)
	if not previous.is_empty():
		inventory[previous] = inventory.get(previous, 0) + 1
	equipment[slot] = id
	return true


func unequip(slot: String) -> bool:
	if not equipment.has(slot):
		return false
	var id: String = equipment[slot]
	if inventory.get(id, 0) == MAX_INT:
		return false
	inventory[id] = inventory.get(id, 0) + 1
	equipment.erase(slot)
	return true


static func _fits(slot: String, id: String) -> bool:
	return EQUIPMENT_SLOTS.has(slot) and DEFINITIONS.has(id) and DEFINITIONS[id].equipment_slot == slot


func remaining(instance_id: String, initial: int) -> int:
	if instance_id.strip_edges().is_empty():
		return 0
	return _world_changes.get(instance_id, {}).get("remaining", maxi(initial, 0))


func take_stack(instance_id: String, item_id: String, initial: int) -> int:
	if initial < 0 or not DEFINITIONS.has(item_id):
		return 0
	var count := remaining(instance_id, initial)
	var owned: Variant = inventory.get(item_id, 0)
	if count <= 0 or not _is_count(owned) or owned > MAX_INT - count:
		return 0
	inventory[item_id] = owned + count
	_world_changes[instance_id] = {"remaining": 0}
	return count


func stock(region_id: String) -> int:
	return _stocks.get(region_id, 0)


# Half-open intervals; one unit per abstract test time unit on the open route.
# Accepted replays are no-ops; only the newly covered suffix can move stock.
func advance_interval(start: int, elapsed: int, route_open: bool = true) -> bool:
	if start < 0 or elapsed <= 0 or start > simulated_until or start > MAX_INT - elapsed:
		return false
	var end := start + elapsed
	if end > simulated_until:
		if route_open:
			var source: String = TEST_ROUTE.source
			var destination: String = TEST_ROUTE.destination
			var moved := mini(stock(source), end - simulated_until)
			_stocks[source] -= moved
			_stocks[destination] += moved
		simulated_until = end
	return true


func save_slot(path: String = SLOT, building_revision := "", building_foot := Vector3.ZERO) -> String:
	var snapshot := {
		"version": VERSION, "equipment": equipment, "player_stats": player_stats.snapshot(), "inventory": inventory, "location_id": location_id,
		"position": position, "world_changes": _world_changes,
		"simulated_until": simulated_until, "stocks": _stocks, "village": village.d,
	}
	if not building_revision.is_empty():
		snapshot.version = BUILDING_VERSION
		snapshot["building_revision"] = building_revision
		snapshot.position = building_foot
	var problem := _validate(snapshot)
	if not problem.is_empty():
		return problem
	var payload := var_to_bytes(snapshot)
	if payload.size() > MAX_SAVE_BYTES:
		return "存档数据过大。"
	# Write a sibling first so failed writes never truncate the live slot.
	var destination := ProjectSettings.globalize_path(path)
	var temp := destination + ".tmp-" + Crypto.new().generate_random_bytes(12).hex_encode()
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return "无法创建临时存档。"
	var written := file.store_buffer(payload)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if not written or write_error != OK:
		DirAccess.remove_absolute(temp)
		return "存档写入失败。"
	if DirAccess.rename_absolute(temp, destination) != OK:
		DirAccess.remove_absolute(temp)
		return "无法替换存档。"
	return ""


func load_slot(path: String = SLOT) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "无法打开存档。"
	var length := file.get_length()
	if length == 0 or length > MAX_SAVE_BYTES:
		return "存档大小无效。"
	var payload := file.get_buffer(length)
	if payload.size() != length:
		return "无法完整读取存档。"
	var snapshot: Variant = bytes_to_var(payload)
	var problem := _validate(snapshot)
	if not problem.is_empty():
		return problem
	if var_to_bytes(snapshot) != payload:
		return "存档编码无效或含有多余数据。"
	village.d = snapshot.get("village", Ledger.INITIAL.duplicate(true))
	if not village.d.has("visit"): village.d.visit = -1.0
	inventory = snapshot.inventory
	equipment = snapshot.get("equipment", {})
	location_id = snapshot.location_id
	position = snapshot.position
	loaded_building_revision = snapshot.get("building_revision", "")
	_world_changes = snapshot.world_changes
	simulated_until = snapshot.simulated_until
	_stocks = snapshot.stocks
	# Keep the same component and its UI subscriptions across loads.
	player_stats.restore(snapshot.get("player_stats", ActorStats.new().snapshot()))
	return ""


static func _is_count(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0


static func _validate(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "存档格式无效。"
	var version: Variant = data.get("version")
	if typeof(version) != TYPE_INT or version not in [1, VERSION, BUILDING_VERSION]:
		return "不支持此存档版本。"
	for key in data:
		if typeof(key) != TYPE_STRING:
			return "存档字段类型无效。"
	if data.has("village") and not Ledger.valid(data.village): return "村落账册无效。"
	if data.size() != (7 if version == 1 else 8 if version == VERSION else 9) + int(data.has("equipment")) + int(data.has("village")):
		return "存档字段数量无效。"
	if version != 1 and not ActorStats.valid_snapshot(data.get("player_stats")):
		return "存档角色属性无效。"
	var place: Variant = data.get("location_id")
	var pos: Variant = data.get("position")
	if typeof(place) != TYPE_STRING or not Rooms.valid_place(place):
		return "存档地点无效。"
	if version == BUILDING_VERSION:
		var revision: Variant = data.get("building_revision")
		if not Rooms.ROOMS.has(place) or typeof(revision) != TYPE_STRING or revision.length() != 64 or not revision.is_valid_hex_number():
			return "存档建筑结构版本无效。"
	if typeof(pos) != TYPE_VECTOR3 or not pos.is_finite():
		return "存档位置无效。"
	var bag: Variant = data.get("inventory")
	var changes: Variant = data.get("world_changes")
	if typeof(bag) != TYPE_DICTIONARY or typeof(changes) != TYPE_DICTIONARY:
		return "存档库存格式无效。"
	for key in bag:
		if typeof(key) != TYPE_STRING or not DEFINITIONS.has(key) or not _is_count(bag[key]) or bag[key] == 0:
			return "存档背包条目无效。"
	var kit: Variant = data.get("equipment", {})
	if typeof(kit) != TYPE_DICTIONARY:
		return "存档装备格式无效。"
	for slot in kit:
		if typeof(slot) != TYPE_STRING or typeof(kit[slot]) != TYPE_STRING or not _fits(slot, kit[slot]):
			return "存档装备条目无效。"
	for key in changes:
		var patch: Variant = changes[key]
		if typeof(key) != TYPE_STRING or key.strip_edges().is_empty() or typeof(patch) != TYPE_DICTIONARY or patch.size() != 1:
			return "存档实例变更格式无效。"
		for field in patch:
			if typeof(field) != TYPE_STRING or field != "remaining" or not _is_count(patch[field]):
				return "存档实例库存无效。"
	var stocks: Variant = data.get("stocks")
	if typeof(stocks) != TYPE_DICTIONARY or stocks.size() != 2:
		return "存档地区库存格式无效。"
	for region in stocks:
		if typeof(region) != TYPE_STRING or region not in [TEST_ROUTE.source, TEST_ROUTE.destination] or not _is_count(stocks[region]) or stocks[region] > TOTAL:
			return "存档地区库存无效。"
	var source: int = stocks[TEST_ROUTE.source]
	var destination: int = stocks[TEST_ROUTE.destination]
	var until: Variant = data.get("simulated_until")
	if source + destination != TOTAL or not _is_count(until) or destination > until:
		return "存档地区库存或时间无效。"
	return ""
