extends RefCounted
## Width is full width in local metres. The path and terrain retain all gameplay authority.
enum Surface { CART_EARTH, FOOT_EARTH }
const SOIL := preload("road_soil.tres")

static func paint(path: Path3D, width: float, surface: Surface) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	path.add_child(view)
	if path.curve == null or path.curve.point_count < 2 or width <= 0: return view
	var rows := PackedVector3Array()
	for p in path.curve.tessellate(6, 3.0):
		if rows.is_empty() or rows[-1].distance_squared_to(p) > .000001: rows.append(p)
	if rows.size() < 2: return view
	var verts := PackedVector3Array(); var norms := PackedVector3Array(); var uv := PackedVector2Array(); var indices := PackedInt32Array()
	for i in rows.size():
		var a := (rows[i]-rows[maxi(0,i-1)]).normalized()
		var b := (rows[mini(rows.size()-1,i+1)]-rows[i]).normalized()
		if i == 0: a = b
		if i == rows.size()-1: b = a
		var axis := (a+b).normalized()
		var side := axis.cross(Vector3.UP) * (.5*width/maxf(.55,axis.dot(a)))
		for sign_x: float in [-1.,1.]:
			verts.append(rows[i]+sign_x*side+Vector3.UP*.023); norms.append(Vector3.UP); uv.append(Vector2(sign_x,float(surface)))
		if i > 0:
			var j := i*2
			indices.append_array([j-2,j+1,j-1,j-2,j,j+1])
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=verts; arrays[Mesh.ARRAY_NORMAL]=norms; arrays[Mesh.ARRAY_TEX_UV]=uv; arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); mesh.surface_set_material(0,SOIL); view.mesh=mesh
	return view
