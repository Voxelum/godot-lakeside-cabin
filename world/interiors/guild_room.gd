extends "res://world/interiors/structures/room_presentation.gd"
const Clearance := preload("res://world/interiors/structures/guild_clearance.gd")

func _ready() -> void:
	# The hall has clerestory and wall lights in the same room. Preserve the
	# individual pools without burning out the flagstone or council papers.
	for lamp: SpotLight3D in $Structure/WindowDaylight.get_children():
		var strength := .64 if String(lamp.name).ends_with("_dormer") else .46
		lamp.set_meta("day_energy",float(lamp.get_meta("day_energy"))*strength)
	super._ready()

func saved_foot_obstructed(foot: Vector3, capsule: CapsuleShape3D) -> bool:
	for piece: CollisionShape3D in $Furnishing.find_children("*", "CollisionShape3D", true, false):
		if Clearance.overlaps(foot,piece,capsule.radius,capsule.height): return true
	return false
