extends "res://tests/clearing_route_checks.gd"
## Use actual F5 dispatch, physics and serialization, with an isolated scratch slot.
func _run() -> void:
	main=MAIN.instantiate(); slot="user://stock-"+Crypto.new().generate_random_bytes(12).hex_encode()+".slot"
	main.get_node("Session").slot_path=slot; main.get_node("BindingPanel").settings_path=slot+".cfg"; root.add_child(main)
	actor=main.field_actor; state=main.session.state; await ticks(4)
	var p=main.session.pasture; var ids:Dictionary={}; var counts:=[0,0,0]
	for b in p.animals:
		var id:String=b.get_meta("livestock_id"); check(not ids.has(id) and b.has_meta("entity") and b.get_node("CollisionShape3D").shape!=null,"unique solid entity: "+id); ids[id]=true; counts[b.get_meta("species")]+=1
	check(counts==[5,3,4],"original flock")
	var a:StaticBody3D=p.animals[0]; var b:StaticBody3D=p.animals[1]; var at:=a.global_position+Vector3(-.45,0,-.84)
	main.show_place(false,at,false); await ticks(4); print("approach ",actor.global_position," hen ",a.global_position," nearest ",p.nearby()); check(p.nearby()==a,"approach named hen")
	await ticks(26); var hud=main.session.hud
	check(hud._tip.visible and str(a.get_meta("label")) in hud._tip_label.text and "亲密度" in hud._tip_label.text and "抚摸" in hud._tip_prompt.text,"projected paper tip matches selected individual")
	var contact:=actor.move_and_collide((a.global_position-actor.global_position).slide(Vector3.UP),true)
	check(contact!=null and contact.get_collider()==a,"actual Walker sweep hits selected animal")
	var wall:=StaticBody3D.new(); var hit:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=Vector3(.06,1.35,1.5); hit.shape=box; wall.add_child(hit); p.add_child(wall); wall.global_position=a.global_position+Vector3(-.225,.67,-.42); await ticks(3)
	key(KEY_F); check(a.get_meta("entity").affection==0 and p.nearby()!=a,"intervening solid blocks use"); wall.queue_free(); await ticks(4)
	key(KEY_F); key(KEY_F); key(KEY_F); check(a.get_meta("entity").affection==1 and b.get_meta("entity").affection==0,"repeat selects just one, once per day"); check(actor.artwork.stroke_left>0,"active F5 rig reaches")
	main.show_place(false,b.global_position+Vector3.FORWARD*.9,false); await ticks(3); key(KEY_F); check(b.get_meta("entity").affection==1,"second hen independently remembers")
	main.session._save_slot(); check(FileAccess.file_exists(slot),"saved scratch slot"); state.village.elapsed(120.0); key(KEY_F); check(b.get_meta("entity").affection==2,"next day can increase")
	main.show_place(true,Vector3.ZERO,false); await ticks(3); check(p.nearby()==null,"interior cannot target pasture"); main.session._read_slot(); await ticks(4); key(KEY_F); check(b.get_meta("entity").affection==1 and a.get_meta("entity").affection==1,"reload restores both date and bonds; no repeat")
	for i in range(2,12): check(p.animals[i].get_meta("entity").affection==0,"other animal untouched")
	# Walk in from the public service lane; never place the Walker inside contact range.
	for index in [5,10]:
		var target:StaticBody3D=p.animals[index]; var pos:=Survey.xz(target.global_position); var label:String=target.get_meta("label")
		main.show_place(false,Survey.point(Vector2(pos.x,15.35)),false); await ticks(4)
		check(await walk(pos+Vector2(0,-1.03),label,false),"walk into range of "+label); await ticks(15)
		check(p.nearby()==target and hud._tip.visible and label in hud._tip_label.text,label+" selected and named")
		var impact:=actor.move_and_collide((target.global_position-actor.global_position).slide(Vector3.UP),true)
		check(impact!=null and impact.get_collider()==target,label+" blocks Walker sweep")
		var before:Array=[]
		for stock in p.animals: before.append(stock.get_meta("entity").affection)
		key(KEY_F); key(KEY_F)
		for n in p.animals.size(): check(p.animals[n].get_meta("entity").affection==before[n]+int(n==index),label+" repeat affects only selected individual: "+str(n))
	print("livestock checks: ",checks," failures ",failures); quit(int(failures!=0))
