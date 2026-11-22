extends "bake_terrace.gd"
## Offline only. Never rebakes or rewrites BanksideRise.
## godot --headless --path . --script res://source/bake_clearing_outskirts.gd
const Survey := preload("res://world/outskirts/outskirts_profile.gd")
const OUTPUT := "res://art/terrace/SouthVerge.tscn"
const GRIT := Color("ac9c73")
const EDGE := Color("9a9e60")
const SETTS: Array[Color] = [Color("c7bd9f"), Color("bcb7a1"), Color("d0c6a9"), Color("b8b2a1"), Color("c8c0aa"), Color("b9b9a2")]

func _initialize() -> void:
	rng.seed = 285041
	land.name = "SouthVerge"
	ink.shader = preload("res://art/woods/pigments.gdshader")
	ink.resource_name = "Dry pigments | south lane"
	_rolling_meadow()
	var track := PackedVector2Array()
	var widths := PackedFloat32Array()
	for i in range(5, Survey.ROUTE.size()):
		track.append(Survey.ROUTE[i])
		widths.append(Survey.WIDTH[i])
	_strip("Cart_Lane_And_Stone_Street", track, widths)
	_strip("Stone_Street_Alley", PackedVector2Array(Survey.ALLEY), PackedFloat32Array([1.62, 1.55, 1.36, 1.08]), true)
	var alley_border := outline
	# Old pavers end on a diagonal at z∼16.5. Sparse, gently lowered stone beyond
	# their edge fades into the wheel-worn earth, not into a second road mesh.
	outline = _outline(PackedVector2Array([Vector2(2.12,16.98), Vector2(3.12,18.33), Vector2(5.20,20.48)]), [.96, 1.92, 1.32])
	_cut_setts(outline, Rect2(.6, 16.25, 6.1, 4.7), .85, .72, [], func(p: Vector2) -> bool:
		return p.y >= 16.98 and rng.randf() > smoothstep(17.5, 21.0, p.y)*.87)
	var street_border := _outline(track.slice(17), [2.05, 2.55, 3.31, 3.82, 4.22, 4.16])
	var joined := Geometry2D.merge_polygons(street_border,alley_border)
	if joined.size()!=1:
		push_error("Expect the alley and main street to share a single cut stone boundary.")
		land.free()
		quit(1)
		return
	_cut_setts(joined[0], Rect2(17.0, 62.2, 20.7, 15.6), .76, .64, SETTS, func(p: Vector2) -> bool:
		var paving := smoothstep(65.0,71.8,p.y)
		if Geometry2D.is_point_in_polygon(p,alley_border): paving = maxf(paving,.82)
		return rng.randf() < lerpf(.30,1.0,paving))
	_habitats()
	_wild_edges()
	var target := OUTPUT
	if FileAccess.file_exists(target) and not "--replace" in OS.get_cmdline_user_args():
		target = Brush.unused_scene_path(OUTPUT.trim_suffix(".tscn"))
	var packed := PackedScene.new()
	var err := packed.pack(land)
	if err == OK:
		err = ResourceSaver.save(packed, target)
	print(target, ": ", error_string(err))
	land.free()
	quit(int(err != OK))

func surface(x: float, z: float) -> float:
	return Survey.surface(Vector2(x,z))

func _rolling_meadow() -> void:
	var turf := ShaderMaterial.new()
	turf.shader = preload("res://art/woods/meadow.gdshader")
	turf.resource_name = "Meadow | southern shoulders"
	var xs := PackedFloat32Array([-50., -22., -10., -4.])
	for x in range(-2, 45):
		xs.append(x)
	xs.append_array(PackedFloat32Array([47., 53., 65.]))
	var zs := PackedFloat32Array()
	for z in range(int(Survey.JOIN_Z), 88):
		zs.append(z)
	zs.append_array(PackedFloat32Array([90., 94., 100., 111.]))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid_points := PackedVector3Array()
	var faces := PackedVector3Array()
	for z in zs:
		for x in xs:
			grid_points.append(Vector3(x, surface(x,z), z))
	for j in zs.size()-1:
		for i in xs.size()-1:
			var k := j*xs.size()+i
			for idx in [k,k+1,k+xs.size()+1,k,k+xs.size()+1,k+xs.size()]:
				var p := grid_points[idx]
				st.add_vertex(p)
				faces.append(p)
	st.generate_normals()
	st.index()
	st.set_material(turf)
	var meadow_view := MeshInstance3D.new()
	meadow_view.name = "Meadow"
	meadow_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	meadow_view.mesh = st.commit()
	put(meadow_view)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var floor_hit := CollisionShape3D.new()
	floor_hit.name = "Dry_Grade_Collision"
	floor_hit.shape = shape
	put(floor_hit)

