extends RefCounted
## Small offline mesh brush. Profiles keep the outline, pigment and rig separate.
## loft() sections: [longitudinal coordinate, Vector2(center), Vector2(radii), hex].
## For axis Y the profile plane is XZ; for Z it is XY. All measures are in meters.

var _pigments: Dictionary = {}
var _vertex_materials: Dictionary = {}

func pigment(hex: String, wet := false) -> StandardMaterial3D:
	var key := hex + ("_wet" if wet else "")
	if not _pigments.has(key):
		var m := StandardMaterial3D.new()
		m.resource_name = key
		m.albedo_color = Color(hex)
		m.roughness = 0.30 if wet else 0.93
		m.metallic_specular = 0.43 if wet else 0.16
		_pigments[key] = m
	return _pigments[key]

func vertex_pigment(wet := false) -> StandardMaterial3D:
	if not _vertex_materials.has(wet):
		var m := StandardMaterial3D.new()
		m.resource_name = "Glaze" if wet else "Painted Pigment"
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.32 if wet else 0.96
		m.metallic_specular = 0.42 if wet else 0.13
		_vertex_materials[wet] = m
	return _vertex_materials[wet]

func joint(parent: Node3D, label: String, at: Vector3, degrees := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = label
	parent.add_child(n)
	n.position = at
	n.rotation_degrees = degrees
	return n

func marker(parent: Node3D, label: String, at: Vector3) -> Marker3D:
	var n := Marker3D.new()
	n.name = label
	parent.add_child(n)
	n.position = at
	return n

func mesh(parent: Node3D, label: String, shape: Mesh, at := Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = label
	n.mesh = shape
	parent.add_child(n)
	n.position = at
	return n

func oval(parent: Node3D, label: String, at: Vector3, dim: Vector3, hex: String, degrees := Vector3.ZERO, sides := 10, wet := false) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radial_segments = sides
	m.rings = 5
	m.material = pigment(hex, wet)
	var n := mesh(parent, label, m, at)
	n.scale = dim
	n.rotation_degrees = degrees
	return n

func box(parent: Node3D, label: String, at: Vector3, dim: Vector3, hex: String, degrees := Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.material = pigment(hex)
	m.size = dim
	var n := mesh(parent, label, m, at)
	n.rotation_degrees = degrees
	return n

func link(parent: Node3D, label: String, a: Vector3, b: Vector3, base: float, tip: float, hex: String, sides := 7) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.bottom_radius = base
	m.top_radius = tip
	m.height = a.distance_to(b)
	m.radial_segments = sides
	m.rings = 0
	m.material = pigment(hex)
	var n := mesh(parent, label, m, (a + b) * 0.5)
	n.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return n

func surface() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

func triangle(st: SurfaceTool, p: Vector3, q: Vector3, r: Vector3, pn: Vector3, qn: Vector3, rn: Vector3, pc: Color, qc: Color, rc: Color) -> void:
	var cr := (q - p).cross(r - p)
	if cr.length_squared() < 0.00000000001:
		return
	_vertex(st, p, pn, pc)
	# Godot's front face is clockwise when viewed from the outside.
	if cr.dot(pn + qn + rn) > 0.0:
		_vertex(st, r, rn, rc)
		_vertex(st, q, qn, qc)
	else:
		_vertex(st, q, qn, qc)
		_vertex(st, r, rn, rc)

func _vertex(st: SurfaceTool, p: Vector3, n: Vector3, c: Color) -> void:
	st.set_normal(n.normalized())
	st.set_color(c)
	st.add_vertex(p)

func flat(st: SurfaceTool, p: Vector3, q: Vector3, r: Vector3, outward: Vector3, paint: Color) -> void:
	var n := (q - p).cross(r - p).normalized()
	if n.dot(outward) < 0.0:
		n = -n
	triangle(st, p, q, r, n, n, n, paint, paint, paint)

func finish(parent: Node3D, label: String, st: SurfaceTool, wet := false) -> MeshInstance3D:
	st.index()
	st.set_material(vertex_pigment(wet))
	var m := st.commit()
	m.resource_name = label
	return mesh(parent, label, m)

func _point(along: float, plane: Vector2, axis: int) -> Vector3:
	return Vector3(plane.x, along, plane.y) if axis == Vector3.AXIS_Y else Vector3(plane.x, plane.y, along)

func loft(parent: Node3D, label: String, rows: Array, sides: int, axis := Vector3.AXIS_Y, ripple := 0.0, wet := false, countershade := 0.0) -> MeshInstance3D:
	var rings: Array[PackedVector3Array] = []
	var colors: Array[PackedColorArray] = []
	var normals: Array[PackedVector3Array] = []
	for j in rows.size():
		var row: Array = rows[j]
		var c: Vector2 = row[1]
		var radius: Vector2 = row[2]
		var ring := PackedVector3Array()
		var tints := PackedColorArray()
		for k in sides:
			var phi := TAU * float(k) / sides
			var ellipse := Vector2(cos(phi), sin(phi))
			var rim := 1.0 + ripple * (sin(phi * 3.0 + j * 0.4) + 0.32 * cos(phi * 5.0 - j * 0.5))
			ring.append(_point(row[0], c + ellipse * radius * rim, axis))
			var tint := Color(row[3]).lightened(0.017 * sin(phi * 3.0 + j * 0.66))
			if countershade > 0.0:
				tint = tint.lerp(Color("c7b9a3"), countershade * smoothstep(0.02, 0.94, -ellipse.y))
			tints.append(tint)
		rings.append(ring)
		colors.append(tints)
	for j in rings.size():
		var around := PackedVector3Array()
		for k in sides:
			var tangent := rings[j][(k + 1) % sides] - rings[j][posmod(k - 1, sides)]
			var along := rings[mini(j + 1, rings.size() - 1)][k] - rings[maxi(0, j - 1)][k]
			var radial: Vector3 = rings[j][k] - _point(rows[j][0], rows[j][1], axis)
			var n := tangent.cross(along).normalized()
			around.append(n if n.dot(radial) >= 0.0 else -n)
		normals.append(around)
	var st := surface()
	for j in range(rings.size() - 1):
		for k in sides:
			var s := (k + 1) % sides
			triangle(st, rings[j][k], rings[j][s], rings[j+1][s], normals[j][k], normals[j][s], normals[j+1][s], colors[j][k], colors[j][s], colors[j+1][s])
			triangle(st, rings[j][k], rings[j+1][s], rings[j+1][k], normals[j][k], normals[j+1][s], normals[j+1][k], colors[j][k], colors[j+1][s], colors[j+1][k])
	var direction := 1.0 if rows.back()[0] > rows.front()[0] else -1.0
	for j in [0, rings.size() - 1]:
		var n := (Vector3.UP if axis == Vector3.AXIS_Y else Vector3.BACK) * direction * (-1.0 if j == 0 else 1.0)
		var c := _point(rows[j][0], rows[j][1], axis)
		for k in sides:
			flat(st, c, rings[j][k], rings[j][(k + 1) % sides], n, colors[j][k])
	return finish(parent, label, st, wet)

## A three-corner outline with two raised ridges: useful for ears, folded cloth and fur locks.
func fold(parent: Node3D, label: String, a: Vector3, b: Vector3, c: Vector3, front: Vector3, back: Vector3, light: String, dark: String) -> MeshInstance3D:
	var st := surface()
	var center := (a + b + c + front + back) / 5.0
	var edge: Array[Vector3] = [a, b, c]
	for i in 3:
		var p := edge[i]
		var q := edge[(i + 1) % 3]
		var shade := Color(light).lerp(Color(dark), 0.1 + float(i) * 0.21)
		flat(st, p, q, front, (p + q + front) / 3.0 - center, shade)
		flat(st, p, q, back, (p + q + back) / 3.0 - center, Color(dark))
	return finish(parent, label, st)
