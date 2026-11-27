extends RefCounted
## Logical identity and state belong to the world, not its disposable bodies.
const Stats := preload("actor_stats.gd")
const Life := preload("resident_life.gd")
class Individual extends RefCounted:
	var id: String
	var stats: Stats
	var inventory: Variant # null = no pack; not shop stock, family purse or held meal
	var affection := 0
	var last_pet_day := -1
	var _body: WeakRef
	func body() -> Node3D:
		return _body.get_ref() if _body != null else null

var records := {}
# Loading may precede creation of a persistent actor's presentation.
var _pending := {}

func _ensure(id: String, stats: Stats = null) -> Individual:
	if records.has(id): return records[id]
	var person := Individual.new()
	person.id = id
	person.stats = stats if stats != null else Stats.new()
	if id.begins_with("resident:"): person.inventory = {}
	records[id] = person
	if _pending.has(id):
		_apply(person, _pending[id]); _pending.erase(id)
	return person

func _bind(person: Individual, body: Node3D) -> Individual:
	person._body = weakref(body)
	body.set_meta(&"entity", person)
	return person

func bind_player(body: Node3D, stats: Stats, bag: Dictionary) -> Individual:
	var player := _ensure("player", stats)
	player.inventory = bag
	return _bind(player, body)

func bind_resident(id: String, body: Node3D) -> Individual:
	assert(id in Life.IDS)
	return _bind(_ensure("resident:" + id), body)

func bind_monster(id: String, body: Node3D, combat_stats: Stats) -> Individual:
	return _bind(_ensure("monster:" + id, combat_stats), body)

func bind_livestock(stable_id: String, body: Node3D) -> Individual:
	assert(stable_id.begins_with("livestock:") and stable_id.length() > 10)
	return _bind(_ensure(stable_id), body)

static func _persistent(id: String) -> bool:
	return (id.begins_with("livestock:") and id.length() > 10 and id.length() <= 128) or (id.begins_with("resident:") and id.trim_prefix("resident:") in Life.IDS)

func snapshot() -> Dictionary:
	var data := _pending.duplicate(true)
	for id: String in records:
		if not _persistent(id): continue
		var person: Individual = records[id]
		var row := {"stats":person.stats.snapshot(), "bag":person.inventory}
		if id.begins_with("livestock:"):
			row.affection = person.affection; row.last_pet_day = person.last_pet_day
		data[id] = row
	return data

static func valid(data: Variant, items: Dictionary) -> bool:
	if not data is Dictionary or data.size() > 1024: return false
	for id in data:
		if not id is String or not _persistent(id): return false
		var row: Variant = data[id]
		if not row is Dictionary or not row.has("bag") or not Stats.valid_snapshot(row.get("stats")): return false
		if id.begins_with("livestock:"):
			if row.size() != 4 or row.bag != null: return false
			if not row.get("affection") is int or row.affection < 0 or row.affection > 100: return false
			if not row.get("last_pet_day") is int or row.last_pet_day < -1: return false
		elif row.size() != 2 or not row.bag is Dictionary: return false
		else:
			for item in row.bag:
				if not item is String or not items.has(item) or not row.bag[item] is int or row.bag[item] <= 0: return false
	return true

func _apply(person: Individual, row: Dictionary) -> void:
	person.stats.restore(row.stats)
	if person.inventory is Dictionary: person.inventory.assign(row.bag)
	person.affection = row.get("affection", 0); person.last_pet_day = row.get("last_pet_day", -1)

func restore(data: Dictionary) -> void:
	_pending = data.duplicate(true)
	for id: String in records:
		if not _persistent(id): continue
		_apply(records[id], _pending.get(id, {"stats":Stats.new().snapshot(), "bag":{}}))
		_pending.erase(id)
