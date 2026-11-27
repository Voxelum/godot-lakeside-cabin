extends SceneTree
## Native before/after reference frames. Same outside framing against the lot
## anchor; actual F5 camera for the interior. This script poses, not walk-tests.
const MAIN := preload("res://Main.tscn")
const Rooms := preload("res://world/interiors/room_catalog.gd")
const IDS := ["cabin", "lime_house", "orchard_house", "hay_barn", "smith_stock", "copper_loft", "sill_house", "bakery"]
const DIAGNOSTIC := {"door_leaf":Color.MAGENTA,"glazing":Color.CYAN,"roof_tile":Color.GREEN,"masonry":Color.YELLOW,"timber":Color.RED}
var output := ""
var errors := 0
var inspect_pixels := false

func _initialize() -> void:
	_run.call_deferred()

func visible_frame(view: SubViewport) -> Image:
	for i in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	return view.get_texture().get_image()

func frame(view: SubViewport, label: String) -> void:
	var image := await visible_frame(view)
	var path := output.path_join(label + ".png")
	if image.is_empty() or image.get_size() != view.size or FileAccess.file_exists(path) or image.save_png(path) != OK:
		push_error("Unable to write new native viewport frame: " + path)
		errors += 1

func inspect_roles(view: SubViewport, nodes: Array, wanted: Array, label: String) -> void:
	# Render object-ID tints into the gameplay viewport, then restore the
	# actual materials. This diagnostic is not saved with the comparison.
	var changed := {}
	var counts := {}
	for node: MeshInstance3D in nodes:
		var mesh := node.mesh as ArrayMesh
		var overrides := {}
		for i in mesh.get_surface_count():
			var role := mesh.surface_get_name(i)
			if not wanted.has(role): continue
			var ink := StandardMaterial3D.new()
			ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ink.albedo_color = DIAGNOSTIC[role]
			overrides[i] = node.get_surface_override_material(i)
			node.set_surface_override_material(i,ink)
			counts[role] = 0
		changed[node] = overrides
	var image := await visible_frame(view)
	for node: MeshInstance3D in changed:
		for i in changed[node]: node.set_surface_override_material(i,changed[node][i])
	for y in image.get_height():
		for x in image.get_width():
			var p := image.get_pixel(x,y)
			for role: String in counts:
				var color: Color = DIAGNOSTIC[role]
				if absf(p.r-color.r)+absf(p.g-color.g)+absf(p.b-color.b) < .10:
					counts[role] += 1
	for role: String in wanted:
		if counts.get(role,0) < (5 if role == "glazing" else 25):
			push_error(label + " clipped/occluded finish " + role + ": " + str(counts))
			errors += 1
	print(label," visible native component pixels ",counts)

func inspect_cutaway(view: SubViewport, layer: MeshInstance3D, label: String) -> void:
	var visible := [layer]
	var roles := ["timber"]
	for side in layer.get_children():
		var selected: MeshInstance3D = side.get_node("Full") if side.get_node("Full").visible else side.get_node("Section")
		visible.append(selected)
		for i in selected.mesh.get_surface_count():
			if selected.mesh.surface_get_name(i) == "glazing" and not roles.has("glazing"): roles.append("glazing")
	await inspect_roles(view,visible,roles,label)

func _run() -> void:
	inspect_pixels = "--check-materials" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): output = ProjectSettings.globalize_path(arg.trim_prefix("--capture="))
	if DisplayServer.get_name() == "headless" or output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Use a rendered window and pass -- --capture=<new output directory>")
		quit(2)
		return
	var game = MAIN.instantiate()
	var token := Crypto.new().generate_random_bytes(12).hex_encode()
	game.get_node("Session").slot_path = "user://review-" + token + ".slot"
	game.get_node("BindingPanel").settings_path = "user://review-" + token + ".cfg"
	root.add_child(game)
	await physics_frame
	var clearing: Node3D = game.field.get_node("Clearing")
	for id: String in IDS:
		var room_id := "place." + id
		var lot: Node3D = clearing.get_node("Cottage") if id == "cabin" else Rooms.outdoor_lot(clearing, room_id)
		var approach: Marker3D = game.field_entry if id == "cabin" else Rooms.outdoor_return(lot)
		game.show_place(false, approach.global_position, true)
		game.field_actor.locked = true
		game.orbit.frozen = true
		game.orbit.size = 10.1
		game.orbit.aim = lot.global_position + Vector3(0, 2.16, .52)
		game.orbit._apply()
		await frame(game.field, id + "-out")
		if inspect_pixels:
			var finishes := ["door_leaf","roof_tile","masonry","timber"]
			if id != "hay_barn": finishes.append("glazing")
			await inspect_roles(game.field,[lot.mesh_view],finishes,id+" outdoors")
			if id == "hay_barn":
				# The old open lean-to intentionally hides the east lights from
				# the high street angle. Inspect them from the real east side.
				var yaw: float = game.orbit.yaw_degrees
				var pitch: float = game.orbit.pitch_degrees
				game.orbit.yaw_degrees = lot.rotation_degrees.y+86.0
				game.orbit.pitch_degrees = 29.0
				game.orbit._apply()
				await frame(game.field,"hay_barn-east-out")
				await inspect_roles(game.field,[lot.mesh_view],["glazing"],id+" east behind lean-to")
				game.orbit.yaw_degrees = yaw
				game.orbit.pitch_degrees = pitch
		game.restore_place(room_id, Vector3(-1, .005, 2.12))
		game.show_place(true, game.room_entry.global_position, true)
		await frame(game.room, id + "-in")
		var structure: Node3D = game.building_structure()
		if inspect_pixels: await inspect_cutaway(game.room,structure.get_node("GroundCutaway"),id+" ground cutaway")
		if structure != null and structure.has_node("StairHead"):
			var head: Vector3 = structure.get_node("StairHead").global_position
			game.show_place(true, head + Vector3(-.72, .005, -.46), true)
			await frame(game.room, id + "-upper")
			if inspect_pixels: await inspect_cutaway(game.room,structure.get_node("LoftCutaway"),id+" upper cutaway")
	print("BUILDING REVIEW FRAMES ", game.room.size, " : ", errors, " errors; ", output)
	quit(int(errors > 0))
