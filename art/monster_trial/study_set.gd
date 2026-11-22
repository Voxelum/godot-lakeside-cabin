extends RefCounted
## An original, deliberately low-contrast forest floor; no gameplay or external art.
const Brush := preload("res://art/monster_trial/source/brush.gd")
var b := Brush.new()
var rng := RandomNumberGenerator.new()

func build(parent: Node3D) -> void:
	rng.seed = 19027
	_ground(parent)
	for data: Vector4 in [
		Vector4(-13.1, -6.2, 1.52,  14), Vector4(-10.8, -4.4, 1.19, -14),
		Vector4(-7.3, -6.9, 1.09,   7), Vector4(-5.1, -6.3, 0.87,  34),
		Vector4(-1.9, -8.7, 1.05,  -9), Vector4( 2.4, -7.9, 0.92,  -9),
		Vector4( 6.1, -6.5, 1.06,  31), Vector4( 8.6, -4.6, 1.30, -25),
		Vector4(12.1, -6.4, 1.53,  12), Vector4(-13.8, 3.1, 1.43, -13),
		Vector4(13.6, 3.5, 1.38, -40),
	]:
		_tree(parent, data)
	_scatter(parent)

func _height(x: float, z: float) -> float:
	return -0.003 + smoothstep(2.4, 5.3, absf(z)) * (0.17 * sin(x * 0.49 + z * 0.41) + 0.14 * cos(x * 0.71 - z * 0.32) + 0.15)

func _earth(x: float, z: float) -> Color:
	var track := sin(x * 0.51) * 0.52 + sin(x * 0.20 + 1.0) * 0.48
	var path := 1.0 - smoothstep(0.94, 2.6, absf(z - track))
	var brush := 0.42 + 0.22 * sin(x * 0.31 + z * 0.47) + 0.16 * sin(x * 0.89 - z * 0.92)
	var weeds := Color("3b4e3b").lerp(Color("6b734c"), brush)
	var clay := Color("766650").lerp(Color("948468"), clampf(brush + 0.14, 0.0, 1.0))
	return weeds.lerp(clay, path).lightened(rng.randf_range(-0.028, 0.023))

func _ground(parent: Node3D) -> void:
	const SIDE := 41
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	for j in SIDE:
		for i in SIDE:
			var x := (i - 20) * 0.91 + rng.randf_range(-0.25, 0.25)
			var z := (j - 20) * 0.91 + rng.randf_range(-0.25, 0.25)
			points.append(Vector3(x, _height(x, z), z))
			colors.append(_earth(x, z))
	var st := b.surface()
	for j in SIDE - 1:
		for i in SIDE - 1:
			var a := j * SIDE + i
			var c := (j + 1) * SIDE + i
			for ids: Vector3i in [Vector3i(a, a+1, c), Vector3i(c, a+1, c+1)]:
				b.triangle(st, points[ids.x], points[ids.y], points[ids.z], Vector3.UP, Vector3.UP, Vector3.UP, colors[ids.x], colors[ids.y], colors[ids.z])
	b.finish(parent, "MossAndClay", st)

func _tree(parent: Node3D, d: Vector4) -> void:
	var trunk := b.joint(parent, "Alder", Vector3(d.x, _height(d.x, d.y), d.y), Vector3(0, d.w, 0))
	trunk.scale = Vector3.ONE * d.z
	b.loft(trunk, "SplitBark", [
		[-0.06, Vector2.ZERO, Vector2(0.42, 0.32), "4d4235"],
		[ 0.24, Vector2(-0.041, 0), Vector2(0.31, 0.24), "61523c"],
		[ 1.00, Vector2(-0.09, 0.12), Vector2(0.25, 0.20), "655740"],
		[ 2.26, Vector2(-0.04, 0.17), Vector2(0.20, 0.17), "71634a"],
		[ 3.58, Vector2(0.16, 0.26), Vector2(0.163, 0.148), "6a624a"],
		[ 4.24, Vector2(0.36, 0.29), Vector2(0.059, 0.070), "5e6049"],
	], 8, Vector3.AXIS_Y, 0.08)
	b.link(trunk, "SplitLimb", Vector3(-0.041, 1.62, 0.12), Vector3(-0.89, 3.45, -0.15), 0.159, 0.065, "655842")
	for s in [-1, 1]:
		b.fold(trunk, "Root", Vector3(-0.04, 0.38, 0.02), Vector3(s * 0.23, -0.043, 0.28), Vector3(s * 0.74, -0.030, 0.71), Vector3(s * 0.38, 0.115, 0.32), Vector3(s * 0.29, -0.045, 0.18), "635641", "4e4938")
	b.oval(trunk, "Canopy", Vector3(0.18, 4.22, 0.10), Vector3(3.43, 2.18, 2.79), "4e6546", Vector3(0, d.w * 0.61, -13), 9)
	b.oval(trunk, "CanopyUnderleaf", Vector3(-1.15, 3.72, -0.17), Vector3(2.12, 1.48, 2.33), "3f573f", Vector3(0, 19, 7), 8)
	b.oval(trunk, "CanopySunward", Vector3(0.87, 4.88, 0.15), Vector3(2.04, 1.43, 2.02), "58704d", Vector3(0, -17, 7), 8)

