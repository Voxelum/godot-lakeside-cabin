extends "res://tests/clearing_route_checks.gd"
const Brush := preload("res://world/outskirts/road_brush.gd")
const Farm := preload("res://world/outskirts/village_pasture.gd")

func capture(label:String) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--photos="):
			var file:=arg.trim_prefix("--photos=").path_join("field-track-%s-%d.png"%[label,main.field.size.x]); DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(file.get_base_dir()))
			await RenderingServer.frame_post_draw
			check(not FileAccess.file_exists(file) and main.field.get_texture().get_image().save_png(file)==OK,"capture "+file)

func _run() -> void:
	main=MAIN.instantiate(); var token:=Crypto.new().generate_random_bytes(8).hex_encode(); main.get_node("Session").slot_path="user://road-"+token+".slot"; main.get_node("BindingPanel").settings_path="user://road-"+token+".cfg"; root.add_child(main); actor=main.field_actor
	await ticks(6)
	var path:Path3D=main.field.get_node("Clearing/Outskirts/FarmLane"); var road:MeshInstance3D=path.get_node("FarmTrackSoil")
	var repeat:=Brush.paint(path,Farm.Space.FIELD_WIDTH,Brush.Surface.CART_EARTH); check(road.mesh.surface_get_arrays(0)==repeat.mesh.surface_get_arrays(0),"repeat build matches all mesh channels"); repeat.free()
	var curved:=Path3D.new(); curved.curve=Curve3D.new(); curved.curve.add_point(Vector3.ZERO,Vector3.ZERO,Vector3.RIGHT*3); curved.curve.add_point(Vector3(4,0,4),Vector3.LEFT*3); root.add_child(curved)
	var other:=Brush.paint(curved,.8,Brush.Surface.FOOT_EARTH); check(other.mesh.surface_get_material(0)==road.mesh.surface_get_material(0),"different curve, width and type share material"); check(other.mesh.surface_get_array_len(0)>4,"Bezier sampled"); curved.free()
	var focus:Vector2=Farm.TRACK[6]; main.show_place(false,Survey.point(focus),false); await ticks(18)
	# Reproduce the former batch with its own vertex colour, face normals and material.
	var old:=StandardMaterial3D.new(); old.vertex_color_use_as_albedo=true; old.vertex_color_is_srgb=true
	var batch:=preload("res://art/building_trial/mesh_batch.gd").new()
	var rows:PackedVector3Array=road.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(0,rows.size()-2,2): batch.quad(rows[i],rows[i+1],rows[i+3],rows[i+2],Vector3.UP,Color("a9936a"))
	var baseline:=batch.add_to(path,"OriginalSoil",old,false)
	paused=true; road.hide(); await capture("before"); baseline.hide(); road.show(); await capture("after"); paused=false; baseline.free()
	check(await walk(Farm.TRACK[7],"field track"),"walker follows unchanged centreline")
	print("road brush: ",checks," checks, ",failures," failures"); quit(int(failures!=0))
