extends "res://tests/building_structure_checks.gd"
## Inspect exactly the outdoor nodes mounted by F5 and each corresponding room.
## Each window is checked against positions, real collision, and rendered faces.
const Catalog := preload("res://world/interiors/room_catalog.gd")
const Clearing := preload("res://world/Clearing.tscn")
const Bake := preload("res://source/bake_buildings.gd")

func view_for(node: Node3D) -> SubViewport:
	var world := SubViewport.new()
	world.own_world_3d = true
	root.add_child(world)
	world.add_child(node)
	return world

func roles_of(node: MeshInstance3D, outside: bool, label: String) -> Array[String]:
	var roles: Array[String] = []
	for i in node.mesh.get_surface_count():
		var mesh := node.mesh as ArrayMesh
		var role := mesh.surface_get_name(i)
		var material := node.get_active_material(i)
		var correct: bool = material is ShaderMaterial and material.shader == Baker.Paint if outside else material is StandardMaterial3D and material.vertex_color_use_as_albedo
		check(correct and material.resource_name == role and not roles.has(role), label + " explicit material and unique surface: " + role)
		roles.append(role)
		var records := mesh.surface_get_arrays(i)
		var vertices: PackedVector3Array = records[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = records[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = records[Mesh.ARRAY_COLOR]
		var uv: PackedVector2Array = records[Mesh.ARRAY_TEX_UV]
		var good := vertices.size() == normals.size() and vertices.size() == colors.size() and vertices.size() == uv.size() and vertices.size()%3 == 0
		for j in range(0, vertices.size(), 3):
			var n := (vertices[j+2]-vertices[j]).cross(vertices[j+1]-vertices[j])
			if n.length_squared() < .00000000001: continue
			n = n.normalized()
			for k in range(j, j+3):
				good = good and n.dot(normals[k]) > .99 and uv[k].is_finite() and uv[k].x in [0.0,1.0,3.0] and colors[k].a > .995
			if not good: break
		check(good, label + " finite finish UV, opaque vertex colors and outward clockwise normals: " + role)
	return roles

func palette(node: MeshInstance3D, role: String, ink: Color, label: String) -> void:
	var mesh := node.mesh as ArrayMesh
	for i in mesh.get_surface_count():
		if mesh.surface_get_name(i) != role: continue
		var colors: PackedColorArray = mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]
		for sample in colors:
			if Vector3(sample.r-ink.r,sample.g-ink.g,sample.b-ink.b).length() < .067:
				check(true, label + " uses authored paint in " + role)
				return
	check(false, label + " missing authored paint in " + role)

func struck_roles(node: MeshInstance3D, a: Vector3, b: Vector3) -> Array[String]:
	var found: Array[String] = []
	var m := node.mesh as ArrayMesh
	for i in m.get_surface_count():
		var vertices: PackedVector3Array = m.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
		for j in range(0,vertices.size(),3):
			var h: Variant = Geometry3D.segment_intersects_triangle(a,b,vertices[j],vertices[j+1],vertices[j+2])
			if h != null:
				found.append(m.surface_get_name(i))
				break
	return found

func inspect(shell: Node3D, p: Shape, outside: bool, label: String) -> void:
	var base_names := ["PaintedShell"] if outside else ["GroundCutaway"]
	if not outside and p.floors.size() == 2: base_names.append("LoftCutaway")
	if shell.has_node("RoofCutAwayFromView"): base_names.append("RoofCutAwayFromView")
	var roles: Array[String] = []
	for name: String in base_names:
		var layer := shell.get_node(name) as MeshInstance3D
		roles.append_array(roles_of(layer, outside, label + " / " + name))
		for sector: Node3D in layer.get_children():
			for version: MeshInstance3D in sector.get_children():
				var drawn := roles_of(version, false, label + " / " + name + "/" + sector.name + "/" + version.name)
				if version.name == &"Section": check(not drawn.has("glazing"), label + " visual section is never a full sash")
				roles.append_array(drawn)
	var front: MeshInstance3D = shell.get_node(base_names[0])
	if outside:
		for leaf in shell.get_node("ThresholdDoor").get_children():
			roles.append_array(roles_of(leaf.get_node("PaintedLeaf"), true, label + " / " + str(leaf.name)))
	var required := ["timber","glazing"]
	if outside: required.append_array(["roof_tile","masonry","door_leaf"] + ([] if p.kind == "barn" else ["facade"]))
	else: required.append_array(["floor_boards" if p.floor_finish == "boards" else "masonry"] + ([] if p.kind == "barn" else ["lining"]))
	check(required.all(func(role: String) -> bool: return role in roles), label + " roles for actual building components")
	if outside:
		palette(front,"timber" if p.kind == "barn" else "facade",p.color("facade"),label)
		palette(front,"roof_tile",p.color("roof"),label)
		palette(front,"masonry",p.color("stone"),label)
		palette(shell.get_node("ThresholdDoor/LeftLeaf/PaintedLeaf"),"door_leaf",p.color("door"),label)
	else:
		palette(front,"floor_boards" if p.floor_finish == "boards" else "masonry",p.color("floor"),label)
	var windows := 0
	var markers := shell.find_children("Opening_*","Marker3D",false,false)
	check(markers.size() == p.openings.size(),label + " no unpaired opening markers")
	for o: Dictionary in p.openings:
		var mark := shell.get_node("Opening_"+o.id) as Marker3D
		var expected := p.opening_frame(o)
		var tag: String = label + " / " + o.id
		check(mark.transform.is_equal_approx(expected) and mark.basis.determinant() > .99 and mark.get_meta("wall") == o.side and mark.get_meta("storey") == o.floor and is_equal_approx(float(mark.get_meta("sill")),float(o.sill)) and Vector2(mark.get_meta("size")).is_equal_approx(Vector2(o.width,o.height)), tag + " orientation, sill, storey and aperture")
		var mid := expected*Vector3(o.width*.22,o.height*.31,0)
		var a := mid+expected.basis.z*.195
		var b := mid-expected.basis.z*(p.wall+.085)
		var impact := collider_at(shell,a,b)
		match o.kind:
			"window":
				windows += 1
				check(impact != null and impact.name == "Glazing_"+o.id,tag + " solid glazing and not a solid wall")
				var skin: MeshInstance3D = front if outside else shell.get_node("RoofCutAwayFromView" if o.gable else ("GroundCutaway" if o.floor == 0 else "LoftCutaway") + "/Wall_" + o.side + "/Full")
				if not outside:
					var beam := shell.get_node("WindowDaylight/"+o.id) as SpotLight3D
					var inward := -expected.basis.z
					var drop := -beam.basis.z
					check(beam.position.distance_to(expected*Vector3(0, o.height*.53, -p.wall-.095)) < .002 and drop.dot(inward) > .3 and drop.y < -.35 and beam.get_meta("storey") == o.floor, tag + " has aperture-centred inward/downward daylight")
					if not o.gable: check(struck_roles(skin.get_parent().get_node("Section"),a,b).is_empty(), tag + " no rendered window across the section sightline")
				check(struck_roles(skin,a,b) == ["glazing"],tag + " mesh ray reaches only painted glass, not a blocking skin/trim")
			"vent":
				check(impact == null,tag + " actual ventilating gable void, not another window/floor")
			"door":
				check(impact != null and impact.name == &"ClosedDoor" if outside else impact == null,tag + " solid outdoor leaf / traversable interior opening")
		if o.kind != "door":
			var under := expected.origin-Vector3.UP*.074
			var wall := collider_at(shell,under+expected.basis.z*.15,under-expected.basis.z*p.wall)
			check(wall != null and String(wall.name).begins_with("Wall_"),tag + " solid wall below sill")
	check(shell.find_children("Glazing_*","CollisionShape3D",true,false).size() == windows,label + " every glass shape belongs to a window")
	for bay: Dictionary in p.front_roof:
		if not bay.has("window"): continue
		# Just behind the front panel the first roof hit must be the new
		# cross-gable, not the old pitch below the new window.
		var well := Vector3(bay.u,p.upper+.05,bay.z-p.wall-.035)
		var cover := collider_at(shell,well,well+Vector3.UP*5.)
		check(cover != null and cover.name.begins_with("RoofHallCross"),label + " / " + bay.id + " connects to the second-storey volume without an intervening pitch or third deck")
	var ground := collider_at(shell,Vector3(0,.15,0),Vector3(0,-.25,0))
	check(ground != null and ground.name == &"GroundSlab",label + " single finished ground datum")
	if p.floors.size() == 1:
		check(not shell.has_node("StairHead") and not shell.has_node("LoftCutaway"),label + " no default/false second storey")
	else:
		var well := p.hole.get_center()
		var at := Vector3(well.x,p.upper,well.y)
		check(collider_at(shell,at+Vector3.UP*.12,at-Vector3.UP*.22) == null,label + " no solid deck across stair hole")
		var solid := Vector3(p.stair.x,p.upper,p.stair.top_z-.52)
		var landing := collider_at(shell,solid+Vector3.UP*.15,solid-Vector3.UP*.10)
		check(landing != null and landing.name.begins_with("LoftSlab"),label + " solid top landing")
		if not p.bay.is_empty():
			var ray := Vector3(p.bay.center,p.upper,p.depth*.5-p.wall*.5)
			var support := collider_at(shell,ray+Vector3.UP*.05,ray-Vector3.UP*.10)
			check(support != null and support.name == &"OrielPortalFloor",label + " oriel portal floor spans former facade thickness")
			ray.z += p.bay.projection*.65
			support = collider_at(shell,ray+Vector3.UP*.05,ray-Vector3.UP*.10)
			check(support != null and support.name == &"OrielDeck",label + " usable real projecting bay floor")

func inspect_partitions(shell: Node3D, p: Shape, label: String) -> void:
	var all := 0
	for d: Dictionary in p.partitions:
		var f := Transform3D(Basis.IDENTITY, Vector3(0,p.floors[d.floor],d.at)) if d.axis == "x" else Transform3D(Basis(Vector3.UP,-PI*.5), Vector3(d.at,p.floors[d.floor],0))
		var depth: float = d.thickness*.5 + .042
		var endpoint: float = d.passages[0].u-d.passages[0].width*.5 if not d.passages.is_empty() else d.to
		var sample := Vector3((d.from+endpoint)*.5, 1.52, depth)
		var solid := collider_at(shell, f*sample, f*Vector3(sample.x,sample.y,-depth))
		check(solid != null and solid.name.begins_with("Partition_"+d.id), label + " solid divider above the visual cut: " + d.id)
		for o: Dictionary in d.passages:
			all += 1
			var peg := shell.get_node_or_null("Portal_"+o.id) as Marker3D
			var size := Vector2(o.width,o.height)
			check(peg != null and peg.transform.is_equal_approx(Transform3D(f.basis,f*Vector3(o.u,0,0))) and peg.get_meta("size") == size and peg.get_meta("storey") == d.floor, label + " real partition portal geometry: " + o.id)
			var head := collider_at(shell, f*Vector3(o.u,o.height+.041,depth), f*Vector3(o.u,o.height+.041,-depth))
			check(head != null and head.name.begins_with("Partition_"+d.id), label + " solid lintel: " + o.id)
			for x: float in [o.u-.30, o.u, o.u+.30]:
				check(collider_at(shell, f*Vector3(x,1.52,depth), f*Vector3(x,1.52,-depth)) == null, label + " passable at player shoulder: " + o.id)
	check(shell.find_children("Portal_*","Marker3D",false,false).size() == all, label + " no stray openings in partition roster")

func invalid_partitions() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR+"inn.json"))
	for reason in ["wrong floor", "narrow passage", "blocked stair", "overlapping passage", "bad span"]:
		var change := fixture.duplicate(true)
		var wall: Dictionary = change.partitions[0]
		match reason:
			"wrong floor": wall.floor = 2
			"narrow passage": wall.passages[0].width = .54
			"blocked stair": wall.at = 2.75
			"overlapping passage": wall.passages[1].u = wall.passages[0].u+.28
			"bad span": wall.to = 9.0
		check(not Shape.new().configure(change).is_empty(),"reject partition " + reason)

