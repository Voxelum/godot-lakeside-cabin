extends "bake_terrace.gd"
## Offline only. Shares the original meadow, dry pigments, flagstone cutter
## and plants. Does not rebuild the lakeside terrace or the surveyed lane.
## godot --headless --path . --script res://source/bake_mountain.gd -- --output=<new .tscn>
const Ridge := preload("res://source/mountain/ridge_mesh.gd")
const RidgeProfile := preload("res://source/mountain/ridge_profile.gd")
const DEFAULT_PROFILE := "res://source/mountain/fern_fold.tres"
const STONE: Array[Color] = [Color("c7b798"), Color("b7aa8e"), Color("c4b8a0"), Color("afaa97"), Color("d0c0a3")]
var ridge := Ridge.new()

func _initialize() -> void:
	var input := DEFAULT_PROFILE
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="): input = arg.trim_prefix("--profile=")
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		else:
			_stop("Unknown argument: " + arg)
			return
	if output.get_extension() != "tscn" or FileAccess.file_exists(output) or DirAccess.dir_exists_absolute(output):
		_stop("Pass --output=<new .tscn path>. Existing assets are not overwritten.")
		return
	var plan := load(input) as RidgeProfile
	if plan == null:
		_stop("Cannot load a ridge profile: " + input)
		return
	var problem := ridge.build(plan)
	if not problem.is_empty():
		_stop(problem)
		return
	var stations := _stations(plan)
	var grade := _trail_grade(stations)
	if grade > .94:
		_stop("Trail or its flanks cross an unsafe grade (%.2f rise/run); move the waypoints into the ramp." % grade)
		return
	land.name = "MountainRise"
	land.position = plan.origin
	land.collision_mask = 0
	ink.shader = preload("res://art/woods/pigments.gdshader")
	ink.resource_name = "Dry pigments | mountain path"
	rng.seed = plan.seed
	ridge.attach(land)
	if not stations.is_empty(): _lay_trail(stations)
	_plant(plan)
	var scene := PackedScene.new()
	var result := scene.pack(land)
	if result == OK: result = ResourceSaver.save(scene, output)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(ridge.faces.to_byte_array())
	print("%s: %s; %d ground triangles, trail grade %.3f, surface digest %s" % [
		output, error_string(result), ridge.faces.size() / 3, grade, digest.finish().hex_encode()])
	land.free()
	quit(int(result != OK))

func _stop(reason: String) -> void:
	printerr(reason)
	land.free()
	quit(2)

func surface(x: float, z: float) -> float:
	return ridge.height_at(Vector2(x, z))

func _curve(path: PackedVector2Array, i: int, t: float) -> Vector2:
	return path[i].cubic_interpolate(path[i+1], path[maxi(0, i-1)], path[mini(path.size()-1, i+2)], t)

func _stations(plan: RidgeProfile) -> Array[Vector4]:
	var rows: Array[Vector4] = []
	var path := plan.trail
	for i in path.size() - 1:
		var count := ceili(path[i].distance_to(path[i+1]) / .27)
		for k in count + int(i == path.size() - 2):
			var t := float(k) / count
			var p := _curve(path, i, t)
			var direction := (_curve(path, i, minf(1.0, t+.02)) - _curve(path, i, maxf(0.0, t-.02))).normalized()
			var side := direction.orthogonal() * lerpf(plan.trail_widths[i], plan.trail_widths[i+1], t) * .5
			rows.append(Vector4(p.x, p.y, side.x, side.y))
	return rows

func _across(row: Vector4, side: float) -> Vector2:
	return Vector2(row.x + row.z * side, row.y + row.w * side)

func _trail_grade(rows: Array[Vector4]) -> float:
	var max_grade := 0.0
	# Includes diagonal sampling inside the central corridor, not just its spine.
	for i in rows.size() - 1:
		for side: float in [-.45, 0.0, .45]:
			var a := _across(rows[i], side)
			for next: float in [side - .25, side, side + .25]:
				var b := _across(rows[i+1], next)
				max_grade = maxf(max_grade, absf(ridge.height_at(a) - ridge.height_at(b)) / maxf(.01, a.distance_to(b)))
	return max_grade

