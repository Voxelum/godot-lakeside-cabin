extends RefCounted
## Bake both views from the same wall cuts, floor sections, roof and stair.
## Visibility of a cutaway never disables its physical structure.
const Shape := preload("res://source/building_structure.gd")
const Parts := preload("res://source/building_components.gd")
const Batch := preload("res://art/building_trial/mesh_batch.gd")
const Join := preload("res://art/building_trial/joinery.gd")
const Trim := preload("res://art/content_batch/buildings/roof_trim.gd")
const Paint := preload("res://world/outskirts/outskirts_shell.gdshader")
const LOT := preload("res://world/interiors/structures/baked_building_lot.gd")
const STAIR_SEAM := .18

class Art:
	var by_role := {}
	func get_layer(role: String) -> Batch:
		if not by_role.has(role): by_role[role] = Batch.new()
		return by_role[role]

	func attach(parent: Node3D, label: String, outside: bool) -> MeshInstance3D:
		var mesh := ArrayMesh.new()
		for role: String in by_role:
			var b: Batch = by_role[role]
			if b.points.is_empty(): continue
			var a := []
			a.resize(Mesh.ARRAY_MAX)
			a[Mesh.ARRAY_VERTEX] = b.points
			a[Mesh.ARRAY_NORMAL] = b.normals
			a[Mesh.ARRAY_COLOR] = b.colors
			# Recipe UV.x is a finish attribute, not a bitmap coordinate. The
			# outdoor shader samples the brush/grain in metres in local 3D space.
			a[Mesh.ARRAY_TEX_UV] = b.finishes
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
			var material: Material
			if outside:
				var ink := ShaderMaterial.new()
				ink.shader = Paint
				material = ink
			else:
				var ink := StandardMaterial3D.new()
				ink.vertex_color_use_as_albedo = true
				ink.roughness = .28 if role == "glazing" else .98 if role in ["masonry", "lining"] else .89
				ink.metallic_specular = .45 if role == "glazing" else .06
				material = ink
			material.resource_name = role
			mesh.surface_set_material(mesh.get_surface_count()-1, material)
			mesh.surface_set_name(mesh.get_surface_count()-1, role)
		var node := MeshInstance3D.new()
		node.name = label
		node.mesh = mesh
		parent.add_child(node)
		return node

