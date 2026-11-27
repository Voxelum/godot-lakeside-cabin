@tool
extends RefCounted
## Horizontal land-use geometry in metres. Enclosed ground floors exclude roof
## eaves and the upstairs oriel. Their rectangles use the baking recipe itself.
const LOTS := preload("res://world/outskirts/settlement_lots.json")
const Survey := preload("res://world/outskirts/outskirts_profile.gd")
const ALLEY_WIDTH := [1.62,1.55,1.36,1.08]
const FIELD_WIDTH := 1.40
const APRON_WIDTH := 2.24
static var recipes := {}

static func place(lots:Node3D) -> void:
	for key:String in LOTS.data:
		var data:Array=LOTS.data[key]; var lot:Node3D=lots.get_node(key)
		lot.position=Vector3(data[0],data[1],data[2]); lot.rotation.y=deg_to_rad(data[3])

static func rectangle(frame:Transform3D, center:Vector2, size:Vector2) -> PackedVector2Array:
	var out:=PackedVector2Array()
	for sign_xy:Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var p:=center+size*.5*sign_xy
		out.append(Survey.xz(frame*Vector3(p.x,0,p.y)))
	return out

static func parcel(node:Node3D) -> Dictionary:
	var center:=Vector2.ZERO; var size:Vector2=node.get_meta("map_size",Vector2.ZERO)
	var id:=str(node.get_meta("map_id",node.name)); var door:=Vector2.ZERO
	if node.has_method("marker") and node.has_meta("room_id"):
		var stem:=str(node.get_meta("room_id")).trim_prefix("place.")
		if not recipes.has(stem): recipes[stem]=load("res://world/interiors/structures/"+stem+".json").data
		var recipe:Dictionary=recipes[stem]; var origin:Array=recipe.get("center",[0,0]); center=Vector2(origin[0],origin[1]); size=Vector2(recipe.size[0],recipe.size[1]); id=recipe.building_id
		door=Survey.xz(node.marker("DoorAnchor").global_position)
	return {"id":id,"shape":rectangle(node.global_transform,center,size),"door":door,"kind":str(node.get_meta("map_kind","building")),"label":str(node.get_meta("map_label",""))}

static func road(id:String, kind:String, points:Array, widths:Array, joins:Array) -> Dictionary:
	assert(points.size()==widths.size() and points.size()>=2)
	return {"id":id,"kind":kind,"points":PackedVector2Array(points),"widths":PackedFloat32Array(widths),"joins":joins}

static func uniform(count:int, width:float) -> Array:
	var widths:=[]; widths.resize(count); widths.fill(width); return widths

static func _cross_section(path: PackedVector2Array, i: int, t: float) -> Vector2:
	return path[i].cubic_interpolate(path[i+1], path[maxi(i-1,0)], path[mini(i+2,path.size()-1)], t)

# Product of the survey centerline, not a row of tiles. Both the stroke and
# chip cutters use the curve's tangent so the old road grows into a bend.
static func stations(path: PackedVector2Array, widths: Array) -> Array[Vector4]:
	var result: Array[Vector4] = []
	for i in path.size()-1:
		var steps := maxi(1, ceili(path[i].distance_to(path[i+1])/.43))
		for j in range(steps + int(i == path.size()-2)):
			var t := float(j)/steps
			var p := _cross_section(path, i, t)
			var heading := _cross_section(path, i, minf(t+.018,1.0)) - _cross_section(path,i,maxf(t-.018,0.0))
			var half := lerpf(widths[i], widths[i+1], t)*.5
			var edge := heading.normalized().orthogonal()*half
			result.append(Vector4(p.x,p.y,edge.x,edge.y))
	return result

## Intersection uses the whole tapered strip, not just centreline points.
static func crosses(r:Dictionary, footprint:PackedVector2Array) -> bool:
	# Baked lanes have cubic bends and the painted edge can vary by 9.3%.
	if r.kind in ["cart_street","stone","field_track"]:
		var points:PackedVector2Array=r.points; var widths:=Array(r.widths)
		var rows:Array[Vector4]=[]
		if r.kind=="field_track":
			for i in points.size():
				var a:Vector2=(points[i]-points[maxi(i-1,0)]).normalized(); var b:Vector2=(points[mini(points.size()-1,i+1)]-points[i]).normalized()
				if i==0: a=b
				if i==points.size()-1: b=a
				var axis:=(a+b).normalized(); var side:=axis.orthogonal()*float(widths[i])*.5/maxf(.55,axis.dot(a)); rows.append(Vector4(points[i].x,points[i].y,side.x,side.y))
		else:
			rows=stations(points,widths)
		for i in rows.size()-1:
			var a:=rows[i]; var b:=rows[i+1]; var u:=Vector2(a.z,a.w); var v:=Vector2(b.z,b.w); var c:=Vector2(a.x,a.y); var d:=Vector2(b.x,b.y)
			if r.kind!="field_track": u*=1.093; v*=1.093
			if not Geometry2D.intersect_polygons(footprint,PackedVector2Array([c-u,d-v,d+v,c+u])).is_empty(): return true
		return false
	for i in r.points.size()-1:
		var a:Vector2=r.points[i]; var b:Vector2=r.points[i+1]; var side:=(b-a).normalized().orthogonal()
		var u:=side*float(r.widths[i])*.5; var v:=side*float(r.widths[i+1])*.5
		if not Geometry2D.intersect_polygons(footprint,PackedVector2Array([a-u,b-v,b+v,a+u])).is_empty(): return true
	return false

