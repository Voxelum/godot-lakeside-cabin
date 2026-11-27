extends "res://tests/interior_door_checks.gd"
## Real F5, both native buffers; no position overrides or direct transition calls.
## --capture=<new directory> captures the active gameplay view, not a model turntable.
const Survey := preload("res://world/outskirts/outskirts_profile.gd")
const VISITS := [["place.general_store", 3], ["place.tavern", 4], ["place.inn", 6], ["place.guild", 8]]
var checks := 0
var token := Crypto.new().generate_random_bytes(12).hex_encode()
var slot := "user://market-court-" + token + ".slot"
var config := "user://market-court-" + token + ".cfg"
var final_feet := Vector3.ZERO

func check(ok: bool, label: String) -> void:
	checks += 1
	super.check(ok, label)

func mount_main() -> void:
	main = MainScene.instantiate()
	session = main.get_node("Session")
	session.slot_path = slot
	main.get_node("BindingPanel").settings_path = config
	root.add_child(main)
	await ticks(7)

func field_step(to: Vector2, label: String) -> bool:
	var before: CharacterBody3D = main.field_actor
	var ok := await walk(Survey.point(to), 225, false)
	# At the ramp/shoulder edge the capsule settles over two physics frames.
	await ticks(3)
	check(ok and not main.indoors and main.active_actor()==before and before.is_on_floor(), label + " reached and supported at " + str(before.global_position))
	return ok and not main.indoors

func room_step(to: Vector3, id: String) -> void:
	await _check_walk(to,id)
	await ticks(2)
	var guest: CharacterBody3D = main.room_actor
	check(guest.is_on_floor() and absf(guest.global_position.y-to.y)<.045, "%s true supported storey at %s (wanted %s)" % [id, guest.global_position, to])

func room_steps(route: Array[Vector3], id: String) -> void:
	for to in route: await room_step(to,id)

func gap_at(sample: Vector3, axis: Vector3, expected: float, id: String) -> void:
	var walker: CharacterBody3D = main.room_actor
	var space := walker.get_world_3d().direct_space_state
	var hits: Array[Vector3] = []
	for s: float in [-1,1]:
		var ray := PhysicsRayQueryParameters3D.create(sample, sample+s*axis*3.0)
		ray.exclude = [walker.get_rid()]
		var hit := space.intersect_ray(ray)
		if not hit.is_empty(): hits.append(hit.position)
	var gap := hits[0].distance_to(hits[1]) if hits.size() == 2 else -1.0
	check(gap >= expected, "%s fixed clearance %.3f m, expected ≥ %.3f m" % [id, gap, expected])
	print(id, " cross-section ", snappedf(gap,.001), " m")

func check_partition_stop(goal: Vector3, d: String) -> void:
	var guest: CharacterBody3D = main.room_actor
	var touched := false
	for i in 37:
		steer((goal-guest.global_position).slide(Vector3.UP).normalized())
		await physics_frame
		for k in guest.get_slide_collision_count():
			var hit := guest.get_slide_collision(k)
			var piece := hit.get_collider_shape() as CollisionShape3D
			touched = touched or (piece != null and piece.name.begins_with("Partition_"+d))
	steer(Vector3.ZERO)
	check(touched and guest.global_position.distance_to(goal) > .40, d + " the real Walker cannot shortcut through the cut wall")

func portal_path(structure: Node3D, name: String, axis: Vector3, reach: float) -> Array[Vector3]:
	var center: Vector3 = structure.get_node("Portal_"+name).global_position
	gap_at(center+Vector3.UP*.62,axis.cross(Vector3.UP),1.05,name)
	return [center-axis*.86, center+axis*reach]

func save_here(id: String) -> Vector3:
	var saved: Vector3 = main.room_actor.global_position
	await hotkey(KEY_F5)
	var snapshot: Variant = bytes_to_var(FileAccess.get_file_as_bytes(slot)) if FileAccess.file_exists(slot) else null
	var structure: Node3D = main.building_structure()
	check(snapshot is Dictionary and snapshot.version == State.BUILDING_VERSION and snapshot.location_id == id and snapshot.building_revision == structure.get_meta("building_revision") and Vector3(snapshot.position).distance_to(structure.to_local(saved)) < .018, id + " F5 stored versioned, building-local feet")
	return saved

