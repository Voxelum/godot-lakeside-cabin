extends SceneTree
## Godot --headless --path . --script res://tests/shore_checks.gd
## Uses Clearing's actual Traveler, collision and input-driven _physics_process.
var walker: CharacterBody3D
var camera: Camera3D
var shore: PackedVector2Array
var failures := 0
var water_entries := 0
var contacts := {}

func _initialize() -> void:
	call_deferred("run")

func flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func place(p: Vector2) -> void:
	walker.position = Vector3(p.x, 1.5, p.y)
	walker.velocity = Vector3.ZERO
	for i in 45:
		await physics_frame
	check(walker.is_on_floor(), "settled on floor at %s" % p)

func walk(label: String, dir: Vector2, frames: int, sprint := false) -> float:
	camera.rotation.y = atan2(-dir.x, -dir.y)
	var start := walker.position
	contacts.clear()
	Input.action_press("walk_up")
	if sprint:
		Input.action_press("sprint")
	for i in frames:
		await physics_frame
		for j in walker.get_slide_collision_count():
			var hit := walker.get_slide_collision(j)
			var collider := hit.get_collider() as Node
			if collider:
				contacts[str(collider.get_path())] = true
		if Geometry2D.is_point_in_polygon(flat(walker.position), shore):
			water_entries += 1
	Input.action_release("walk_up")
	Input.action_release("sprint")
	var advance := (flat(walker.position) - flat(start)).dot(dir)
	print("%s: %s -> %s; advance %.3f; %s" % [label, start, walker.position, advance, contacts.keys()])
	return advance

func hit_path(fragment: String) -> bool:
	for path in contacts:
		if fragment in path:
			return true
	return false

# Vertical intersection with the actual baked triangles (including packed mesh
# quantization); take the top visible surface, not decorative vegetation.
func triangle_height(faces: PackedVector3Array, p: Vector2) -> float:
	var y := -INF
	var from := Vector3(p.x, 3.0, p.y)
	for i in range(0, faces.size(), 3):
		var a := faces[i]; var b := faces[i+1]; var c := faces[i+2]
		if p.x < minf(a.x,minf(b.x,c.x)) or p.x > maxf(a.x,maxf(b.x,c.x)):
			continue
		if p.y < minf(a.z,minf(b.z,c.z)) or p.y > maxf(a.z,maxf(b.z,c.z)):
			continue
		var hit: Variant = Geometry3D.ray_intersects_triangle(from, Vector3.DOWN, a, b, c)
		if hit != null:
			y = maxf(y, hit.y)
	return y

func grade_check(land: Node3D, starts: Array[Vector2]) -> void:
	var soil: MeshInstance3D = land.get_node("Meadow")
	var grout: MeshInstance3D = land.get_node("Sandy_Grout")
	var flags: MeshInstance3D = land.get_node("Handcut_Flagstones_093")
	var ground_faces := soil.mesh.get_faces()
	var grout_faces := grout.mesh.get_faces()
	var flag_faces := flags.mesh.get_faces()
	var shape: ConcavePolygonShape3D = land.get_node("Continuous_Soil_And_Lane").shape
	var collision_faces := shape.get_faces()
	var samples := starts.duplicate()
	var wet_count := 0
	var wet_max := -INF
	var wet_collision_max := -INF
	var sole_min := INF
	var sole_max := -INF
	# Sample the slanted edge both dry and wet, not only the six walk starts.
	for i in range(2, 7):
		var a := shore[i]; var b := shore[i+1]
		var outward := Vector2((b-a).y, -(b-a).x).normalized()
		for t in [.15, .5, .85]:
			var edge := a.lerp(b, t)
			for distance in [-.20, -.04, 0.0, .04, .20, .32]:
				var p := edge + outward * float(distance)
				if distance <= 0.0:
					wet_count += 1
					wet_max = maxf(wet_max, triangle_height(ground_faces,p))
					wet_collision_max = maxf(wet_collision_max,triangle_height(collision_faces,p))
				else:
					samples.append(p)
	var min_gap := INF
	var max_gap := -INF
	for p in samples:
		var visible := maxf(triangle_height(ground_faces,p),maxf(triangle_height(grout_faces,p),triangle_height(flag_faces,p)))
		var collision := triangle_height(collision_faces,p)
		var gap := collision - visible
		check(is_finite(gap), "baked surfaces sampled at %s" % p)
		min_gap = minf(min_gap,gap)
		max_gap = maxf(max_gap,gap)
		if p in starts:
			await place(p)
			var feet: Array[float] = []
			for side in ["L", "R"]:
				var boot := "Appearance/Facing/Hips/Thigh%s/Calf%s/Boot%s/" % [side,side,side]
				var lower := INF
				for contact in ["HeelContact", "ToeContact"]:
					var marker: Node3D = walker.get_node(boot+contact)
					var foot := marker.global_position
					var at := flat(foot)
					var top := maxf(triangle_height(ground_faces,at),maxf(triangle_height(grout_faces,at),triangle_height(flag_faces,at)))
					lower = minf(lower,foot.y-top)
				feet.append(lower)
				sole_min = minf(sole_min,lower)
				sole_max = maxf(sole_max,lower)
			print("fit %s: visible %.4f, collision %.4f, capsule bottom %.4f, lower sole gaps L/R %s" % [p,visible,collision,walker.position.y,feet])
	print("surface fit: %d dry samples, collision-visible [%.4f, %.4f] m; lower sole gaps [%.4f, %.4f] m" % [samples.size(),min_gap,max_gap,sole_min,sole_max])
	print("wet fit: %d wet/edge samples, highest soil Y %.4f, highest collision Y %.4f" % [wet_count,wet_max,wet_collision_max])
	check(min_gap >= -.04 and max_gap <= .035, "support aligns with visible grade")
	check(maxf(wet_max,wet_collision_max) <= .014, "wet-side soil and support remain below water surface")

