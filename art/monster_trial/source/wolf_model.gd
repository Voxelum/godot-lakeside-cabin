extends RefCounted
## Ash Wolf: slate saddle, cream ruff, wedge muzzle and a low brush tail.
const Kit := preload("res://art/monster_trial/source/rig.gd")
const Brush := preload("res://art/monster_trial/source/brush.gd")

func build() -> PackedScene:
	var k := Kit.new("Wolf")
	var b := k.b
	var body := b.joint(k.rig, "Body", Vector3(0, 0.70, 0))
	b.loft(body, "SaddleAndRuff", [
		[-0.70, Vector2(0, 0.012), Vector2(0.094, 0.104), "605b57"],
		[-0.58, Vector2(0, -0.009), Vector2(0.234, 0.184), "625f5b"],
		[-0.34, Vector2(0, 0.006), Vector2(0.279, 0.216), "6b6964"],
		[-0.08, Vector2(0, 0.012), Vector2(0.224, 0.207), "696967"],
		[ 0.16, Vector2(0, 0.027), Vector2(0.270, 0.258), "7e7c77"],
		[ 0.39, Vector2(0, 0.063), Vector2(0.335, 0.296), "8c8880"],
		[ 0.56, Vector2(0, 0.094), Vector2(0.291, 0.267), "a4a094"],
		[ 0.75, Vector2(0, 0.167), Vector2(0.206, 0.193), "b1aa9c"],
		[ 0.86, Vector2(0, 0.199), Vector2(0.103, 0.131), "9d978c"],
	], 14, Vector3.AXIS_Z, 0.039, false, 0.59)
	for i in 2:
		var s := float(i * 2 - 1)
		var suffix := "L" if i == 0 else "R"
		b.fold(body, "FurFan" + suffix, Vector3(s * 0.201, 0.236, 0.522), Vector3(s * 0.253, -0.048, 0.508), Vector3(s * 0.385, 0.043, 0.086), Vector3(s * 0.346, 0.087, 0.368), Vector3(s * 0.182, 0.089, 0.293), "a39b8d", "716e66")
		b.fold(body, "BreastLock" + suffix, Vector3(s * 0.119, 0.065, 0.714), Vector3(s * 0.268, -0.029, 0.581), Vector3(s * 0.072, -0.269, 0.409), Vector3(s * 0.172, -0.111, 0.629), Vector3(s * 0.048, -0.053, 0.518), "c7b9a2", "8a8174")
	var tail := b.joint(body, "Tail", Vector3(0, 0.039, -0.607))
	b.loft(tail, "BrushTail", [
		[0.041, Vector2(0, 0), Vector2(0.101, 0.096), "66635e"],
		[-0.19, Vector2(-0.012, -0.022), Vector2(0.137, 0.127), "79726a"],
		[-0.36, Vector2(-0.022, -0.119), Vector2(0.139, 0.127), "827a6e"],
		[-0.58, Vector2(-0.047, -0.223), Vector2(0.103, 0.092), "615952"],
		[-0.77, Vector2(-0.063, -0.262), Vector2(0.066, 0.066), "504846"],
		[-0.89, Vector2(-0.044, -0.238), Vector2(0.013, 0.017), "494344"],
	], 10, Vector3.AXIS_Z, 0.04, false, 0.25)

	var head := b.joint(body, "Head", Vector3(0, 0.224, 0.738), Vector3(-2, 0, 0))
	var jaw := _face(b, head)
	var legs: Array[Kit.Leg] = []
	for j in 2:
		var rear := j == 1
		for i in 2:
			var s := float(i * 2 - 1)
			var label := ("Hind" if rear else "Fore") + ("L" if i == 0 else "R")
			var socket := Vector3(s * (0.214 if rear else 0.227), 0.646 if rear else 0.758, -0.414 if rear else 0.413)
			var ankle := Vector3(socket.x, 0.092, (-0.51 if rear else 0.494) + 0.044 * s)
			var lim := Vector3(0.352, 0.300, 0.155) if rear else Vector3(0.391, 0.396, 0.0)
			var leg := Kit.Leg.new(b, k.rig, label, socket, ankle, lim, 1.0 if rear else -1.0)
			_paw(b, leg, rear)
			legs.append(leg)
	var parts: Array[Node3D] = [body, head, jaw, tail]
	for leg in legs:
		parts.append_array(leg.joints())
	k.bind(parts)
	k.clip(&"idle", 2.8, true, func(p: float) -> void:
		var w := sin(p * TAU)
		body.position.y += w * 0.019
		body.rotation_degrees.x = w * 1.6
		head.rotation_degrees += Vector3(-w * 2.9, 7.5 * w, w * 3.2)
		tail.rotation_degrees = Vector3(2.4 * w, sin(p * TAU * 2.0) * 13.0, 2 * w)
		for leg in legs:
			leg.solve(_socket(body, leg), leg.rest_ankle)
	)
	k.clip(&"move", 0.66, true, func(p: float) -> void:
		var w := sin(p * TAU)
		body.position.y += 0.035 - 0.025 * cos(p * TAU * 2.0)
		body.rotation_degrees.x = w * 4.0
		head.rotation_degrees += Vector3(-w * 2.4 - 2.0, w * 3.0, w * 2.0)
		tail.rotation_degrees = Vector3(-10.0 - w * 3.7, w * 15.0, 0)
		for i in 4:
			var leg := legs[i]
			var diagonal := 0.0 if i == 0 or i == 3 else 0.5
			var d := Kit.stride(p + diagonal - (0.045 if i >= 2 else 0.0), 0.475, 0.127 if i < 2 else 0.17, 0.55)
			leg.solve(_socket(body, leg), leg.rest_ankle + Vector3(0, d.x, d.y), -1.9 * d.x, -0.59 - d.x)
	)
	k.clip(&"pounce", 1.76, false, func(p: float) -> void:
		# Shoulder drop, rear drive, front reach, two-beat catch, gather back to mark.
		var torso := Kit.curve([
			[0.00,  0.000,  0.000,   0,   0,   0,   0],
			[0.18, -0.106, -0.106,  12, -14,  -6,   0],
			[0.37, -0.223, -0.193,  18, -16, -14,   0],
			[0.47, -0.066, -0.084, -16,   9, -17,   7],
			[0.56,  0.221,  0.238, -19,  13, -25,  16],
			[0.66,  0.152,  0.464,   7,  -2, -13,  18],
			[0.73, -0.139,  0.551,  11, -12,   5,   5],
			[0.80, -0.064,  0.472,  -3,  -5,   1,   0],
			[0.90,  0.003,  0.204,  -2,  -2,  -3,   0],
			[1.00,  0.000,  0.000,   0,   0,   0,   0],
		], p)
		body.position += Vector3(0, torso[0], torso[1])
		body.rotation_degrees.x = torso[2]
		head.rotation_degrees.x += torso[3]
		tail.rotation_degrees.x = torso[4]
		jaw.rotation_degrees.x = torso[5]
		for i in 4:
			var leg := legs[i]
			var rear := i >= 2
			var q := clampf(p + ((0.019 if i % 2 == 0 else -0.016) * sin(p * PI)), 0.0, 1.0)
			var foot := Kit.curve(_pounce_steps(rear), q)
			var target := leg.rest_ankle + Vector3(0, foot[0], foot[1])
			leg.solve(_socket(body, leg), target, deg_to_rad(foot[2]), -0.59 - 1.3 * foot[0])
	)
	var result := k.pack()
	k.root.free()
	return result

