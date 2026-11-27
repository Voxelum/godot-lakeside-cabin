extends "res://tests/clearing_route_checks.gd"

func snap(prefix:String) -> void:
	await RenderingServer.frame_post_draw
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--photos="):
			var path:=arg.trim_prefix("--photos=").path_join("%s-%d.png"%[prefix,main.field.size.x]); DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
			check(not FileAccess.file_exists(path) and root.get_texture().get_image().save_png(path)==OK,"new capture "+path)

func _run() -> void:
	var token:=Crypto.new().generate_random_bytes(12).hex_encode(); main=MAIN.instantiate(); main.get_node("Session").slot_path="user://pasture-"+token+".slot"; main.get_node("BindingPanel").settings_path="user://pasture-"+token+".cfg"; root.add_child(main); root.mode=Window.MODE_WINDOWED; root.size=Vector2i(960,540); actor=main.field_actor
	await ticks(10); var map=main.session.field_map; key(KEY_M); await process_frame; await process_frame
	check(map.visible and not actor.locked,"spawn map"); await snap("map")
	key(KEY_J); await process_frame; await process_frame; var d:Dictionary=main.session.state.village.d; var was:bool=d.auto_farm; key(KEY_M); check(d.auto_farm==was and not map.visible and map.enabled,"ledger M ignored"); key(KEY_G); check(d.auto_farm!=was,"G toggles helpers"); key(KEY_J); key(KEY_ESCAPE); await process_frame; await process_frame; key(KEY_M); check(not map.visible and map.enabled,"settings shields map"); key(KEY_ESCAPE); await ticks(3)
	main.show_place(true,Vector3.ZERO,false); key(KEY_M); await ticks(3); check(not map.visible and map.enabled,"indoors no outdoor map"); main.show_place(false,Survey.point(Survey.ROUTE[0]),false); await ticks(6); key(KEY_M)
	for i in range(1,12):
		if not await walk(Survey.ROUTE[i],"pasture station"): check(false,"walk"); quit(1); return
	var track:=preload("res://world/outskirts/village_pasture.gd").TRACK
	for i in range(1,6): check(await walk(track[i],"farm lane"),"turn onto farm lane")
	check(await walk(Vector2(32.2,17.4),"pasture shoulder"),"enter meadow")
	await ticks(15)
	for stall:Vector2 in preload("res://world/outskirts/village_pasture.gd").STALLS:
		check(main.orbit.is_position_in_frustum(Vector3(stall.x,.6,stall.y)),"animal lies inside normal camera")
	check(actor.global_position.distance_to(Survey.point(Vector2(32.2,17.4)))<.25 and not actor.locked,"real walker reached paddock")
	check(not map.visible,"world view"); await snap("pasture")
	var farm=main.field.get_node("Clearing/Outskirts/VillageFarm")
	check(await walk(Vector2(32.2,15.35),"track"),"return to farm track")
	for id in ["hen","cow","sheep","field"]:
		var dest:=Survey.xz(farm.farm_station(id)); var junction:=Vector2(dest.x,15.35)
		check(await walk(junction,"service lane"),"approach "+id)
		check(await walk(dest,"workstation"),"reach "+id+" with full player collision")
		if id in ["hen","cow"]:
			await ticks(45); await snap(id+"-station")
		check(await walk(junction,"clear barn"),"return from "+id)
	check(await walk(Vector2(30.2,13.2),"west furrows"),"walk into planted soil")
	key(KEY_J); await process_frame; await process_frame; var sun=main.field.get_node("Clearing/Almanac"); var paused:bool=sun.halted
	if d.auto_farm: key(KEY_G)
	# Scratch ledger only: exercise an empty bed and then the same bed sown.
	d.crop=0; d.wet=false; d.seed=2
	key(KEY_P); check(d.crop==1 and d.seed==1,"P sows exactly one seed"); key(KEY_P)
	check(main.session.village_book.visible and main.session.village_book.near() and d.wet and sun.halted==paused,"P waters without toggling sky pause"); print("pasture map checks: ",checks," failures ",failures); quit(int(failures!=0))
