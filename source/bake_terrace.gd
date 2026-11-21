extends "bake_land.gd"
## Offline only: --headless --path . --script res://source/bake_terrace.gd
const Profile = preload("res://art/terrace/terrain_profile.gd")
const DEST := "res://art/terrace/BanksideRise.tscn"
var drape := false

func _initialize() -> void:
	rng.seed = 502143
	land.name = "BanksideRise"
	ink.shader = load(DIR + "pigments.gdshader")
	ink.resource_name = "Dry pigments | stone and wildflowers"
	drape = true
	road(); foliage_patches(); markers(); stone_herbs()
	drape = false
	meadow()
	land.move_child(land.get_node("Meadow"), 0)
	rock("Shoulder_Split_Ledge", Vector2(3.12, 4.03), Vector3(.64,.69,.36), .19)
	rock("Shoulder_Cold_Slab", Vector2(2.57, 4.48), Vector3(.44,.44,.38), -.49)
	rock("Shoulder_Broken_Tooth", Vector2(2.24, 4.16), Vector3(.24,.29,.23), .81)
	rock("Shoulder_Fallen_Chip", Vector2(2.20, 4.97), Vector3(.25,.18,.18), .42)
	rock("Shoulder_Shard", Vector2(2.92, 4.60), Vector3(.14,.14,.12), -.28)
	rock("West_Bedding_Outcrop", Vector2(-5.18,1.30), Vector3(.69,.62,.48), -.51)
	rock("West_Bedding_Flake", Vector2(-5.71,1.83), Vector3(.32,.33,.23), .22)
	rock("West_Loose_Spall", Vector2(-6.01,2.14), Vector3(.19,.16,.17), -.31)
	stratum("Lane_West_Exposed_Bedding", Vector2(-3.30, 3.91), 1.52, .48)
	stratum("Lane_West_Fractured_End", Vector2(-3.38, 4.93), .45, .31)
	var target := DEST if "--replace" in OS.get_cmdline_user_args() or not FileAccess.file_exists(DEST) else Brush.unused_scene_path(DEST.trim_suffix(".tscn"))
	var scene := PackedScene.new()
	var err := scene.pack(land)
	if err == OK: err = ResourceSaver.save(scene, target)
	print(target, ": ", error_string(err))
	land.free()
	quit(0 if err == OK else 1)

func put(n: Node) -> void:
	if n is GeometryInstance3D: n.layers = 2
	if drape and n is MeshInstance3D and n.mesh:
		var a: Array = n.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var ids: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var b = Brush.new()
		var paved := String(n.name).begins_with("Handcut") or n.name == "Sandy_Grout"
		var raise_grout := .033 if n.name == "Sandy_Grout" else 0.0
		for k in range(0,ids.size(),3):
			var p := PackedVector3Array()
			for j in 3: p.append(v[ids[k+j]] + n.position + Vector3.UP * raise_grout)
			if paved:
				pave_tri(b, p[0],p[1],p[2], normals[ids[k]], colors[ids[k]])
			else:
				for j in 3: p[j].y += Profile.soil(p[j].x,p[j].z)
				b.tri(p[0],p[1],p[2],normals[ids[k]],normals[ids[k+1]],normals[ids[k+2]],colors[ids[k]],colors[ids[k+1]],colors[ids[k+2]])
		var old: String = n.mesh.resource_name
		var m: MeshInstance3D = b.bake(old, ink)
		n.mesh = m.mesh
		m.free()
		n.position = Vector3.ZERO
	land.add_child(n)
	n.owner = land

func pave_tri(b, a: Vector3, d: Vector3, c: Vector3, n: Vector3, pigment: Color) -> void:
	# Split all edges over the same length threshold, including the long, skinny
	# ears of the triangulated grout polygon and the flagstones' bevel faces.
	var lengths := Vector3(a.distance_squared_to(d),d.distance_squared_to(c),c.distance_squared_to(a))
	if lengths.x > .0484 and lengths.x >= maxf(lengths.y,lengths.z):
		var m := (a+d)*.5
		pave_tri(b,a,m,c,n,pigment); pave_tri(b,m,d,c,n,pigment)
	elif lengths.y > .0484 and lengths.y >= lengths.z:
		pave_tri(b,d,c,a,n,pigment)
	elif lengths.z > .0484:
		pave_tri(b,c,a,d,n,pigment)
	else:
		var center := (a+d+c)/3.0
		var dx := (Profile.soil(center.x+.0125,center.z)-Profile.soil(center.x-.0125,center.z))*40.0
		var dz := (Profile.soil(center.x,center.z+.0125)-Profile.soil(center.x,center.z-.0125))*40.0
		b.flat(lift(a), lift(d), lift(c), Vector3(n.x-dx*n.y,n.y,n.z-dz*n.y), pigment)