func _scatter(parent: Node3D) -> void:
	var st := b.surface()
	# Short blades outside of the display lane frame the warm path instead of masking the paws.
	for i in 550:
		var x := rng.randf_range(-15.4, 15.4)
		var z := rng.randf_range(-12.2, 10.1)
		if absf(z) < 1.83:
			continue
		var base := Vector3(x, _height(x, z) - 0.020, z)
		var color := Color("43573f").lerp(Color("92915c"), rng.randf() * 0.68)
		for j in rng.randi_range(2, 4):
			var theta := rng.randf() * TAU
			var dir := Vector3(cos(theta), 0, sin(theta))
			var edge := dir.cross(Vector3.UP)
			var width := rng.randf_range(0.028, 0.054)
			var tip := base + dir * rng.randf_range(0.09, 0.256) + Vector3.UP * rng.randf_range(0.079, 0.28)
			_leaf(st, base, tip, dir, edge, width, color)
	# Bigger hand-placed fern sprays and flat river stones: just edge accents.
	for data: Vector3 in [Vector3(-5.30, 2.00, 0.95), Vector3(-2.00, -2.35, 0.95), Vector3(1.81, -2.31, 0.83), Vector3(4.82, 2.01, 1.06), Vector3(-4.81, -2.74, 1.22), Vector3(6.6, -2.91, 1.29)]:
		var at := Vector3(data.x, _height(data.x, data.y) - 0.015, data.y)
		_fern(st, at, data.z)
	for data: Vector4 in [Vector4(-5.22, 2.52, 1.25, 3.0), Vector4(-5.88, 2.47, 0.65, 1.0), Vector4(5.3, -2.84, 0.85, 2.0), Vector4(5.59, -2.55, 0.60, 0.1), Vector4(2.2, 2.89, 0.6, 0.4)]:
		var col := "817663" if data.x < 0 else "757569"
		b.oval(parent, "Riverslab", Vector3(data.x, _height(data.x, data.y) + 0.052 * data.z, data.y), Vector3(0.76, 0.28, 0.50) * data.z, col, Vector3(-4, 22 * data.w, -6), 8)
	# Leaf litter along the lip of the trail, not under the three staging marks.
	for i in 94:
		var x := rng.randf_range(-12.8, 12.8)
		var z := rng.randf_range(1.12, 3.85) * (-1.0 if i % 2 == 0 else 1.0)
		var at := Vector3(x, _height(x, z) + 0.022, z)
		var phi := rng.randf() * TAU
		var d := Vector3(cos(phi), 0, sin(phi))
		var l := rng.randf_range(0.063, 0.181)
		var side := d.cross(Vector3.UP)
		_leaf(st, at, at + d * l + Vector3.UP * 0.003, d, side, l * 0.38, Color("a28855").lerp(Color("745f43"), rng.randf()))
	var detail := b.finish(parent, "FernsAndFallenLeaves", st)
	detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _leaf(st: SurfaceTool, base: Vector3, tip: Vector3, _dir: Vector3, edge: Vector3, width: float, c: Color) -> void:
	var mid := base.lerp(tip, 0.49)
	var spine := mid + Vector3.UP * width * 0.18
	for s: float in [-1.0, 1.0]:
		var flank := mid + edge * width * s
		var tint := c.lightened(0.07 * s)
		b.flat(st, base, flank, spine, Vector3.UP, tint)
		b.flat(st, spine, flank, tip, Vector3.UP, tint.lightened(0.08))

func _fern(st: SurfaceTool, at: Vector3, stature: float) -> void:
	for k in 6:
		var theta := TAU * float(k) / 6.0 + rng.randf_range(-0.23, 0.23)
		var along := Vector3(cos(theta), 0, sin(theta))
		var cross := along.cross(Vector3.UP)
		for j in 6:
			var u := float(j) / 6.0
			var rise := sin(u * PI * 0.72) * 0.43
			var start := at + (along * (u * 0.58) + Vector3.UP * rise) * stature
			for side: float in [-1.0, 1.0]:
				var d := along * 0.45 + cross * side
				var tip := start + (d * (0.078 + 0.145 * sin((u + 0.14) * PI)) + Vector3.UP * 0.028) * stature
				_leaf(st, start, tip, d, d.cross(Vector3.UP), (0.046 - 0.027 * u) * stature, Color("657650").lightened(0.16 * u))