func component_substitution() -> void:
	var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR+"copper_loft.json"))
	var base := shape_of(recipe.duplicate(true),"component fixture baseline")
	var original := recipe.duplicate(true)
	for opening: Dictionary in recipe.openings:
		if opening.id == "west_low": opening.component = "shop_display"
	recipe.wall_panel = "board_batten"
	var selected := shape_of(recipe,"new exterior component selection")
	var inside := shape_of(selected.interior_data(),"automatic matching interior selection")
	check(selected.source_revision == base.source_revision and selected.authored_revision != base.authored_revision, "changing a finish component doesn't move v3 feet")
	for outside in [true, false]:
		var p := selected if outside else inside
		var home := Baker.make(p, outside)
		var datum := home.get_node("GroundDatum") if outside else home
		var mesh: MeshInstance3D = datum.get_node("PaintedShell" if outside else "GroundCutaway/Wall_west/Full")
		var peg := datum.get_node("Opening_west_low") as Marker3D
		var window: Vector2 = peg.get_meta("size")
		var before := Baker.make(base if outside else shape_of(base.interior_data(),"original inner component fixture"), outside)
		var original_datum := before.get_node("GroundDatum") if outside else before
		var old_mesh: MeshInstance3D = original_datum.get_node("PaintedShell" if outside else "GroundCutaway/Wall_west/Full")
		var plate := peg.transform * Vector3(window.x*.083,window.y*.52,0)
		var a := plate+peg.basis.z*.195
		var b := plate-peg.basis.z*(p.wall+.085)
		check(home.get_meta("wall_panel") == "board_batten" and peg.get_meta("component") == "shop_display" and peg.transform.is_equal_approx(original_datum.get_node("Opening_west_low").transform), "both bakes use new components at unchanged aperture")
		var old_roles := struck_roles(old_mesh,a,b)
		var new_roles := struck_roles(mesh,a,b)
		check("timber" in old_roles and new_roles == ["glazing"], "new display profile removes cross rail (%s, %s → %s)" % ["exterior" if outside else "interior", old_roles, new_roles])
		if not outside:
			var wall_mesh := mesh.mesh as ArrayMesh
			check(not range(wall_mesh.get_surface_count()).any(func(i: int) -> bool: return wall_mesh.surface_get_name(i) == "lining"), "new panel kit also replaces plaster geometry inside")
		before.free()
		home.free()
	original.openings[1].component = "louver"
	check(not Shape.new().configure(original).is_empty(),"reject a vent-only component on a glazed opening")