func lift(p: Vector3) -> Vector3:
	return p + Vector3.UP * Profile.soil(p.x,p.z)

func support(x: float, z: float) -> float:
	var y := Profile.soil(x,z)
	if x < -2.72 or x > 7.04 or z < -6.32 or z > 16.8: return y
	var p := Vector2(x,z)
	if not Geometry2D.is_point_in_polygon(p,outline): return y
	var dist2 := .22*.22
	for i in outline.size():
		dist2 = minf(dist2,p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p, outline[i], outline[(i+1)%outline.size()])))
	return y + .075 * smoothstep(0,.22,sqrt(dist2))

func grid(a: float,b: float) -> PackedFloat32Array:
	var result := PackedFloat32Array([-40., a-2., a-1.])
	for i in range(roundi((b-a)*8)+1): result.append(a+i*.125)
	result.append_array(PackedFloat32Array([b+1.,b+2.,40.]))
	return result

func meadow() -> void:
	var turf := ShaderMaterial.new()
	turf.shader = load(DIR + "meadow.gdshader")
	turf.resource_name = "Meadow | terrace pigments"
	var xs := grid(-6., 8.)
	var zs := grid(-8.,17.)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ground := PackedVector3Array()
	var walk := PackedVector3Array()
	var faces := PackedVector3Array()
	ground.resize(xs.size()*zs.size()); walk.resize(ground.size())
	for j in zs.size():
		for i in xs.size():
			var x := xs[i]; var z := zs[j]; var k := j*xs.size()+i
			ground[k] = Vector3(x, Profile.soil(x,z), z)
			walk[k] = Vector3(x, support(x,z), z)
	for j in zs.size()-1:
		for i in xs.size()-1:
			var k := j*xs.size()+i
			for idx in [k,k+1,k+xs.size()+1,k,k+xs.size()+1,k+xs.size()]:
				var p := ground[idx]
				st.set_uv(Vector2(p.x+40,p.z+40)/80.)
				st.add_vertex(p)
				faces.append(walk[idx])
	st.generate_normals()
	st.index(); st.set_material(turf)
	var g := MeshInstance3D.new()
	g.name = "Meadow"
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.mesh = st.commit(); put(g)
	var sc := ConcavePolygonShape3D.new()
	sc.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.name = "Continuous_Soil_And_Lane"; cs.shape = sc; put(cs)

func rock(label: String, p: Vector2, s: Vector3, turn: float) -> void:
	var b = Brush.new()
	var verts := PackedVector3Array()
	var base := Profile.soil(p.x,p.y)
	var lower := PackedVector3Array()
	var rim := PackedVector3Array()
	var top := PackedVector3Array()
	var n := rng.randi_range(5,7)
	for i in n:
		var a := TAU*i/n + rng.randf_range(-.14,.14)
		var o := (Vector3(cos(a)*s.x,0,sin(a)*s.z)*rng.randf_range(.78,1.06)).rotated(Vector3.UP,turn)
		var depth := Profile.soil(p.x+o.x,p.y+o.z)-base
		lower.append(o + Vector3.UP * (minf(-.11,depth-.08)))
		rim.append(o*rng.randf_range(.88,1.02) + Vector3.UP*(s.y*rng.randf_range(.27,.54)))
		top.append(o*rng.randf_range(.36,.79) + Vector3.UP*(s.y*rng.randf_range(.70,.96)))
	var crest := Vector3(-.2*s.x,s.y,.1*s.z).rotated(Vector3.UP,turn)
	for i in n:
		var j := (i+1)%n
		var outward := Vector3(rim[i].x+rim[j].x,.12,rim[i].z+rim[j].z)
		var dark := Color("777c72").lightened(rng.randf_range(-.08,.12))
		var facet := Color("98988a").lightened(rng.randf_range(-.16,.16))
		chip(b,lower[i],lower[j],rim[j],outward,dark)
		chip(b,lower[i],rim[j],rim[i],outward,dark.lightened(.065))
		chip(b,rim[i],rim[j],top[i],outward,facet)
		chip(b,rim[j],top[j],top[i],outward,facet.darkened(.11))
		chip(b,top[i],top[j],crest,Vector3.UP,facet.lightened(.11))
		if i == 1 or i == 3 and n == 7:
			var origin := (top[i]+top[j]+crest)/3.
			var offset := (top[j]-top[i]).cross(crest-top[i]).normalized()
			if offset.y < 0: offset = -offset
			for k in 3:
				var c := origin.lerp(crest,k*.22) + offset*.003
				var col := Color("a2aa7c") if k%2 == 0 else Color("778973")
				b.flat(c.lerp(top[i],.15),c.lerp(top[j],.24),c.lerp(crest,.19),offset,col)
	verts.append_array(lower); verts.append_array(rim); verts.append_array(top); verts.append(crest)
	var instance: MeshInstance3D = b.bake(label,ink)
	instance.position = Vector3(p.x,base,p.y)
	put(instance)
	var hull := ConvexPolygonShape3D.new(); hull.points = verts
	var hit := CollisionShape3D.new(); hit.name = label + "_Hull"; hit.shape = hull
	hit.position = instance.position; put(hit)

