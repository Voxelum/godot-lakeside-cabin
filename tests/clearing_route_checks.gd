extends SceneTree
## F5's real Main, with a scratch slot. Only camera-relative Walker input drives
## the itinerary, including return travel, landings, and the two grade sides.
const MAIN := preload("res://Main.tscn")
const Survey := preload("res://world/outskirts/outskirts_profile.gd")
const Catalog := preload("res://world/interiors/room_catalog.gd")
const ACTIONS := [&"walk_left", &"walk_right", &"walk_up", &"walk_down"]
var main
var actor: CharacterBody3D
var site: Node3D
var state
var slot: String
var failures := 0
var checks := 0
var moving_ticks := 0
var unsupported_ticks := 0
var unsupported_at_joins := 0
var max_stride := 0.0
var uninterrupted := true
var contacts := {}

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func drive(dir: Vector2, fast := false) -> void:
	var right := main.orbit.global_basis.x.slide(Vector3.UP).normalized() as Vector3
	var heading := Vector3(dir.x,0.,dir.y)
	var v := Vector2(heading.dot(right),heading.dot(right.cross(Vector3.UP)))
	var amounts := [-v.x,v.x,-v.y,v.y]
	for i in ACTIONS.size():
		if amounts[i] > .001:
			Input.action_press(ACTIONS[i], amounts[i])
		else:
			Input.action_release(ACTIONS[i])
	if fast: Input.action_press(&"sprint")
	else: Input.action_release(&"sprint")

func ticks(n: int) -> void:
	for i in n: await physics_frame

func sample(from: Vector3) -> void:
	moving_ticks += 1
	if not actor.is_on_floor():
		unsupported_ticks += 1
		var p := Survey.xz(actor.global_position)
		if absf(p.y-Survey.JOIN_Z)<.48 or absf(p.y-16.5)<.48 or absf(p.y-10.75)<.48:
			unsupported_at_joins += 1
		print("short floor snap at ",actor.global_position)
	max_stride = maxf(max_stride,from.distance_to(actor.global_position))
	uninterrupted = uninterrupted and not main.indoors and not main.crossing and not actor.locked and main.active_actor()==actor

func walk(dest: Vector2, label: String, fast := true) -> bool:
	var initial := Survey.xz(actor.global_position)
	var left := dest-initial
	var limit := int(ceil(left.length()*60.0/(actor.sprint_speed if fast else actor.walk_speed)))+125
	for i in limit:
		var from := actor.global_position
		var delta := dest-Survey.xz(from)
		if delta.length() <= .086:
			drive(Vector2.ZERO)
			return true
		drive(delta.normalized(),fast)
		await physics_frame
		sample(from)
	drive(Vector2.ZERO)
	printerr("stuck @ ",actor.global_position," toward ",dest," (",label,") from ",initial)
	return false

func wall_probe(dir: Vector2, n: int, expected: String) -> bool:
	contacts.clear()
	var travel := Survey.xz(actor.global_position)
	for i in n:
		var from := actor.global_position
		drive(dir,true)
		await physics_frame
		sample(from)
		for k in actor.get_slide_collision_count():
			var hit := actor.get_slide_collision(k)
			var c := hit.get_collider() as Node
			if c and absf(hit.get_normal().y) < .24:
				contacts[str(c.get_path())] = true
	drive(Vector2.ZERO)
	await ticks(2)
	for path in contacts:
		if expected in path:
			print("blocked by ",expected," at ",actor.global_position," after ",Survey.xz(actor.global_position).distance_to(travel)," m")
			return true
	printerr("expected wall ",expected,"; contacts: ",contacts.keys())
	return false

func key(code: Key) -> void:
	for press: bool in [true,false]:
		var e := InputEventKey.new()
		e.pressed = press; e.keycode = code; e.physical_keycode = code
		Input.parse_input_event(e)
		Input.flush_buffered_events()

func take_sample() -> void:
	key(KEY_F)

