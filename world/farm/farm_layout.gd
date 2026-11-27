extends RefCounted
## XZ in Clearing metres. The farm grows east off the smithy bend; the old grade stops at X=40.
const START := 31.2
const STRIDE := 8.4
const COLUMNS := 6
const END := START + COLUMNS * STRIDE
const AISLE := 31.4
const HALF_AISLE := 1.9
const DEPTH := 6.0
const GATE_HALF := 1.22
const NORTH_JOIN := Vector2(26.985, 30.05)
const SOUTH_JOIN := Vector2(26.074, 33.42)
const REST := Vector2(29.25, 29.78)
const RECOVERY := Vector2(29.4, AISLE)
const FORK:Vector2 = preload("res://world/outskirts/outskirts_profile.gd").ROUTE[13]

static func side(tier: int) -> float:
	return -1.0 if tier == 1 else 1.0

static func gate(tier: int, column: int) -> Vector2:
	return Vector2(START + (column + .5) * STRIDE, AISLE + side(tier) * HALF_AISLE)

static func pen(tier: int, column: int) -> Rect2:
	var start_z := AISLE - HALF_AISLE - DEPTH if tier == 1 else AISLE + HALF_AISLE
	return Rect2(START + STRIDE * column, start_z, STRIDE, DEPTH)

static func home(tier: int, column: int, coat: int) -> Vector2:
	var g := gate(tier, column)
	return g + Vector2([0.0, -2.27, 2.28][coat], side(tier) * [2.65, 4.52, 4.12][coat])

static func xz(p: Vector3) -> Vector2:
	return Vector2(p.x,p.z)

static func foot(p: Vector2, lift := .015) -> Vector3:
	return Vector3(p.x, lift, p.y)

static func on_farm(p: Vector2) -> bool:
	return Rect2(26.0, AISLE-HALF_AISLE-DEPTH-.7, END-26.0+.7, (HALF_AISLE+DEPTH+.7)*2.0).has_point(p)
