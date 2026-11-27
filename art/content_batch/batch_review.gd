extends SceneTree
## Tests the authored F5 placements without injecting or swapping any assets.
const MAIN := preload("res://Main.tscn")
const Survey := preload("res://world/outskirts/outskirts_profile.gd")
const ACTIONS := [&"walk_left",&"walk_right",&"walk_up",&"walk_down"]
const CLIPS := [&"rear_and_sniff",&"rattle_guard"]
const HOURS := [14.,18.66667]
const REVIEW := "res://art/content_batch/captures/"
var main
var field: SubViewport
var actor: CharacterBody3D
var orbit: Camera3D
var clock: Node
var lots: Array[Node3D] = []
var creatures: Array[Node3D] = []
var checks := 0
var failures := 0
var slot: String
var prefs: String
var building_sheet: Image
var creature_sheet: Image

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func _run() -> void:
	var token := Crypto.new().generate_random_bytes(16).hex_encode()
	slot = "user://content_batch_%s.slot" % token
	prefs = "user://content_batch_%s.cfg" % token
	main = MAIN.instantiate()
	main.get_node("Session").slot_path = slot
	main.get_node("BindingPanel").settings_path = prefs
	var clearing: Node3D = main.get_node("Pixels/Clearing")
	var neighborhood := clearing.get_node("Outskirts/Lots")
	var forge: Node3D = neighborhood.get_node("Blacksmith")
	lots = [forge, neighborhood.get_node("LimeHouse"), neighborhood.get_node("SillHouse")]
	var habitats := clearing.get_node("Outskirts/Habitats")
	creatures = [habitats.get_node("GiantRat"), habitats.get_node("SkeletonSentry")]
	root.add_child(main)
	field = main.field
	actor = main.field_actor
	orbit = main.orbit
	clock = clearing.get_node("Almanac")
	await _ticks(7)
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://Main.tscn" and field.get_camera_3d()==orbit and not main.indoors,"F5 and its active outdoor pixel camera")
	check(field.size==(Vector2i(320,180) if "--320" in OS.get_cmdline_user_args() else Vector2i(480,270)),"native preset selected by Main")
	orbit.set_process(false)
	clearing.get_node("ForestLife").set_process(false)
	for lot in lots:
		var shell: MeshInstance3D = lot.mesh_view
		var painted: bool = shell.mesh.get_surface_count() > 0
		for i in shell.mesh.get_surface_count(): painted = painted and shell.get_active_material(i) != null
		check(painted and lot.get_world_3d()==actor.get_world_3d(),"painted component surfaces in Clearing: "+str(lot.name))
		var anchors_ok := true
		for peg in ["DoorAnchor","Landing","Approach","Lamp"]:
			anchors_ok = anchors_ok and is_instance_valid(lot.marker(peg))
		check(anchors_ok,"lot anchor contract: "+str(lot.name))
		var entries := lot.find_children("*","OmniLight3D",true,false)
		var lamp := entries.front() as OmniLight3D
		check(entries.size()==1 and lamp.is_in_group(&"night_omni") and clock._locals.has(lamp),"lamp is registered by the original Almanac: "+str(lot.name))
		_time(14.)
		check(not lamp.visible,"lamp off at 14:00: "+str(lot.name))
		_time(18.66667)
		check(lamp.visible,"lamp on at 18:40: "+str(lot.name))
		await _doorfront(lot)
	await _open_bay(forge)
	for i in 2:
		_creature_checks(creatures[i],i)
	if DisplayServer.get_name() != "headless":
		await _renders()
		if failures==0 and "--capture" in OS.get_cmdline_user_args():
			_save_sheet(building_sheet,"buildings")
			_save_sheet(creature_sheet,"creatures")
	elif "--capture" in OS.get_cmdline_user_args():
		check(false,"--capture needs a windowed renderer")
	check(not FileAccess.file_exists(slot) and not FileAccess.file_exists(prefs),"test wrote no save or binding file")
	print("content_batch: %d/%d passed; %s; native %s" % [checks-failures,checks,DisplayServer.get_name(),str(field.size)])
	quit(int(failures!=0))

