extends RefCounted
## Offline heightfield loft. Rock, turf and the static floor have exactly the
## same triangles. Only the raised footprint is emitted: its toe touches the
## host's level meadow at y=0, without a second coplanar apron.
const Profile := preload("ridge_profile.gd")
const Brush := preload("res://source/brush_mesh.gd")
const MEADOW := preload("res://art/woods/meadow.gdshader")
const PIGMENT := preload("res://art/woods/pigments.gdshader")
const STEPS := [0., .14, .28, .42, .56, .70, .86, 1.]
const ROCK_RUN := [0., .16, .29, .41, .61, .71, .86, 1.]
const ROCK_LIFT := [0., .13, .32, .47, .52, .75, .91, 1.]
const BED_TONES := [.72, .87, .96, .80, 1.09, .93, 1.05]

var faces := PackedVector3Array()
var _angles := PackedFloat32Array()
var _wedge: Array[PackedVector3Array] = []
var _turf := Brush.new()
var _rock := Brush.new()
var _top := 0.0

func build(profile: Profile) -> String:
	var problem := profile.validation_error()
	if not problem.is_empty(): return problem
	faces.clear()
	_angles.clear()
	_wedge.clear()
	_turf = Brush.new()
	_rock = Brush.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = profile.seed
	for i in profile.sectors:
		var jitter := rng.randf_range(-.20, .20) if i > 0 else 0.0
		_angles.append(TAU * (i + jitter) / profile.sectors)
		_wedge.append(PackedVector3Array())

	var lower_y := 0.0
	var previous_lip := PackedVector3Array()
	for tier in profile.tiers:
		var phase := rng.randf_range(0.0, TAU)
		var rows: Array[PackedVector3Array] = []
		for k in STEPS.size(): rows.append(PackedVector3Array())
		for i in _angles.size():
			var angle := _angles[i]
			var section := tier.section(angle, phase)
			var radial := Vector2.from_angle(angle)
			if section.x < .35:
				return "Degenerate crest at %.1f degrees." % rad_to_deg(angle)
			if not previous_lip.is_empty() and Vector2(previous_lip[i].x, previous_lip[i].z).length() - section.x - section.y < .45:
				return "Tier at %.2f m overlaps the previous shelf near %.1f degrees (need .45 m clear)." % [tier.height, rad_to_deg(angle)]
			for k in STEPS.size():
				var t: float = STEPS[k]
				var split := sin(PI * t) * tier.rock_relief * (1.0 - section.z)
				# Long bedding waves with shorter fractures. Pin both ends of a band
				# so there can never be separate seams at the shelf or toe.
				var depth := lerpf(ROCK_RUN[k], t, section.z) + split * .054 * sin(angle * 10.0 + phase + t * 5.0)
				var lift := lerpf(ROCK_LIFT[k], smoothstep(0.0, 1.0, t), section.z)
				lift += split * (.041 * cos(angle * 7.0 - phase + t * 4.0) + .022 * sin(angle * 17.0 + phase))
				var p := radial * (section.x + section.y * (1.0 - depth))
				rows[k].append(Vector3(p.x, lerpf(lower_y, tier.height, lift), p.y))

		for i in _angles.size():
			var j := (i + 1) % _angles.size()
			var a := (_angles[i] + (_angles[j] if j > 0 else TAU)) * .5
			var cut := tier.ramp_weight(a)
			if not previous_lip.is_empty():
				_quad(i, previous_lip[i], previous_lip[j], rows[0][j], rows[0][i], false, Color.WHITE)
			for k in STEPS.size() - 1:
				var tone: float = BED_TONES[k] + .105 * sin(a * 5.0 + phase) + .04 * cos(a * 15.0 - phase)
				var strata := Color(profile.rock_tone.r * tone, profile.rock_tone.g * tone, profile.rock_tone.b * tone)
				# Broken earth at the toe and moss in occasional shoulder pockets.
				if k == 0: strata = strata.lerp(Color("887b59"), .42)
				if k == 6 and sin(a * 13.0 + phase) > .15: strata = strata.lerp(Color("91996a"), .48)
				strata = strata.lerp(Color("a39772"), smoothstep(.16, .91, cut) * .67)
				_quad(i, rows[k][i], rows[k][j], rows[k+1][j], rows[k+1][i], cut < .91, strata)
		previous_lip = rows[-1]
		lower_y = tier.height

	_top = lower_y
	for i in _angles.size():
		_tri(i, previous_lip[i], previous_lip[(i+1) % _angles.size()], Vector3(0, _top, 0), false, Color.WHITE)
	return ""

func _quad(wedge: int, a: Vector3, b: Vector3, c: Vector3, d: Vector3, is_rock: bool, pigment: Color) -> void:
	_tri(wedge, a, b, d, is_rock, pigment)
	_tri(wedge, b, c, d, is_rock, pigment.lightened(.028) if is_rock else pigment)

func _tri(wedge: int, a: Vector3, b: Vector3, c: Vector3, is_rock: bool, pigment: Color) -> void:
	# Godot's front face is clockwise, including on the exposed cliff.
	var n := (c - a).cross(b - a).normalized()
	if n.y < 0.0:
		var swap := b
		b = c
		c = swap
		n = -n
	var tri := PackedVector3Array([a, b, c])
	faces.append_array(tri)
	_wedge[wedge].append_array(tri)
	var paint := _rock if is_rock else _turf
	paint.flat(a, b, c, n, pigment)

func height_at(p: Vector2) -> float:
	# Query the actual triangles, not a second interpolator. This is also used
	# by the old paver brush when it drapes the new treads across the slope.
	var angle := fposmod(p.angle(), TAU)
	var i := maxi(0, _angles.bsearch(angle, false) - 1)
	var from := Vector3(p.x, _top + 1.0, p.y)
	var tris := _wedge[i]
	for k in range(0, tris.size(), 3):
		var h: Variant = Geometry3D.ray_intersects_triangle(from, Vector3.DOWN, tris[k], tris[k+1], tris[k+2])
		if h != null: return maxf(0.0, h.y)
	return 0.0

func attach(body: StaticBody3D) -> void:
	var grass := ShaderMaterial.new()
	grass.shader = MEADOW
	grass.resource_name = "Meadow | upland shelves"
	var slate := ShaderMaterial.new()
	slate.shader = PIGMENT
	slate.resource_name = "Dry pigments | fractured bedding"
	for node in [_turf.bake("Turf_and_Ramp_Floors", grass), _rock.bake("Exposed_Bedding", slate)]:
		node.layers = 2 # Below the old mirror pass, like the original ground.
		if node.name == &"Turf_and_Ramp_Floors":
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(node)
		node.owner = body
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.name = "Dry_Relief_Collision"
	collider.shape = shape
	body.add_child(collider)
	collider.owner = body
