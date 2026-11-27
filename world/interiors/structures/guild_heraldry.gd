extends RefCounted
## The same crossed-sword mark goes on wood, cloth and woven wool.
const Batch := preload("res://art/building_trial/mesh_batch.gd")
const BLUE := Color("415572")
const EDGE := Color("bb9156")
const IVORY := Color("fae2ad")

static func shield(b: Batch, at: Vector3, width: float, height: float) -> void:
	var points := [Vector2(-.49,.37), Vector2(-.32,.43), Vector2(0,.50), Vector2(.32,.43), Vector2(.49,.37), Vector2(.44,-.13), Vector2(.31,-.34), Vector2(0,-.52), Vector2(-.31,-.34), Vector2(-.44,-.13)]
	for layer in [[1.065, .0, Color("51372a")], [1.0, .035, EDGE], [.84, .070, BLUE]]:
		var ring := PackedVector3Array()
		for pt: Vector2 in points:
			ring.append(at+Vector3(pt.x*width*layer[0], pt.y*height*layer[0], layer[1]))
		b.fan(ring, Vector3.BACK, layer[2])
	swords(b, at+Vector3(0,0,.088), minf(width,height)*.76)

static func swords(b: Batch, at: Vector3, size: float, face := Basis.IDENTITY) -> void:
	for side: float in [-1,1]:
		var axis := Vector2(side,.92).normalized()
		var cross := Vector2(-axis.y,axis.x)
		var outline := [axis*.53, axis*.38+cross*.051, -axis*.19+cross*.058, -axis*.19-cross*.058, axis*.38-cross*.051]
		var vertices := PackedVector3Array()
		for v: Vector2 in outline: vertices.append(at+face*Vector3(v.x*size,v.y*size,.002*side))
		b.fan(vertices, face.z, IVORY if side > 0 else IVORY.darkened(.11))
		var guard := -axis*.23
		_bar(b, at, face, (guard+cross*.144)*size, (guard-cross*.144)*size, size*.062, EDGE.lightened(.18))
		_bar(b, at, face, -axis*.43*size, guard*size, size*.077, IVORY.darkened(.19))

static func _bar(b: Batch, at: Vector3, face: Basis, a: Vector2, c: Vector2, width: float, ink: Color) -> void:
	b.bar(at+face*Vector3(a.x,a.y,.009), at+face*Vector3(c.x,c.y,.009), width, .014, ink, face.z)