func _time(hour: float) -> void:
	clock.hour = hour
	clock.halted = true
	clock._advance_sky()

func _stage(p: Vector2) -> void:
	actor.global_position = Survey.point(p,.006)
	actor.velocity = Vector3.ZERO
	actor.reset_physics_interpolation()

func _ticks(n: int) -> void:
	for i in n: await physics_frame

func _drive(direction: Vector2) -> void:
	var right := orbit.global_basis.x.slide(Vector3.UP).normalized()
	var dir := Vector3(direction.x,0,direction.y)
	var x := dir.dot(right)
	var y := dir.dot(right.cross(Vector3.UP))
	var axes := [-x,x,-y,y]
	for i in 4:
		if axes[i] > .001: Input.action_press(ACTIONS[i],axes[i])
		else: Input.action_release(ACTIONS[i])

func _walk(dest: Vector2) -> bool:
	var start := Survey.xz(actor.global_position)
	var timeout := ceili(start.distance_to(dest)*60./actor.walk_speed)+85
	for t in timeout:
		var d := dest-Survey.xz(actor.global_position)
		if d.length()<.068:
			_drive(Vector2.ZERO)
			return true
		_drive(d.normalized())
		await physics_frame
	_drive(Vector2.ZERO)
	print("blocked while walking: ",start," -> ",dest," at ",actor.global_position)
	return false

func _doorfront(lot: Node3D) -> void:
	var outside: Marker3D = lot.marker("Approach")
	var door: Marker3D = lot.marker("DoorAnchor")
	if not outside or not door: return
	var approach := Survey.xz(outside.global_position)
	var road := Survey.nearest_track(approach)
	_stage(road)
	await _ticks(4)
	# These exteriors now have rooms. Stop on the front of the stoop and
	# leave directed threshold travel to tests/interior_door_checks.gd.
	var reached := (await _walk(approach)) and (await _walk(Survey.xz(door.to_global(Vector3(0,0,.52)))))
	await _ticks(4)
	check(reached and actor.is_on_floor(),"walk existing road to supported landing front: "+str(lot.name))
	check(not main.indoors and not main.crossing,"front of the stoop stays outdoors: "+str(lot.name))
	check((await _walk(approach)) and (await _walk(road)),"descend and return to existing road: "+str(lot.name))

func _open_bay(forge: Node3D) -> void:
	var entry := Survey.xz(forge.to_global(Vector3(2.62,0,3.10)))
	_stage(entry)
	await _ticks(4)
	var under := Survey.xz(forge.to_global(Vector3(2.62,0,1.77)))
	check((await _walk(under)) and actor.is_on_floor(),"Walker really passes between forge posts, into the open work bay")
	check(await _walk(entry),"Walker leaves the work bay")

func _pose(clipper: AnimationPlayer, id: StringName, fraction: float) -> void:
	if clipper.current_animation!=id:
		clipper.play(id)
	clipper.seek(clipper.get_animation(id).length*fraction,true)

