@tool
extends RefCounted
## A flat-shaded, vertex-painted batch. Normals and clockwise winding are explicit;
## hundreds of little tile courses and stone faces are still one draw per batch.

var points := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var finishes := PackedVector2Array()

func tri(a: Vector3, b: Vector3, c: Vector3, toward: Vector3, ink: Color, finish := 0.0) -> void:
	var n := (c - a).cross(b - a)
	if n.length_squared() < 1e-12:
		return
	if n.dot(toward) < 0.0:
		var swap := b
		b = c
		c = swap
		n = -n
	n = n.normalized()
	for p in [a, b, c]:
		points.append(p)
		normals.append(n)
		colors.append(ink)
		finishes.append(Vector2(finish, 0.0))

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ink: Color, finish := 0.0) -> void:
	tri(a, b, c, n, ink, finish)
	tri(a, c, d, n, ink, finish)

func fan(p: PackedVector3Array, n: Vector3, ink: Color, finish := 0.0) -> void:
	for i in range(1, p.size() - 1):
		tri(p[0], p[i], p[i + 1], n, ink, finish)

func box(p: Vector3, size: Vector3, ink: Color, finish := 0.0, axes := Basis.IDENTITY) -> void:
	var x := axes.x * size.x * 0.5
	var y := axes.y * size.y * 0.5
	var z := axes.z * size.z * 0.5
	quad(p-x-y+z, p+x-y+z, p+x+y+z, p-x+y+z, z, ink, finish)
	quad(p+x-y-z, p-x-y-z, p-x+y-z, p+x+y-z, -z, ink.darkened(0.07), finish)
	quad(p+x-y+z, p+x-y-z, p+x+y-z, p+x+y+z, x, ink.darkened(0.045), finish)
	quad(p-x-y-z, p-x-y+z, p-x+y+z, p-x+y-z, -x, ink.darkened(0.045), finish)
	quad(p-x+y+z, p+x+y+z, p+x+y-z, p-x+y-z, y, ink.lightened(0.09), finish)
	quad(p-x-y-z, p+x-y-z, p+x-y+z, p-x-y+z, -y, ink.darkened(0.19), finish)

func bar(a: Vector3, b: Vector3, width: float, thickness: float, ink: Color, back := Vector3.BACK, finish := 0.0) -> void:
	var y := (b - a).normalized()
	var x := y.cross(back).normalized()
	if x.length_squared() < 0.25:
		x = y.cross(Vector3.RIGHT).normalized()
	box((a + b) * 0.5, Vector3(width, a.distance_to(b), thickness), ink, finish, Basis(x, y, x.cross(y)))

func lathe(p: Vector3, axis: Vector3, profile: PackedVector2Array, sides: int, ink: Color, finish := 0.0) -> void:
	# Profile is (axis distance, radius). Close with zero-radius rows where needed.
	var n := axis.normalized()
	var u := n.cross(Vector3.UP).normalized() if absf(n.y) < 0.9 else Vector3.RIGHT
	var v := n.cross(u)
	for i in sides:
		var a := TAU * float(i) / float(sides)
		var b := TAU * float(i + 1) / float(sides)
		var d := u * cos(a) + v * sin(a)
		var e := u * cos(b) + v * sin(b)
		var c := tone(ink, 0.055 * sin(a * 2.0 + 0.8))
		for j in range(profile.size() - 1):
			var low := profile[j]
			var high := profile[j + 1]
			var out := (d + e) * (high.x - low.x) + n * (low.y - high.y)
			quad(p+n*low.x+d*low.y, p+n*low.x+e*low.y, p+n*high.x+e*high.y, p+n*high.x+d*high.y, out, c, finish)

func roller(p: Vector3, axis: Vector3, length: float, radius: float, sides: int, ink: Color, finish := 0.0) -> void:
	var h := length * 0.5
	lathe(p, axis, PackedVector2Array([Vector2(-h, 0), Vector2(-h, radius), Vector2(h, radius), Vector2(h, 0)]), sides, ink, finish)

func add_to(parent: Node3D, label: String, material: Material, shadows := true) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = finishes
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	if not shadows:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func tone(c: Color, t: float) -> Color:
	return Color(clampf(c.r * (1.0 + t), 0.0, 1.0), clampf(c.g * (1.0 + t), 0.0, 1.0), clampf(c.b * (1.0 + t), 0.0, 1.0))
