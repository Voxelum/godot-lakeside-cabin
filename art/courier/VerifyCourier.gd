extends SceneTree

func _initialize() -> void:
	call_deferred("measure")

func measure() -> void:
	var c = load("res://art/courier/Courier.tscn").instantiate()
	root.add_child(c)
	for d in [Vector3.BACK, Vector3.FORWARD]:
		c.reset_pose(d)
		assert(c.facing.global_basis.z.dot(d) > 0.99999)
	c.reset_pose(Vector3.BACK)
	var max_knee := 0.0
	var min_floor := 10.0
	var max_clearance := 0.0
	var max_slip := 0.0
	var max_frame := 0.0
	var pass_lift := 0.0
	var last := Vector3.ZERO
	var last_support := Vector3.ZERO
	var last_mode := -1
	const DS := 0.001
	for j in range(2600):
		c.position.z += DS
		c.pose_world(Vector3.BACK, DS, 1.0 / 1500.0)
		if j < 220:
			continue
		var boot: Node3D = c.boots[0]
		var heel: Vector3 = boot.get_node("HeelContact").global_position
		var toe: Vector3 = boot.get_node("ToeContact").global_position
		var floor_y := minf(heel.y, toe.y)
		var other: Node3D = c.boots[1]
		if absf(boot.global_position.z - other.global_position.z) < 0.015:
			pass_lift = maxf(pass_lift, floor_y)
		var p := fposmod(c.phase + 0.05, 1.0)
		var support := heel if heel.y <= toe.y + 0.000001 else toe
		var mode := (0 if support == heel else 1) if p < c.STANCE else -1
		if j > 220:
			max_frame = maxf(max_frame, last.distance_to(toe))
			if mode >= 0 and mode == last_mode:
				max_slip = maxf(max_slip, last_support.distance_to(support))
		last = toe
		last_mode = mode
		last_support = support
		min_floor = minf(min_floor, floor_y)
		max_clearance = maxf(max_clearance, floor_y)
		max_knee = maxf(max_knee, rad_to_deg(c.calves[0].rotation.x))
	print("peak knee deg=%.3f, minimum sole m=%.6f, peak sole lift m=%.3f, max incremental stance slip m=%.6f, max toe sample delta m=%.6f" % [max_knee, min_floor, max_clearance, max_slip, max_frame])
	print("passing lower-sole lift m=%.3f" % pass_lift)
	var ok := pass_lift > 0.13 and max_knee >= 55 and max_knee <= 85 and min_floor >= -0.001 and max_clearance > 0.15 and max_slip < 0.0001 and max_frame < 0.012
	for j in 35:
		c.pose_world(Vector3.BACK, 0.0, 1.0 / 60.0)
	ok = ok and c.gait == 0.0 and absf(c.boots[0].get_node("ToeContact").global_position.y) < 0.001
	quit(0 if ok else 1)
