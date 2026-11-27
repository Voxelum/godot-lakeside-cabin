extends RefCounted
## Non-magical actor state. Formula and practice catalog belong to this prototype,
## not to a Walker or to the world-save schema.
signal changed

const BASE_LIMIT := 999
const PRACTICE_LIMIT := 99999
const POINTS_PER_BONUS := 5
const DEFAULT_TOUGHNESS := 5
const PRACTICE_ID := &"conditioning"

var _toughness: int
var _practice := 0
var _hp: int
# Creature tuning is instance-local and never added to the player snapshot schema.
var _fixed_vitality := 0
var _physical_defense := 0
var growth_enabled := false
# Prototype tuning, not balance targets. Store unspent progress as well.
const STRENGTH_STEP := 10.0 # weighted metres per point
const TOUGHNESS_STEP := 5 # actual HP lost per point
const MIN_LOAD_KG := 1.0
var _load_metres := 0.0
var _damage_taken := 0


func strength_bonus() -> int:
	return floori(_load_metres / STRENGTH_STEP)


func toughness_bonus() -> int:
	@warning_ignore("integer_division")
	var bonus := _damage_taken / TOUGHNESS_STEP
	return bonus


func load_metres() -> float:
	return _load_metres


func damage_taken() -> int:
	return _damage_taken


func record_loaded_stride(metres: float, weight_kg: float) -> void:
	if not is_finite(metres) or not is_finite(weight_kg) or metres <= 0.0 or weight_kg < MIN_LOAD_KG:
		return
	if _attribute_growth({&"strength": metres * minf(weight_kg / MIN_LOAD_KG, 3.0)}):
		changed.emit()


## Explicit damage entrance; direct HP edits, restores and cap changes bypass it.
func take_damage(amount: int) -> int:
	var lost := clampi(amount, 0, _hp)
	if lost == 0:
		return 0
	_hp -= lost
	_attribute_growth({&"toughness": lost})
	changed.emit()
	return lost


## One qualified action can allocate a budget to multiple growth tracks.
func _attribute_growth(credits: Dictionary) -> bool:
	if not growth_enabled:
		return false
	var before_load := _load_metres
	var before_damage := _damage_taken
	_load_metres = minf(PRACTICE_LIMIT, _load_metres + float(credits.get(&"strength", 0.0)))
	_damage_taken = mini(PRACTICE_LIMIT, _damage_taken + int(credits.get(&"toughness", 0)))
	return _load_metres != before_load or _damage_taken != before_damage


func _init(base_toughness := DEFAULT_TOUGHNESS, creature_vitality := 0, armor := 0) -> void:
	_toughness = clampi(base_toughness, 0, BASE_LIMIT)
	_fixed_vitality = maxi(0, creature_vitality)
	_physical_defense = maxi(0, armor)
	_hp = max_hp()


## Armor cannot make a living opponent immune to basic melee. Guard and growth
## see only the actual physical loss; restoring HP never grants practice.
func take_physical_damage(power: int, guarded := false) -> int:
	if power <= 0: return 0
	var after_armor := maxi(1, power - _physical_defense)
	return take_damage(ceili(after_armor * .25) if guarded else after_armor)


func base_toughness() -> int:
	return _toughness


func practice_points() -> int:
	return _practice


func max_hp() -> int:
	return _fixed_vitality if _fixed_vitality > 0 else _derive_max(_toughness + toughness_bonus(), _practice)


func hp() -> int:
	return _hp


func change_hp(delta: int) -> int:
	var before := _hp
	_hp += clampi(delta, -_hp, max_hp() - _hp)
	if _hp != before:
		changed.emit()
	return _hp - before


func set_base_toughness(value: int) -> void:
	var next := clampi(value, 0, BASE_LIMIT)
	if next == _toughness:
		return
	_toughness = next
	_hp = mini(_hp, max_hp())
	changed.emit()


## Call once for an already validated completed action, never for a frame/key.
## Qualification and anti-repeat rules belong to the caller; no shipping action yet.
func record_practice(activity: StringName) -> bool:
	if not growth_enabled or activity != PRACTICE_ID or _practice == PRACTICE_LIMIT:
		return false
	_practice += 1
	changed.emit()
	return true


func snapshot() -> Dictionary:
	return {"toughness": _toughness, "conditioning": _practice, "hp": _hp,
		"load_metres": _load_metres, "damage_taken": _damage_taken}


func restore(data: Variant) -> bool:
	if not valid_snapshot(data):
		return false
	_toughness = data.toughness
	_practice = data.conditioning
	_load_metres = data.get("load_metres", 0.0)
	_damage_taken = data.get("damage_taken", 0)
	_hp = data.hp
	changed.emit()
	return true


@warning_ignore("integer_division")
static func _derive_max(toughness: int, practice: int) -> int:
	return 20 + 4 * (toughness + practice / POINTS_PER_BONUS)


static func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or data.size() not in [3, 5]:
		return false
	for key in data:
		if typeof(key) != TYPE_STRING:
			return false
	for key in ["toughness", "conditioning", "hp"]:
		if typeof(data.get(key)) != TYPE_INT:
			return false
	var damage := 0
	if data.size() == 5:
		var metres: Variant = data.get("load_metres")
		var taken: Variant = data.get("damage_taken")
		if typeof(metres) != TYPE_FLOAT or not is_finite(metres) or metres < 0.0 or metres > PRACTICE_LIMIT:
			return false
		if typeof(taken) != TYPE_INT or taken < 0 or taken > PRACTICE_LIMIT:
			return false
		damage = taken
	@warning_ignore("integer_division")
	var bonus := damage / TOUGHNESS_STEP
	return (data.toughness >= 0 and data.toughness <= BASE_LIMIT
		and data.conditioning >= 0 and data.conditioning <= PRACTICE_LIMIT
		and data.hp >= 0 and data.hp <= _derive_max(data.toughness + bonus, data.conditioning))