func _lay_trail(stations: Array[Vector4]) -> void:
	var edge_a := PackedVector2Array()
	var edge_b := PackedVector2Array()
	var rows: Array[PackedVector3Array] = []
	var lanes := [-1., -.72, -.36, .12, .52, .78, 1.]
	for i in stations.size():
		var row := PackedVector3Array()
		for j in lanes.size():
			var wobble := .044 * sin(i * 1.43 + j * 2.45) + .048 * cos(i * .49 - j * 1.82)
			var p := _across(stations[i], lanes[j] + wobble)
			row.append(at(p, .018))
			if j == 0: edge_a.append(p)
			if j == lanes.size()-1: edge_b.append(p)
		rows.append(row)
	var earth := Brush.new()
	for i in rows.size() - 1:
		for j in lanes.size() - 1:
			var a := rows[i][j]; var b := rows[i][j+1]
			var c := rows[i+1][j+1]; var d := rows[i+1][j]
			var tone := Color("ac9b74") if j in [1, 4] else Color("b7a580")
			if j == 0 or j == lanes.size()-2: tone = Color("97925f")
			tone = tone.lightened(.042 * sin(i*.51+j*1.72) + .021 * cos(i*1.31-j*.71))
			pave_tri(earth, a, b, d, Vector3.UP, tone)
			pave_tri(earth, b, c, d, Vector3.UP, tone.lightened(.018))
	var view: MeshInstance3D = earth.bake("Dust_and_Worn_Edges", ink)
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	put(view)

	edge_b.reverse()
	outline = edge_a + edge_b
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for p in outline: bounds = bounds.expand(p)
	bounds = bounds.grow(.7)
	var seeds := PackedVector2Array()
	var step := Vector2(.76, .64)
	for z in ceili(bounds.size.y / step.y) + 1:
		for x in ceili(bounds.size.x / step.x) + 1:
			seeds.append(bounds.position + Vector2((x + .41 * (z % 2)) * step.x + rng.randf_range(-.18, .18),
				z * step.y + rng.randf_range(-.15, .15)))
	drape = true
	flagstones(seeds, .035, .053, .020, .013, func(p: Vector2) -> bool:
		var grade := ridge.height_at(p)
		var rise := absf(ridge.height_at(p + Vector2(.32, .19)) - grade)
		return rng.randf() < (.93 if rise > .09 else .58) and rise < .34, STONE)
	drape = false
	(land.get_child(-1) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _plant(plan: RidgeProfile) -> void:
	var herbs := Brush.new()
	var colors := [Color("82934c"), Color("71974f"), Color("96a35a"), Color("748a4e")]
	var accepted := 0
	for i in 145:
		var a := TAU * rng.randf()
		var p := Vector2.from_angle(a) * sqrt(rng.randf()) * plan.tiers[0].crest_radius * 1.18
		var h := ridge.height_at(p)
		if h < .13 or not _quiet_ground(p, h): continue
		for k in rng.randi_range(3, 8):
			var q := p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(.07, .42)
			var y := ridge.height_at(q)
			if absf(y-h) > .16 or not _quiet_ground(q, y): continue
			tuft(herbs, at(q, y+.010), rng.randf_range(.70, 1.18), colors[(i+k) % colors.size()])
			if k == 1 and accepted % 3 == 0:
				flower(herbs, at(q, y+.011), Color("d8c486") if i % 2 == 0 else Color("c0b9cf"), .88)
		if accepted % 4 == 0: bracken(herbs, at(p, h+.012), rng.randf_range(.76, 1.16))
		accepted += 1
		if accepted == 28: break
	put(herbs.bake("Upland_Ferns_And_Grass", ink))

	# A few low broken blocks at a rock face's foot, never scattered into a tread.
	var tier := plan.tiers[0]
	for a: float in [.62, 1.04, 1.74, 2.44, 2.95, 4.12, 4.97, 5.57]:
		var section := tier.section(a, 0.0)
		if section.z > .07: continue
		var p := Vector2.from_angle(a) * (section.x + section.y + .24)
		if not _quiet_ground(p, ridge.height_at(p)): continue
		var scale := rng.randf_range(.70, 1.18)
		rock("Loose_Shale_%02d" % land.get_child_count(), p, Vector3(.36, .37, .25) * scale, -.36 + a)
	if plan.trail.size() >= 5:
		var p := plan.trail[3]
		var left := (p - plan.trail[2]).normalized().orthogonal()
		rock("Fork_Waystone", p + left * 1.00, Vector3(.34, .58, .26), .52)

func _quiet_ground(p: Vector2, height: float) -> bool:
	if not outline.is_empty():
		if Geometry2D.is_point_in_polygon(p, outline): return false
		for i in outline.size():
			if p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p, outline[i], outline[(i+1) % outline.size()])) < .27*.27:
				return false
	for d in [Vector2(.16, 0), Vector2(-.16, 0), Vector2(0, .16), Vector2(0, -.16)]:
		if absf(ridge.height_at(p+d) - height) > .10: return false
	return true