func field_capture(label: String) -> void:
	await ticks(14)
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = main.field.get_texture().get_image()
	check(not image.is_empty() and image.get_size() == expected_size and main.get_node("Screen").texture == main.field.get_texture(), label + " active native outdoor frame")
	if not capture_dir.is_empty() and not image.is_empty():
		var path := capture_dir.path_join(label+".png")
		check(not FileAccess.file_exists(path) and image.save_png(path)==OK, label + " clean outdoor capture")

func verify_guild_portico(lot: Node3D) -> void:
	var datum := lot.get_node("GroundDatum") as Node3D
	var body := datum.get_node("StructureCollision") as StaticBody3D
	var traveler: CharacterBody3D = main.field_actor
	var space := traveler.get_world_3d().direct_space_state
	var posts := body.find_children("GuildColumnFoot*", "CollisionShape3D", false, false)
	check(posts.size() == 2 and body.has_node("GuildCanopy") and body.has_node("GuildEntablature") and body.has_node("GuildSteps"), "guild has two masonry piers, solid portico and broad stair flight")
	var step: CollisionShape3D = body.get_node("GuildSteps")
	var stair_width: float = Array(step.shape.points).reduce(func(maximum: float, point: Vector3) -> float: return maxf(maximum,absf(point.x)),0.)*2.
	check(is_equal_approx(stair_width,4.38) and lot.door_width >= 1.80, "public podium is 4.38 m across and the double portal exceeds 1.8 m")
	for post: CollisionShape3D in posts:
		var start := post.global_position+datum.global_basis.z*.46
		var ray := PhysicsRayQueryParameters3D.create(start,post.global_position)
		ray.exclude = [traveler.get_rid()]
		var hit := space.intersect_ray(ray)
		check(hit.get("collider") == body and body.shape_owner_get_owner(body.shape_find_owner(hit.shape)) == post, "guild masonry plinth is present in physics")
	var sign_position: Vector3 = lot.marker("Sign").global_position
	var camera: Camera3D = main.field.get_camera_3d()
	check(Rect2(Vector2.ZERO,Vector2(expected_size)).has_point(camera.unproject_position(sign_position)), "guild crossed-swords shield is in the outdoor gameplay framing")

func lot_outline(lot: Node3D) -> PackedVector2Array:
	var mesh: MeshInstance3D = lot.get_node("GroundDatum/PaintedShell")
	var bounds := mesh.get_aabb()
	var corners := PackedVector2Array()
	for pt: Vector2 in [Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.end.x,bounds.position.z),Vector2(bounds.end.x,bounds.end.z),Vector2(bounds.position.x,bounds.end.z)]:
		corners.append(Survey.xz(mesh.to_global(Vector3(pt.x,0,pt.y))))
	corners.append(corners[0])
	return corners

