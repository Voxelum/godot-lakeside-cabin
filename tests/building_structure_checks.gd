extends SceneTree
## Compare shipped and edited/rebaked pairs, including the actual collision queries.
const Shape := preload("res://source/building_structure.gd")
const Baker := preload("res://source/building_baker.gd")
const State := preload("res://scripts/foundation/world_state.gd")
const DIR := "res://world/interiors/structures/"
const EXTERIOR := preload(DIR + "CopperLoftExterior.scn")
const INTERIOR := preload(DIR + "CopperLoftStructure.scn")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)

func shape_of(data: Dictionary, label: String) -> Shape:
	var s := Shape.new()
	var message := s.configure(data)
	check(message.is_empty(), label + ": " + message)
	return s if message.is_empty() else null

func round_trip(node: Node3D, label: String) -> Node3D:
	var path := "user://bake-fixture-" + label + "-" + Crypto.new().generate_random_bytes(10).hex_encode() + ".scn"
	var scene := PackedScene.new()
	var packed := scene.pack(node) == OK
	node.free()
	if not packed or ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS) != OK:
		check(false, label + " serialized isolated baked scene")
		return null
	var loaded := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	check(loaded != null and DirAccess.remove_absolute(path) == OK, label + " reloaded and removed isolated bake")
	return loaded.instantiate() if loaded else null

func collider_at(shell: Node3D, from: Vector3, to: Vector3) -> CollisionShape3D:
	var hit := shell.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(shell.to_global(from), shell.to_global(to)))
	if hit.is_empty(): return null
	var body := hit.collider as CollisionObject3D
	return body.shape_owner_get_owner(body.shape_find_owner(hit.shape)) as CollisionShape3D

func verify_shell(origin: Node3D, source: Shape, outside: bool, label: String) -> void:
	var world := SubViewport.new()
	world.own_world_3d = true
	root.add_child(world)
	world.add_child(origin)
	var shell := origin.get_node("GroundDatum") as Node3D if outside else origin
	for i in 3: await physics_frame
	check(Vector2(origin.get_meta("net_footprint")).is_equal_approx(source.inside.size), label + " clear size metadata")
	var ground := shell.get_node("StructureCollision/GroundSlab") as CollisionShape3D
	var size := (ground.shape as BoxShape3D).size
	check(Vector2(size.x, size.z).is_equal_approx(Vector2(source.width, source.depth)), label + " footprint collision dimensions")
	var mesh := shell.get_node("PaintedShell" if outside else "GroundCutaway") as MeshInstance3D
	check(mesh.mesh.get_aabb().size.x >= source.width - .001 and mesh.mesh.get_aabb().size.z >= source.depth - .001, label + " visible mesh spans footprint")
	for o in source.openings:
		var marker := shell.get_node("Opening_" + o.id) as Marker3D
		var expected := source.frame(o.side_index, o.u, o.y)
		check(marker.transform.is_equal_approx(expected) and Vector2(marker.get_meta("size")).is_equal_approx(Vector2(o.width,o.height)), label + " shared wall, direction, floor, sill and size " + o.id)
		var center := marker.transform * Vector3(0, o.height*.5, 0)
		var normal := marker.basis.z
		var hit := collider_at(shell, center+normal*.31, center-normal*(source.wall-.015))
		if o.kind == "window":
			check(hit != null and hit.name == StringName("Glazing_" + o.id), label + " real wall opening stops at glazed pane " + o.id)
			var under := marker.position-Vector3.UP*.14
			hit = collider_at(shell, under+normal*.28, under-normal*(source.wall-.015))
			check(hit != null and String(hit.name).begins_with("Wall_"), label + " solid wall below " + o.id)
		else:
			check(hit != null and hit.name == &"ClosedDoor" if outside else hit == null, label + " closed exterior leaf / open interior doorway")
	var foot := (shell.get_node("StairFoot") as Marker3D).position
	var head := (shell.get_node("StairHead") as Marker3D).position
	check(foot.is_equal_approx(Vector3(source.stair.x, 0, source.stair.bottom_z)) and head.is_equal_approx(Vector3(source.stair.x, source.upper, source.stair.top_z)), label + " stair changes reach both bakes")
	var hole := source.hole.get_center()
	var at := Vector3(hole.x, source.upper, hole.y)
	check(collider_at(shell, at + Vector3.UP*.14, at-Vector3.UP*.27) == null, label + " no upper slab across the stair shaft")
	var ramp := collider_at(shell, at-Vector3.UP*.29, at-Vector3.UP*(source.upper-.05))
	check(ramp != null and ramp.name == &"StairWalkSurface", label + " the same shaft contains the stair collision")
	for pos: Vector2 in [Vector2(0, hole.y), Vector2(hole.x, head.z-.45)]:
		var deck := Vector3(pos.x, source.upper, pos.y)
		var plate := collider_at(shell, deck + Vector3.UP*.14, deck-Vector3.UP*.10)
		check(plate != null and String(plate.name).begins_with("LoftSlab_"), label + " solid upper aisle and landing")
	world.queue_free()

