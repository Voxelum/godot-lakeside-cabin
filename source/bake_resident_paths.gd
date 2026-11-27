extends SceneTree
## Rebuild after moving beds, walls or stairs. Walk a capsule up to each bed.
const Space := preload("res://world/interiors/interior_walk_space.gd")
const Catalog := preload("res://world/interiors/room_catalog.gd")
const BEDS := {"lime_house":["Cot1"],"orchard_house":["Cot1"],"bakery":["BakersCot"],"copper_loft":["Loft/Cot1"],"sill_house":["Loft/Cot1"],"inn":["Loft/NorthBed","Loft/SouthBed"]}
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var baked := {}
	for key in BEDS:
		var room := Catalog.layout("place."+key).instantiate() as Node3D
		root.add_child(room)
		var probe := CharacterBody3D.new(); room.add_child(probe)
		for i in 3: await physics_frame
		var structure:Node3D=room.get_node("Structure")
		var plan:=Space.Plan.new(); var err:=plan.configure(load("res://world/interiors/structures/%s.json"%key).data)
		if err!="": push_error(err); quit(1); return
		var space:=Space.new(); space.build(plan,structure,probe,.46)
		var start:int=space.graph.get_closest_point(structure.get_node("Entry").position)
		for bed in BEDS[key]:
			var mattress:=structure.to_local(room.get_node("Furnishing/"+bed).global_position)+Vector3.UP*.48
			var goal:=space.graph.get_closest_point(mattress-Vector3.UP*.48)
			var path:=space.graph.get_point_path(start,goal)
			if path.is_empty() or path[-1].distance_to(mattress)>1.5: push_error(str(key," inaccessible ",bed," ",mattress)); quit(1); return
			var points:Array=[]; var last:=Vector3.ZERO
			for i in path.size():
				var heading:=Vector3.ZERO if i+1==path.size() else path[i].direction_to(path[i+1])
				if not last.is_equal_approx(heading): points.append([path[i].x,path[i].y,path[i].z]); last=heading
			points.append([mattress.x,mattress.y,mattress.z]); baked[key+"/"+bed]=points
		room.free()
	var f:=FileAccess.open("res://world/interiors/resident_paths.json",FileAccess.WRITE); f.store_string(JSON.stringify(baked,"  ")+"\n"); f.close(); quit()
