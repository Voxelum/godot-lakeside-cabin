@tool
extends RefCounted
## Roof profiles share one tessellator. Eaves, courses and ridge are solved from
## the selected shell, so profiles are not freely scaled or snapped onto other spans.

const Batch = preload("res://art/building_trial/mesh_batch.gd")
const Rules = preload("res://art/building_trial/lot_rules.gd")

var along_x: bool
var half_cross: float
var half_ridge: float
var eave_y: float
var rise: float
var profile: int
var hip: float
var rng := RandomNumberGenerator.new()

func _init(kind: int, shape: int, body: Vector4, height: float, seed_value: int) -> void:
	along_x = kind in [Rules.FARM, Rules.SHOP]
	half_cross = (body.y if along_x else body.x) * .5 + Rules.EAVE
	half_ridge = (body.x if along_x else body.y) * .5 + Rules.EAVE
	eave_y = height
	rise = body.w
	profile = shape
	hip = minf(1.34, half_ridge * .51) if shape == Rules.HIP else (.72 if shape == Rules.CLIPPED else 0.0)
	rng.seed = seed_value ^ 627631

func ridge_vector() -> Vector3:
	return Vector3.RIGHT if along_x else Vector3.BACK

func on_roof(side: float, t: float, u: float) -> Vector3:
	var s := side * half_cross * (1.0 - t)
	var y := eave_y + rise * _grade(t)
	var a := u * (half_ridge - _inset(t))
	return Vector3(a, y, s) if along_x else Vector3(s, y, a)

func _grade(t: float) -> float:
	if profile == Rules.GAMBREL:
		return .66 * t / .4 if t <= .4 else lerpf(.66, 1.0, (t - .4) / .6)
	if profile == Rules.SWEEP:
		return t * (.66 + .34 * t)
	return t

func _inset(t: float) -> float:
	if profile == Rules.HIP:
		return hip * t
	if profile == Rules.CLIPPED:
		return hip * maxf(0.0, (t - .7) / .3)
	return 0.0

func crown(b: Batch, ink: Color, fascia: Color) -> void:
	const ROWS := 10
	var dip := Vector3.DOWN * .095
	var bare := ink.darkened(.29)
	var tile_count := ceili((half_ridge * 2.0) / .39)
	var half_tile := 1.0 / float(tile_count)
	for side: float in [-1.0, 1.0]:
		for j in ROWS:
			var t0 := float(j) / ROWS
			var t1 := float(j + 1) / ROWS
			var a := on_roof(side, t0, -1.0)
			var c := on_roof(side, t0, 1.0)
			b.quad(a, c, on_roof(side, t1, 1.0), on_roof(side, t1, -1.0), Vector3.UP, bare)
			if j == 0:
				b.quad(a, c, c + dip, a + dip, a - on_roof(0, 0, -1), fascia)
			var offset := half_tile if j % 2 == 1 else 0.0
			for i in range(-1, tile_count):
				var left := -1.0 + 2.0 * half_tile * i + offset
				var u0 := maxf(-.999, left + .0035)
				var u1 := minf(.999, left + 2.0 * half_tile - .0035)
				if u1 <= u0 + .006:
					continue
				_tile(b, side, t0, t1, u0, u1, Batch.tone(ink, rng.randf_range(-.135, .153)))
		for end: float in [-1.0, 1.0]:
			for j in range(0, ROWS, 2):
				var a := on_roof(side, float(j) / ROWS, end)
				var c := on_roof(side, float(j + 2) / ROWS, end)
				if hip != 0.0:
					# Match every bend at a hip, not just its end points.
					var mid := on_roof(side, float(j + 1) / ROWS, end)
					b.bar(a, mid, .072, .065, ink.lightened(.10), Vector3.UP)
					b.bar(mid, c, .072, .065, ink.lightened(.10), Vector3.UP)
				else:
					b.bar(a + dip * .46, c + dip * .46, .11, .13, fascia, ridge_vector(), 1)

	for end: float in [-1.0, 1.0]:
		for j in ROWS:
			var t0 := float(j) / ROWS
			var t1 := float(j + 1) / ROWS
			if _inset(t1) == 0.0:
				continue
			var a := on_roof(-1, t0, end)
			var c := on_roof(1, t0, end)
			var d := on_roof(-1, t1, end)
			var e := on_roof(1, t1, end)
			b.quad(a, c, e, d, Vector3.UP, bare)
			var n := maxi(2, ceili(a.distance_to(c) / .39))
			for i in n:
				var u0 := (float(i) + .033) / n
				var u1 := (float(i) + .967) / n
				var bump := Vector3.UP * .029
				b.quad(a.lerp(c, u0)+bump, a.lerp(c, u1)+bump, d.lerp(e, u1)+bump, d.lerp(e, u0)+bump, Vector3.UP, Batch.tone(ink, rng.randf_range(-.05, .19)))
		var a := on_roof(-1, 0, end)
		var c := on_roof(1, 0, end)
		b.quad(a, c, c + dip, a + dip, ridge_vector() * end, fascia)
		if end > 0:
			b.quad(a + dip, c + dip, on_roof(1, 0, -end) + dip, on_roof(-1, 0, -end) + dip, Vector3.DOWN, fascia.darkened(.20), 1)

	var n := ceili((half_ridge - hip) * 2 / .41)
	var ridge_a := on_roof(0, 1, -1) + Vector3.UP * .039
	var ridge_b := on_roof(0, 1, 1) + Vector3.UP * .039
	for i in n:
		b.roller(ridge_a.lerp(ridge_b, (i + .5) / n), ridge_vector(), ridge_a.distance_to(ridge_b) / n + .017, .080, 7, Batch.tone(ink, .10 + rng.randf_range(-.09, .12)))

