extends SceneTree
const State:=preload("res://scripts/foundation/world_state.gd")
const L:=preload("res://scripts/foundation/village_ledger.gd")
var errors:=0
func check(ok:bool,why:String)->void:
	if not ok: errors+=1; push_error(why)
func _initialize()->void: call_deferred("run")
func run()->void:
	var s:=State.new(); var l:=s.village; var d:=l.d
	for i in 24*10:
		l.step(); check(L.valid(d),"invalid ledger")
	check(d.health==10 and d.missed==0 and d.wagon.tool>0 and d.paid_out>0,"normal decade")
	print("10 days: ",d)
	var season:=L.new()
	var served:=0
	for day in 90:
		season.elapsed(120.)
		for id:String in L.ResidentLife.IDS:
			if season.d.life[id].ate==day: served+=1
	check(served==720,"all seven residents and driver bought and ate daily: %d/720"%served)
	print("paid meals consumed over 90 days: ",served)
	check(season.d.missed==0 and season.d.health==10,"90 days including external exhaustion")
	print("90 days: health ",season.d.health," missed ",season.d.missed," funds ",season.d.purse)
	var frozen:=L.new(); frozen.d.road=false; frozen.d.auto_farm=false
	for i in 24*4: frozen.step()
	check(frozen.d.health<10 and frozen.d.shed.egg>0 and frozen.d.store.egg==0,"road starvation")
	print("closed road: health ",frozen.d.health," missing ",frozen.d.missed," depot eggs ",frozen.d.shed.egg)
	frozen.d.road=true; frozen.d.auto_farm=true
	for i in 24*3: frozen.step()
	check(frozen.d.health>4,"resupply"); print("reopened: health ",frozen.d.health," missing ",frozen.d.missed)
	var haul:=L.new()
	while haul.d.hour<11: haul.step()
	var hold:Dictionary=haul.d.cart.duplicate(); haul.d.road=false
	for i in 24: haul.step()
	check(haul.d.cart==hold and haul.d.cart_eta==2,"closed road retains local shipment")
	haul.d.road=true; haul.step(); haul.step(); check(haul.d.cart_eta==0 and haul.d.store.egg==1,"local cart unload once")
	var livestock:=L.new(); livestock.d.grass=0; livestock.d.hay=2
	livestock.elapsed(18.5) # 09:42, all three collection visits finished
	check(livestock.d.hay==0 and livestock.d.shed.egg==1 and livestock.d.shed.milk==L.FarmJobs.YIELDS[1] and livestock.d.shed.wool==0,"only two hay rations")
	var shop:=L.new(); shop.d.wagon.iron=0; shop.d.purse.caravan=0; shop.d.purse.family+=120; shop.d.store.tool=2
	shop.shipment("tool",2,false); shop.shipment("iron",2,true)
	check(shop.d.cargo.is_empty() and shop.d.store.tool==2,"no free iron or exports to insolvent buyer")
	var plot:=L.new(); plot.d.auto_farm=false; plot.tend()
	for i in 48: plot.step()
	check(plot.d.crop==0 and plot.d.withered==1,"two dry dawns kill wheat")
	plot.tend()
	for i in 2:
		plot.tend()
		for h in 24: plot.step()
	check(plot.d.crop==3,"two watered dawns")
	plot.tend(); check(plot.d.wheat==4,"harvest")
	while int(d.hour)%24!=14: l.step()
	check(not d.cargo.is_empty(),"mid journey")
	var slot:="user://ledger_"+Crypto.new().generate_random_bytes(12).hex_encode()+".slot"
	var mid:=State.new(); mid.village.elapsed(11.8)
	for wait_time:float in [4.0,1.2,9.0]:
		check(mid.save_slot(slot)=="","save during rounds")
		var copy:=State.new(); check(copy.load_slot(slot)=="","load during rounds")
		mid.village.elapsed(wait_time); copy.village.elapsed(wait_time)
		check(copy.village.d==mid.village.d,"no duplicate rations or yields on reload")
	check(mid.village.d.fed==7 and mid.village.d.collected==7 and mid.village.d.cart.egg==1 and mid.village.d.cart.milk==L.FarmJobs.YIELDS[1] and mid.village.d.cart.wool==1,"three rationed products on wagon once")
	check(s.save_slot(slot)=="","save")
	var loaded:=State.new(); check(loaded.load_slot(slot)=="","load")
	for i in 24: l.step(); loaded.village.step()
	check(d==loaded.village.d,"replay once")
	for hour in [11]:
		while int(d.hour)%24!=hour: l.step()
		check(d.cart_eta>0,"local cargo has departed")
		check(s.save_slot(slot)=="" and loaded.load_slot(slot)=="","local cargo round-trip")
		for n in 3: l.step(); loaded.village.step()
		check(d==loaded.village.d,"local cargo delivered once")
	var main=preload("res://Main.tscn").instantiate(); var sess=main.get_node("Session"); sess.slot_path=slot; root.add_child(main)
	var baseline:=L.new(); baseline.d=sess.state.village.d.duplicate(true)
	for inside in [false,true,false]:
		main.show_place(inside,Vector3.ZERO,false)
		main.get_node("Pixels/Clearing/Almanac")._process(122.5); baseline.elapsed(122.5)
		check(sess.state.village.d==baseline.d,"visible/indoor mismatch")
	var ev:=InputEventKey.new(); ev.keycode=KEY_J; ev.pressed=true
	check(sess.handle_event(ev) and sess.village_book.visible,"open paper")
	check(sess.village_book.worker!=null,"farm view installed")
	await process_frame; await process_frame
	var paper=sess.village_book
	check(paper.text.position.x+paper.text.size.x<=paper.size.x-10 and paper.text.position.y+paper.text.size.y<=paper.size.y-8,"ledger text exceeds paper: %s vs %s"%[paper.text.size,paper.size])
	main.field_actor.global_position=Vector3(32.2,0,17.4); var before_grass:int=sess.state.village.d.grass
	paper.key(KEY_H); check(sess.state.village.d.grass==maxi(0,before_grass-1),"hay key on pasture")
	DirAccess.remove_absolute(slot); print("village checks: ",errors," failures"); quit(int(errors!=0))