func edge_gap(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var gap := INF
	for i in a.size()-1:
		for j in b.size()-1:
			if Geometry2D.segment_intersects_segment(a[i],a[i+1],b[j],b[j+1]) != null: return 0.
			for pt: Vector2 in [a[i],a[i+1]]:
				gap = minf(gap,pt.distance_to(Geometry2D.get_closest_point_to_segment(pt,b[j],b[j+1])))
			for pt: Vector2 in [b[j],b[j+1]]:
				gap = minf(gap,pt.distance_to(Geometry2D.get_closest_point_to_segment(pt,a[i],a[i+1])))
	return gap

func survey_guild(lot: Node3D) -> void:
	var boundary := lot_outline(lot)
	for neighbor_name: String in ["Tavern","Inn"]:
		var neighbor := lot.get_parent().get_node(neighbor_name) as Node3D
		var separation := edge_gap(boundary,lot_outline(neighbor))
		check(separation >= 1.25, "guild projected mesh footprint retains ≥1.25 m to " + neighbor_name)
		print("guild projected gap to ",neighbor_name,": ",snappedf(separation,.001)," m")
	var fence := edge_gap(boundary,PackedVector2Array(Survey.MARKET_VERGE))
	check(fence >= .95, "guild projected mesh footprint is clear of the market fence")
	print("guild projected gap to fence line: ",snappedf(fence,.001)," m")

func check_guild_prior_feet(lot: Node3D, bag: Dictionary) -> void:
	var saved: Variant = bytes_to_var(FileAccess.get_file_as_bytes(slot)) if FileAccess.file_exists(slot) else null
	if not saved is Dictionary:
		check(false,"guild prior-foot fixtures need the isolated upstairs save")
		return
	# Last shipped guild revision. A valid upstairs coordinate then must not
	# silently reuse the new staircase/deck reference frame.
	for version: int in [1,2,State.BUILDING_VERSION]:
		var interior: Dictionary = saved.duplicate(true)
		interior.position = Vector3(.80,2.50,-1.69)
		interior.version = version
		if version < 3:
			interior.erase("building_revision")
			if version == 1: interior.erase("player_stats")
		else: interior.building_revision = "c685cf40310e924113a96370b351b71fed34fe0143d374064b27d14efa5bd1b3"
		_write_fixture(interior)
		await hotkey(KEY_F9)
		await ticks(5)
		check(main.indoors and main.place_id()=="place.guild" and main.room_actor.global_position.distance_to(main.room_entry.global_position)<.022 and main.room_actor.is_on_floor() and session.state.inventory==bag and session.state.remaining("market.fixture",2)==0,"v%d guild feet fall back safely to the new ground entry, bag and source preserved" % version)
	var outdoor: Dictionary = saved.duplicate(true)
	outdoor.version = State.VERSION
	outdoor.erase("building_revision")
	outdoor.location_id = Catalog.FIELD
	var post := lot.get_node("GroundDatum/StructureCollision/GuildColumnFoot") as CollisionShape3D
	outdoor.position = Survey.point(Survey.xz(post.global_position))
	_write_fixture(outdoor)
	await hotkey(KEY_F9)
	await ticks(5)
	check(not main.indoors and main.field_actor.global_position.distance_to(Catalog.outdoor_return(lot).global_position)<.16 and main.field_actor.is_on_floor() and session.state.inventory==bag,"pre-refit outdoor feet at new column return safely to its market path")
	var podium: Marker3D = lot.marker("Landing")
	var exposed := podium.to_global(Vector3(1.11,0,0))
	outdoor.position = Survey.point(Survey.xz(exposed))
	_write_fixture(outdoor)
	await hotkey(KEY_F9)
	await ticks(5)
	check(main.field_actor.global_position.distance_to(Catalog.outdoor_return(lot).global_position)<.16 and main.field_actor.is_on_floor(),"old feet below the new platform use its approach")
	outdoor.position = exposed
	_write_fixture(outdoor)
	await hotkey(KEY_F9)
	await ticks(5)
	check(main.field_actor.global_position.distance_to(exposed)<.04 and main.field_actor.is_on_floor(),"current unobstructed feet on the new platform keep exact position")

func _write_fixture(data: Dictionary) -> void:
	var file := FileAccess.open(slot,FileAccess.WRITE)
	if file == null:
		check(false,"write isolated guild fixture")
		return
	file.store_buffer(var_to_bytes(data))
	file.close()

func _leave(steps: Array[Vector3], id: String, door: Marker3D, approach: Marker3D) -> bool:
	await room_steps(steps,id+" return")
	await room_step(main.room_entry.global_position,id+" entry return")
	if not await cross(main.room_door.to_global(Vector3(0,0,.49)),id+" exit"): return false
	check(not main.indoors and main.place_id() == Catalog.FIELD and main.field_actor.global_position.distance_to(approach.global_position)<.16 and main.field_actor.is_on_floor(),id+" returned to its own outside approach")
	check(main.field_actor.artwork.get_node("Facing").global_basis.z.dot(door.global_basis.z)>.998,id+" faced away from its own door outdoors")
	return not main.indoors

func visit(id: String, lot: Node3D, bag: Dictionary) -> bool:
	var door := Catalog.outdoor_door(lot)
	var approach := Catalog.outdoor_return(lot)
	var guest: CharacterBody3D = main.room_actor
	await check_hinge_approach(lot,id)
	if not await cross(door.to_global(Vector3(0,0,-.38)),id+" enter"): return false
	check(main.indoors and main.place_id()==id and session.state.location_id==id and main.room_actor==guest and guest.is_on_floor(),id+" arrived on its floor with the same Guest")
	if not main.indoors or main.place_id()!=id: return false
	check(main.room.size==expected_size and main.get_node("Screen").texture==main.room.get_texture(),id+" active native RoomPixels")
	check(guest.global_position.distance_to(main.room_entry.global_position)<.08,id+" landed at the safe generated entry")
	check_direction(id,door)
	check_framing(id)
	var fname := id.trim_prefix("place.")
	var structure: Node3D = main.building_structure()
	var furniture: Node3D = main.get_node("RoomPixels/Interior/Furnishing")
	var back: Array[Vector3] = []
	var up := structure.has_node("StairHead")
	if up:
		var guild := id == "place.guild"
		var desk_goal := Vector3(1.94,0,-2.23) if guild else Vector3(-1.72,0,.36)
		var public := Vector3(-2.52,0,1.56) if guild else Vector3(-1.30,0,1.32)
		if guild:
			await room_steps([Vector3(0,0,1.60),public,Vector3(-2.53,0,-.31),Vector3(-2.61,0,-1.80),Vector3(-2.54,0,-.24),Vector3(-.15,0,-.12)],id+" waiting, commissions and front counter")
			await capture(fname+"-ground")
			var front_saved := await save_here(id)
			await room_step(Vector3(-.15,0,.68),id+" back away from the public counter")
			await hotkey(KEY_F9)
			await ticks(5)
			check(guest.global_position.distance_to(front_saved)<.022 and guest.is_on_floor() and session.state.inventory==bag,id+" F9 restored exact public counter feet")
			await verify_blocker(id,furniture.get_node("ReceptionDesk"))
			await room_steps([Vector3(-.15,0,-.10),Vector3(1.94,0,-.10),desk_goal,Vector3(-.81,0,-2.23),Vector3(-2.31,0,-2.23),Vector3(-2.31,0,-.10),Vector3(-.15,0,-.10),Vector3(1.94,0,-.10),desk_goal],id+" behind the registry")
			gap_at(Vector3(1.94,.58,-1.35),Vector3.RIGHT,2.50,"guild east ground cross-section")
			gap_at(Vector3(-1.60,.58,-2.23),Vector3.BACK,.95,"guild left archive approach")
			gap_at(Vector3(1.19,.58,-2.23),Vector3.BACK,.95,"guild right archive approach")
			var ground_saved := await save_here(id)
			await room_step(Vector3(1.94,0,-.10),id+" move away from ground save")
			await hotkey(KEY_F9)
			await ticks(5)
			check(guest.global_position.distance_to(ground_saved)<.022 and guest.is_on_floor() and session.state.inventory==bag and not structure.get_node("LoftCutaway").visible,id+" F9 restored exact reception feet below the loft")
			var valid: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(slot))
			var blocked := valid.duplicate(true)
			# Clear behind the previous counter, but inside the rebuilt worktop footprint.
			blocked.position = Vector3(.9,0,-1.72)
			_write_fixture(blocked)
			await hotkey(KEY_F9)
			await ticks(5)
			check(guest.global_position.distance_to(main.room_entry.global_position)<.022 and guest.is_on_floor() and session.state.inventory==bag,id+" same-revision obstructed feet fall back to the safe entry")
			_write_fixture(valid)
			await hotkey(KEY_F9)
			await ticks(5)
		else:
			await room_steps([public,desk_goal],id+" reception")
		if not guild: await capture(fname+"-ground")
		await verify_furnishings(id, furniture, ["ReceptionDesk", "VisitorBench", "DoorBench", "DispatchShelf"] if guild else ["CheckInDesk", "WaitingTable"], 1.86 if guild else 1.66)
		if guild: await verify_furnishings(id, furniture, ["ReturnsShelf"], 1.86)
		var board: Node3D = furniture.get_node("CommissionBoard" if guild else "LodgingBoard")
		check(Rect2(Vector2.ZERO,Vector2(expected_size)).has_point(main.room.get_camera_3d().unproject_position(board.global_position)),id+" world notice board in the cutaway")
		var foot: Vector3 = structure.get_node("StairFoot").global_position
		var head: Vector3 = structure.get_node("StairHead").global_position
		var lower := Vector3(foot.x,0,foot.z+.52)
		var turn := Vector3(head.x,head.y,head.z-(.65 if guild else .78))
		var side := Vector3(1.94 if guild else 1.19,0,lower.z)
		await room_steps([Vector3(side.x,0,desk_goal.z),side,lower,turn],id+" ascent")
		await ticks(25)
		check(structure.get_node("LoftCutaway").visible and furniture.get_node("Loft").visible,id+" displayed upstairs only after gaining height")
		if guild:
			var chair_lane := Vector3(1.09,head.y,.53)
			var archive_front := Vector3(1.30,head.y,-1.78)
			var upper_corner := Vector3(1.80,head.y,turn.z)
			await room_steps([upper_corner,chair_lane,archive_front,Vector3(-2.87,head.y,-1.78)],id+" council and archive")
			back = [archive_front,upper_corner,turn,lower,side,Vector3(.60,0,2.35)]
			await verify_furnishings(id,furniture.get_node("Loft"),["CouncilTable","ArchiveRack"],1.66)
		else:
			var north := portal_path(structure,"north_guest",Vector3.LEFT,1.55)
			var south := portal_path(structure,"south_guest",Vector3.LEFT,1.66)
			gap_at(Vector3(1.19,head.y+.49,.28),Vector3.RIGHT,2.05,id+" upper hall")
			await room_steps(north, id+" reach the north bed")
			await room_steps([north[0],south[0],south[1]], id+" reach the separate south bed")
			await check_partition_stop(Vector3(south[1].x,head.y,-.92),"guest_divider")
			await room_step(south[1],id+" south guest save zone")
			back = [south[0],north[0],turn,lower,side,Vector3(.06,0,2.36)]
			await verify_furnishings(id,furniture.get_node("Loft"),["NorthBed","SouthBed"],1.66)
		await capture(fname+"-upper")
	elif id == "place.tavern":
		var foyer := Vector3(.79,0,2.22)
		await room_steps([foyer,Vector3(.80,0,.38),Vector3(-.35,0,-.04)],id+" taproom")
		await check_partition_stop(Vector3(-.35,0,-1.43),"taproom_divider")
		await capture(fname+"-taproom")
		await verify_furnishings(id,furniture,["CommonTable","ServiceCounter"],1.66)
		var rear := portal_path(structure,"cask_store",Vector3.FORWARD,1.07)
		await room_steps([Vector3(-.34,0,.12),rear[0],rear[1],Vector3(-1.66,0,-1.58)],id+" through the rear doorway to the casks")
		check(guest.get_world_3d() == structure.get_world_3d() and not main.crossing, id+" rear room has no extra scene change")
		await capture(fname+"-rear")
		back = [Vector3(.88,0,-1.57),rear[0],foyer]
	else:
		var queue := Vector3(.97,0,.84)
		var aisle := Vector3(.97,0,-.78)
		await room_steps([queue,Vector3(-.34,0,.84),queue,aisle,Vector3(-.92,0,-.79)],id+" display, queue and stock access")
		gap_at(Vector3(.97,.48,.30),Vector3.RIGHT,1.46,id+" side shopping aisle")
		gap_at(Vector3(-.87,.48,-.79),Vector3.BACK,.91,id+" behind the counter")
		await verify_furnishings(id,furniture,["WeighCounter","DryGoods","ToolsDisplay","ProduceDisplay"],2.20)
		await capture(fname+"-ground")
		back = [aisle,queue]
	var saved := await save_here(id)
	if not await _leave(back,id,door,approach): return false
	await hotkey(KEY_F9)
	await ticks(5)
	check(main.indoors and main.place_id()==id and guest.global_position.distance_to(saved)<.022 and guest.is_on_floor() and session.state.inventory==bag and session.state.remaining("market.fixture",2)==0,id+" F9 restored exact local feet, physical support and retained bag")
	if not main.indoors or main.place_id()!=id: return false
	if up: check(main.building_structure().get_node("LoftCutaway").visible,id+" F9 restores the upper view")
	final_feet = saved
	return await _leave(back,id,door,approach)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Requires a rendered Godot window")
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	expected_size = Vector2i(320,180) if "--320" in args else Vector2i(480,270)
	for arg in args:
		if arg.begins_with("--capture="): capture_dir = ProjectSettings.globalize_path(arg.trim_prefix("--capture="))
	if not capture_dir.is_empty() and (DirAccess.dir_exists_absolute(capture_dir) or DirAccess.make_dir_recursive_absolute(capture_dir)!=OK):
		printerr("Capture directory must be new: ",capture_dir)
		quit(2)
		return
	await mount_main()
	var field: Node3D = main.get_node("Pixels/Clearing")
	check(Survey.xz(main.field_actor.global_position).distance_to(Survey.ROUTE[0])<.01 and main.field_actor.is_on_floor(),"stock F5 spawn, no fixture teleport")
	session.state.take_stack("market.fixture","item.sample",2)
	var bag: Dictionary = session.state.inventory.duplicate()
	for i in range(1,25):
		if not await field_step(Survey.ROUTE[i],"old road station %d"%i):
			_finish_court(); return
	var station := -1
	var guild_only := "--guild-only" in args
	var visits := [VISITS.back()] if guild_only else VISITS
	for trip: Array in visits:
		var id: String = trip[0]
		while station < int(trip[1]):
			station += 1
			if not await field_step(Survey.MARKET_ROUTE[station],"market station %d"%station):
				_finish_court(); return
			if not guild_only and station==2: await field_capture("market-gate")
			if not guild_only and station==5: await field_capture("market-upper-lane")
		var lot := Catalog.outdoor_lot(field,id)
		var approach := Catalog.outdoor_return(lot)
		var link := Survey.nearest_on(Survey.xz(approach.global_position),Survey.MARKET_ROUTE)
		if not await field_step(link,id+" spur"):
			_finish_court(); return
		if id == "place.guild":
			# The default camera shows the entire roof from the lane, not in
			# the close-up at the stairs. No camera or character teleport.
			await field_capture("guild-outside")
			verify_guild_portico(lot)
			survey_guild(lot)
		if not await field_step(Survey.xz(approach.global_position),id+" stoop path"):
			_finish_court(); return
		if id != "place.guild": await field_capture(id.trim_prefix("place.")+"-outside")
		if not await visit(id,lot,bag) or not await field_step(link,id+" back to lane"):
			_finish_court(); return
	for i in range(Survey.MARKET_ROUTE.size()-2,-1,-1):
		if not await field_step(Survey.MARKET_ROUTE[i],"return to old town %d"%i):
			_finish_court(); return
	await field_step(Survey.ROUTE[24],"rejoin the untouched stone street")
	main.queue_free()
	await process_frame
	await mount_main()
	check(main.indoors and main.place_id()=="place.guild" and main.room_actor.is_on_floor() and main.room_actor.global_position.distance_to(final_feet)<.022 and main.building_structure().get_node("LoftCutaway").visible and session.state.inventory==bag,"fresh F5 Main read the last test slot upstairs with its bag")
	await check_guild_prior_feet(Catalog.outdoor_lot(main.get_node("Pixels/Clearing"),"place.guild"),bag)
	_finish_court()

func _finish_court() -> void:
	for path in [slot,config]:
		if FileAccess.file_exists(path): check(DirAccess.remove_absolute(path)==OK,"remove only own isolated fixture")
	print("MARKET COURT ",expected_size,": ", checks-failures,"/",checks," passed")
	quit(int(failures!=0))
