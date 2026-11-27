extends RefCounted
## Stable slot IDs are independent of node names, layout reuse and marker positions.
const CABIN := "place.cabin"
const FIELD := "place.clearing"
const ROOMS := {
	CABIN: ["Cottage", "res://world/Interior.tscn"],
	"place.smith_stock": ["Outskirts/Lots/Blacksmith", "res://world/interiors/SmithStock.tscn"],
	"place.hay_barn": ["Outskirts/Lots/HayBarn", "res://world/interiors/HayStorage.tscn"],
	"place.lime_house": ["Outskirts/Lots/LimeHouse", "res://world/interiors/FarmRoom.tscn"],
	"place.orchard_house": ["Outskirts/Lots/OrchardHouse", "res://world/interiors/OrchardRoom.tscn"],
	"place.copper_loft": ["Outskirts/Lots/CopperLoft", "res://world/interiors/TownRoom.tscn"],
	"place.sill_house": ["Outskirts/Lots/SillHouse", "res://world/interiors/SillRoom.tscn"],
	"place.bakery": ["Outskirts/Lots/Bakery", "res://world/interiors/BakeryRoom.tscn"],
	"place.guild": ["Outskirts/Lots/Guild", "res://world/interiors/GuildHall.tscn"],
	"place.inn": ["Outskirts/Lots/Inn", "res://world/interiors/InnLodging.tscn"],
	"place.tavern": ["Outskirts/Lots/Tavern", "res://world/interiors/TavernTaproom.tscn"],
	"place.general_store": ["Outskirts/Lots/GeneralStore", "res://world/interiors/GeneralStoreRoom.tscn"],
}

static func valid_place(id: String) -> bool:
	return id == FIELD or ROOMS.has(id)

static func layout(id: String) -> PackedScene:
	if not ROOMS.has(id): return null
	return load(ROOMS[id][1]) as PackedScene

static func outdoor_lot(clearing: Node, id: String) -> Node3D:
	if not ROOMS.has(id): return null
	return clearing.get_node_or_null(ROOMS[id][0]) as Node3D

static func outdoor_door(lot: Node3D) -> Marker3D:
	return lot.marker("DoorAnchor") if lot != null else null

static func outdoor_return(lot: Node3D) -> Marker3D:
	return lot.marker("Approach") if lot != null else null

static func outdoor_hinge(lot: Node3D) -> Node3D:
	return lot.get_node_or_null("GroundDatum/ThresholdDoor") as Node3D

static func crossed_outdoor(lot: Node3D, previous: Vector3, current: Vector3) -> bool:
	var door := outdoor_door(lot)
	if door == null: return false
	var a := door.to_local(previous)
	var b := door.to_local(current)
	# The existing iris anchor is 0.103 m outside the actual facade plane.
	const STOOP_PLANE := -.103
	var hinge := outdoor_hinge(lot)
	if hinge == null or not hinge.is_clear(): return false
	if a.z <= STOOP_PLANE or b.z > STOOP_PLANE: return false
	var hit := a.lerp(b, (a.z - STOOP_PLANE) / (a.z - b.z))
	return absf(hit.x) <= float(lot.get("door_width")) * 0.5 - .13 and absf(hit.y) < 0.42
