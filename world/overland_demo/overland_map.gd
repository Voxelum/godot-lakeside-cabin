extends Node3D
## One resident World3D. A single floor supports all sectors; ground decoration
## is batched in strips for renderer frustum culling, not loading/unloading.
const Kit := preload("res://art/building_trial/trial_site.gd")
const Site := preload("res://world/overland_demo/integrated_site.gd")
const Batch := preload("res://art/building_trial/mesh_batch.gd")
const Props := preload("res://art/building_trial/street_props.gd")
const Specimen := preload("res://world/overland_demo/specimen.gd")
const VILLAGE := preload("res://art/building_trial/VillageLane.tscn")
const TOWN := preload("res://art/building_trial/TownCorner.tscn")
const BOUNDS := Rect2(-78, -33, 156, 63)
const VILLAGE_AT := Vector2(-40, 6)
const TOWN_AT := Vector2(55, 0)
const WEST_PATH := [Vector2(-71.3, 12.6), Vector2(-69, 12.35), Vector2(-65, 12.3), Vector2(-62, 10.1), Vector2(-58.65, 8.49)]
const FOREST_PATH := [Vector2(-21.42, 7.26), Vector2(-17, 6.35), Vector2(-13, 3.8), Vector2(-9, -.6), Vector2(-4, -4.8), Vector2(0, -8), Vector2(6, -10.65), Vector2(11, -11.05), Vector2(17, -9.60), Vector2(23, -7.3), Vector2(27, -5.7), Vector2(31, -2.36), Vector2(34, .92), Vector2(36.40, 1.49)]
const RETURN_MARK := Vector2(70.0, -.02)
# An easy place to stand off the trail, facing the specimen across open ground.
const VIEWING := [Vector2(-9.0, -2.36), Vector2(6.7, -11.95), Vector2(22.65, -8.44)]
const FIELD_INK := Color("8b9970")
const ROAD_EDGE := Color("9f8d67")
const ROAD_INK := Color("b29b74")
const SIGN_INK := Color("d9ac64")

@onready var player: CharacterBody3D = $Traveler
@onready var camera: Camera3D = $Camera
var village: Site
var town: Site
var specimens: Array[Specimen] = []
var _body: StaticBody3D
var _kit: Kit
var _paint := ShaderMaterial.new()
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	village = _place(VILLAGE, VILLAGE_AT, 0)
	town = _place(TOWN, TOWN_AT, 1)
	_kit = village # Use its pure road-strip/stone mesh helpers; no trial ground or camera.
	for child in $Specimens.get_children():
		specimens.append(child as Specimen)
	_paint.shader = Kit.PIGMENT
	_rng.seed = 190417
	_body = StaticBody3D.new()
	_body.name = "SharedFloorAndVergeCollision"
	_body.collision_mask = 0
	add_child(_body)
	_block(Vector3(0, -.3, -1.5), Vector3(BOUNDS.size.x + 1, .6, BOUNDS.size.y + 1))
	_ground_and_verge()
	_join_roads()
	_landmarks()
	camera.make_current()

func _place(scene: PackedScene, shift: Vector2, style: int) -> Site:
	var site := scene.instantiate()
	site.set_script(Site)
	site.set("setting", style)
	site.position = point(shift)
	site.get_node("Camera").current = false
	add_child(site)
	return site as Site

func centerline() -> Array[Vector2]:
	var path: Array[Vector2] = []
	for i in range(1, WEST_PATH.size() - 1):
		path.append(WEST_PATH[i])
	for p: Vector2 in Kit.LANE:
		path.append(VILLAGE_AT + p)
	for i in range(1, FOREST_PATH.size() - 1):
		path.append(FOREST_PATH[i])
	for p: Vector2 in Kit.STREET:
		if p.x < RETURN_MARK.x - TOWN_AT.x:
			path.append(TOWN_AT + p)
	path.append(RETURN_MARK)
	return path

static func point(p: Vector2, y := 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)

func _block(p: Vector3, extent: Vector3, yaw := 0.0) -> void:
	var shape := BoxShape3D.new()
	shape.size = extent
	var slot := CollisionShape3D.new()
	slot.position = p
	slot.rotation.y = yaw
	slot.shape = shape
	_body.add_child(slot)

