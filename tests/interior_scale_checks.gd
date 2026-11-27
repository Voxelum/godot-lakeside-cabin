extends SceneTree
## Rendered, calibrated exterior/interior references. Gameplay framing is
## recorded separately and restored; reference views do not change the game.
const MAIN := preload("res://Main.tscn")
const Catalog := preload("res://world/interiors/room_catalog.gd")
const IDS := ["bakery", "smith_stock", "cabin", "lime_house", "orchard_house", "hay_barn", "copper_loft", "sill_house"]
# Horizontal free passage ray through a representative point between real
# static colliders. z is positive toward the street. All at knee height.
const LANES := {
	"bakery": ["queue in front of counter", Vector3(2.16,.38,1.37), Vector3.BACK, 1.12],
	"smith_stock": ["receiving between shelf and bench",Vector3(.1,.38,.28),Vector3.RIGHT,2.1],
	"cabin": ["past dining table through center floor",Vector3(-.9,.38,-.55),Vector3.RIGHT,2.0],
	"lime_house": ["door to seed bench",Vector3(-1.52,.38,-.85),Vector3.RIGHT,1.25],
	"orchard_house": ["sorting to sleep side",Vector3(-.91,.38,.15),Vector3.RIGHT,1.4],
	"hay_barn": ["cart unloading near middle",Vector3(0,.38,.19),Vector3.RIGHT,2.1],
	"copper_loft": ["approach stairs beside dine-in",Vector3(.36,.38,.84),Vector3.RIGHT,.76],
	"sill_house": ["door to parlor",Vector3(.22,.38,-.78),Vector3.RIGHT,.88],
}
const CUT_LIGHT := {"bakery": "east_display", "smith_stock": "west_sash"}
var game
var failures := 0
var checks := 0
var output := ""

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func rendered(view: SubViewport) -> Image:
	for i in 2:
		await process_frame
		await RenderingServer.frame_post_draw
	return view.get_texture().get_image()

func record(image: Image, label: String) -> void:
	if output.is_empty(): return
	var path := output.path_join(label + ".png")
	check(not image.is_empty() and not FileAccess.file_exists(path) and image.save_png(path) == OK, "new native capture " + label)