func _creature_checks(unit: Node3D, i: int) -> void:
	var feet := unit.global_position
	var ray := PhysicsRayQueryParameters3D.create(feet + Vector3.UP, feet - Vector3.UP, 1, [actor.get_rid(), (unit as PhysicsBody3D).get_rid()])
	var hit := unit.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty() and absf(feet.y - hit.position.y - .009) < .02,
		"creature root rests on the original ground: " + str(unit.name))
	var model := unit.get_node("Model") as Node3D
	var clipper := model.get_node("AnimationPlayer") as AnimationPlayer
	check(unit.is_in_group(&"field_occupant") and model.get_script()==null and model.find_children("*","CollisionObject3D",true,false).is_empty(),"solid F5 host; standalone scene remains scriptless artwork: "+str(unit.name))
	check(clipper.autoplay==&"idle" and clipper.current_animation==&"idle","idle autoplays: "+str(unit.name))
	clipper.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var track_ok := true
	for clip: StringName in [&"RESET",&"idle",&"move",CLIPS[i]]:
		var anim := clipper.get_animation(clip)
		var loops := clip in [&"idle",&"move"]
		track_ok = track_ok and (anim.loop_mode==Animation.LOOP_LINEAR if loops else anim.loop_mode==Animation.LOOP_NONE)
		for j in anim.get_track_count():
			track_ok = track_ok and str(anim.track_get_path(j)).begins_with("Rig/")
	check(track_ok,"native track routes stay under Rig; only idle/move loop: "+str(unit.name))
	var look := unit.find_child("NoseTip" if i==0 else "RimTip",true,false) as Marker3D
	var original := unit.transform
	_pose(clipper,CLIPS[i],0.)
	var start := unit.to_local(look.global_position)
	var low := 0.0
	var bottom := 1.0
	var high := start.y
	var soles := unit.find_children("Sole","Marker3D",true,false)
	var tail: Array[Node3D] = []
	if i==0:
		for tag in ["Tail01","Tail02","Tail03","Tail04","TailTip"]:
			tail.append(unit.find_child(tag,true,false) as Node3D)
	var tail_clearance := 1.0
	for j in 17:
		_pose(clipper,CLIPS[i],float(j)/16.)
		high = maxf(high,unit.to_local(look.global_position).y)
		for foot: Marker3D in soles: bottom = minf(bottom,unit.to_local(foot.global_position).y)
		for k in tail.size():
			var radius: float = [.087,.077,.064,.048,.018][k]
			tail_clearance = minf(tail_clearance,unit.to_local(tail[k].global_position).y-radius)
	check(unit.to_local(look.global_position).distance_to(start)<.014 and unit.transform.is_equal_approx(original),"signature ends at the original pose and never drives the instance root: "+str(unit.name))
	for j in 16:
		_pose(clipper,&"move",float(j)/16.)
		for foot: Marker3D in soles: low = minf(low,unit.to_local(foot.global_position).y)
		for k in tail.size():
			var radius: float = [.087,.077,.064,.048,.018][k]
			tail_clearance = minf(tail_clearance,unit.to_local(tail[k].global_position).y-radius)
	if not tail.is_empty():
		check(tail_clearance>-.016,"rat tail does not dig into flat ground (min envelope %.3f m)"%tail_clearance)
	check(high-start.y>(.39 if i==0 else .19),"nose rises / shield lifts: "+str(unit.name))
	check(minf(low,bottom)>-.046,"sole samples stay at or above grade (47 mm tolerance): "+str(unit.name))
	var end_seen := []
	var watch := func(id: StringName) -> void: end_seen.append(id)
	clipper.animation_finished.connect(watch)
	_pose(clipper,CLIPS[i],0.)
	clipper.advance(clipper.get_animation(CLIPS[i]).length+.02)
	clipper.animation_finished.disconnect(watch)
	check(end_seen==[CLIPS[i]],"one completion signal; host can return to idle: "+str(unit.name))
	if i==1:
		_pose(clipper,CLIPS[i],.495)
		var jaw := unit.find_child("Mandible",true,false) as Node3D
		check(jaw.rotation_degrees.x>30.,"raised guard keeps its jaw rattle")
	print(unit.name,": signature marker lift %.3f m; lowest sole move/signature %.3f / %.3f m" % [high-start.y,low,bottom])
	_pose(clipper,&"idle",.14)

func _grab() -> Image:
	for i in 2:
		await process_frame
		await RenderingServer.frame_post_draw
	return field.get_texture().get_image()

func _point_camera(aim: Vector3, zoom: int) -> void:
	orbit.zoom_step = zoom
	orbit.size = orbit.sizes[zoom]
	orbit.aim = aim
	orbit._apply()