func _socket(body: Node3D, leg: Kit.Leg) -> Vector3:
	return body.transform * (leg.rest_socket - Vector3(0, 0.70, 0))

func _pounce_steps(rear: bool) -> Array:
	# Time, height above contact, Z reach, paw pitch in degrees.
	if rear:
		return [
			[0.00, 0.00,  0.00,   0], [0.42, 0.00, -0.028,  0],
			[0.49, 0.09, -0.190,  20], [0.61, 0.24,  0.13, -19],
			[0.72, 0.10,  0.56,  -7], [0.78, 0.00,  0.61,   0],
			[0.86, 0.00,  0.61,   0], [0.92, 0.15,  0.25,   8],
			[1.00, 0.00,  0.00,   0],
		]
	return [
		[0.00, 0.00, 0.00, 0], [0.35, 0.00, 0.051, 0],
		[0.44, 0.20, 0.18, -20], [0.52, 0.30, 0.52, -11],
		[0.60, 0.26, 0.89, 10], [0.69, 0.055, 0.995, 4],
		[0.74, 0.00, 0.99, 0], [0.78, 0.00, 0.96, 0],
		[0.88, 0.16, 0.49, -10], [0.94, 0.09, 0.23, -7],
		[1.00, 0.00, 0.00, 0],
	]