func first_hit(at: Vector3, direction: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(at, at + direction*12.0)
	query.exclude = [game.room_actor.get_rid()]
	var hit: Dictionary = game.room.find_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("position", at)

func lane(id: String) -> void:
	var spec: Array = LANES[id]
	var at: Vector3 = spec[1]
	var direction: Vector3 = spec[2]
	var a := first_hit(at,direction)
	var b := first_hit(at,-direction)
	var width := a.distance_to(b)
	check(a.distance_to(at) > .31 and b.distance_to(at) > .31 and width >= spec[3], "%s lane %s: %.2f m (%s, %s)" % [id,spec[0],width,a,b])
	print("LANE ", id, " · ", spec[0], " = %.2f m" % width)

func rendered_light(id: String, clock: Node, structure: Node3D) -> void:
	var lamp := structure.get_node("WindowDaylight/"+CUT_LIGHT[id]) as SpotLight3D
	var marker := structure.get_node("Opening_"+CUT_LIGHT[id]) as Marker3D
	var wall := structure.get_node("GroundCutaway/Wall_" + String(marker.get_meta("wall"))) as Node3D
	check(wall.get_node("Section").visible and not wall.get_node("Full").visible, id+" foreground window is not a sash in the gameplay view")
	var day := await rendered(game.room)
	record(day,id+"-day")
	var saved := {}
	for other: SpotLight3D in structure.get_node("WindowDaylight").get_children():
		if other != lamp:
			saved[other] = other.get_meta("day_energy")
			other.set_meta("day_energy", 0.0)
	var only_day := await rendered(game.room)
	var day_energy := lamp.light_energy
	clock.hour = 17.60
	clock._advance_sky()
	await rendered(game.room)
	var evening_energy := lamp.light_energy
	clock.handle_key(KEY_3)
	var without_sun := await rendered(game.room)
	var dim_energy := lamp.light_energy
	for other in saved: other.set_meta("day_energy",saved[other])
	record(await rendered(game.room),id+"-dusk")
	var camera: Camera3D = game.room.get_camera_3d()
	var axis := -lamp.global_basis.z
	var pool := lamp.global_position + axis * (-lamp.global_position.y / axis.y)
	var px := camera.unproject_position(pool)
	var total := 0
	var near := 0
	var radius := float(game.room.size.y) * .19
	for y in only_day.get_height():
		for x in only_day.get_width():
			var difference := only_day.get_pixel(x,y).get_luminance() - without_sun.get_pixel(x,y).get_luminance()
			if difference > .045:
				total += 1
				if px.distance_to(Vector2(x,y)) < radius: near += 1
	check(day_energy > 1. and evening_energy < day_energy*.88 and evening_energy > dim_energy+.06 and dim_energy < day_energy*.19, id+" uses the same solar clock, gradually fading at dusk")
	check(near >= 14 and total < day.get_width()*day.get_height()*.14 and float(near)/maxi(total,1) > .64, id+" visibly localized light inside the actual window at both sizes")
	print("DAYLIGHT ", id, " · day / evening / dusk %.2f / %.2f / %.2f; significant pixels %d, within pool %d" % [day_energy,evening_energy,dim_energy,total,near])
	clock.handle_key(KEY_1)

func ref_cameras(id: String, lot: Node3D) -> void:
	var outdoor: Camera3D = game.field.get_camera_3d()
	var indoor: Camera3D = game.room.get_camera_3d()
	var ground := lot.get_node("GroundDatum") as Node3D
	var field_basis: Basis = game.orbit.global_basis
	var basis := Basis.from_euler(Vector3(-deg_to_rad(39.), atan2(-field_basis.x.z,field_basis.x.x),0.))
	# One fixed 9 m vertical orthographic span across each pair. The two
	# cameras share pitch and plan angle expressed relative to their door.
	const SPAN := 9.0
	outdoor.size = SPAN
	outdoor.global_transform = Transform3D(basis, ground.global_position + Vector3.UP*2.15 + basis.z*23.)
	var coverage_out := metre_and_body(outdoor, game.field_actor)
	var field_frame := await rendered(game.field)
	game.show_place(true, game.room_entry.global_position, true)
	game.sync_control()
	game.room_actor.locked = true
	indoor = game.room.get_camera_3d()
	var game_span := indoor.size
	indoor.size = SPAN
	# RoomPresentation would normally ease back to gameplay framing.
	game.get_node("RoomPixels/Interior").set_process(false)
	var coverage_in := metre_and_body(indoor, game.room_actor)
	var room_frame := await rendered(game.room)
	game.get_node("RoomPixels/Interior").set_process(true)
	indoor.size = game_span
	check(coverage_out.is_equal_approx(coverage_in) and absf(coverage_in.x - float(game.room.size.y)/SPAN) < .02 and absf(coverage_in.z - .62) < .002, id+" matching texels/metre and real Walker dimensions")
	check(not field_frame.is_empty() and not room_frame.is_empty(),id+" both native reference buffers rendered")
	print("SCALE ",id," · pair px/m %.1f, 1.68m screen height %.1f px; normal room %.1f px/m" % [coverage_in.x,coverage_in.y,float(game.room.size.y)/game_span])
	record(field_frame,id+"-out-match")
	record(room_frame,id+"-in-match")

func metre_and_body(view: Camera3D, actor: CharacterBody3D) -> Vector3:
	var body := actor.get_node("Body") as CollisionShape3D
	var capsule := body.shape as CapsuleShape3D
	var at := actor.global_position
	var px := view.unproject_position(at)
	return Vector3(px.distance_to(view.unproject_position(at+view.global_basis.x)), px.distance_to(view.unproject_position(at+body.global_basis.y*capsule.height)), 2.0*capsule.radius*body.global_basis.x.length())

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Scale checks require the real renderer")
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): output = ProjectSettings.globalize_path(arg.trim_prefix("--capture="))
	if not output.is_empty() and (DirAccess.dir_exists_absolute(output) or DirAccess.make_dir_recursive_absolute(output) != OK):
		push_error("Pass a new capture directory")
		quit(2)
		return
	game = MAIN.instantiate()
	var tag := Crypto.new().generate_random_bytes(8).hex_encode()
	game.get_node("Session").slot_path = "user://scale-checks-"+tag+".slot"
	game.get_node("BindingPanel").settings_path = "user://scale-checks-"+tag+".cfg"
	root.add_child(game)
	await physics_frame
	var clearing: Node3D = game.field.get_node("Clearing")
	var clock: Node = clearing.get_node("Almanac")
	clock.handle_key(KEY_1)
	for id: String in IDS:
		var room_id := "place." + id
		var lot := Catalog.outdoor_lot(clearing,room_id)
		game.show_place(false,Catalog.outdoor_return(lot).global_position,true)
		game.field_actor.locked = true
		game.orbit.frozen = true
		game._mount_room(room_id)
		await ref_cameras(id,lot)
		await physics_frame
		await physics_frame
		lane(id)
		var structure: Node3D = game.building_structure()
		if id in CUT_LIGHT: await rendered_light(id,clock,structure)
		if structure.has_node("StairHead"):
			var head: Vector3 = structure.get_node("StairHead").global_position
			game.show_place(true, head + Vector3(-.75, .005, -.38), true)
			check(game.room.get_camera_3d().global_basis.x.is_equal_approx(game.room_door.global_basis * (Catalog.outdoor_door(lot).global_basis.inverse() * game.orbit.global_basis.x)),id+" upper camera preserves the same walking axes")
			record(await rendered(game.room),id+"-upper")
	print("INTERIOR SCALE ",game.room.size,": ",checks," checks, ",failures," failures")
	quit(int(failures > 0))