func _join_roads() -> void:
	var b := Batch.new()
	_dirt(b, WEST_PATH)
	_dirt(b, FOREST_PATH)
	# Distinctively grey and gradually more paved at the town mouth.
	var apron := [Vector2(32.65, -.01), Vector2(34.15, .95), Vector2(36.40, 1.49)]
	_kit._ribbon(b, apron, 3.98, .015, Color("99958a"))
	for i in 47:
		var f := _rng.randf()
		var p: Vector2 = apron[0].lerp(apron[-1], f) + Vector2(0, _rng.randf_range(-1.68, 1.68))
		_kit.stone(b, p, .023, .10 + f * .13, .08 + f * .07, Batch.tone(Color("acaa98"), _rng.randf_range(-.10, .12)))
	# A short walk to the porch, plus three gravel viewing bays.
	_kit._ribbon(b, [Vector2(-65.95, 9.55), Vector2(-65.95, 10.70), Vector2(-65, 12.3)], 1.18, .018, Color("bca680"), true)
	for i in specimens.size():
		var p := specimens[i].position
		var back := Vector2(p.x, p.z)
		var front: Vector2 = VIEWING[i]
		_kit._ribbon(b, [back, front, front + Vector2(0, 1.30)], 1.24, .018, Color("ae9e79"), true)
		b.roller(point(back, .009), Vector3.UP, .026, 2.08, 12, Color("bcaf87"), 4)
		for j in 17:
			var angle := j * 2.4
			var q := back + Vector2(cos(angle), sin(angle)) * _rng.randf_range(1.37, 2.08)
			_kit.stone(b, q, .026, .085, .065, Batch.tone(Color("a59877"), .17 * sin(angle)))
	b.add_to(self, "ContinuousRoadStitches", _paint, false)

func _dirt(b: Batch, path: Array) -> void:
	_kit._ribbon(b, path, 3.32, .008, ROAD_EDGE, true)
	_kit._ribbon(b, path, 2.92, .013, ROAD_INK, true)
	for shift: float in [-.64, .66]:
		var track: Array[Vector2] = []
		for p: Vector2 in path:
			track.append(p + Vector2(0, shift))
		_kit._ribbon(b, track, .39, .017, Color("b8a27e"), true)

func _ground_and_verge() -> void:
	var main := centerline()
	for strip in 8:
		var x0 := BOUNDS.position.x + strip * 19.5
		var x1 := x0 + 19.5
		var ground := Batch.new()
		var plants := Batch.new()
		for ix in 4:
			var x := lerpf(x0, x1, ix / 4.0)
			var right := x + 19.5 / 4.0
			for row in 9:
				var z := BOUNDS.position.y + row * 7.0
				var shade := .037 * sin(x * .17 + z * .5) + .038 * sin(x * .41 - z * .21)
				var base := FIELD_INK.lerp(Color("a8a482"), smoothstep(25.0, 53.0, x))
				ground.quad(Vector3(x, 0, z), Vector3(right, 0, z), Vector3(right, 0, z + 7), Vector3(x, 0, z + 7), Vector3.UP, Batch.tone(base, shade), 4)
		for i in 365:
			var p := Vector2(_rng.randf_range(x0, x1), _rng.randf_range(-31.8, 28.8))
			if _occupied(p, main, 2.24, 2.7):
				continue
			var q := point(p, .005)
			for blade in 3:
				var a := blade * 2.4 + _rng.randf_range(-.3, .3)
				var side := Vector3(cos(a), 0, sin(a))
				plants.tri(q - side * .08, q + side * .06, q + side * .19 + Vector3.UP * _rng.randf_range(.085, .29), Vector3.UP, Batch.tone(Color("798c56"), _rng.randf_range(-.14, .17)))
			if i % 13 == 0:
				plants.roller(q + Vector3.UP * .18, Vector3.UP, .046, .078, 5, Color("e0c581") if i % 2 == 0 else Color("bbb2a1"))
		for i in 41:
			var p := Vector2(_rng.randf_range(x0 + .5, x1 - .5), _rng.randf_range(-31, 28))
			# Keep the entire travel corridor clear in the camera-facing half.
			var need := 5.2 if p.y < 0.0 else 10.3
			if _occupied(p, main, need, 5.1) or (p.x > 40 and p.y > -17 and p.y < 16):
				continue
			if i % 3 == 0 or p.y > 21.0 or p.y < -22.0:
				_pine(plants, point(p), _rng.randf_range(.67, 1.12))
			else:
				_rock(plants, point(p), _rng.randf_range(.42, .90))
		# The edge is visible and physical, not a row of invisible trial walls.
		for z: float in [BOUNDS.position.y, BOUNDS.end.y]:
			Props.rail(plants, Vector3(x0, 0, z), Vector3(x1, 0, z))
		if strip == 0 or strip == 7:
			var x := x0 if strip == 0 else x1
			Props.rail(plants, Vector3(x, 0, BOUNDS.position.y), Vector3(x, 0, BOUNDS.end.y))
		ground.add_to(self, "Ground%02d" % strip, _paint, false)
		plants.add_to(self, "Verge%02d" % strip, _paint)
	for z: float in [BOUNDS.position.y, BOUNDS.end.y]:
		_block(Vector3(0, .45, z), Vector3(BOUNDS.size.x + .14, .9, .16))
	for x: float in [BOUNDS.position.x, BOUNDS.end.x]:
		_block(Vector3(x, .45, -1.5), Vector3(.16, .9, BOUNDS.size.y + .14))

