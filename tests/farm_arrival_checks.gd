extends SceneTree
## No manual farm callbacks: advance the production clock inside/outside and replay snapshots.
const State := preload("res://scripts/foundation/world_state.gd")
const Life := preload("res://scripts/foundation/resident_life.gd")
var errors := 0
func check(ok:bool,why:String)->void:
	if not ok: errors+=1; push_error(why)
func _initialize()->void: call_deferred("run")
func run()->void:
	var main=preload("res://Main.tscn").instantiate(); var session=main.get_node("Session")
	var slot:="user://farm_round_"+Crypto.new().generate_random_bytes(12).hex_encode()+".slot"; session.slot_path=slot; root.add_child(main)
	var s:State=session.state; var ground:Node3D=session.village_book.grounds; var clearing:Node3D=main.get_node("Pixels/Clearing"); var clock=clearing.get_node("Almanac")
	clock.set_process(false)
	var farmers:=get_nodes_in_group("village_person").filter(func(p):return p.person_id=="farmer")
	check(farmers.size()==1,"exactly one F5 farmer"); var farmer:Node3D=farmers[0]
	var copy:=State.new(); var arrivals:=0; var reloads:=0
	for tick in 510:
		if tick in [80,160,280,360]: main.show_place(tick in [80,280],Vector3.ZERO,false)
		if tick%37==0:
			check(s.save_slot(slot)=="" and copy.load_slot(slot)=="","mid-route save/load"); reloads+=1
		var d:=s.village.d; var fed:int=d.fed; var collected:int=d.collected; var watered:bool=d.field_done
		clock._process(.05); copy.village.elapsed(.05)
		check(d==copy.village.d,"offline replay differs at %d"%tick)
		var station:=""; var activity:=""
		if not watered and d.field_done: station="field"; activity="浇水"
		for i in 3:
			if int(d.fed^fed)&(1<<i): station=["hen","cow","sheep"][i]; activity="饲喂"
			if int(d.collected^collected)&(1<<i): station=["hen","cow","sheep"][i]; activity="采集"
		if station!="":
			var pose:=Life.pose(d,"farmer"); var distance:=clearing.to_global(pose.position).distance_to(ground.farm_station(station)); arrivals+=1
			for n in 3: await physics_frame
			var physical_distance:=farmer.global_position.distance_to(ground.farm_station(station))
			check(farmer.visible and farmer.activity=="work" and physical_distance<.4,"F5 farmer real position/activity: "+station)
			session.village_book.refresh()
			var action:String="麦田浇水" if station=="field" else ({"hen":"喂鸡","cow":"喂牛","sheep":"喂羊"} if activity=="饲喂" else {"hen":"收蛋","cow":"挤奶","sheep":"剪毛"})[station]
			var actual_text:String=session.village_book.worker_tag.text
			check(action in actual_text,"expected %s, got %s"%[action,actual_text]); print("F5 tag=",actual_text," entity offset=",physical_distance)
			check(pose.scene=="field" and distance<.40,"off-station job: "+station); print(station," ",activity," distance=",distance," activity=",pose.activity)
	check(arrivals==7,"expected exactly seven jobs, observed %d"%arrivals)
	check(s.village.d.cart.egg==1 and s.village.d.cart.milk==s.village.FarmJobs.YIELDS[1] and s.village.d.cart.wool==1,"single daily wagon payload")
	DirAccess.remove_absolute(slot); print("farm arrivals=",arrivals," snapshots=",reloads," failures=",errors); quit(int(errors!=0))
