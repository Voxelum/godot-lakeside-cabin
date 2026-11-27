extends RefCounted
## Read-only snapshot, in Structure-local metres. Build after physics sync.
## Surface grid (not a waypoint list); widths are physical body diameters.
const Plan = preload("res://source/building_structure.gd")
const PITCH := 0.16
var graph := AStar3D.new()
var portals := {}
var _ids := {}
var _base := Vector2.ZERO
var _pitch := Vector2.ZERO
var diameter := 0.62

## Source supplies floor elevations, hole, ramp and domain; the mounted room's
## physics supplies actual solid walls, partitions, rails and moved furniture.
func build(p: Plan, structure: Node3D, walker: CharacterBody3D, width := 0.62) -> void:
	graph.clear()
	_ids.clear()
	portals.clear()
	diameter = width
	if width <= 0 or width > Plan.BODY_HEIGHT: return
	var bounds := p.inside
	if not p.bay.is_empty(): bounds.size.y += p.wall + float(p.bay.projection)
	_base = bounds.position
	var count := Vector2i(ceili(bounds.size.x/PITCH), ceili(bounds.size.y/PITCH))
	_pitch = bounds.size / Vector2(count)
	var space := structure.get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = width*.5
	shape.height = Plan.BODY_HEIGHT
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.exclude = [walker.get_rid()]
	q.collision_mask = walker.collision_mask
	var ray := PhysicsRayQueryParameters3D.new()
	ray.exclude = q.exclude
	ray.collision_mask = q.collision_mask
	var s := p.stair
	for ix in count.x:
		for iz in count.y:
			var uv := _base + (Vector2(ix,iz)+Vector2(.5,.5))*_pitch
			for layer in p.floors.size()+int(not s.is_empty()):
				var ramp := layer == 2
				var y := 0.0
				if ramp:
					if absf(uv.x-s.x)>s.width*.5 or uv.y<s.top_z or uv.y>s.bottom_z: continue
					y = p.upper*inverse_lerp(s.bottom_z,s.top_z,uv.y)
				else:
					y = p.floors[layer]
					if layer == 1 and p.hole.has_point(uv): continue
					if layer == 0 and not p.inside.has_point(uv): continue
				var foot := Vector3(uv.x,y,uv.y)
				ray.from = structure.to_global(foot+Vector3.UP*.12)
				ray.to = structure.to_global(foot-Vector3.UP*.12)
				var hit := space.intersect_ray(ray)
				if hit.is_empty() or hit.normal.y < .70: continue
				var support := structure.to_local(hit.position)
				if absf(support.y-y)>.035: continue
				# On a slope the lower hemisphere touches off centre. Lift by
				# r*(sec(angle)-1); include the same clearance at ramp seams.
				var lift := .008
				if not s.is_empty() and absf(uv.x-s.x)<s.width*.5+width*.5 and uv.y>=s.top_z-width*.5 and uv.y<=s.bottom_z+width*.5:
					var grade: float = p.upper/(s.bottom_z-s.top_z)
					lift += width*.5*(sqrt(1+grade*grade)-1)
				q.transform = structure.global_transform.translated_local(support+Vector3.UP*(shape.height*.5+lift))
				if not space.intersect_shape(q,1).is_empty(): continue
				var key := Vector3i(ix,layer,iz)
				var id := graph.get_available_point_id()
				graph.add_point(id,support)
				_ids[key] = id
				for offset in [Vector3i.LEFT,Vector3i.FORWARD]:
					for other_layer in p.floors.size()+int(not s.is_empty()):
						var near: Vector3i = key+offset
						near.y = other_layer
						if not _ids.has(near): continue
						var prev := graph.get_point_position(_ids[near])
						if absf(prev.y-support.y)>.17: continue
						q.motion = structure.global_basis*(prev-support)
						var safe := space.cast_motion(q)[0] >= .999
						q.motion = Vector3.ZERO
						if safe: graph.connect_points(id,_ids[near])
	# The exterior crossing is semantic: crossing the real threshold changes
	# World3D. Its indoor endpoint is the supported arrival, not a phantom
	# floor cell outside the building. The caller owns travel/door state.
	var entry := structure.to_local(structure.get_node("Entry").global_position)
	portals[p.door.id] = {"width":p.door.width,"foot":entry,"cell":cell(entry),
		"threshold":structure.to_local(structure.get_node("DoorAnchor").global_position),
		"building_id":p.data.building_id,"room_id":p.data.room_id}
	for part in p.partitions:
		for gap: Dictionary in part.passages:
			var pos := Vector3(gap.u,p.floors[part.floor],part.at) if part.axis=="x" else Vector3(part.at,p.floors[part.floor],gap.u)
			portals[gap.id] = {"foot":pos,"width":gap.width}
	if not s.is_empty(): portals["stairs"] = {"bottom":Vector3(s.x,0,s.bottom_z),"top":Vector3(s.x,p.upper,s.top_z),"width":s.width}

## Grid resolution limits endpoint classification; never globally snap across a wall.
func cell(foot: Vector3) -> int:
	var uv := Vector2(foot.x,foot.z)-_base
	if _ids.is_empty(): return -1
	var key := Vector3i(floori(uv.x/_pitch.x),0,floori(uv.y/_pitch.y))
	for layer in 3:
		key.y = layer
		if _ids.has(key) and absf(graph.get_point_position(_ids[key]).y-foot.y)<.13: return _ids[key]
	return -1

func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := cell(from)
	var b := cell(to)
	return graph.get_point_path(a,b) if a>=0 and b>=0 else PackedVector3Array()