func _mask(model: Node3D, matte: Material) -> Dictionary:
	var parts := model.find_children("*","MeshInstance3D",true,false)
	var old: Array[Material] = []
	for part: MeshInstance3D in parts:
		old.append(part.material_override)
		part.material_override=matte
	var marked := await _grab()
	for i in parts.size(): parts[i].material_override=old[i]
	var pixels := {}
	var corner := field.size
	var end := Vector2i.ZERO
	for y in marked.get_height():
		for x in marked.get_width():
			var c := marked.get_pixel(x,y)
			if c.r>.94 and c.g<.08 and c.b>.94:
				var p := Vector2i(x,y)
				pixels[p]=true
				corner=corner.min(p)
				end=end.max(p)
	return {"points":pixels,"bounds":Rect2i(corner,end-corner+Vector2i.ONE) if not pixels.is_empty() else Rect2i()}

func _detail(model: Node3D, matte: Material) -> Dictionary:
	var live := await _grab()
	model.hide()
	var empty := await _grab()
	model.show()
	var result := await _mask(model,matte)
	var hit := 0
	for p: Vector2i in result.points:
		var diff := live.get_pixelv(p)-empty.get_pixelv(p)
		if maxf(absf(diff.r),maxf(absf(diff.g),absf(diff.b)))>=.09: hit += 1
	result.contrast = float(hit)/maxi(1,result.points.size())
	return result

func _visible_probe(anchor: Marker3D, matte: Material) -> bool:
	if not anchor:
		return false
	var view := orbit.unproject_position(anchor.global_position)
	var p := Vector2i(view.round())
	if not Rect2i(Vector2i.ONE*5,field.size-Vector2i.ONE*10).has_point(p):
		return false
	var probe := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = .057
	ball.height = .114
	ball.radial_segments = 8
	ball.rings = 4
	probe.mesh = ball
	probe.material_override = matte
	probe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anchor.add_child(probe)
	var img := await _grab()
	anchor.remove_child(probe)
	probe.free()
	for y in range(p.y-3,p.y+4):
		for x in range(p.x-3,p.x+4):
			var pixel := img.get_pixel(x,y)
			if pixel.r>.94 and pixel.g<.08 and pixel.b>.94:
				return true
	return false

func _in_frame(bounds: Rect2i) -> bool:
	return bounds.has_area() and Rect2i(Vector2i.ONE*5,field.size-Vector2i.ONE*10).encloses(bounds)

