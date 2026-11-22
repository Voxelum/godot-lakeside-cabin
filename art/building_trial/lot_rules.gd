@tool
extends RefCounted
## Versioned, pure appearance resolver. Lot IDs are not parameters to this resolver.
## All spans include eaves; the compact fallback is finite rather than a scale warp.

const FARM := 0
const TOWN := 1
const SHOP := 2
const BARN := 3
const SWEEP := 1
const HIP := 2
const STEEP := 3
const CLIPPED := 4
const GAMBREL := 5
const EAVE := 0.24
const EDGE_RESERVE := 0.31  # Eave plus trim, or a projecting window sill.
const WING := 1.45

# Width, depth, wall to eave, pitch rise; standard then compact.
const BODIES := [
	[Vector4(5.85, 3.75, 2.38, 1.43), Vector4(4.85, 3.45, 2.28, 1.38)],
	[Vector4(3.32, 4.12, 4.02, 1.80), Vector4(2.90, 3.78, 3.88, 1.71)],
	[Vector4(5.08, 4.13, 2.96, 1.53), Vector4(4.58, 3.61, 2.85, 1.39)],
	[Vector4(5.06, 4.20, 2.56, 2.18), Vector4(4.24, 3.74, 2.48, 1.93)],
]
const ROOFS := [[SWEEP, HIP], [STEEP, CLIPPED], [HIP, SWEEP], [GAMBREL, STEEP]]
# Wall, woodwork, roof, accent, stone. Three coordinated sets per archetype.
const INKS := [
	[["e1c59a", "69473a", "b2674d", "34746d", "97867a"], ["d8cb9f", "685647", "827a55", "527d67", "9b8c76"], ["d4b8a1", "664d49", "886376", "406777", "8d7e7b"]],
	[["d8ba91", "554047", "6d667d", "456c79", "8f8588"], ["d9bc9c", "67483e", "a66554", "38675e", "a78a7c"], ["c9c7a6", "4e5048", "69786e", "845449", "929189"]],
	[["e0c49d", "6c4943", "a96150", "3c796f", "a18b7e"], ["d4bf9e", "62504c", "6f697f", "9d504f", "9a8982"], ["d7caa8", "67544a", "6c857b", "56748b", "a09182"]],
	[["9b7354", "604337", "815e51", "547168", "968473"], ["a18661", "645044", "8b7257", "7c5349", "a1957b"], ["977967", "5d4947", "78677a", "557374", "8c817d"]],
]

static func roll(seed: int, channel: String, count: int) -> int:
	var digest := ("building-trial/v1/%d/%s" % [seed, channel]).sha256_buffer()
	return ((int(digest[0]) << 16) | (int(digest[1]) << 8) | int(digest[2])) % count

static func faces(index: int) -> float:
	return 90.0 * float(posmod(index, 4))

static func span(body: Vector4, lean_to := false) -> float:
	return body.x + EDGE_RESERVE * 2.0 + (WING if lean_to else 0.0)

static func resolve(kind: int, parcel: Vector2, seed: int, body_lock: int, roof_lock: int, color_lock: int, stack_lock: int, wing_lock: int, door_lock: int, shutter_lock: int) -> Dictionary:
	var warnings := PackedStringArray()
	kind = clampi(kind, FARM, BARN)
	var bodies: Array = BODIES[kind]
	var allowed_bodies: Array[int] = []
	for i in bodies.size():
		var size: Vector4 = bodies[i]
		if span(size) <= parcel.x and size.y + EDGE_RESERVE * 2.0 <= parcel.y:
			allowed_bodies.append(i)
	if allowed_bodies.is_empty():
		return {"valid": false, "warnings": ["Parcel is too small for the compact shell with eaves."]}
	var mass := allowed_bodies[roll(seed, "mass", allowed_bodies.size())]
	if body_lock > 0:
		if body_lock - 1 in allowed_bodies:
			mass = body_lock - 1
		else:
			warnings.append("Locked body does not fit the parcel; using a fitting shell.")

	var roofs: Array = ROOFS[kind]
	var roof: int = roofs[roll(seed, "roof", roofs.size())]
	if roof_lock > 0:
		if roof_lock in roofs:
			roof = roof_lock
		else:
			warnings.append("Locked profile does not fit this archetype; using its allowed roof.")
	var inks: Array = INKS[kind][clampi(color_lock - 1, 0, 2) if color_lock > 0 else roll(seed, "ink", 3)]
	var stack := 1 + roll(seed, "chimney", 3) if kind != BARN else 1
	if stack_lock > 0:
		if kind == BARN and stack_lock != 1:
			warnings.append("The barn gable has no chimney slot.")
		else:
			stack = clampi(stack_lock, 1, 3)

	var body: Vector4 = bodies[mass]
	var wing := false
	var wants_wing := wing_lock == 2 or (wing_lock == 0 and kind == BARN and roll(seed, "wing", 2) == 1)
	if wants_wing:
		wing = kind == BARN and span(body, true) <= parcel.x
		if not wing and wing_lock == 2:
			warnings.append("Lean-to needs a barn side bay and %.2f m of plot width." % span(body, true))

	# 1=left, 2=center, 3=right. Shop's door and its display share a keyed fascia.
	var door_slots := [[1, 3], [1, 2, 3], [3], [2]]
	var slots: Array = door_slots[kind]
	var door: int = slots[roll(seed, "door", slots.size())]
	if door_lock > 0:
		if door_lock in slots:
			door = door_lock
		else:
			warnings.append("That doorway conflicts with the display, glazing or barn frame.")
	var shutters := kind != BARN and kind != SHOP and roll(seed, "shutter", 2) == 1
	if shutter_lock > 0:
		shutters = shutter_lock == 2 and kind in [FARM, TOWN]
		if shutter_lock == 2 and not shutters:
			warnings.append("Shutters are not compatible with this display or hay door.")
	return {"valid": true, "warnings": warnings, "body": body, "roof": roof, "stack": stack, "wing": wing,
		"door": door, "shutters": shutters, "ink": inks}