func verify_pair(outside: Node3D, inside: Node3D, base: Shape, projected: Shape, label: String) -> void:
	check(outside.get_meta("building_revision") == base.source_revision and inside.get_meta("building_revision") == base.source_revision, label + " same revision as canonical source")
	check(projected.inside.is_equal_approx(base.inside), label + " identical net footprint")
	check(is_equal_approx(projected.inside.size.aspect(), base.inside.size.aspect()), label + " preserved clear width/depth ratio")
	for i in base.openings.size():
		var a := base.openings[i]; var b := projected.openings[i]
		check(base.frame(a.side_index, a.u, a.y).is_equal_approx(projected.frame(b.side_index, b.u, b.y)) and a.width == b.width and a.height == b.height and a.y == b.y, label + " exact local placement with unchanged aperture " + a.id)
	check(projected.stair.width == base.stair.width and (Vector2(projected.stair.top_z, projected.stair.bottom_z) - Vector2(base.stair.top_z, base.stair.bottom_z)).is_equal_approx(Vector2.ONE*(projected.depth-base.depth)*.5), label + " translates stair/shaft without scaling tread run")
	await verify_shell(outside, base, true, label + " exterior")
	await verify_shell(inside, projected, false, label + " room")

func _run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "copper_loft.json"))
	var canonical := shape_of(data, "authored plan")
	if canonical == null:
		quit(1)
		return
	var projected := shape_of(canonical.interior_data(), "projected room")
	if projected == null:
		quit(1)
		return
	var legacy := data.duplicate(true)
	legacy.erase("wall_panel")
	for opening: Dictionary in legacy.openings: opening.erase("component")
	legacy.interior_area_multiplier = 1.5
	legacy.stairs = JSON.parse_string('{"x":1.02,"width":0.94,"bottom_z":1.585,"top_z":-0.765,"steps":13,"opening":{"min_x":0.51,"max_x":1.51,"min_z":-0.765,"max_z":1.715}}')
	check(canonical.source_revision != ("rect-loft/1\n" + JSON.stringify(legacy, "", true, true)).sha256_text(), "1:1 CopperLoft revision sends old expanded-room v3 feet to entry")
	check(not Shape.new().configure(legacy).is_empty(), "reject the old per-room multiplier")
	await verify_pair(EXTERIOR.instantiate(), INTERIOR.instantiate(), canonical, projected, "shipped")
	var edited := data.duplicate(true)
	edited.size[0] += .34
	for o: Dictionary in edited.openings:
		if o.id == "west_low": o.u -= .29
	var s: Dictionary = edited.stairs
	s.bottom_z -= .13; s.top_z -= .21; s.opening.min_z = s.top_z; s.opening.max_z -= .12
	var variant := shape_of(edited, "wider plan / moved window / adjusted stair")
	if variant != null:
		var variant_room := shape_of(variant.interior_data(), "projected variant")
		if variant_room != null:
			variant_room.source_revision = variant.source_revision
			check(variant.source_revision != canonical.source_revision, "edit changes the revision shared by both variants")
			var outside := round_trip(Baker.make(variant, true), "wider-exterior")
			var inside := round_trip(Baker.make(variant_room, false), "wider-interior")
			if outside != null and inside != null:
				await verify_pair(outside, inside, variant, variant_room, "edited and rebaked")
			else:
				if outside != null: outside.free()
				if inside != null: inside.free()
	for invalid in ["no stair", "no opening", "too short", "off landing", "too steep", "blocked approach"]:
		var broken := data.duplicate(true)
		match invalid:
			"no stair": broken.erase("stairs")
			"no opening": broken.stairs.erase("opening")
			"too short": broken.stairs.opening.max_z -= 1.5
			"off landing": broken.stairs.opening.min_z += .20
			"too steep": broken.stairs.bottom_z -= .8
			"blocked approach": broken.openings[0].u = .80
		check(not Shape.new().configure(broken).is_empty(), "reject " + invalid)
	if "--inspect-default-slot" in OS.get_cmdline_user_args() and FileAccess.file_exists(State.SLOT):
		var sha := FileAccess.get_sha256(State.SLOT)
		var existing: Variant = bytes_to_var(FileAccess.get_file_as_bytes(State.SLOT))
		var reason := State.new().load_slot(State.SLOT)
		check(reason.is_empty() and sha == FileAccess.get_sha256(State.SLOT), "installed default slot was readable without rewriting it")
		if reason.is_empty(): print("Existing default slot read only; version ", existing.version, "; SHA retained")
	print("BUILDING STRUCTURE: ", checks, " checks, ", failures, " failures")
	quit(int(failures != 0))
