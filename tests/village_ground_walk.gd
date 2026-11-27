extends "res://tests/clearing_route_checks.gd"
const Farm := preload("res://world/outskirts/village_pasture.gd")

func photo(label:String) -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--photos="): continue
		var path:=arg.trim_prefix("--photos=").path_join("%s-%d.png"%[label,main.field.size.x]); DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		await RenderingServer.frame_post_draw
		check(not FileAccess.file_exists(path) and main.field.get_texture().get_image().save_png(path)==OK,"unique native photo "+path)

func _run() -> void:
	var token:=Crypto.new().generate_random_bytes(12).hex_encode(); main=MAIN.instantiate(); main.get_node("Session").slot_path="user://farm-"+token+".slot"; main.get_node("BindingPanel").settings_path="user://farm-"+token+".cfg"; root.add_child(main); actor=main.field_actor
	await ticks(8)
	for i in range(1,12): check(await walk(Survey.ROUTE[i],"village entry"),"entry")
	for i in range(1,6): check(await walk(Farm.TRACK[i],"farm lane"),"farm lane")
	check(await walk(Vector2(32.2,17.4),"pasture"),"reach open grass"); await ticks(8); await photo("cattle-fold")
	var d:Dictionary=main.session.state.village.d; key(KEY_J)
	for hour in 24:
		if d.grass>0: break
		key(KEY_N)
	var before:int=d.hay; key(KEY_H); check(d.hay==before+1,"grass only: cut hay"); key(KEY_J); await ticks(3)
	check(await walk(Vector2(30.2,13.2),"wheat bed"),"reach west furrows"); key(KEY_J); if d.auto_farm: key(KEY_G)
	if d.crop==0: key(KEY_P)
	for j in 2:
		if d.crop<3: key(KEY_P)
		for hour in 24: key(KEY_N)
	check(d.crop==3,"two watered dawns mature plot"); key(KEY_J); await ticks(8); await photo("wheat-field")
	check(await walk(Farm.TRACK[5],"farm turn"),"return to headland")
	for i in range(6, Farm.TRACK.size()):
		check(await walk(Farm.TRACK[i],"outer headland"),"continuous field circuit %d"%i)
		if i==6: await ticks(10); await photo("pasture-and-wheat")
		if i==8: await ticks(10); await photo("far-furrows")
	check(await walk(Vector2(46.1,3.8),"across field"),"cross rows"); key(KEY_J); var wheat:int=d.wheat; key(KEY_P); check(d.crop==0 and d.wheat==wheat+4,"harvest from opposite corner"); key(KEY_J)
	# Scratch legacy outdoor save on the formerly open glade, now inside the barn.
	var barn:Node3D=main.field.get_node("Clearing/Outskirts/Lots/HayBarn"); var legacy:Vector3=barn.get_node("GroundDatum").global_position; legacy.y=.002
	var state_now=main.session.state; state_now.position=legacy; check(state_now.save_slot(main.session.slot_path).is_empty(),"write outdoor fixture"); key(KEY_F9); await ticks(5)
	var approach:Vector3=barn.marker("Approach").global_position; check(actor.global_position.distance_to(approach)<.18,"recover obstructed old outdoor save at actual barn door")
	check(await walk(Survey.nearest_track(Survey.xz(approach)),"escape old barn save"),"walk back to public lane")
	var site_now:=barn.get_parent().get_parent(); var local:=site_now.get_node("LocalProduceRoute") as Path3D
	check(not local.is_in_group("village_caravan_route"),"local goods do not impersonate visiting caravan")
	for i in local.curve.point_count:
		check(await walk(Survey.xz(local.to_global(local.curve.get_point_position(i))),"local delivery"),"real walker traverses loaded delivery station %d"%i)
	await ticks(8); await photo("exchange-stall")
	var shape_q:=PhysicsShapeQueryParameters3D.new(); shape_q.shape=actor.get_node("Body").shape; shape_q.exclude=[actor.get_rid()]
	for hour in [6,8,10,14,19]:
		var foot:Vector3=site_now.worker_station(hour); shape_q.transform=Transform3D(Basis.IDENTITY,foot+Vector3.UP*.92)
		check(actor.get_world_3d().direct_space_state.intersect_shape(shape_q).is_empty(),"resident stance has full capsule clearance at %d"%hour)
	DirAccess.remove_absolute(main.session.slot_path)
	print("village ground walk: ",checks," checks, ",failures," failures"); quit(int(failures!=0))
