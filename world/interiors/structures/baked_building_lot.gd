@tool
extends Node3D
## Adapter for existing Outskirts path, lighting and door clients. No runtime geometry.
@export var lot_id: StringName
@export var door_width: float
@onready var mesh_view: MeshInstance3D = $GroundDatum/PaintedShell

func marker(label: String) -> Marker3D:
	var peg := get_node_or_null("GroundDatum/" + label) as Marker3D
	return peg if peg != null else get_node_or_null("GroundDatum/OpenForge/" + label) as Marker3D

func covers_outdoor_foot(foot: Vector3) -> bool:
	# v1/v2 outdoor feet are world-space. A previously open patch can now
	# be inside an enlarged shell; only recover that case, not every old save.
	var datum := $GroundDatum as Node3D
	var slab := datum.get_node("StructureCollision/GroundSlab") as CollisionShape3D
	var p := datum.to_local(foot) - slab.position
	var half := (slab.shape as BoxShape3D).size*.5
	if p.y >= -1.0 and p.y <= float(get_meta("wall_height"))+.35 and absf(p.x) < half.x+.03 and absf(p.z) < half.z+.03:
		return true
	if lot_id == &"clearing.market_court.guild":
		var clearance := preload("res://world/interiors/structures/guild_clearance.gd")
		for piece: CollisionShape3D in slab.get_parent().find_children("Guild*", "CollisionShape3D", false, false):
			if clearance.overlaps(foot,piece,.31,1.68): return true
		# An old terrain-height foot can be buried under the standing podium.
		# A current save made on top of it is still restored exactly.
		var steps := slab.get_parent().get_node_or_null("GuildSteps") as CollisionShape3D
		if steps == null: return false
		var hull: PackedVector3Array = steps.shape.points
		var local := datum.to_local(foot)
		var a := hull[0]
		var e := hull[6]
		if local.z > a.z and local.z < e.z and absf(local.x-float(marker("DoorAnchor").position.x)) < (hull[2].x-a.x)*.5+.09:
			var crest := lerpf(0.,e.y,clampf(inverse_lerp(hull[4].z,e.z,local.z),0.,1.))
			if local.y < crest-.10: return true
	return false
