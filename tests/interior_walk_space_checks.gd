extends SceneTree

const Main = preload("res://Main.tscn")
const Space = preload("res://world/interiors/interior_walk_space.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	var main := Main.instantiate()
	main.get_node("Session").slot_path = "user://walk-space-"+Crypto.new().generate_random_bytes(12).hex_encode()
	root.add_child(main)
	for i in 4: await physics_frame
	for key in ["tavern","guild"]:
		main.restore_place("place."+key,Vector3.ZERO)
		for i in 4: await physics_frame
		var structure: Node3D = main.building_structure()
		var p := Space.Plan.new()
		check(p.configure(JSON.parse_string(FileAccess.get_file_as_string("res://world/interiors/structures/%s.json"%key))).is_empty(),"authored plan")
		var m := Space.new()
		m.build(p,structure,main.room_actor)
		var entry: Vector3 = m.portals[p.door.id].foot
		print(key," cells=",m.graph.get_point_count()," entry=",entry)
		check(m.cell(entry)>=0,key+" entry")
		if key=="tavern":
			var goal := Vector3(.88,0,-1.67)
			check(not m.path(entry,goal).is_empty(),"back room through open jambs")
			check(m.cell(Vector3(-.35,0,-.86))<0,"solid partition")
			m.build(p,structure,main.room_actor,1.36)
			check(m.cell(Vector3(.88,0,-.86))<0,"oversize body cannot enter 1.18 m jamb")
			# Pick valid cells on each side: a missing endpoint isn't proof of a cut.
			var front := -1
			var rear := -1
			for id in m.graph.get_point_ids():
				var z := m.graph.get_point_position(id).z
				if z>0: front = id
				if z<-1.55: rear = id
			check(front>=0 and rear>=0 and m.graph.get_id_path(front,rear).is_empty(),"wide body yields disconnected supported regions")
		else:
			check(not m.path(entry,Vector3(1.09,p.upper,.53)).is_empty(),"stair reaches council")
			check(not m.path(entry,Vector3(-.81,0,-2.23)).is_empty(),"rear of counter via side aisle")
			check(m.cell(Vector3(.9,0,-1.72))<0,"desk worktop blocks capsule")
			check(m.cell(Vector3(p.stair.x,p.upper,0))<0,"no floating floor in stairwell")
	print("INTERIOR WALK SPACE: ",failures," failures")
	quit(int(failures>0))