static func make(p: Shape, outside: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "BuildingExterior" if outside else "Structure"
	root.set_meta("building_revision", p.source_revision)
	root.set_meta("authored_revision", p.authored_revision)
	root.set_meta("room_id", p.data.room_id)
	root.set_meta("net_footprint", p.inside.size)
	root.set_meta("storeys", p.floors.size())
	root.set_meta("wall_height", p.eave)
	var shell := root
	if outside:
		root.set_script(LOT)
		root.set("lot_id", StringName(p.data.building_id))
		root.set("door_width", float(p.door.width))
		shell = _node(root, "GroundDatum")
		shell.position = Vector3(p.origin.x, p.rise, p.origin.y)
	else:
		root.set_meta("upper_floor", p.upper)
	var collision := StaticBody3D.new()
	collision.name = "StructureCollision"
	collision.collision_mask = 0
	shell.add_child(collision)
	root.set_meta("wall_panel", p.wall_panel)
	var art := [Art.new(), Art.new()]
	var high_wall := Art.new()
	var partitions := {}
	for side in (4 if p.bay.is_empty() else 7):
		for level in p.floors.size():
			if side >= 4 and level == 0: continue
			var full: Art = art[0] if outside else Art.new()
			var section := Art.new()
			_walls(p, side, level, outside, full, collision)
			if not outside:
				_walls(p, side, level, false, section, null, true)
				partitions[Vector2i(side,level)] = [full,section]
			for o: Dictionary in p.openings:
				if o.gable or o.floor != level or o.side_index != side: continue
				_opening(p, o, outside, full, collision, shell)
				if not outside: _opening(p, o, false, section, null, null, true)
			if p.gabled(side) and (level == 0 or p.front_roof.is_empty()): _gable(p, side, outside, art[0] if outside else high_wall, collision)
	for o: Dictionary in p.openings:
		if o.gable: _opening(p, o, outside, art[0] if outside else high_wall, collision, shell)
	for divider: Dictionary in p.partitions:
		_partition(p, divider, art[0 if outside else divider.floor], collision, shell, outside)
	if not p.bay.is_empty(): _oriel(p, art[0 if outside else 1], collision, outside)
	_slab(p, Rect2(-p.width*.5, -p.depth*.5, p.width, p.depth), 0.0, p.rise + .09, art[0], collision, "GroundSlab", outside)
	if p.floors.size() == 2:
		var sections := _upper_sections(p)
		for i in sections.size():
			_slab(p, sections[i], p.upper, p.slab, art[0 if outside else 1], collision, "LoftSlab_%d" % i, outside)
		_stairs(p, art[0].get_layer("timber"), art[0 if outside else 1].get_layer("timber"), collision)
		_marker(shell, "StairFoot", Vector3(p.stair.x, 0, p.stair.bottom_z))
		_marker(shell, "StairHead", Vector3(p.stair.x, p.upper, p.stair.top_z))
	if p.front_roof.is_empty():
		_roof_collision(p, collision)
		if outside: p.roof.crown(art[0].get_layer("roof_tile"), p.color("roof"), p.color("fascia", p.color("timber").darkened(.12)))
	else:
		preload("res://source/building_front_roof.gd").make(p, art[0] if outside else high_wall, collision, outside)
	if outside:
		_chimney(p, art[0].get_layer("masonry"), collision)
		if not p.data.has("portico"): _stoop(p, art[0], collision, shell)
		# Delayed preload is unnecessary: details consume the Art interface, not Baker.
		preload("res://source/building_exterior_details.gd").make(p, art[0], shell, collision)
		art[0].attach(shell, "PaintedShell", true).add_to_group(&"clearing_extension_occluder", true)
	else:
		var views: Array[Node3D] = [art[0].attach(shell, "GroundCutaway", false)]
		if p.floors.size() == 2: views.append(art[1].attach(shell, "LoftCutaway", false))
		for key: Vector2i in partitions:
			var f := p.frame(key.x)
			var side := _node(views[key.y], "Wall_" + Shape.SIDES[key.x])
			side.set_meta("normal", f.basis.z)
			var near := f.basis.z.dot(Vector3(.5,0,.866)) > .0001
			partitions[key][0].attach(side,"Full",false).visible = not near
			partitions[key][1].attach(side,"Section",false).visible = near
		if not high_wall.by_role.is_empty(): high_wall.attach(shell, "RoofCutAwayFromView", false).hide()
		var daylight := _node(root, "WindowDaylight")
		for o: Dictionary in p.openings:
			if o.kind == "window": _daylight(p, o, daylight)
		var f := p.frame(0, p.door.u)
		var marker := _marker(root, "DoorAnchor", f.origin)
		marker.basis = f.basis
		marker.set_meta("passage_width", float(p.door.width))
		_marker(root, "Entry", f * Vector3(0, .004, -.57)).basis = f.basis
	for child in root.get_children():
		_own(child, root)
	return root

static func _own(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children(): _own(child, owner)

static func _node(parent: Node3D, label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	parent.add_child(node)
	return node

static func _marker(parent: Node3D, label: String, p: Vector3) -> Marker3D:
	var node := Marker3D.new()
	node.name = label
	node.position = p
	parent.add_child(node)
	return node

static func _collider(body: StaticBody3D, label: String, shape: Shape3D, transform := Transform3D.IDENTITY) -> void:
	var node := CollisionShape3D.new()
	node.name = label
	node.shape = shape
	node.transform = transform
	body.add_child(node, true)

static func _box(body: StaticBody3D, label: String, size: Vector3, center: Vector3, basis := Basis.IDENTITY) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	_collider(body, label, shape, Transform3D(basis, center))

static func _poly(body: StaticBody3D, label: String, points: PackedVector3Array) -> void:
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	_collider(body, label, shape)

static func _cuts(p: Shape, side: int, level: int, gable: bool) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for o in p.openings:
		if o.side_index == side and o.floor == level and o.gable == gable: result.append(o.rect)
	if side == 0 and level == 1 and not gable and not p.bay.is_empty(): result.append(p.bay_portal())
	return result

static func _wall_breaks(half: float, cuts: Array[Rect2]) -> Array[float]:
	var xs: Array[float] = [-half, half]
	for rect in cuts:
		if rect.position.x not in xs: xs.append(rect.position.x)
		if rect.end.x not in xs: xs.append(rect.end.x)
	return xs

static func _walls(p: Shape, side: int, level: int, outside: bool, art: Art, hit: StaticBody3D, section := false) -> void:
	var bottom := p.floors[level]
	var top := p.floors[level+1] if level+1 < p.floors.size() else p.eave
	var half := p.wall_span(side)*.5
	var f := p.frame(side, 0, 0, p.wall*.5)
	var cuts := _cuts(p, side, level, false)
	var xs := _wall_breaks(half, cuts)
	xs.sort()
	var parts: Dictionary = Parts.WALLS[p.wall_panel]
	var band := bottom + ((.27 if parts.plinth else .18) if outside and level == 0 else .55 if parts.plinth else .41)
	if p.data.has("portico") and outside and level == 0: band = .58
	var cap := bottom + (.31 if side == 0 else .36) if section else top
	var wall_ink := p.color("facade" if outside else "lining")
	var wood := p.color("timber" if outside else "interior_timber")
	var stone := p.color("stone")
	var panel_role := "facade" if outside else "lining"
	var base_role := "masonry" if outside and level == 0 or not outside and parts.plinth else "timber"
	var wall_role := "timber" if parts.boards else panel_role
	var base_ink := stone if base_role == "masonry" else wood.lightened(.13)
	var body_art := art.get_layer(wall_role)
	var base_art := art.get_layer(base_role)
	var beams := art.get_layer("timber")
	for i in xs.size() - 1:
		var u := (xs[i] + xs[i+1]) * .5
		var span := xs[i+1] - xs[i]
		var heights: Array[float] = [bottom, top]
		for r in cuts:
			if absf(u-r.get_center().x) < r.size.x*.5:
				heights.append(r.position.y)
				heights.append(r.end.y)
		heights.sort()
		for j in heights.size()-1:
			var low := heights[j]
			var high := heights[j+1]
			if high - low <= .0001: continue
			var center := Vector2(u, (low + high)*.5)
			if cuts.any(func(r: Rect2) -> bool: return r.has_point(center)): continue
			if hit != null:
				_box(hit, "Wall_%s_%d" % [Shape.SIDES[side], level], Vector3(span, high-low, p.wall), f * Vector3(center.x, center.y, 0), f.basis)
			# The section drops a little farther at the window's exact u range.
			# It does not extrude the sill up into the sightline.
			var cap_here := cap
			if section and cuts.any(func(r: Rect2) -> bool: return r.position.y > bottom and absf(u-r.get_center().x) < r.size.x*.5):
				cap_here -= .059
			var limit := minf(cap_here, high)
			Parts.panel(base_art, f, u, span, low, minf(limit, band), p.wall, base_ink)
			Parts.panel(body_art, f, u, span, maxf(low, band), limit, p.wall, wall_ink, float(parts.boards))
			if section and is_equal_approx(limit, cap_here) and limit > low:
				Parts.panel(beams, f, u, span, limit-.023, limit+.025, p.wall+.023, wood, 1)
			if outside and level == 0 and low < band:
				_masonry(p, base_art, f, xs[i], xs[i+1], minf(high, band), stone)
			if parts.boards:
				var z := (p.wall*.5+.013) * (1 if outside else -1)
				Parts.battens(body_art, f, xs[i], xs[i+1], maxf(low, band), limit, z, wall_ink)
			if not section:
				# Fit the rails into solid pieces only. No beam or trim crossing glazing.
				var rail_y := top-.085 if outside else bottom+.54
				if rail_y-.06 >= low and rail_y+.06 <= high:
					var z := p.wall*.5+.022 if outside else -p.wall*.5-.028
					Join.panel(beams, f, Vector3(u,rail_y,z), Vector3(span,.106,.099), wood,1)
				if (parts.framed or p.data.get("sign", "") == "guild") and not outside and high >= top - .003:
					Join.panel(beams, f, Vector3(u,high-.078,-p.wall*.5-.024), Vector3(span,.114,.080), wood,1)
				if parts.framed and outside and span > .56 and low <= bottom+.002 and high >= top-.002:
					Join.panel(beams, f, Vector3(u,(top+band)*.5,p.wall*.5+.032), Vector3(.102,top-band,.092), wood,1)
	if not section:
		var z := p.wall*.5+.028 if outside else -p.wall*.5-.030
		for s: float in [-1,1]:
			var x := s*(half-(.044 if outside else p.wall+.029))
			Join.panel(beams, f, Vector3(x,(bottom+top)*.5,z), Vector3(.127,top-bottom,.108), wood,1)
	if outside and level == 1 and side < 4:
		Join.panel(beams, p.frame(side), Vector3(0,bottom-.055,.050),Vector3(2*half+.07,.175,.172),wood.darkened(.10),1)

static func _masonry(p: Shape, art: Batch, f: Transform3D, a: float, b: float, y: float, ink: Color) -> void:
	if y < .115: return
	if p.data.has("portico"):
		for course in 2:
			var low := .005+course*.287
			var crest := minf(y,.286+course*.287)
			if crest-low < .04: continue
			var shift := .29*course
			for i in range(floori((a-shift)/.60),ceili((b-shift)/.60)):
				var l := maxf(a,i*.60+shift)+.009
				var r := minf(b,(i+1)*.60+shift)-.009
				if r-l < .03: continue
				Join.panel(art,f,Vector3((l+r)*.5,(low+crest)*.5,p.wall*.5+.023),Vector3(r-l,crest-low,.07),Batch.tone(ink,.117*sin(i*3.1+course*3.7+f.origin.z)))
		return
	for i in range(floori(a/.49), ceili(b/.49)):
		var left := maxf(a, i*.49) + .008
		var right := minf(b, (i+1)*.49) - .008
		if right-left < .024: continue
		Join.panel(art, f, Vector3((left+right)*.5, y*.5-.015, p.wall*.5+.018), Vector3(right-left,y+.010,.062), Batch.tone(ink,.132*sin(i*3.1+f.origin.z)))

static func _gable(p: Shape, side: int, outside: bool, art: Art, hit: StaticBody3D) -> void:
	var half := p.wall_span(side)*.5
	var cuts := _cuts(p, side, 0, true)
	var xs := _wall_breaks(half,cuts)
	for i in range(1, 24):
		var x := lerpf(-half,half,i/24.0)
		if not x in xs: xs.append(x)
	xs.sort()
	var f := p.frame(side,0,0,p.wall*.5)
	var barn: bool = Parts.WALLS[p.wall_panel].boards
	var rail := p.color("timber" if outside else "interior_timber")
	var ink := p.color("facade" if outside else "lining")
	var b := art.get_layer("timber" if barn else "facade" if outside else "lining")
	for i in xs.size()-1:
		var l := xs[i]; var r := xs[i+1]
		if r-l < .0001: continue
		var tl := p.gable_top(side,l); var tr := p.gable_top(side,r)
		var spans := PackedFloat32Array([p.eave,INF])
		var mid := (l+r)*.5
		for cut in cuts:
			if cut.position.x < mid and cut.end.x > mid: spans.append_array([cut.position.y,cut.end.y])
		spans.sort()
		for k in spans.size()-1:
			var low := spans[k]
			var high_l := minf(tl,spans[k+1]); var high_r := minf(tr,spans[k+1])
			if maxf(high_l,high_r) <= low+.001: continue
			var sample := Vector2(mid,(low+(high_l+high_r)*.5)*.5)
			if cuts.any(func(r: Rect2) -> bool: return r.has_point(sample)): continue
			var face := [Vector2(l,low),Vector2(r,low),Vector2(r,high_r),Vector2(l,high_l)]
			var points := PackedVector3Array()
			for s: float in [-1,1]:
				var poly := PackedVector3Array()
				for pt: Vector2 in face: poly.append(f * Vector3(pt.x, pt.y, s*p.wall*.5))
				points.append_array(poly)
				b.fan(poly, f.basis.z*s, Batch.tone(ink,.11*sin(i*3.73) if barn else .018*sin(i*4.3)), float(barn))
			_poly(hit,"Wall_%s_Gable" % Shape.SIDES[side],points)
	if outside:
		var wood := art.get_layer("timber")
		var outer := p.frame(side)
		Join.panel(wood,outer,Vector3(0,p.eave,.037),Vector3(half*2.0,.13,.106),rail,1)
		# The gable braces stop short of the region that can carry a light/vent.
		for s: float in [-1, 1]:
			Join.timber(wood,outer,Vector3(s*half*.91,p.eave+.02,.05),Vector3(s*half*.52,p.gable_top(side,s*half*.52)-.12,.05),Vector2(.095,.12),rail,1)

static func _swing_door(shell: Node3D, f: Transform3D, width: float, height: float, wall: float, wood: Color, ink: Color, stone: Color, kind: String) -> void:
	var mechanism := _node(shell, "ThresholdDoor")
	mechanism.transform = f
	mechanism.set_script(preload("res://world/interiors/structures/threshold_door.gd"))
	mechanism.set("passage_width", width)
	var pairs := kind == "double"
	var leaf_width := width * (.5 if pairs else 1.0)
	for side: int in ([-1, 1] if pairs else [-1]):
		var leaf := AnimatableBody3D.new()
		leaf.name = "LeftLeaf" if side < 0 else "RightLeaf"
		leaf.collision_mask = 0
		leaf.sync_to_physics = false
		leaf.position.x = side * width * .5
		leaf.set_meta("swing", -side)
		mechanism.add_child(leaf)
		var center := -side * leaf_width * .5
		var leaf_art := Art.new()
		var batch := leaf_art.get_layer("door_leaf")
		var frame := Transform3D(Basis.IDENTITY, Vector3(center, 0, 0))
		Join.panel(batch,frame,Vector3(0,height*.5,-.025),Vector3(leaf_width,height,.085),ink.darkened(.37),1)
		Join.entry(batch,frame,leaf_width,height,wood,ink,stone,kind == "arched",false,true,float(-side))
		leaf_art.attach(leaf, "PaintedLeaf", true)
		_box(leaf, "ClosedDoor", Vector3(leaf_width,height,.125), Vector3(center,height*.5,.02), Basis.IDENTITY)
	# A short render-only recess reads as black even from the elevated camera.
	# No ray/Walker collision is added inside the opening.
	var reveal := _node(shell, "BlackReveal")
	reveal.transform = f
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	var reach := maxf(wall+.08, leaf_width + .11)
	var start := wall + .012
	var middle := -(reach + start)*.5
	var run := reach - start
	_black_liner(reveal, black, Vector3(width+.07,height+.03,.022), Vector3(0,height*.5,-reach))
	_black_liner(reveal, black, Vector3(width+.07,.022,run), Vector3(0,.01,middle))
	_black_liner(reveal, black, Vector3(width+.07,.022,run), Vector3(0,height,middle))
	for side: int in [-1, 1]:
		_black_liner(reveal, black, Vector3(.022,height,run), Vector3(side*(width*.5+.027),height*.5,middle))

static func _black_liner(parent: Node3D, black: StandardMaterial3D, dimensions: Vector3, center: Vector3) -> void:
	var surface := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	surface.mesh = box
	surface.material_override = black
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.position = center
	parent.add_child(surface)

static func _opening(p: Shape, o: Dictionary, outside: bool, art: Art, hit: StaticBody3D, shell: Node3D, section := false) -> void:
	var f := p.opening_frame(o)
	var width: float = o.width
	var height: float = o.height
	if shell != null:
		var ref := _marker(shell, "Opening_" + o.id, f.origin)
		ref.basis = f.basis
		ref.set_meta("size", Vector2(width, height))
		ref.set_meta("wall", o.side)
		ref.set_meta("fraction", o.u / p.wall_span(o.side_index))
		ref.set_meta("storey", o.floor)
		ref.set_meta("sill", o.sill)
		ref.set_meta("kind", o.kind)
		ref.set_meta("component", o.get("component", p.data.get("entry_style", "arched")))
		ref.set_meta("cut_from_camera", o.gable and not outside)
	var wood := p.color("timber" if outside else "interior_timber")
	if o.kind != "door":
		if section: return # aperture, glazing collision and daylight are still present
		var trim := art.get_layer("timber")
		var sash := p.color("window_trim", wood)
		var size := Vector2(width, height)
		var glass := art.get_layer("glazing")
		var sill := art.get_layer("masonry" if outside and p.kind != "cabin" else "timber")
		var sill_color := p.color("stone").lightened(.20) if outside and p.kind != "cabin" else sash.lightened(.18)
		var parts: Dictionary = Parts.WINDOWS[o.component]
		Parts.sash(trim,glass,sill,f,size,p.wall,parts,sash,p.color("glass"),sill_color,outside)
		if parts.shutters and outside:
			Parts.shutters(trim,f,size,p.color("shutter",p.color("door")))
		if o.kind == "window" and hit != null:
			_box(hit, "Glazing_" + o.id, Vector3(width, height, .042), f * Vector3(0,height*.5,-p.wall*.5), f.basis)
		return
	var trim := art.get_layer("timber")
	if outside:
		var kind: String = p.data.get("entry_style", "arched")
		var door_ink := p.color("door")
		Join.entry_frame(trim,f,width,height,wood,p.color("stone"),kind == "arched")
		_swing_door(shell, f, width, height, p.wall, wood, door_ink, p.color("stone"), kind)
		if p.kind == "town":
			var hardware := art.get_layer("hardware")
			Join.panel(hardware,f,Vector3(.68,1.26,.16),Vector3(.17,.18,.062),Color("735350"))
			Join.panel(hardware,f,Vector3(.68,1.26,.20),Vector3(.095,.076,.035),Color("d1b785"))
	else:
		for s: float in [-1,1]:
			var jamb_height := .31 if section else height
			Join.panel(trim, f, Vector3(s*(width*.5+.03),jamb_height*.5,-.07), Vector3(.099,jamb_height,p.wall+.07),wood,1)
		Join.panel(trim, f, Vector3(0,-.010,-p.wall*.5), Vector3(width,.023,p.wall+.21),wood.lightened(.20),1)

static func _partition(p: Shape, d: Dictionary, art: Art, hit: StaticBody3D, shell: Node3D, outside: bool) -> void:
	var y := p.floors[d.floor]
	var f := Transform3D(Basis.IDENTITY, Vector3(0,y,d.at)) if d.axis == "x" else Transform3D(Basis(Vector3.UP,-PI*.5), Vector3(d.at,y,0))
	var stop: float = d.from
	var timber := art.get_layer("timber")
	var stain := p.color("interior_timber")
	var t: float = d.thickness
	for o: Dictionary in d.passages:
		var left: float = o.u-o.width*.5
		var right: float = o.u+o.width*.5
		_partition_panel(p, d, f, art, hit, stop, left, 0.0, outside)
		_partition_panel(p, d, f, art, hit, left, right, o.height, outside)
		var jamb: float = o.height if outside else .95
		for u: float in [left-.027, right+.027]:
			Join.panel(timber, f, Vector3(u,jamb*.5,0), Vector3(.054,jamb,t+.036), stain.darkened(.13), 1)
		Join.panel(timber, f, Vector3(o.u,.004,0), Vector3(o.width,.012,t+.055), stain.lightened(.20), 1)
		var peg := _marker(shell, "Portal_"+o.id, f*Vector3(o.u,0,0))
		peg.basis = f.basis
		peg.set_meta("size", Vector2(o.width,o.height))
		peg.set_meta("storey", int(d.floor))
		stop = right
	_partition_panel(p, d, f, art, hit, stop, d.to, 0.0, outside)

static func _partition_panel(p: Shape, d: Dictionary, f: Transform3D, art: Art, hit: StaticBody3D, left: float, right: float, bottom: float, outside: bool) -> void:
	var center := (left+right)*.5
	var width := right-left
	var top: float = d.height
	var t: float = d.thickness
	_box(hit, "Partition_"+d.id, Vector3(width,top-bottom,t), f*Vector3(center,(bottom+top)*.5,0), f.basis)
	# Dollhouse view drops the divider to desk height, never the body or
	# lintel. Solid walls and their genuinely empty passages stay physical.
	var cap := top if outside else minf(top, .73)
	if bottom >= cap: return
	var timber := art.get_layer("timber")
	var stain := p.color("interior_timber")
	Parts.panel(art.get_layer("lining"), f, center, width, bottom, cap, t, p.color("lining").darkened(.075))
	Parts.panel(timber, f, center, width, maxf(.0,bottom), minf(.102,cap), t+.024, stain, 1)
	Parts.panel(timber, f, center, width, maxf(cap-.056,bottom), cap, t+.044, stain.lightened(.06), 1)
	if width > .60 and bottom < .20:
		for u: float in [left+.08,right-.08]:
			Join.panel(timber, f, Vector3(u,cap*.5,0), Vector3(.070,cap,t+.030), stain, 1)

static func _daylight(p: Shape, o: Dictionary, parent: Node3D) -> void:
	var frame := p.opening_frame(o)
	var lamp := SpotLight3D.new()
	lamp.name = o.id
	lamp.position = frame * Vector3(0, float(o.height)*.53, -p.wall-.095)
	var height: float = o.sill + o.height*.53
	var drop := height + .075
	# The source is set just inside the glazing. The lit pool is down and
	# farther into the room from that specific sill, never aimed at the viewer.
	var reach := clampf(height*.94+.22, 1.15, 2.90)
	var inward := -frame.basis.z
	var direction := (inward*reach-Vector3.UP*drop).normalized()
	lamp.basis = Basis.looking_at(direction)
	lamp.spot_range = Vector2(drop, reach).length() + 1.20
	lamp.spot_angle = clampf(17.0 + float(o.width)*5.5, 18.0, 30.0)
	lamp.spot_attenuation = 1.35
	lamp.spot_angle_attenuation = .71
	lamp.light_color = Color("ffd9a8")
	lamp.light_specular = .10
	lamp.light_energy = 0.0
	lamp.shadow_enabled = true
	lamp.set_meta("storey", o.floor)
	lamp.set_meta("day_energy", clampf(1.34 + float(o.width*o.height)*.58, 1.44, 2.90))
	parent.add_child(lamp)

static func _upper_sections(p: Shape) -> Array[Rect2]:
	var i := p.inside
	var h := p.hole
	return [Rect2(i.position, Vector2(h.position.x-i.position.x, i.size.y)),
		Rect2(h.end.x, i.position.y, i.end.x-h.end.x, i.size.y),
		Rect2(h.position.x, i.position.y, h.size.x, h.position.y-i.position.y),
		Rect2(h.position.x, h.end.y, h.size.x, i.end.y-h.end.y)]

static func _slab(p: Shape, rect: Rect2, y: float, thick: float, art: Art, hit: StaticBody3D, label: String, outside: bool) -> void:
	if rect.size.x < .005 or rect.size.y < .005: return
	var c := rect.get_center()
	var size := Vector3(rect.size.x, thick, rect.size.y)
	var center := Vector3(c.x, y-thick*.5, c.y)
	if label == "LoftSlab_2":
		_box(hit, label, size - Vector3.BACK*STAIR_SEAM, center - Vector3.BACK*STAIR_SEAM*.5)
	else:
		_box(hit, label, size, center)
	if outside and y != 0.0: return # enclosed joists
	var floor_paint := p.color("floor")
	var finish: String = p.data.get("upper_floor_finish",p.floor_finish) if y > .0 else p.floor_finish
	var masonry := outside or finish != "boards"
	var b := art.get_layer("masonry" if masonry else "floor_boards")
	b.box(center, size, (p.color("stone") if outside else floor_paint).darkened(.24))
	if outside: return
	var tile := rect.intersection(p.inside)
	if not tile.has_area(): return
	var wide := .28 if finish == "boards" else .43 if finish == "flags" else .23
	var long := 1.22 if finish == "boards" else .61 if finish == "flags" else .42
	var rows := ceili(tile.size.x/wide)
	var w := tile.size.x / rows
	for row in rows:
		var x := tile.position.x + (row+.5)*w
		var start := tile.position.y
		var j := 0
		while start < tile.end.y-.012:
			var end := minf(tile.end.y, start + (long if j > 0 or row%2 == 0 else long*.52))
			var tint := Batch.tone(floor_paint, .13*sin(row*2.7+j*3.1))
			b.box(Vector3(x, y-.010, (start+end)*.5), Vector3(w-.010, .024, maxf(.003,end-start-.012)), tint, 0 if masonry else 1)
			start = end
			j += 1

static func _oriel(p: Shape, art: Art, hit: StaticBody3D, outside: bool) -> void:
	var rim := p.bay_rim()
	# The original main slab stops at the back rim. Extend both hit shapes
	# and deck art to the actual shallow, trapezoid bay without a step.
	var deck := PackedVector3Array()
	var top_deck := PackedVector3Array()
	for pt in rim:
		var a := pt + Vector3.UP*p.upper
		deck.append(a)
		deck.append(a - Vector3.UP*p.slab)
		top_deck.append(a + Vector3.UP*.002)
	_poly(hit,"OrielDeck",deck)
	# Close the wall-thickness strip between the clear rectangle and bay.
	# Its floor and collision share the same finished-floor height.
	var bridge := Rect2(rim[0].x,p.inside.end.y,rim[3].x-rim[0].x,p.wall+.002)
	_slab(p,bridge,p.upper,p.slab,art,hit,"OrielPortalFloor",outside)
	var boards := art.get_layer("timber" if outside else "floor_boards")
	var color := p.color("timber" if outside else "floor")
	if outside:
		boards.fan(top_deck,Vector3.UP,color,1)
		var bottom := PackedVector3Array()
		for pt in top_deck: bottom.append(pt-Vector3.UP*(p.slab+.002))
		boards.fan(bottom,Vector3.DOWN,color.darkened(.15),1)
		for i in 3: boards.quad(top_deck[i],top_deck[i+1],bottom[i+1],bottom[i],p.frame(i+4).basis.z,color,1)
	else:
		var n := ceili(p.bay.front/.27)
		for i in n:
			var t0 := (i+.012)/n
			var t1 := (i+.98)/n
			boards.quad(top_deck[0].lerp(top_deck[3],t0),top_deck[0].lerp(top_deck[3],t1),top_deck[1].lerp(top_deck[2],t1),top_deck[1].lerp(top_deck[2],t0),Vector3.UP,Batch.tone(color,.09*sin(i*4.6)),1)
	# Sloped cap follows the walls. The otherwise open south gable plane
	# above the connection is solid as on any main gable.
	var a := rim[1]+Vector3(-.09,p.eave+.034,.14)
	var b := rim[2]+Vector3(.09,p.eave+.034,.14)
	var c := rim[0]+Vector3(-.10,p.eave+.28,-.04)
	var d := rim[3]+Vector3(.10,p.eave+.28,-.04)
	_roof_panel(hit,"OrielRoof",[a,b,d,c])
	if outside:
		Trim.slope(art.get_layer("roof_tile"),a,b,c,d,p.color("roof"),p.color("timber"),4)
		var fascia := art.get_layer("timber")
		for i in 3:
			var l := rim[i]+Vector3.UP*(p.eave-.07)
			var r := rim[i+1]+Vector3.UP*(p.eave-.07)
			var ll := l+Vector3.UP*(.31 if i == 0 else .09)
			var rr := r+Vector3.UP*(.31 if i == 2 else .09)
			fascia.quad(l,r,rr,ll,p.frame(i+4).basis.z,p.color("timber"),1)

static func _stairs(p: Shape, ground: Batch, loft: Batch, hit: StaticBody3D) -> void:
	var s := p.stair
	var steps := int(s.steps)
	var run: float = s.bottom_z-s.top_z
	var x: float = s.x
	var width: float = s.width
	var west := x-width*.5
	var boards := p.color("floor")
	var wood := p.color("interior_timber")
	if p.data.has("portico"): boards = boards.lerp(wood,.48)
	var points := PackedVector3Array()
	for edge: float in [west, x+width*.5]:
		for z: float in [s.bottom_z, s.top_z]:
			var y: float = (s.bottom_z-z)*p.upper/run
			points.append(Vector3(edge, y, z))
			points.append(Vector3(edge, y-.12, z))
		var restart: float = s.top_z-STAIR_SEAM-.045
		points.append(Vector3(edge, p.upper, restart))
		points.append(Vector3(edge, p.upper-.12, restart))
	_poly(hit, "StairWalkSurface", points) # swept capsule walks over the tread noses
	for i in steps:
		var z: float = s.bottom_z - (i+.5)*run/steps
		var y := (i+.5)*p.upper/steps
		ground.box(Vector3(x, y-.069, z), Vector3(width, .138, run/steps+.013), Batch.tone(boards, .09*sin(i*3.2)), 1)
	var a := Vector3(west-.021, p.upper, s.top_z)
	var z_start: float = s.bottom_z-.51
	var b := Vector3(a.x, (s.bottom_z-z_start)*p.upper/run, z_start)
	for t: float in [0, .50, 1]:
		ground.box(a.lerp(b, t) + Vector3.UP*.43, Vector3(.068, .91, .073), wood, 1)
	ground.bar(a+Vector3.UP*.89, b+Vector3.UP*.89, .087, .075, wood, Vector3.RIGHT, 1)
	var fence := PackedVector3Array()
	for pt: Vector3 in [a, b]:
		for xd: float in [-.025, .025]:
			for y: float in [-.25, .92]: fence.append(pt+Vector3(xd, y, 0))
	_poly(hit, "StairBanister", fence)
	_rail(loft, hit, p.hole.position, Vector2(p.hole.position.x, p.hole.end.y), p.upper, wood)
	_rail(loft, hit, Vector2(p.hole.position.x, p.hole.end.y), p.hole.end, p.upper, wood)

static func _rail(art: Batch, hit: StaticBody3D, a: Vector2, b: Vector2, y: float, wood: Color) -> void:
	var from := Vector3(a.x, y, a.y)
	var to := Vector3(b.x, y, b.y)
	var count := maxi(1,ceili(a.distance_to(b)/.52))
	for i in count+1:
		art.box(from.lerp(to, float(i)/count)+Vector3.UP*.42, Vector3(.066, .85, .066), wood, 1)
	art.bar(from+Vector3.UP*.84, to+Vector3.UP*.84, .084, .075, wood, Vector3.UP, 1)
	_box(hit, "LoftGuard", Vector3(absf(b.x-a.x)+.055, .87, absf(b.y-a.y)+.055), (from+to)*.5+Vector3.UP*.435)

static func _roof_panel(hit: StaticBody3D, label: String, corners: Array) -> void:
	var points := PackedVector3Array()
	for pt: Vector3 in corners:
		points.append(pt)
		points.append(pt - Vector3.UP*.095)
	_poly(hit,label,points)

static func _roof_collision(p: Shape, hit: StaticBody3D) -> void:
	var roof := p.roof
	# These boundaries include the profile bends and match the rendered rows.
	for j in 10:
		var t0 := j/10.0
		var t1 := (j+1)/10.0
		for side: float in [-1,1]:
			_roof_panel(hit,"RoofPanel",[roof.on_roof(side,t0,-1),roof.on_roof(side,t0,1),roof.on_roof(side,t1,1),roof.on_roof(side,t1,-1)])
			if roof._inset(t1)-roof._inset(t0) > .0001:
				_roof_panel(hit,"RoofHip",[roof.on_roof(-1,t0,side),roof.on_roof(1,t0,side),roof.on_roof(1,t1,side),roof.on_roof(-1,t1,side)])

static func _stoop(p: Shape, art: Art, hit: StaticBody3D, shell: Node3D) -> void:
	var x: float = p.door.u
	var half: float = (p.door.width+.38)*.5
	var front := p.depth*.5
	var a := front-.035
	var b := front+float(p.data.get("stoop_landing",.36))
	var c := b+float(p.data.get("stoop_run",maxf(.72,p.rise*2.7)))
	var stone := p.color("stone")
	var masonry := art.get_layer("masonry")
	const SHOULDER := .40
	var points := PackedVector3Array()
	for s: float in [-1, 1]:
		var edge := x + s*half
		for yz: Vector2 in [Vector2(0,a),Vector2(0,b),Vector2(-p.rise,c),Vector2(-p.rise-.08,a),Vector2(-p.rise-.08,c)]:
			points.append(Vector3(edge, yz.x, yz.y))
		for z: float in [a, c]:
			points.append(Vector3(edge + s*SHOULDER, -p.rise, z))
			points.append(Vector3(edge + s*SHOULDER, -p.rise-.08, z))
	_poly(hit, "SlopedStoop", points)
	var cols := 5 if p.kind == "barn" else 3
	for j in 4:
		var z0 := a if j == 0 else lerpf(b, c, (j-1)/3.0)
		var z1 := b if j == 0 else lerpf(b, c, j/3.0)
		var y0 := -p.rise*maxf(0,(j-1)/3.0)+.004
		var y1 := -p.rise*j/3.0+.004
		for i in cols:
			var l := x + lerpf(-half, half, float(i)/cols) + .008
			var r := x + lerpf(-half, half, float(i+1)/cols) - .008
			masonry.quad(Vector3(l,y0,z0), Vector3(r,y0,z0), Vector3(r,y1,z1), Vector3(l,y1,z1), Vector3.UP, Batch.tone(stone,.23+.08*sin(i+j*2.5)))
		for s: float in [-1,1]:
			var edge := x+half*s
			var toe := edge+SHOULDER*s
			var k0 := lerpf(edge, toe, maxf(0,(j-1)/3.0))
			var k1 := lerpf(edge, toe, j/3.0)
			if j > 0: masonry.quad(Vector3(edge,y0,z0), Vector3(k0,y0,z0), Vector3(k1,y1,z1), Vector3(edge,y1,z1), Vector3.UP, stone.lightened(.18))
			var toe_y := -p.rise+.004
			masonry.quad(Vector3(k0,y0,z0), Vector3(toe,toe_y,z0), Vector3(toe,toe_y,z1), Vector3(k1,y1,z1), Vector3.UP, stone.lightened(.08))
	_marker(shell,"DoorAnchor",Vector3(x,0,front+.103))
	_marker(shell,"Landing",Vector3(x,0,b-.015))
	_marker(shell,"Approach",Vector3(x,-p.rise,c+.18))
	# The guild's portico supplies its own pair of lanterns.
	if p.kind in ["cabin", "smith"] or p.data.get("sign", "") == "guild": return
	var dx := x+(.92 if x<0.0 else -.87)
	if p.kind == "barn": dx = p.door.width*.5+.43
	if p.kind == "shop": dx = p.width*.469
	var lamp := Vector3(dx,1.85,front+.26)
	_marker(shell,"Lamp",lamp)
	Join.lantern(art.get_layer("hardware"),lamp)
	var glow := OmniLight3D.new()
	glow.position = lamp+Vector3(0,-.09,.23)
	glow.light_energy = 1.10
	glow.omni_range = 3.25
	glow.light_color = Color("ffd495")
	glow.visible = false
	glow.add_to_group(&"night_omni",true)
	shell.add_child(glow)

static func _chimney(p: Shape, art: Batch, hit: StaticBody3D) -> void:
	var style: String = p.data.get("chimney", "legacy")
	if style == "none": return
	var side := -1.0 if style == "left" or (p.roof.along_x and style == "right") else 1.0
	var along := (.46 if style == "right" else -.59) if p.roof.along_x else -.34
	var at := p.roof.on_roof(side,.62,along)
	var h := 1.80 if p.kind in ["town","cabin"] else 1.47
	var width := .63 if p.kind == "cabin" else .487
	var y := at.y-.47
	var stone := p.color("stone")
	var brick := stone.lerp(p.color("roof"),.31 if p.kind == "cabin" else .58)
	art.box(Vector3(at.x,y+h*.5,at.z),Vector3(width,h,width+.007),brick.darkened(.15))
	_box(hit,"MasonryStack",Vector3(width,h,width+.007),Vector3(at.x,y+h*.5,at.z))
	for row in 6:
		var row_y := y+(row+.5)*h/6.0
		for j: float in [-1,1]:
			var u := j*width*.235+(.013 if row%2 else -.015)
			var ink := Batch.tone(brick,.11*sin(row*2.4+j))
			art.box(Vector3(at.x+u,row_y,at.z+width*.515),Vector3(width*.443,h/6.0-.019,.034),ink)
			art.box(Vector3(at.x+width*.521,row_y,at.z+u),Vector3(.034,h/6.0-.019,width*.443),ink.darkened(.06))
	art.box(Vector3(at.x,y+h-.064,at.z),Vector3(width+.13,.13,width+.13),stone)
	art.box(Vector3(at.x,y+h+.056,at.z),Vector3(width+.07,.14,width+.077),brick.lightened(.148))
	art.box(Vector3(at.x,y+h+.131,at.z),Vector3(width*.64,.019,width*.68),Color("3b3437"))