func ground(p: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,4.,p.y),Vector3(p.x,-2.,p.y))
	query.exclude = [actor.get_rid()]
	return actor.get_world_3d().direct_space_state.intersect_ray(query)

func _run() -> void:
	var token := Crypto.new().generate_random_bytes(16).hex_encode()
	slot = "user://clearing_route_%s.slot" % token
	main = MAIN.instantiate()
	main.get_node("Session").slot_path = slot
	main.get_node("BindingPanel").settings_path = "user://clearing_route_%s.cfg" % token
	root.add_child(main)
	actor = main.field_actor
	state = main.session.state
	site = main.field.get_node("Clearing/Outskirts")
	await ticks(8)
	check(Survey.xz(actor.global_position).distance_to(Survey.ROUTE[0])<.001 and actor.is_on_floor(),"untouched, dry original spawn")
	take_sample()
	key(KEY_F6)
	check(state.inventory.get("item.sample", 0)==1 and state.remaining("bank.sample_a",1)+state.remaining("bank.sample_b",1)==1,"picked exactly one original ground stack alongside the starting equipment")
	check(state.simulated_until==1 and state.stock("region.bank")==11 and state.stock("region.rise")==1,"original abstract interval still works")
	var bag: Dictionary = state.inventory.duplicate()
	var left := state.remaining("bank.sample_a",1) as int
	var right := state.remaining("bank.sample_b",1) as int
	var view: World3D = actor.get_world_3d()
	var travelled := await _itinerary()
	check(travelled,"completed the itinerary and returned through the old lane")
	check(uninterrupted and view==actor.get_world_3d() and state.location_id=="place.clearing","same outdoor actor, viewport world and location; no iris or position jump")
	check(unsupported_at_joins==0 and unsupported_ticks<=8 and max_stride<.13,"continuous footing at joins (joins %d, total %d/%d short snaps, max step %.4f m)" % [unsupported_at_joins,unsupported_ticks,moving_ticks,max_stride])
	check(state.inventory==bag and state.remaining("bank.sample_a",1)==left and state.remaining("bank.sample_b",1)==right \
		and state.simulated_until==1 and state.stock("region.bank")==11 and state.stock("region.rise")==1,"inventory, depleted source and region state survived travel/load")
	if FileAccess.file_exists(slot):
		check(DirAccess.remove_absolute(slot)==OK,"remove only own scratch slot")
	print("clearing_route_checks: %d/%d passed; airborne %d/%d; max step %.4f m" % [checks-failures,checks,unsupported_ticks,moving_ticks,max_stride])
	quit(int(failures!=0))

