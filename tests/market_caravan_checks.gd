extends "res://tests/clearing_route_checks.gd"
const Ledger := preload("res://scripts/foundation/village_ledger.gd")

func snap(label: String) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--photos="):
			await RenderingServer.frame_post_draw
			var path:=arg.trim_prefix("--photos=").path_join("%s-%d.png"%[label,main.field.size.x]); DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())); check(not FileAccess.file_exists(path) and root.get_texture().get_image().save_png(path)==OK,"capture "+path)

func _run() -> void:
	var token:=Crypto.new().generate_random_bytes(12).hex_encode(); slot="user://market-"+token+".slot"
	main=MAIN.instantiate(); main.get_node("Session").slot_path=slot; main.get_node("BindingPanel").settings_path="user://market-"+token+".cfg"; root.add_child(main)
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(960,540)
	var clock=main.field.get_node("Clearing/Almanac"); clock.set_process(false)
	var book=main.session.village_book; var l=main.session.state.village; var cart=book.caravan; book.refresh()
	var r:Path3D=get_first_node_in_group("village_caravan_route"); check(r!=null,"route attached to Main")
	if not r: quit(1); return
	var first:=r.to_global(r.curve.get_point_position(0)); var last:=r.to_global(r.curve.get_point_position(r.curve.point_count-1))
	check(not cart.visible and l.d.hour==6,"new game starts before visit")
	# Normal Almanac rate in frame-sized deltas: no preset, spawn or ledger mutation.
	for i in 1800: clock._process(1.0/60)
	clock._process(.000001); book.refresh(); check(cart.visible and cart.global_position.distance_to(first)<.01,"noon enters at route start")
	clock._process(3.0); book.refresh(); main.show_place(false,cart.global_position+Vector3(-1.4,0,2.1),false); await ticks(18); await snap("arriving")
	for i in 120: clock._process(1.0/60)
	book.refresh(); check(cart.global_position.distance_to(r.to_global(r.curve.sample_baked(r.curve.get_baked_length()*.5)))<.01,"halfway on surveyed road")
	main.show_place(false,cart.global_position+Vector3(1.3,0,2.1),false); await ticks(12); await snap("on-road")
	clock._process(5.0); book.refresh(); check(cart.global_position.distance_to(last)<.01 and not l.d.cargo.is_empty() and l.d.paid_out>0,"dock pays once")
	main.show_place(false,last+Vector3(-1.34,0,3.42),false); await ticks(18)
	check(main.orbit.is_position_in_frustum(cart.global_position+Vector3.UP),"vehicle in normal view")
	await snap("dock")
	var was_paid:int=l.d.paid_in+l.d.paid_out; var crate:Vector3=cart.loads[0].position
	clock._process(1.0); book.refresh(); check(cart.loads[0].position.distance_to(crate)>.5 and cart.global_position.distance_to(last)<.01,"paid import lifted across stopped cart rail")
	clock._process(2.0); book.refresh(); check(not cart.loads[0].visible and cart.loads[2].visible and was_paid==l.d.paid_in+l.d.paid_out,"load export without paying again")
	clock._process(4.25); book.refresh(); var mid:Vector3=cart.global_position; var paid:int=l.d.paid_in+l.d.paid_out
	check(mid.distance_to(r.to_global(r.curve.sample_baked(r.curve.get_baked_length()*.775)))<.01,"returns along same road")
	l.d.road=false; main.show_place(true,Vector3.ZERO,false); clock._process(125); book.refresh(); main.show_place(false,first,false); book.refresh(); check(mid.distance_to(cart.global_position)<.001 and paid==l.d.paid_in+l.d.paid_out,"closed road inside/out + missed noon: no movement or repeat pay")
	var same=Ledger.new(); same.d=l.d.duplicate(true); l.d.road=true; same.d.road=true
	for dt in [.25,3.75,8.0,120.0,120.0,132.0]:
		check(main.session.state.save_slot(slot)=="" and main.session.state.load_slot(slot)=="","disk roundtrip")
		clock._process(dt); same.elapsed(dt); book.refresh()
		check(l.d==same.d and Ledger.valid(l.d) and get_nodes_in_group("market_caravan").size()==1,"same ledger, one vehicle after resume")
	var legacy:Dictionary=l.d.duplicate(true); legacy.erase("visit"); check(Ledger.valid(legacy),"previous ledger loadable")
	DirAccess.remove_absolute(slot); print("market caravan: ",checks," checks, ",failures," failures at ",main.field.size); quit(int(failures!=0))