func _occupied(p: Vector2, main: Array, road_space: float, bay_space: float) -> bool:
	if _kit._distance(p, main) < road_space:
		return true
	if Vector2(-65.5, 6.6).distance_to(p) < 6.4:
		return true
	if absf(p.x - VILLAGE_AT.x) < 18.5 and absf(p.y - VILLAGE_AT.y) < 9.7:
		return true
	if absf(p.x - TOWN_AT.x) < 18.5 and absf(p.y) < 9.7:
		return true
	for actor in specimens:
		if p.distance_to(Vector2(actor.position.x, actor.position.z)) < bay_space:
			return true
	return false

func _pine(b: Batch, p: Vector3, k: float) -> void:
	b.lathe(p, Vector3.UP, PackedVector2Array([Vector2(0, .25 * k), Vector2(1.60 * k, .13 * k), Vector2(3.2 * k, .08 * k)]), 7, Color("755d46"), 1)
	for i in 4:
		var y := (1.01 + i * .72) * k
		var r := (1.22 - i * .225) * k
		var ink := Batch.tone(Color("536d4e"), .06 * i + _rng.randf_range(-.13, .095))
		b.lathe(p + Vector3.UP * y, Vector3.UP, PackedVector2Array([Vector2(-.18 * k, 0), Vector2(0, r * .95), Vector2(.31 * k, r), Vector2(1.48 * k, 0)]), 7, ink)
	_block(p + Vector3.UP * .72 * k, Vector3(.48, 1.45, .48) * k)

func _rock(b: Batch, p: Vector3, k: float) -> void:
	b.lathe(p, Vector3.UP, PackedVector2Array([Vector2(-.03, .44 * k), Vector2(.19 * k, .65 * k), Vector2(.49 * k, .39 * k), Vector2(.55 * k, 0)]), 6, Color("9f9e83"))
	if k > .68:
		_block(p + Vector3.UP * .17 * k, Vector3(.90, .35, .89) * k)

func _landmarks() -> void:
	var b := Batch.new()
	for p: Vector2 in [Vector2(-61, 8.24), Vector2(-54.9, 6.13), Vector2(-23.3, 5.1), Vector2(-13.1, 1.02), Vector2(-2.0, -8.9), Vector2(12.05, -13.1), Vector2(27.5, -8), Vector2(34.6, -1.45), Vector2(69.7, -2.26)]:
		_waymark(b, point(p))
	# Cottage orchard; a tally post at each wildlife alcove, off its actor's lap.
	Props.orchard_tree(b, Vector3(-71, 0, 6.8), .89, .22)
	_block(Vector3(-71, .66, 6.8), Vector3(.42, 1.32, .42))
	Props.woodpile(b, Vector3(-61.8, 0, 6.55))
	_block(Vector3(-61.8, .26, 6.55), Vector3(1.17, .52, .66))
	for i in specimens.size():
		var p := specimens[i].position + Vector3(-2.23, 0, -.35)
		_rock(b, p, .77)
		_waymark(b, p + Vector3(.52, 0, .18), i + 1)
	b.add_to(self, "AmberWaymarksAndOrchard", _paint)

func _waymark(b: Batch, p: Vector3, marks := 0) -> void:
	var oak := Color("75563e")
	b.roller(p + Vector3.UP * .086, Vector3.UP, .17, .245, 6, Color("a79782"))
	b.box(p + Vector3.UP * .67, Vector3(.16, 1.30, .18), oak, 1)
	var center := p + Vector3(0, 1.16, 0)
	var top := center + Vector3(-.25, .16, .114)
	var base := center + Vector3(-.28, -.141, .114)
	b.box(center, Vector3(.59, .31, .19), oak.darkened(.07), 1)
	b.fan(PackedVector3Array([base, base + Vector3(.42, 0, 0), center + Vector3(.344,.01,.114), top + Vector3(.43,0,0), top]), Vector3.BACK, SIGN_INK)
	for i in marks:
		b.box(center + Vector3(-.118 + i * .092, 0, .12), Vector3(.03, .14, .027), oak)
	_block(p + Vector3.UP * .68, Vector3(.20, 1.36, .20))
