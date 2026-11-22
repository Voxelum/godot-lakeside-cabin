extends RefCounted

const SAMPLE = preload("res://scripts/foundation/sample.tres")
const DEFINITIONS := {
	"item.sample": SAMPLE,
	"item.bread": preload("res://scripts/foundation/bread.tres"),
	"item.cup": preload("res://scripts/foundation/cup.tres"),
}
const SLOT := "user://foundation.slot"
const VERSION := 1
const BANK := "region.bank"
const RISE := "region.rise"
const TEST_ROUTE := {"source": BANK, "destination": RISE}
const TOTAL := 12
const MAX_INT := 9223372036854775807
const MAX_SAVE_BYTES := 1024 * 1024

var inventory: Dictionary = {}
var location_id: String = "place.clearing"
var position: Vector3 = Vector3.ZERO
var simulated_until: int = 0
var _world_changes: Dictionary = {}
var _stocks: Dictionary = {TEST_ROUTE.source: TOTAL, TEST_ROUTE.destination: 0}


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


func save_slot(path: String = SLOT) -> String:
	var snapshot := {
		"version": VERSION, "inventory": inventory, "location_id": location_id,
		"position": position, "world_changes": _world_changes,
		"simulated_until": simulated_until, "stocks": _stocks,
	}
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
	inventory = snapshot.inventory
	location_id = snapshot.location_id
	position = snapshot.position
	_world_changes = snapshot.world_changes
	simulated_until = snapshot.simulated_until
	_stocks = snapshot.stocks
	return ""


static func _is_count(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0


static func _validate(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "存档格式无效。"
	var version: Variant = data.get("version")
	if typeof(version) != TYPE_INT or version != VERSION:
		return "不支持此存档版本。"
	for key in data:
		if typeof(key) != TYPE_STRING:
			return "存档字段类型无效。"
	if data.size() != 7:
		return "存档字段数量无效。"
	var place: Variant = data.get("location_id")
	var pos: Variant = data.get("position")
	if typeof(place) != TYPE_STRING or place not in ["place.clearing", "place.cabin"]:
		return "存档地点无效。"
	if typeof(pos) != TYPE_VECTOR3 or not pos.is_finite():
		return "存档位置无效。"
	var bag: Variant = data.get("inventory")
	var changes: Variant = data.get("world_changes")
	if typeof(bag) != TYPE_DICTIONARY or typeof(changes) != TYPE_DICTIONARY:
		return "存档库存格式无效。"
	for key in bag:
		if typeof(key) != TYPE_STRING or not DEFINITIONS.has(key) or not _is_count(bag[key]) or bag[key] == 0:
			return "存档背包条目无效。"
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