func _face(b: Brush, head: Node3D) -> Node3D:
	b.loft(head, "WedgeHead", [
		[-0.17, Vector2(0, 0.017), Vector2(0.138, 0.144), "7d786f"],
		[-0.04, Vector2(0, 0.033), Vector2(0.231, 0.207), "9e9789"],
		[0.105, Vector2(0, 0.037), Vector2(0.228, 0.185), "a8a195"],
		[0.227, Vector2(0, 0.016), Vector2(0.183, 0.116), "aaa193"],
		[0.357, Vector2(0, -0.026), Vector2(0.138, 0.076), "92887d"],
		[0.536, Vector2(0, -0.044), Vector2(0.103, 0.063), "7e746d"],
	], 13, Vector3.AXIS_Z, 0.022, false, 0.65)
	b.oval(head, "NoseLeather", Vector3(0, -0.039, 0.527), Vector3(0.230, 0.128, 0.131), "383642", Vector3(9, 0, 0), 10)
	b.oval(head, "NosePlane", Vector3(-0.035, 0.014, 0.55), Vector3(0.091, 0.029, 0.057), "5b5860")
	var jaw := b.joint(head, "Jaw", Vector3(0, -0.072, 0.163))
	b.oval(jaw, "Chin", Vector3(0, -0.053, 0.167), Vector3(0.256, 0.104, 0.406), "c5b9a6", Vector3(-3, 0, 0), 11)
	b.oval(jaw, "MouthLine", Vector3(0, -0.027, 0.173), Vector3(0.262, 0.035, 0.395), "4e4240", Vector3(-1, 0, 0), 10)
	for i in 2:
		var s := float(i * 2 - 1)
		var suffix := "L" if i == 0 else "R"
		b.fold(head, "CheekFur" + suffix, Vector3(s * 0.184, 0.056, 0.159), Vector3(s * 0.143, -0.118, 0.177), Vector3(s * 0.288, -0.143, -0.077), Vector3(s * 0.244, -0.062, 0.078), Vector3(s * 0.124, -0.055, 0.031), "d1c5af", "837a70")
		var ear := b.joint(head, "Ear" + suffix, Vector3(s * 0.142, 0.182, -0.024), Vector3(2, s * 7, -s * 6))
		b.fold(ear, "GuardFur", Vector3(-s * 0.088, -0.022, 0.01), Vector3(s * 0.082, -0.039, 0.067), Vector3(s * 0.059, 0.225 - i * 0.014, -0.092), Vector3(s * 0.015, 0.055, 0.042), Vector3(s * 0.012, 0.035, -0.074), "8e8982", "655f5d")
		b.fold(ear, "Inner", Vector3(-s * 0.035, 0.018, 0.037), Vector3(s * 0.052, 0.008, 0.050), Vector3(s * 0.05, 0.170 - i * 0.013, -0.049), Vector3(s * 0.017, 0.053, 0.049), Vector3(s * 0.01, 0.04, 0.029), "a18b7c", "716363")
		var eye := b.joint(head, "Eye" + suffix, Vector3(s * 0.176, 0.075, 0.232), Vector3(-12, s * 56, s * 16))
		b.oval(eye, "Marking", Vector3.ZERO, Vector3(0.156, 0.075, 0.052), "4d4a47", Vector3.ZERO, 9)
		b.oval(eye, "Amber", Vector3(0.004 * s, 0.002, 0.025), Vector3(0.101, 0.043, 0.018), "d7a860", Vector3.ZERO, 9)
		b.oval(eye, "Pupil", Vector3(-s * 0.007, 0.000, 0.036), Vector3(0.031, 0.043, 0.012), "423936", Vector3.ZERO, 8)
	b.marker(head, "Look", Vector3(0, 0.075, 0.385))
	b.marker(head, "Nose", Vector3(0, -0.034, 0.588))
	return jaw

func _paw(b: Brush, leg: Kit.Leg, rear: bool) -> void:
	b.oval(leg.top, "GuardCoat", Vector3(0, -0.102, 0.023), Vector3(0.268 if rear else 0.239, 0.449 if rear else 0.476, 0.318 if rear else 0.255), "79736a" if rear else "a49a8a", Vector3.ZERO, 10)
	b.link(leg.shin, "TaperedCuff", Vector3(0, 0.050, 0), Vector3(0, -leg.l2, 0), 0.094 if rear else 0.082, 0.052, "a8a08e", 8)
	if leg.hock != null:
		b.link(leg.hock, "HockFur", Vector3(0, 0.016, 0), Vector3(0, -leg.hock_length, 0), 0.061, 0.049, "8e8375", 7)
	b.oval(leg.paw, "Pad", Vector3(0, -0.034, 0.041), Vector3(0.173 if rear else 0.192, 0.113, 0.236 if rear else 0.254), "837a6e" if rear else "b0a694", Vector3.ZERO, 10)
	b.marker(leg.paw, "Sole", Vector3(0, -0.0905, 0.041))