func _renders() -> void:
	var size := field.size
	var stamped := "--capture" in OS.get_cmdline_user_args()
	var matte := StandardMaterial3D.new()
	matte.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	matte.albedo_color = Color.MAGENTA
	building_sheet = Image.create_empty(size.x*3,size.y*2,false,Image.FORMAT_RGBA8)
	creature_sheet = Image.create_empty(size.x*2,size.y*4,false,Image.FORMAT_RGBA8)
	var building_cameras := [Vector2(20.02,33.68),Vector2(8.95,22.94),Vector2(30.47,73.85)]
	var specimen_cameras := [Vector2(13.45,29.38),Vector2(18.55,59.72)]
	for time_index in HOURS.size():
		_time(HOURS[time_index])
		# Sample the unmodified follow camera at each nearby walkable viewpoint.
		for i in lots.size() + creatures.size():
			var is_lot := i < lots.size()
			var j := i if is_lot else i - lots.size()
			var subject := lots[j] if is_lot else creatures[j]
			_stage(building_cameras[j] if is_lot else specimen_cameras[j])
			orbit.zoom_step = 4
			orbit.size = orbit.sizes[4]
			orbit.align_at_subject()
			var follow := await _detail(subject, matte)
			var min_pixels := 750 if is_lot else 65
			check(follow.points.size() >= min_pixels and follow.contrast >= .46,
				"default follow camera at shoulder: %s (%d px, %.1f%%)" % [subject.name, follow.points.size(), 100. * follow.contrast])
		for i in lots.size():
			var lot:=lots[i]
			_stage(building_cameras[i])
			var point := lot.global_position+Vector3.UP*(2.76 if i==2 else 1.92)+lot.global_basis.z*.38
			_point_camera(point,4)
			var sample := await _detail(lot,matte)
			check(_in_frame(sample.bounds) and sample.points.size()>920,"whole building readable at default 13.4 m: "+str(lot.name))
			check(sample.contrast>=.46,"building against actual backdrop: "+str(lot.name))
			print(lot.name," hour ",HOURS[time_index],": ",sample.bounds.size," / ",sample.points.size()," px; separated %.1f%%"%(sample.contrast*100))
			if time_index==0:
				var details: Array = [["Sign","Anvil","Hearth"],["PorchEave"],["Oriel"]][i]
				for peg: String in details:
					var anchor: Marker3D = lot.marker(peg)
					var clear_feature := await _visible_probe(anchor,matte)
					check(clear_feature,"feature clear at default F5 zoom: "+str(lot.name)+"/"+peg)
					if not clear_feature and anchor:
						var shell: MeshInstance3D = lot.mesh_view
						var p := shell.to_local(anchor.global_position)
						var eye := shell.to_local(anchor.global_position+orbit.global_basis.z*12.)
						var faces := shell.mesh.get_faces()
						for f in range(0,faces.size(),3):
							var hit: Variant = Geometry3D.segment_intersects_triangle(p,eye,faces[f],faces[f+1],faces[f+2])
							if hit != null: print("local feature occluder ", hit)
			if stamped:
				_point_camera(point,2)
				var cropped := await _mask(lot,matte)
				check(_in_frame(cropped.bounds),"near 8.95 m building frame not clipped: "+str(lot.name))
				_blit(building_sheet,await _grab(),Vector2i(i,time_index)*size)
		for i in 2:
			var unit := creatures[i]
			var clips := [&"idle",&"move",CLIPS[i]]
			var phases := [.14,.39,.56 if i==0 else .495]
			var player := unit.get_node("Model/AnimationPlayer") as AnimationPlayer
			var point := unit.global_position+Vector3.UP*(.79 if i==0 else 1.05)
			_stage(specimen_cameras[i])
			var still := {}
			var movement := .0
			for index in clips.size():
				_point_camera(point,4)
				_pose(player,clips[index],phases[index])
				var sample := await _detail(unit,matte)
				var label := "%s %s %.2f" % [unit.name,clips[index],HOURS[time_index]]
				print(label,": ",sample.bounds.size," / ",sample.points.size()," px; separated %.1f%%"%(sample.contrast*100))
				check(sample.points.size()>=60 and sample.bounds.size.x>=9 and sample.bounds.size.y>=9 and _in_frame(sample.bounds),"readable, unclipped at the default F5 zoom: "+label)
				check(sample.contrast>=.54,"separated from the actual backdrop: "+label)
				if index==0: still=sample.points
				if index==2:
					var overlap := 0
					for pixel in sample.points: overlap += int(still.has(pixel))
					movement = 1.-float(overlap)/maxi(1,still.size()+sample.points.size()-overlap)
				if stamped and index!=1:
					_point_camera(point,0)
					var near := await _mask(unit,matte)
					check(_in_frame(near.bounds),"near 6.2 m creature frame not clipped: "+label)
					_blit(creature_sheet,await _grab(),Vector2i(i,time_index*2+int(index==2))*size)
			check(movement>=.20,"signature replaces at least 20%% of idle/pose union: %s %.1f%%" % [unit.name,movement*100.])

func _blit(sheet: Image, frame: Image, at: Vector2i) -> void:
	check(frame.get_size()==field.size,"capture pixel dimensions match the native F5 viewport")
	frame.convert(Image.FORMAT_RGBA8)
	sheet.blit_rect(frame,Rect2i(Vector2i.ZERO,field.size),at)

func _save_sheet(sheet: Image, category: String) -> void:
	var path := REVIEW + "%s-%d.png" % [category,field.size.x]
	check(not FileAccess.file_exists(path) and sheet.save_png(path)==OK,"save new native contact sheet: "+path)
