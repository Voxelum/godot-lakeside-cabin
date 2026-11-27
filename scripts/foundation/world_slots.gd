extends RefCounted
## Stable placement IDs are also the original item source IDs. Use slots are
## authored in the route catalog and keyed by bed, not by a live scene node.
const Routes := preload("res://scripts/foundation/resident_routes.gd")
const PLACE := &"place_item"
const USE := &"use_resident"
const PLACEMENTS := {"cabin.dining.bread.01":"item.bread"}

static func accepts(slot: String, kind: StringName, subject: String) -> bool:
	match kind:
		PLACE: return PLACEMENTS.has(slot) and PLACEMENTS[slot] == subject
		USE: return Routes.BEDS.has(subject) and Routes.BEDS[subject] == slot
	return false
