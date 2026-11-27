extends SceneTree
const Life:=preload("res://scripts/foundation/resident_life.gd")
const State:=preload("res://scripts/foundation/world_state.gd")
const Main:=preload("res://Main.tscn")
var errors:=0
func check(b:bool,why:String) -> void:
	if not b: errors+=1; push_error(why)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var main:=Main.instantiate(); var session=main.get_node("Session"); var slot:="user://resident_checks_"+Crypto.new().generate_random_bytes(8).hex_encode(); session.slot_path=slot; root.add_child(main)
	var solar:=main.get_node("Pixels/Clearing/Almanac"); solar.set_process(false)
	for n in 3: await physics_frame
	var people:={}
	for body in get_nodes_in_group("village_person"): check(not people.has(body.person_id),"duplicate "+body.person_id); people[body.person_id]=body
	check(people.size()==Life.IDS.size(),"F5 has all eight bodies")
	if people.size()!=Life.IDS.size(): quit(1); return
	var l=session.state.village
	for id:String in Life.HOMES:
		main.restore_place(Life.HOMES[id],Vector3.ZERO)
		for n in 3: await physics_frame
		var p:=Life.pose(l.d,id); var body:CharacterBody3D=people[id]; var bed:Node3D=main._room_layout.get_node("Furnishing/"+str(p.bed).split("/",true,1)[1]); check(body.visible and body.activity=="sleep" and body.get_world_3d()==bed.get_world_3d() and body.global_position.distance_to(bed.global_position)<1.,"actual bedside "+id)
	main.restore_place("place.clearing",Vector3.ZERO); check(not main.indoors,"return to field")
	l.elapsed(7.35); var before:=Life.pose(l.d,"farmer"); check(session.state.save_slot(slot)=="","save travelling")
	var restored:=State.new(); check(restored.load_slot(slot)=="" and Life.pose(restored.village.d,"farmer")==before,"reload midway")
	l.elapsed(6.); restored.village.elapsed(6.); check(l.d==restored.village.d,"no second farm arrival")
	for n in 3: await physics_frame
	var fp:=Life.pose(l.d,"farmer"); check(people.farmer.visible and people.farmer.global_position.distance_to(main.field.get_node("Clearing").to_global(fp.position))<.02,"visible farmer agrees with state")
	while l.d.visit<0: l.step()
	l.elapsed(2.); var arrival:=Life.pose(l.d,Life.MERCHANT); l.elapsed(1.); check(arrival.position.distance_to(Life.pose(l.d,Life.MERCHANT).position)>1.,"merchant enters by moving cart")
	l.d.road=false; var halted:=Life.pose(l.d,Life.MERCHANT); l.elapsed(50.); var camp:=Life.pose(l.d,Life.MERCHANT); check(camp.position==halted.position and camp.activity=="camp","stranded merchant stays overnight, not resident bed")
	l.d.road=true; l.elapsed(24.); check(Life.pose(l.d,Life.MERCHANT).scene=="away","merchant leaves after road reopens")
	DirAccess.remove_absolute(slot); print("F5 RESIDENTS: ",errors," failures; ",people.keys()); quit(int(errors>0))