## Spatial snapshot in a common frame. Virtual links have no renderer.
static func snapshot(field:Node) -> Dictionary:
	var parcels:={}; var roads:={}; var links:={}; var duplicates:=PackedStringArray()
	for node in field.get_tree().get_nodes_in_group("village_map_landmark"):
		if not field.is_ancestor_of(node): continue
		var p:=parcel(node); p.node=node
		if parcels.has(p.id): duplicates.append(p.id)
		parcels[p.id]=p
		if p.kind=="building":
			var approach:=Survey.xz(node.marker("Approach").global_position)
			var parent_road:=str(node.name)+"Footpath" if node.name!=&"Cottage" else "SouthLane"
			links[p.id]={"normal":Survey.xz(node.marker("DoorAnchor").global_basis.z).normalized(),"target":parent_road,"approach":approach,"door":p.door,"free_yard":node.name==&"Cottage"}
	for node in field.get_tree().get_nodes_in_group("village_map_road"):
		if not field.is_ancestor_of(node): continue
		var r:Dictionary=node.get_meta("space_road").duplicate(true)
		for i in r.points.size():
			var p:Vector2=r.points[i]; r.points[i]=Survey.xz(node.to_global(Vector3(p.x,0,p.y)))
		if roads.has(r.id): duplicates.append(r.id)
		roads[r.id]=r
	return {"parcels":parcels,"roads":roads,"links":links,"duplicates":duplicates}

static func edge_distance(at:Vector2, r:Dictionary) -> float:
	var nearest:=INF
	for i in r.points.size()-1:
		var a:Vector2=r.points[i]; var b:Vector2=r.points[i+1]
		var foot:=Geometry2D.get_closest_point_to_segment(at,a,b)
		var t:=clampf(a.distance_to(foot)/maxf(.0001,a.distance_to(b)),0,1)
		nearest=minf(nearest,foot.distance_to(at)-.5*lerpf(r.widths[i],r.widths[i+1],t))
	return nearest

static func validate(s:Dictionary) -> PackedStringArray:
	var errors:=PackedStringArray(); var connected:={"SouthLane":true}
	for id in s.duplicates: errors.append("duplicate:"+id)
	for r:Dictionary in s.roads.values():
		for p:Dictionary in s.parcels.values():
			if p.kind in ["building","field","shelter"] and crosses(r,p.shape): errors.append("overlap:%s:%s"%[r.id,p.id])
	var houses:=[]
	for p:Dictionary in s.parcels.values():
		if p.kind!="building": continue
		for other:Dictionary in houses:
			if not Geometry2D.intersect_polygons(p.shape,other.shape).is_empty(): errors.append("house-overlap:%s:%s"%[p.id,other.id])
		houses.append(p)
	for step in s.roads.size():
		var old:=connected.size()
		for r:Dictionary in s.roads.values():
			if connected.has(r.id): continue
			for target in r.joins:
				if connected.has(target) and s.roads.has(target) and edge_distance(r.points[0],s.roads[target])<=.03:
					connected[r.id]=true; break
		if connected.size()==old: break
	for id in s.roads:
		if not connected.has(id): errors.append("unreachable:"+id)
	for id in s.links:
		var l:Dictionary=s.links[id]; var r:Dictionary=s.roads.get(l.target,{})
		if r.is_empty() or not connected.has(l.target): errors.append("missing-door-route:"+id); continue
		var arrival:Vector2=r.points[0] if l.free_yard else r.points[-1]
		if arrival.distance_to(l.approach)>(5.0 if l.free_yard else .24): errors.append("broken-door-link:"+id)
		var inward:Vector2=l.approach-l.door
		var shape:PackedVector2Array=s.parcels[id].shape
		if inward.dot(l.normal)<.31 or absf(inward.cross(l.normal))>.1 or not Geometry2D.is_point_in_polygon(l.door-l.normal*.3,shape) or Geometry2D.is_point_in_polygon(l.door+l.normal*.3,shape): errors.append("illegal-door-side:"+id)
		var passage:=road(id,"virtual",[arrival,l.approach,l.door],[.62,.62,.62],[])
		for other:Dictionary in s.parcels.values():
			if other.id!=id and other.kind in ["building","shelter"] and crosses(passage,other.shape): errors.append("blocked-door-link:%s:%s"%[id,other.id])
	return errors