func _cross_section(path: PackedVector2Array, i: int, t: float) -> Vector2:
	return path[i].cubic_interpolate(path[i+1], path[maxi(i-1,0)], path[mini(i+2,path.size()-1)], t)

# Product of the survey centerline, not a row of tiles. Both the stroke and
# chip cutters use the curve's tangent so the old road grows into a bend.
func _stations(path: PackedVector2Array, widths: Array) -> Array[Vector4]:
	var result: Array[Vector4] = []
	for i in path.size()-1:
		var steps := maxi(1, ceili(path[i].distance_to(path[i+1])/.43))
		for j in range(steps + int(i == path.size()-2)):
			var t := float(j)/steps
			var p := _cross_section(path, i, t)
			var heading := _cross_section(path, i, minf(t+.018,1.0)) - _cross_section(path,i,maxf(t-.018,0.0))
			var half := lerpf(widths[i], widths[i+1], t)*.5
			var edge := heading.normalized().orthogonal()*half
			result.append(Vector4(p.x,p.y,edge.x,edge.y))
	return result

func _outline(path: PackedVector2Array, widths: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	var rows := _stations(path, widths)
	for r in rows:
		points.append(Vector2(r.x+r.z,r.y+r.w))
	rows.reverse()
	for r in rows:
		points.append(Vector2(r.x-r.z,r.y-r.w))
	return points

func _strip(label: String, path: PackedVector2Array, widths: PackedFloat32Array, alley := false) -> void:
	var rows: Array[PackedVector3Array] = []
	var stations := _stations(path, Array(widths))
	var cuts := [-1., -.81, -.56, -.20, .17, .50, .79, 1.]
	for i in stations.size():
		var r := stations[i]
		var row := PackedVector3Array()
		for j in cuts.size():
			var wobble := .04 * sin(i*1.67+j*2.83) + .053 * sin(i*.67+j*.88)
			var side: float = cuts[j] + wobble
			var p := Vector2(r.x+r.z*side,r.y+r.w*side)
			row.append(at(p,.014 if not alley else .018))
		rows.append(row)
	var brush := Brush.new()
	for i in rows.size()-1:
		for j in cuts.size()-1:
			var a := rows[i][j]; var b := rows[i][j+1]
			var c := rows[i+1][j+1]; var d := rows[i+1][j]
			var p := (a+b+c+d)*.25
			var stone := 1.0 if alley else smoothstep(65.2,73.6,p.z)
			var at_edge := j in [0,cuts.size()-2]
			var ink_color := EDGE if at_edge else (Color("b6a57d") if j in [2,4] else GRIT)
			ink_color = ink_color.lerp(Color("aaa28b") if not at_edge else Color("999878"), stone * (.65 if at_edge else .92))
			var variation := .044*sin(p.x*3.59+p.z*2.17) + .025*sin(p.x*.62-p.z*1.74)
			ink_color = ink_color.lightened(variation)
			pave_tri(brush,a,b,c,Vector3.UP,ink_color)
			pave_tri(brush,a,c,d,Vector3.UP,ink_color.lightened(.018*sin(i*1.62+j)))
	var mesh: MeshInstance3D = brush.bake(label, ink)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	put(mesh)
	outline = _outline(path, Array(widths))

func _cut_setts(border: PackedVector2Array, bounds: Rect2, spacing_x: float, spacing_z: float, palette: Array[Color], filter := Callable()) -> void:
	outline = border
	var seeds := PackedVector2Array()
	for row in ceili(bounds.size.y/spacing_z)+1:
		for column in ceili(bounds.size.x/spacing_x)+1:
			seeds.append(bounds.position+Vector2((column+.30*(row%2))*spacing_x+rng.randf_range(-.16,.16),row*spacing_z+rng.randf_range(-.14,.14)))
	drape = true
	flagstones(seeds,.038,.053,.019,.016,filter,palette)
	drape = false
	var cut := land.get_child(-1) as MeshInstance3D
	cut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _habitats() -> void:
	for i in Survey.HABITATS.size():
		var p: Vector2 = Survey.HABITATS[i]
		var b := Brush.new()
		var rings := PackedVector2Array()
		for j in 17:
			var a := TAU*j/17.0
			var radius := 1.0+.11*sin(a*3.0+i)+.09*cos(a*7.0-i)
			rings.append(p+Vector2(cos(a)*1.89,sin(a)*1.41)*radius)
		var ink_color: Color = Survey.HABITAT_SOILS[i]
		for j in rings.size():
			pave_tri(b,at(p,.013),at(rings[j],.013),at(rings[(j+1)%rings.size()],.013),Vector3.UP,ink_color.lightened(.05*sin(j*2.36)))
		for j in 32:
			var a := rng.randf()*TAU
			var r := sqrt(rng.randf_range(.13,1.0))
			var g := p+Vector2(cos(a)*1.8,sin(a)*1.26)*r
			var step := Vector2.from_angle(a)*rng.randf_range(.04,.13)
			b.flat(lift(at(g-step.orthogonal(),.024)),lift(at(g+step,.028)),lift(at(g+step.orthogonal(),.024)),Vector3.UP,ink_color.lightened(rng.randf_range(-.11,.16)))
		var patch: MeshInstance3D = b.bake("Habitat_%d_Dry_Litter" % (i+1),ink)
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		put(patch)
		rock("Habitat_%d_Split_Stone" % (i+1),p+Vector2(-1.88,-.62),Vector3(.68,.44,.49),.46*i)
		rock("Habitat_%d_Chips" % (i+1),p+Vector2(-1.19,-1.44),Vector3(.36,.23,.30),-.28*i)

func _wild_edges() -> void:
	# Beds are composed, not a carpet: sunny shoulders and woodland groups
	# repeat the original ferns, grass blades and few bright petals.
	var beds := [Vector2(-1.73,15.46),Vector2(3.84,16.78),Vector2(-.96,19.82),Vector2(2.67,22.72),
		Vector2(7.43,24.49),Vector2(8.68,27.53),Vector2(14.98,28.76),Vector2(19.03,29.03),
		Vector2(23.05,32.37),Vector2(17.92,34.21),Vector2(12.64,34.37),Vector2(12.18,38.39),
		Vector2(18.86,40.44),Vector2(12.60,41.02),Vector2(8.69,43.25),Vector2(16.11,45.89),
		Vector2(7.12,47.26),Vector2(10.27,49.71),Vector2(17.82,49.92),Vector2(20.31,53.42),
		Vector2(12.11,53.57),Vector2(10.12,56.78),Vector2(18.63,55.01),Vector2(22.96,58.69),
		Vector2(12.09,59.74),Vector2(15.27,63.15),Vector2(21.86,64.26),Vector2(18.86,69.68),
		Vector2(22.91,74.54),Vector2(27.30,77.13),Vector2(35.81,77.17),Vector2(36.99,71.64)]
	drape = true
	for i in beds.size():
		var center: Vector2 = beds[i]
		var b := Brush.new()
		for j in rng.randi_range(10,18):
			var a := rng.randf()*TAU
			var p := center + Vector2(cos(a)*1.52,sin(a)*1.10)*sqrt(rng.randf())
			var distance := p.distance_to(Survey.nearest_track(p))
			if distance < (2.6 if p.y>68.0 else 1.61): continue
			var c: Color = [Color("719949"),Color("7b9d49"),Color("8da955"),Color("71974f")][(i+j)%4]
			tuft(b,at(p,.012),rng.randf_range(.75,1.15),c)
			if j%5 == 0:
				flower(b,at(p,.014),Color("fff1bd") if i%3 == 0 else Color("b8aed9"),rng.randf_range(.83,1.17))
		if i%3 != 1:
			bracken(b,at(center,.012),rng.randf_range(1.0,1.36))
		put(b.bake("South_Wild_Border_%02d" % (i+1),ink))
	drape = false
	rock("South_Long_Worn_Gatepost",Vector2(-1.80,13.85),Vector3(.43,.64,.34),.51)
	rock("South_Gatepost_Chips",Vector2(-1.42,14.33),Vector3(.33,.22,.21),-.12)
	rock("Fordless_Bedding",Vector2(12.88,41.51),Vector3(.52,.46,.39),-.38)
	rock("Upper_Bluff",Vector2(11.48,62.88),Vector3(1.26,.94,.71),.37)
	rock("Upper_Bluff_Chip",Vector2(12.88,62.42),Vector3(.63,.39,.39),-.59)