func chip(b,a:Vector3,d:Vector3,c:Vector3,outside:Vector3,col:Color) -> void:
	var n := (d-a).cross(c-a)
	if n.dot(outside) < 0.: n = -n
	b.flat(a,d,c,n,col)

# A thin outcrop, not a row of boulders: along-strike sections define a
# scarp, a narrow bedding seam and a low, buried upslope shoulder.
func stratum(label: String, p: Vector2, length: float, relief: float) -> void:
	var b = Brush.new()
	var base := Profile.soil(p.x,p.y)
	var points := PackedVector3Array()
	var stations := [-.55,-.39,-.07,.23,.49]
	var noses := [.08,.32,.38,.28,.13]
	var levels := [.26,.83,1.,.86,.49]
	for i in stations.size():
		var z: float = stations[i]*length
		var x: float = noses[i]
		var r: float = levels[i]*relief
		var grade := Profile.soil(p.x+x,p.y+z)-base
		var tucked := Profile.soil(p.x-.60,p.y+z)-base
		points.append(Vector3(x-.10,grade-.105,z))
		points.append(Vector3(x,grade+r*.36,z))
		points.append(Vector3(x-.045,grade+r*.46,z+.023))
		points.append(Vector3(x-.15,grade+r,z-.035))
		points.append(Vector3(-.34,grade+r*.81,z-.055))
		points.append(Vector3(-.60,tucked-.10,z))
	var palette := [Color("747a79"),Color("a1998c"),Color("858a88"),Color("a5a394"),Color("82867a")]
	for i in stations.size()-1:
		for k in 5:
			var a := i*6+k
			var d := a+6
			var outward := Vector3.RIGHT if k < 3 else Vector3.UP
			var tint: Color = palette[k].lightened(.025 if i%2 == 1 else -.028)
			chip(b,points[a],points[d],points[d+1],outward,tint)
			chip(b,points[a],points[d+1],points[a+1],outward,tint.lightened(.045))
			if k == 3 and i%2 == 0:
				var u := points[a]
				var v := points[d+1]
				var w := points[a+1]
				var n := (v-u).cross(w-u).normalized()
				if n.y < 0: n = -n
				var slip := n*.003
				b.flat(u.lerp(v,.15)+slip,u.lerp(v,.64)+slip,u.lerp(w,.54)+slip,n,Color("818a64"))
	for k in range(1,5):
		chip(b,points[0],points[k],points[k+1],Vector3.FORWARD,Color("7d817c").lightened(k*.018))
		var end := (stations.size()-1)*6
		chip(b,points[end],points[end+k],points[end+k+1],Vector3.BACK,Color("898478").lightened(k*.016))
	var node: MeshInstance3D = b.bake(label,ink)
	node.position = Vector3(p.x,base,p.y)
	put(node)
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var blocker := CollisionShape3D.new()
	blocker.name = label + "_Hull"
	blocker.position = node.position
	blocker.shape = shape
	put(blocker)