func check_shell_resize(p: Shape, id: String) -> void:
	# Change exactly one outside axis at a time; don't supply an interior dimension.
	for axis in range(2):
		var input := p.data.duplicate(true)
		input.size[axis] += .30
		var variant := shape_of(input, id + " resized shell")
		if variant == null: continue
		var plan := shape_of(variant.interior_data(), id + " resized projection")
		if plan == null: continue
		plan.source_revision = variant.source_revision
		var baked := round_trip(Baker.make(plan, false), id + "-axis-" + str(axis))
		if baked == null: continue
		check(Vector2(baked.get_meta("net_footprint")).is_equal_approx(variant.inside.size), id + " shell-only edit rebakes matching net axes")
		check(baked.get_meta("building_revision") == variant.source_revision and variant.source_revision != p.source_revision, id + " resizing invalidates old saved coordinates")
		baked.free()

func _run() -> void:
	var field := Clearing.instantiate()
	var outdoors := view_for(field)
	var lots := field.get_node("Outskirts/Lots")
	check(lots.get_child_count() == 11 and Catalog.ROOMS.size() == Bake.STEMS.size() and Catalog.ROOMS.size() == 12,"F5 enclosed building roster complete")
	check(field.get_node("Glasshouse") is StaticBody3D and not Catalog.valid_place("place.glasshouse"),"original conservatory is not a transition")
	for id: String in Bake.STEMS:
		var room_id := "place." + id
		var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR+id+".json"))
		var p := shape_of(input,id)
		if p == null: continue
		var plan := shape_of(p.interior_data(),id+" projected")
		if plan == null: continue
		check_shell_resize(p, id)
		var lot := Catalog.outdoor_lot(field,room_id)
		var layout := Catalog.layout(room_id).instantiate() as Node3D
		var indoors := view_for(layout)
		await physics_frame
		await physics_frame
		var inner := layout.get_node("Structure") as Node3D
		var outer := lot.get_node("GroundDatum") as Node3D
		check(lot.lot_id == StringName(p.data.building_id) and inner.get_meta("room_id") == room_id and lot.get_meta("room_id") == room_id,id+" registered lot and room identity")
		check(lot.get_meta("authored_revision") == p.authored_revision and inner.get_meta("authored_revision") == p.authored_revision and lot.get_meta("building_revision") == inner.get_meta("building_revision") and inner.get_meta("building_revision") == p.source_revision,id+" both current bakes, identical source and feet versions")
		check(Vector2(lot.get_meta("net_footprint")).is_equal_approx(p.inside.size) and Vector2(inner.get_meta("net_footprint")).is_equal_approx(plan.inside.size) and plan.inside.size.is_equal_approx(p.inside.size),id+" chosen net area/ratio, no whole-scene scaling")
		var entry := inner.get_node("Entry") as Marker3D
		var door := inner.get_node("DoorAnchor") as Marker3D
		check(absf(entry.position.y) < .02 and entry.position.distance_to(door.position) < .6 and is_equal_approx(float(door.get_meta("passage_width")),float(lot.door_width)),id+" connected real ground entrance")
		for o: Dictionary in p.openings:
			var a := outer.get_node("Opening_"+o.id) as Marker3D
			var b := inner.get_node("Opening_"+o.id) as Marker3D
			check(a.get_meta("wall") == b.get_meta("wall") and a.get_meta("storey") == b.get_meta("storey") and a.get_meta("sill") == b.get_meta("sill") and a.get_meta("size") == b.get_meta("size") and a.get_meta("component") == b.get_meta("component") and b.get_meta("component") == o.get("component", input.get("entry_style","arched")) and a.transform.is_equal_approx(b.transform),id+" identical local window/door & component match: "+o.id)
		check(lot.get_meta("wall_panel") == plan.wall_panel and inner.get_meta("wall_panel") == plan.wall_panel,id+" same selected wall kit in both bakes")
		inspect(outer,p,true,id+" exterior")
		inspect(inner,plan,false,id+" interior")
		inspect_partitions(outer,p,id+" exterior")
		inspect_partitions(inner,plan,id+" interior")
		if input.has("sign"):
			var signboard := outer.get_node_or_null("Sign") as Marker3D
			check(signboard != null and signboard.position.y > float(p.door.height), id+" visible facade emblem above the walk plane")
		var hinge := Catalog.outdoor_hinge(lot)
		var leaf_center := hinge.to_global(Vector3(0, .8, 0))
		var facade_center := outer.to_local(leaf_center)
		var liner := outer.get_node("BlackReveal").get_child(0) as MeshInstance3D
		check(liner.material_override.albedo_color == Color.BLACK and liner.material_override.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, id + " the cavity has an actual black surface")
		hinge.track_foot(hinge.to_global(Vector3(0, 0, .7)), 1.0)
		await physics_frame
		await physics_frame
		check(collider_at(outer,facade_center+Vector3.BACK*.25,facade_center-Vector3.BACK*.42) == null, id + " opened leaf and black liner do not block the central threshold")
		hinge.track_foot(hinge.to_global(Vector3(0, 0, 4)), 1.0)
		await physics_frame
		await physics_frame
		# Aim slightly off the meeting line of the two centered leaves.
		var leaf_panel := facade_center+Vector3.RIGHT*.12
		var reclosed := collider_at(outer,leaf_panel+Vector3.BACK*.25,leaf_panel-Vector3.BACK*.42)
		check(reclosed != null and reclosed.name == &"ClosedDoor", id + " leaving returns a solid closed leaf")
		print(id," net ",p.inside.size," / ",plan.inside.size," at x",plan.inside.get_area()/p.inside.get_area(),"; ",p.floors.size()," floor(s)")
		indoors.queue_free()
		await process_frame
	outdoors.queue_free()
	component_substitution()
	invalid_partitions()
	print("BUILDING ROSTER: ",checks," checks, ",failures," failures")
	quit(int(failures != 0))
