extends RefCounted
## Static routes; the save stores named edge endpoints and metres along the edge,
## not live Nodes, World3D handles, or a list of guessed future positions.
const Survey := preload("res://world/outskirts/outskirts_profile.gd")
const Lots := preload("res://world/outskirts/settlement_lots.json")
const Paths := preload("res://world/interiors/resident_paths.json")
const Rooms := preload("res://world/interiors/room_catalog.gd")
const Farm := preload("res://world/outskirts/village_pasture.gd")
const BEDS := {"farmer":"orchard_house/Cot1","HazelTender":"lime_house/Cot1","BakeryRunner":"bakery/BakersCot","WellPotter":"copper_loft/Loft/Cot1","NetMender":"sill_house/Loft/Cot1","Lamplighter":"inn/Loft/NorthBed","LakesideCompanion":"inn/Loft/SouthBed"}
const JOBS := {"LakesideCompanion":Vector2(1.09,7.36),"HazelTender":Vector2(8.43,23.38),"WellPotter":Vector2(16.74,26.86),"NetMender":Vector2(9.65,25.15),"BakeryRunner":Vector2(31.08,75.62),"Lamplighter":Vector2(29.15,76.6)}
static var graph := AStar3D.new()
static var keys:Array[String]=[]
static var ids:Dictionary={}
static var scenes:Dictionary={}
static var freight:=Curve3D.new()
static func add(k:String,p:Vector3,scene:="field") -> void:
	ids[k]=keys.size(); keys.append(k); scenes[k]=scene; graph.add_point(ids[k],p)
static func link(a:String,b:String) -> void: graph.connect_points(ids[a],ids[b])
static func pos(k:String) -> Vector3: return graph.get_point_position(ids[k])
static func outdoor(k:String,p:Vector2) -> void: add(k,Survey.point(p,.008))
static func track(prefix:String,line:Array) -> void:
	for i in line.size():
		outdoor(prefix+str(i),line[i]); if i>0: link(prefix+str(i-1),prefix+str(i))
static func tap(k:String,p:Vector2,prefix:String,line:Array) -> void:
	outdoor(k,p); var q:=Survey.nearest_on(p,line); var best:=0
	for i in line.size()-1:
		if q.distance_to(Geometry2D.get_closest_point_to_segment(q,line[i],line[i+1]))<.001: best=i; break
	outdoor(k+".join",q); link(k,k+".join"); link(k+".join",prefix+str(best)); link(k+".join",prefix+str(best+1))
static func setup() -> void:
	if not keys.is_empty(): return
	track("lane",Survey.ROUTE); track("court",Survey.MARKET_ROUTE); link("lane24","court0")
	track("yard",Farm.TRACK.slice(0,7)); link("lane11","yard0")
	for station:String in Farm.WORK_POINTS:
		var p:Vector2=Farm.WORK_POINTS[station]; outdoor(station,p); link(station,"yard"+str(4 if station=="hen" else 5 if station in ["field","cow"] else 6))
	link("hen","cow"); link("cow","sheep")
	for id:String in JOBS: tap("job."+id,JOBS[id],"lane",Survey.ROUTE)
	outdoor("apron",Vector2(18.88,24.52)); link("lane11","apron")
	outdoor("dock",Vector2(19.48,22.34)); link("apron","dock")
	for i in BEDS.size():
		var p:=Vector2(20.37,21.1+float(i)*.42); outdoor("shop"+str(i),p); link("shop"+str(i),"apron")
	for p:Vector2 in Survey.ROUTE.slice(3,12)+[Vector2(18.88,24.52),Vector2(19.48,22.34)]: freight.add_point(Survey.point(p))
	for id:String in BEDS:
		var path:String=BEDS[id]; var stem:=path.get_slice("/",0); var room:="place."+stem; var door:="door."+stem
		if not ids.has(door):
			var lot:String=Rooms.ROOMS[room][0].get_file(); var datum:Array=Lots.data[lot]; var frame:=Transform3D(Basis(Vector3.UP,deg_to_rad(datum[3])),Vector3(datum[0],datum[1],datum[2]))
			var model:Node3D=load("res://world/interiors/structures/%sExterior.scn"%lot).instantiate(); var local:Node3D=model.get_node("GroundDatum")
			var approach:Vector3=frame*local.transform*model.marker("Approach").position; var sill:Vector3=frame*local.transform*model.marker("DoorAnchor").position; model.free()
			tap(door+".path",Survey.xz(approach),"court" if stem=="inn" else "lane",Survey.MARKET_ROUTE if stem=="inn" else Survey.ROUTE); add(door,sill); link(door,door+".path")
		var prev:=door; var points:Array=Paths.data[path]
		for i in points.size():
			var k:="bed."+id if i==points.size()-1 else id+".room."+str(i); var p:Array=points[i]; add(k,Vector3(p[0],p[1],p[2]),room); link(prev,k); prev=k
static func next(a:String,b:String) -> String:
	var steps:=graph.get_id_path(ids[a],ids[b]); return keys[steps[1]] if steps.size()>1 else a
