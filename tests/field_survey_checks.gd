extends "res://tests/clearing_route_checks.gd"
## Run in a real window with -- --photos=<new directory> [--320].
func _run() -> void:
	var token:=Crypto.new().generate_random_bytes(12).hex_encode()
	main=MAIN.instantiate(); main.get_node("Session").slot_path="user://survey-"+token+".slot"; main.get_node("BindingPanel").settings_path="user://survey-"+token+".cfg"; root.add_child(main)
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(960,540); actor=main.field_actor
	await ticks(10); var map=main.session.field_map; key(KEY_M); await ticks(5)
	check(map.visible and not actor.locked,"non-modal Main map opens")
	var house:Node3D; var kinds:={}
	for id in map.landmarks:
		var entry:Dictionary=map.landmarks[id]; kinds[entry.kind]=true
		if entry.kind=="building" and entry.shape.size()>=3: house=entry.node
	for kind in ["building","field","pasture","shelter","market"]: check(kinds.has(kind),"real scene includes "+kind)
	check(not map.roads.is_empty(),"actual Path3D roads")
	var captions:=[]; var label_boxes:Array[Rect2]=[]
	for tag in map.labels:
		var box:Rect2=tag.box; check(map.PLOT.grow(3).encloses(box),"caption inside paper: "+tag.text)
		check(not label_boxes.any(func(other): return other.intersects(box)),"caption avoids others: "+tag.text); label_boxes.append(box); captions.append(tag.text)
	check(captions.has("湖畔小屋") and captions.has("魔物园入口"),"cottage and farm gate stay labeled")
	for entry in map.landmarks.values():
		if entry.kind in ["market","field","pasture","shelter"]: check(captions.has(entry.label),"visible working parcel: "+entry.label)
	for node in get_nodes_in_group(&"village_map_road"):
		if not main.field.is_ancestor_of(node): continue
		var trace:=PackedVector2Array()
		for i in node.curve.point_count: trace.append(map.xz(node.to_global(node.curve.get_point_position(i))))
		check(trace in map.roads,"world-space ordered curve: "+str(node.name))
	if not house: quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--photos="):
			await RenderingServer.frame_post_draw
			var dir:=ProjectSettings.globalize_path(arg.trim_prefix("--photos=")); DirAccess.make_dir_recursive_absolute(dir)
			var path:=dir.path_join("field-survey-%d.png"%main.field.size.x); check(not FileAccess.file_exists(path) and root.get_texture().get_image().save_png(path)==OK,"new Main photo")
	var id:=str(house.lot_id); var before:Vector2=map.landmarks[id].center; var first:PackedVector2Array=map.landmarks[id].shape; var original:=house.global_position
	house.global_position+=Vector3(7,0,-4); await create_timer(1.0).timeout
	check((map.landmarks[id].center-before).is_equal_approx(Vector2(7,-4)),"moved actual house shifts its map center")
	check((map.landmarks[id].shape[0]-first[0]).is_equal_approx(Vector2(7,-4)),"moved actual geometry updates footprint")
	var angle:=house.rotation.y; house.rotation.y+=.5; map.survey()
	check(not map.landmarks[id].shape[0].is_equal_approx(first[0]+Vector2(7,-4)),"rotation changes authored footprint")
	house.rotation.y=angle; house.global_position=original; key(KEY_J); await ticks(4); key(KEY_M); check(not map.visible and map.enabled,"ledger shields map"); key(KEY_J); await ticks(4); check(map.visible,"map restores after modal")
	print("Field survey checks ",checks,", failures ",failures); quit(int(failures!=0))