func run() -> void:
	var world := (load("res://world/Clearing.tscn") as PackedScene).instantiate()
	root.add_child(world)
	walker = world.get_node("Traveler")
	camera = world.get_node("Camera")
	camera.set_process(false)
	camera.set_physics_process(false)
	var barrier: CollisionPolygon3D = world.get_node("Pool/PoolBarrier/Shoreline")
	for p in barrier.polygon:
		shore.append(flat(barrier.to_global(Vector3(p.x, p.y, 0))))

	var starts: Array[Vector2] = [Vector2(4.5, 3.35), Vector2(5.2, 3.0), Vector2(5.7, 2.7),
		Vector2(6.2, 2.55), Vector2(6.7, 2.35), Vector2(7.2, 2.14)]
	await grade_check(world.get_node("Land"), starts)
	for route in [
		[Vector2(4.5, 3.35), Vector2(0, -1)],
		[Vector2(5.2, 3.0), Vector2(-1, -1).normalized()],
		[Vector2(5.7, 2.7), Vector2(-1, -1).normalized()],
		[Vector2(6.2, 2.55), Vector2(-1, 0)],
		[Vector2(6.7, 2.35), Vector2(-1, 0)],
		[Vector2(7.2, 2.14), Vector2(-1, 0)],
	]:
		var bank: Vector2 = route[0]
		var uphill: Vector2 = route[1]
		await place(bank)
		var start := walker.position
		check(await walk("uphill", uphill, 32) >= 0.95 and walker.position.y > start.y + 0.15,
			"climb from %s along %s" % [bank, uphill])
		check(await walk("downhill", -uphill, 32) >= 0.85 and flat(walker.position).distance_to(bank) < 0.5,
			"return to dry bank near %s" % bank)

	var tangent := Vector2(1, -0.5).normalized()
	await place(Vector2(4.65, 3.24))
	check(await walk("along shore toward lamp", tangent, 44) >= 1.2, "along shore toward lamp")
	check(await walk("along shore away from lamp", -tangent, 44) >= 1.2, "along shore away from lamp")
	for threat in [
		[Vector2(4.5, 3.35), Vector2(0.52, 0.85).normalized()],
		[Vector2(5.7, 2.7), Vector2(0.39, 0.92).normalized()],
		[Vector2(6.7, 2.35), Vector2(0.3, 0.95).normalized()],
	]:
		await place(threat[0])
		check(await walk("sprint into pool edge", threat[1], 48, true) < 0.65 and hit_path("/PoolBarrier"),
			"pool wall retains walker near %s" % threat[0])
	await place(Vector2(5.35, 0.55))
	check(await walk("sprint into glasshouse", Vector2(-1, 0), 48, true) < 0.7 and hit_path("/Glasshouse"),
		"glasshouse wall retains walker")
	await place(Vector2(7.68, 1.79))
	check(await walk("walk into bank lamp", Vector2(0, -1), 32) < 0.45 and hit_path("/BankLantern"),
		"bank lamp hull retains walker")
	check(water_entries == 0, "zero physics frames with Traveler center inside pool")
	print("shore_checks: %d failures; %d wet frames" % [failures, water_entries])
	quit(0 if failures == 0 else 1)