func _itinerary() -> bool:
	var run_length := 0.0
	for i in range(1, Survey.ROUTE.size()):
		if not await walk(Survey.ROUTE[i],"out station %d"%i): return false
		run_length += Survey.ROUTE[i-1].distance_to(Survey.ROUTE[i])
		if i in [14,17,20]:
			var j := [14,17,20].find(i)
			check(await walk(Survey.PULLOUTS[j],"viewing shoulder %d"%j,false),"walk off the trail to exhibit %d" %j)
			var clear_shoulder := true
			for foe in main.session.farm.fighters:
				if Survey.xz(foe.actor.global_position).distance_to(Survey.PULLOUTS[j]) < 3.0: clear_shoulder = false
			check(clear_shoulder and main.session.farm.opponent == null,"former exhibit %d is now peaceful; combat belongs in the farm"%j)
			if not await walk(Survey.ROUTE[i],"rejoin after exhibit %d"%j,false): return false
	print("Survey from old spawn to stone street: %.2f m" % run_length)
	var a := ground(Vector2(15.82,39.86)); var b := ground(Vector2(15.68,40.16))
	check(not a.is_empty() and not b.is_empty() and a.collider.name==&"Land" and b.collider.name==&"SouthVerge" and absf(a.position.y-b.position.y)<.022,"old and new grade exactly meet at z=40")
	check(not FileAccess.file_exists(slot),"continuous travel did not auto-save")
	var at := actor.global_position
	key(KEY_F5)
	check(FileAccess.file_exists(slot),"explicit F5 saves the new outdoor position")
	check(await wall_probe(Vector2(1,-.28).normalized(),115,"/VisiblePropsAndRails"),"far rail prevents exiting the town")
	key(KEY_F9)
	await ticks(5)
	check(actor.global_position.distance_to(at)<.03,"F9 restores the saved street coordinates in Clearing")
	var street: Vector2 = Survey.ROUTE[-1]
	for i in range(Survey.ROUTE.size()-2,22,-1):
		if not await walk(Survey.ROUTE[i],"town return station %d"%i): return false
		if i!=25: continue
		for p in Survey.ALLEY:
			if not await walk(p,"town alley",false): return false
		for j in range(Survey.ALLEY.size()-2,-1,-1):
			if not await walk(Survey.ALLEY[j],"return from alley",false): return false
		if not await walk(Survey.ROUTE[i],"return from alley onto main street",false): return false
		check(true,"alley through the two narrow houses and back out")
	street = Survey.ROUTE[23]
	for lot_name in ["CopperLoft", "SillHouse", "Bakery"]:
		if not await doorfront(site.get_node("Lots/"+lot_name)): return false
	if not await walk(street,"town mouth after the lots"): return false
	for i in range(22,-1,-1):
		if not await walk(Survey.ROUTE[i],"return station %d"%i): return false
		if i==15:
			if not await doorfront(site.get_node("Lots/HayBarn")): return false
			if not await walk(Survey.ROUTE[i],"barn shoulder to lane"): return false
		if i==12:
			if not await doorfront(site.get_node("Lots/Blacksmith")): return false
			if not await walk(Survey.ROUTE[i],"smithy back to lane"): return false
		if i!=10: continue
		for lot_name in ["LimeHouse", "OrchardHouse"]:
			if not await doorfront(site.get_node("Lots/"+lot_name)): return false
		if not await walk(Survey.ROUTE[i],"well to old lane"): return false
	return true

func doorfront(lot: Node3D) -> bool:
	var approach: Marker3D = lot.marker("Approach")
	var landing: Marker3D = lot.marker("Landing")
	var door: Marker3D = lot.marker("DoorAnchor")
	if not approach or not landing or not door:
		check(false,"missing approach on "+lot.name)
		return false
	var trail := Survey.nearest_track(Survey.xz(approach.global_position))
	# Stay outside the new directed door plane; interior_door_checks covers
	# walking onward across it. This itinerary must remain entirely outdoors.
	var stoop_front := Survey.xz(door.to_global(Vector3(0, 0, .52)))
	if not await walk(trail,lot.name+" road link") \
		or not await walk(Survey.xz(approach.global_position),lot.name+" approach",false) \
		or not await walk(stoop_front,lot.name+" stoop front",false):
		return false
	await ticks(4)
	# A short ray below the overhead eave tests the landing proper.
	var ray := PhysicsRayQueryParameters3D.create(landing.global_position + Vector3.UP * .18, landing.global_position - Vector3.UP * .16)
	ray.exclude = [actor.get_rid()]
	var support := actor.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not support.is_empty() and absf(support.position.y-landing.global_position.y)<.035,"level support on %s stoop"%lot.name)
	# The leaf now opens on approach. At the landing the portal centre must
	# be physically clear without having triggered the directed threshold.
	await ticks(16)
	var hinge := Catalog.outdoor_hinge(lot)
	var shell_ray := PhysicsRayQueryParameters3D.create(door.to_global(Vector3(0, .85, .44)), door.to_global(Vector3(0, .85, -.52)))
	shell_ray.exclude = [actor.get_rid()]
	var shell := actor.get_world_3d().direct_space_state.intersect_ray(shell_ray)
	check(hinge != null and hinge.is_clear() and shell.is_empty() and not main.indoors and not main.crossing,"%s opened at its old landing without an iris"%lot.name)
	return await walk(Survey.xz(approach.global_position),lot.name+" descend",false) and await walk(trail,lot.name+" back to road",false)
