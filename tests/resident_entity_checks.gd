extends SceneTree
## Real F5 Walker, real model-owned collision and use dispatcher. No player save.
const Main := preload("res://Main.tscn")
const Life := preload("res://scripts/foundation/resident_life.gd")
var main
var failures:=0
var checks:=0

func _initialize() -> void: run.call_deferred()
func check(ok:bool,what:String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL ",what)
func ticks(n:int) -> void:
	for i in n: await physics_frame

func probe(person:Node3D) -> bool:
	var actor:CharacterBody3D=main.active_actor()
	actor.locked=true
	for side in [Vector3.RIGHT,Vector3.LEFT,Vector3.BACK,Vector3.FORWARD]:
		actor.global_position=person.global_position+side*1.3+Vector3.UP*.025
		var hit:=actor.move_and_collide(-side*2.0)
		if hit and hit.get_collider()==person and (actor.global_position-person.global_position).dot(side)>.38:
			main.session._use()
			var panel=main.get_node("FieldDialogue")
			var spoke:bool=panel.visible
			if spoke: panel._dismiss()
			print("Walker hit ",person.name," distance ",actor.global_position.distance_to(person.global_position)," use=",spoke)
			return spoke
	return false

func run() -> void:
	var token:=Crypto.new().generate_random_bytes(12).hex_encode()
	main=Main.instantiate(); main.get_node("Session").slot_path="user://npc_"+token+".slot"; main.get_node("BindingPanel").settings_path="user://npc_"+token+".cfg"; root.add_child(main)
	var ledger=main.session.state.village
	main.field.get_node("Clearing/Almanac").halted=true
	await ticks(4)
	var book=main.session.village_book
	var jobs:Dictionary={}
	book.show()
	for frame in 750:
		ledger.elapsed(1./30.); book.refresh()
		jobs[book.worker_tag.text]=true
	for job:String in ["麦田浇水","喂鸡","喂牛","喂羊","收蛋","挤奶","剪毛","赶路"]:
		check(jobs.has("农户 · "+job),"real arrival tag: "+job)
	check("今日住户" in book.text.text and "已餐" in book.text.text and "提篮" not in book.text.text,"ledger lists individual meals")
	book.hide()
	var people:Dictionary={}
	for p in get_nodes_in_group(&"village_person"):
		check(not people.has(p.person_id),"unique "+p.person_id); people[p.person_id]=p
	check(people.size()==Life.IDS.size(),"entire roster")
	var done:Dictionary={}
	for half_hour in 50:
		await ticks(2)
		for id:String in Life.IDS:
			var person:Node3D=people[id]
			if id=="CaravanMerchant" and (ledger.d.visit<10.9 or ledger.d.visit>=15): continue
			if done.has(id) or not person.is_visible_in_tree() or person.get_world_3d()!=main.field_actor.get_world_3d(): continue
			if probe(person): done[id]=true
			main.field_actor.global_position=Vector3(0,.1,7)
		ledger.elapsed(2.5)
	for id:String in Life.IDS: check(done.has(id),"outdoors collision and use: "+id)
	var inside:=false
	for h in 25:
		var p:=Life.pose(ledger.d,"farmer")
		if str(p.scene).begins_with("place."):
			main._mount_room(p.scene); main.show_place(true,main.room_entry.global_position,true); await ticks(4)
			var actor=people.farmer
			# The cot has its own solid frame, so use from the authored bedside aisle.
			var path:Array=preload("res://world/interiors/resident_paths.json").data[p.bed]
			var side:Array=path[-2]; main.room_actor.global_position=Vector3(side[0],side[1],side[2]); main.session._use()
			var panel=main.get_node("FieldDialogue")
			inside=actor.is_visible_in_tree() and actor.get_world_3d()==main.room_actor.get_world_3d() and panel.visible
			check(absf(actor.solid.global_basis.y.dot(Vector3.UP))<.02,"sleeping capsule lies along real cot")
			if panel.visible: panel._dismiss()
			check(actor.global_position.distance_to(main.room_entry.global_position)>.8,"room entry stays clear")
			main.show_place(false,main.field_actor.global_position,false); await ticks(3)
			check(not actor.visible and actor.collision_layer==0,"no ghost after leaving room")
			break
		ledger.step()
	check(inside,"same farmer and usable collider in the room")
	print("resident entities: ",checks," checks; ",failures," failures"); quit(int(failures!=0))