func _tile(b: Batch, side: float, t0: float, t1: float, u0: float, u1: float, ink: Color) -> void:
	var bump := Vector3.UP * .034
	var a := on_roof(side, t0, u0) + bump
	var c := on_roof(side, t0, u1) + bump
	var e := on_roof(side, t1 - .002, u1) + bump * .63
	var d := on_roof(side, t1 - .002, u0) + bump * .63
	var roll_a := a.lerp(c, .23) + bump * .90
	var roll_b := d.lerp(e, .23) + bump * .69
	b.quad(a, roll_a, roll_b, d, Vector3.UP, ink.lightened(.12))
	b.quad(roll_a, c, e, roll_b, Vector3.UP, ink)
	var out := on_roof(side, 0, 0) - on_roof(0, 0, 0)
	b.quad(a, c, c - bump, a - bump, out, ink.darkened(.28))

func fill_gables(b: Batch, wall: Color, beam: Color, barn: bool) -> void:
	if profile == Rules.HIP:
		return
	var along := half_ridge - Rules.EAVE + .011
	var cross := half_cross - Rules.EAVE
	var axis := ridge_vector()
	var trans := Vector3.BACK if along_x else Vector3.RIGHT
	var brow := minf(.99, .7 + .3 * Rules.EAVE / hip) if profile == Rules.CLIPPED else 1.0
	for end: float in [-1.0, 1.0]:
		var origin := axis * end * along + Vector3.UP * eave_y
		# Boards on the hay loft and plaster in the narrow gable both follow the roof rake.
		var count := ceili(cross * 2.0 / (.23 if barn else .30))
		for i in count:
			var a := lerpf(-cross, cross, float(i) / count)
			var c := lerpf(-cross, cross, float(i + 1) / count) - (.011 if barn else .0)
			var y0 := _grade(minf(brow, 1.0 - absf(a) / half_cross)) * rise - .095
			var y1 := _grade(minf(brow, 1.0 - absf(c) / half_cross)) * rise - .095
			b.quad(origin + trans*a, origin + trans*c, origin + trans*c + Vector3.UP*y1, origin + trans*a + Vector3.UP*y0, axis*end, Batch.tone(wall, rng.randf_range(-.14, .12) if barn else rng.randf_range(-.025,.025)), 1.0 if barn else 0.0)
		origin += axis * (.048 * end)
		b.bar(origin-trans*cross, origin+trans*cross, .16, .15, beam, axis, 1)
		if not barn and not along_x:
			var top := origin + Vector3.UP * (rise * .83)
			b.bar(origin, top, .13, .12, beam, axis, 1)
			for side: float in [-1.0, 1.0]:
				b.bar(origin+trans*side*cross*.72, origin+Vector3.UP*rise*.61, .095, .125, beam, axis, 1)
