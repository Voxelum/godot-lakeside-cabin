extends RefCounted
## Bramble Scout: shoulder-forward silhouette, blade ears, free hand and a separate club.
const Kit := preload("res://art/monster_trial/source/rig.gd")
const Brush := preload("res://art/monster_trial/source/brush.gd")

func build() -> PackedScene:
	var k := Kit.new("Goblin")
	var b := k.b
	var hips := b.joint(k.rig, "Hips", Vector3(0, 0.635, -0.024))
	b.oval(hips, "Breeches", Vector3(0, 0.03, 0), Vector3(0.55, 0.27, 0.38), "4b4935")
	var spine := b.joint(hips, "Spine", Vector3(0, 0.105, 0), Vector3(15, 0, -4))
	b.loft(spine, "CanvasJerkin", [
		[-0.09, Vector2(0, 0.008), Vector2(0.242, 0.188), "5b4830"],
		[0.034, Vector2(0, 0), Vector2(0.258, 0.189), "795a36"],
		[0.180, Vector2(0, 0), Vector2(0.263, 0.193), "a47842"],
		[0.318, Vector2(-0.005, -0.016), Vector2(0.305, 0.216), "bf995b"],
		[0.415, Vector2(0, -0.033), Vector2(0.246, 0.172), "c7a466"],
		[0.452, Vector2(0, 0.018), Vector2(0.133, 0.127), "745238"],
	], 12, Vector3.AXIS_Y, 0.037)
	b.oval(spine, "Neck", Vector3(0, 0.443, 0.077), Vector3(0.33, 0.22, 0.31), "718546")
	b.loft(spine, "BroadBelt", [
		[0.011, Vector2(0, 0.009), Vector2(0.260, 0.200), "47342e"],
		[0.073, Vector2(0, 0.009), Vector2(0.262, 0.200), "594037"],
		[0.108, Vector2(0, 0.009), Vector2(0.263, 0.200), "795640"],
	], 12, Vector3.AXIS_Y, 0.012)
	b.box(spine, "HammeredBuckle", Vector3(0.062, 0.060, 0.208), Vector3(0.126, 0.098, 0.023), "d1a256", Vector3(0, 4, -7))
	b.box(spine, "BuckleInlay", Vector3(0.063, 0.058, 0.222), Vector3(0.076, 0.058, 0.011), "543a2d", Vector3(0, 4, -7))
	b.box(spine, "ShoulderStrap", Vector3(-0.044, 0.236, 0.191), Vector3(0.075, 0.40, 0.045), "654334", Vector3(-3, 0, 31))
	b.oval(spine, "SidePouch", Vector3(0.238, 0.001, -0.092), Vector3(0.211, 0.238, 0.204), "82513c", Vector3(5, 0, 10))
	b.fold(spine, "TornApron", Vector3(-0.208, 0.039, 0.171), Vector3(0.092, 0.040, 0.191), Vector3(-0.07, -0.219, 0.144), Vector3(-0.064, -0.044, 0.217), Vector3(-0.044, -0.017, 0.123), "a47c45", "6b492f")
	b.loft(spine, "BrickNeckerchief", [
		[0.393, Vector2(0.012, 0.039), Vector2(0.209, 0.166), "883e31"],
		[0.433, Vector2(0.013, 0.039), Vector2(0.208, 0.171), "be6140"],
		[0.474, Vector2(0.012, 0.055), Vector2(0.181, 0.146), "a14a36"],
	], 10, Vector3.AXIS_Y, 0.049)
	var scarf := b.joint(spine, "ScarfTails", Vector3(0.172, 0.438, 0.120))
	b.oval(scarf, "Knot", Vector3.ZERO, Vector3(0.139, 0.113, 0.131), "c36c43")
	b.fold(scarf, "LongTatter", Vector3(-0.040, 0.011, 0.056), Vector3(0.046, -0.029, 0.064), Vector3(0.138, -0.279, 0.128), Vector3(0.073, -0.099, 0.106), Vector3(0.070, -0.084, 0.042), "c57248", "843d34")
	b.fold(scarf, "ShortTatter", Vector3(0.013, 0.026, 0.013), Vector3(0.050, -0.015, 0.022), Vector3(0.24, -0.155, -0.016), Vector3(0.112, -0.054, 0.050), Vector3(0.117, -0.041, -0.007), "a95937", "723a30")

	var head := b.joint(spine, "Head", Vector3(0.006, 0.463, 0.093), Vector3(-9, 0, 3))
	var eyes := _face(b, head)
	var club_arm := b.joint(spine, "ClubShoulder", Vector3(-0.286, 0.328, 0.003), Vector3(-29, -7, -21))
	var club_elbow := _arm(b, club_arm, true)
	var grip := b.joint(club_elbow, "PropSocket", Vector3(0, -0.303, 0.016), Vector3(56, -15, 28))
	_club(b, grip)
	var free_arm := b.joint(spine, "FreeShoulder", Vector3(0.286, 0.309, 0.013), Vector3(19, 3, 15))
	var free_elbow := _arm(b, free_arm, false)
	var legs: Array[Kit.Leg] = []
	for i in 2:
		var side := float(i * 2 - 1)
		var socket := hips.position + Vector3(side * 0.147, -0.040, 0.014)
		var ankle := Vector3(socket.x, 0.126, 0.035 - side * 0.042)
		var leg := Kit.Leg.new(b, k.rig, "LegL" if i == 0 else "LegR", socket, ankle, Vector3(0.318, 0.285, 0), 1.0)
		_boot(b, leg)
		legs.append(leg)

	var parts: Array[Node3D] = [hips, spine, head, scarf, eyes[0], eyes[1], club_arm, club_elbow, grip, free_arm, free_elbow]
	for leg in legs:
		parts.append_array(leg.joints())
	k.bind(parts)
	k.clip(&"idle", 2.8, true, func(p: float) -> void:
		var w := sin(p * TAU)
		hips.position.y += 0.019 * w
		spine.rotation_degrees += Vector3(w * 2.3, w * 4.5, 0)
		head.rotation_degrees.y -= 9.5 * w
		free_elbow.rotation_degrees.x -= 5.0 * w
		scarf.rotation_degrees.z = w * 8.0
		for eye in eyes:
			eye.scale.y = 1.0 - 0.88 * exp(-pow((p - 0.72) * 32.0, 2.0))
		for leg in legs:
			leg.solve(leg.rest_socket + Vector3(0, hips.position.y - 0.635, 0.02 * w), leg.rest_ankle)
	)
	k.clip(&"move", 0.88, true, func(p: float) -> void:
		var w := sin(p * TAU)
		var bob := -0.025 * cos(p * TAU * 2.0)
		hips.position.y += bob
		spine.rotation_degrees += Vector3(4.0, -11.0 * w, w * 8.0)
		head.rotation_degrees += Vector3(-3.0, w * 7.0, -w * 6.0)
		club_arm.rotation_degrees.x += 17.0 * w
		club_elbow.rotation_degrees.x -= 9.0 * w
		free_arm.rotation_degrees.x -= 33.0 * w
		free_elbow.rotation_degrees.x += 10.0 * w
		scarf.rotation_degrees += Vector3(-10.0, 13.0 * w, 10.0 * w)
		for i in 2:
			var leg := legs[i]
			var d := Kit.stride(p + i * 0.5, 0.39, 0.144, 0.60)
			leg.solve(leg.rest_socket + Vector3(0, bob, 0.034), leg.rest_ankle + Vector3(0, d.x, d.y), -d.x * 2.0)
	)
	k.clip(&"feint", 1.52, false, func(p: float) -> void:
		# Dip, show the club, step out and cut across; the free hand counters the turn.
		var v := Kit.curve([
			[0.00,  0.00,  0.00,   0,   0,   0,   0,    0,   0,  0.00],
			[0.20, -0.08, -0.09,  -6, -33,  19, -20,  -24,   8,  0.00],
			[0.37, -0.05, -0.07,  -4, -38, -22, -42,  -38,  14,  0.10],
			[0.47, -0.02,  0.08,  11,  14, -47, -11,  -12,  -5,  0.29],
			[0.56, -0.09,  0.20,  22,  43, -30,  42,   31, -24,  0.40],
			[0.66, -0.07,  0.18,  13,  31, -15,  33,   18, -17,  0.40],
			[0.79, -0.055, 0.06,   1,  10,  -7,  15,    4,  -7,  0.21],
			[0.96,  0.00,  0.00,   0,   0,   0,   0,    0,   0,  0.00],
			[1.00,  0.00,  0.00,   0,   0,   0,   0,    0,   0,  0.00],
		], p)
		hips.position += Vector3(0, v[0], v[1])
		spine.rotation_degrees += Vector3(v[2], v[3], 0.12 * v[3])
		head.rotation_degrees += Vector3(-v[2] * 0.54, -v[3] * 0.67, -v[7] * 0.4)
		club_arm.rotation_degrees += Vector3(v[4], v[5], v[6] * 0.62)
		club_elbow.rotation_degrees += Vector3(v[6] * 0.9, v[5] * 0.30, v[6] * 0.30)
		grip.rotation_degrees += Vector3(v[5] * 0.37, v[7] * 0.63, -v[6] * 0.55)
		free_arm.rotation_degrees += Vector3(v[7] * 1.47, -v[5] * 0.51, absf(v[3]) * 0.36)
		free_elbow.rotation_degrees.x += v[4] * 0.25
		scarf.rotation_degrees += Vector3(-v[4] * 0.55, v[3] * 0.44, -v[3] * 0.58)
		for i in 2:
			var leg := legs[i]
			var lift := 0.0
			if i == 0:
				lift = 0.093 * exp(-pow((p - 0.37) * 18.0, 2.0)) + 0.093 * exp(-pow((p - 0.81) * 15.0, 2.0))
			leg.solve(leg.rest_socket + Vector3(0, v[0], v[1]), leg.rest_ankle + Vector3(0, lift, v[8] if i == 0 else -v[8] * 0.14), -lift * 2.0)
	)
	var result := k.pack()
	k.root.free()
	return result

func _face(b: Brush, head: Node3D) -> Array[Node3D]:
	b.loft(head, "ChiselledHead", [
		[-0.122, Vector2(0, 0.041), Vector2(0.122, 0.125), "58673a"],
		[-0.048, Vector2(0, 0.020), Vector2(0.216, 0.208), "77844a"],
		[0.093, Vector2(0, 0.004), Vector2(0.257, 0.235), "93a358"],
		[0.205, Vector2(0, -0.033), Vector2(0.250, 0.205), "a1ac64"],
		[0.310, Vector2(0, -0.043), Vector2(0.177, 0.189), "b0b573"],
		[0.359, Vector2(0.004, -0.047), Vector2(0.087, 0.093), "8c9a58"],
	], 12, Vector3.AXIS_Y, 0.033)
	b.fold(head, "HookedNose", Vector3(-0.101, 0.145, 0.200), Vector3(0.104, 0.145, 0.203), Vector3(0.025, -0.028, 0.311), Vector3(0.019, 0.063, 0.382), Vector3(0.003, 0.092, 0.151), "afb66a", "73834c")
	b.oval(head, "Underbite", Vector3(0.015, -0.054, 0.212), Vector3(0.246, 0.066, 0.105), "617443", Vector3(-5, 1, -6))
	b.oval(head, "Mouth", Vector3(0.011, -0.041, 0.261), Vector3(0.202, 0.034, 0.032), "403d2c", Vector3(-6, 0, -6))
	b.fold(head, "Scruff", Vector3(-0.152, 0.267, -0.085), Vector3(0.126, 0.302, -0.047), Vector3(-0.089, 0.412, -0.123), Vector3(-0.042, 0.336, 0.041), Vector3(-0.018, 0.327, -0.160), "5c4832", "362e2b")
	var eyes: Array[Node3D] = []
	for i in 2:
		var s := float(i * 2 - 1)
		var suffix := "L" if i == 0 else "R"
		var ear := b.joint(head, "Ear" + suffix, Vector3(s * 0.205, 0.147 + 0.016 * i, -0.040), Vector3(0, 5 * s, 9 * i))
		b.fold(ear, "Blade", Vector3(-s * 0.027, -0.073, 0.016), Vector3(s * 0.055, 0.103, 0.009), Vector3(s * 0.383, 0.188 - 0.025 * i, -0.083), Vector3(s * 0.119, 0.066, 0.078), Vector3(s * 0.146, 0.062, -0.043), "a6af61", "596b3c")
		b.fold(ear, "InnerCartilage", Vector3(s * 0.039, -0.023, 0.045), Vector3(s * 0.088, 0.081, 0.062), Vector3(s * 0.299, 0.151 - 0.017 * i, -0.033), Vector3(s * 0.137, 0.070, 0.079), Vector3(s * 0.121, 0.059, 0.049), "b58a57", "8b6846")
		if i == 1:
			var ring := TorusMesh.new()
			ring.inner_radius = 0.037
			ring.outer_radius = 0.062
			ring.rings = 10
			ring.ring_segments = 7
			ring.material = b.pigment("d7ac62")
			var stud := b.mesh(ear, "CopperRing", ring, Vector3(0.193, 0.011, 0.005))
			stud.rotation_degrees = Vector3(81, 13, 0)
		b.link(head, "Tusk" + suffix, Vector3(s * 0.101, -0.086, 0.237), Vector3(s * 0.124, 0.003, 0.297), 0.038, 0.004, "e8d0a1", 6)
		var eye := b.joint(head, "Eye" + suffix, Vector3(s * 0.135, 0.129, 0.200), Vector3(-8, s * 25, s * 16))
		eyes.append(eye)
		b.oval(eye, "Socket", Vector3.ZERO, Vector3(0.161, 0.077, 0.064), "4b5838")
		b.oval(eye, "Amber", Vector3(-s * 0.008, -0.004, 0.032), Vector3(0.116, 0.044, 0.023), "e6c46b")
		b.oval(eye, "Pupil", Vector3(-s * 0.014, -0.004, 0.044), Vector3(0.035, 0.042, 0.016), "3b3227", Vector3.ZERO, 8)
		b.oval(head, "Brow" + suffix, Vector3(s * 0.142, 0.177, 0.207), Vector3(0.177, 0.062, 0.075), "7f8e51", Vector3(-5, s * 24, s * 19))
	b.marker(head, "Look", Vector3(0, 0.137, 0.275))
	return eyes

func _arm(b: Brush, upper: Node3D, carries_club: bool) -> Node3D:
	b.oval(upper, "RagSleeve", Vector3(0, -0.058, 0.002), Vector3(0.258, 0.297, 0.245), "ae8249" if carries_club else "8f683d")
	b.link(upper, "UpperArm", Vector3(0, -0.067, 0), Vector3(0, -0.281, 0), 0.109, 0.081, "879550")
	var elbow := b.joint(upper, "Elbow", Vector3(0, -0.278, 0), Vector3(-53 if carries_club else -28, 0, 0))
	b.link(elbow, "Forearm", Vector3(0, 0.042, 0), Vector3(0, -0.29, 0), 0.091, 0.056, "9aa95d")
	b.link(elbow, "Bracer", Vector3(0, -0.12, 0), Vector3(0, -0.245, 0), 0.083, 0.073, "6a4b38" if carries_club else "ac9061")
	b.oval(elbow, "Knuckles", Vector3(0, -0.304, 0.016), Vector3(0.162, 0.181, 0.15), "a2aa62")
	if not carries_club:
		b.oval(elbow, "SplayedThumb", Vector3(0.084, -0.30, 0.047), Vector3(0.085, 0.123, 0.097), "889951", Vector3(0, 0, -34))
	return elbow

func _club(b: Brush, grip: Node3D) -> void:
	var club := b.joint(grip, "RootwoodClub", Vector3.ZERO)
	b.loft(club, "Knotwood", [
		[-0.156, Vector2(0, 0), Vector2(0.046, 0.041), "4f372e"],
		[0.083, Vector2(0, 0), Vector2(0.049, 0.047), "79533a"],
		[0.251, Vector2(-0.010, 0.007), Vector2(0.066, 0.071), "946440"],
		[0.431, Vector2(-0.026, 0.012), Vector2(0.104, 0.097), "a9794a"],
		[0.637, Vector2(-0.049, 0.010), Vector2(0.119, 0.097), "886043"],
		[0.705, Vector2(-0.073, -0.006), Vector2(0.081, 0.073), "ac8457"],
	], 9, Vector3.AXIS_Y, 0.051)
	b.link(club, "HideWrap", Vector3(0, -0.103, 0), Vector3(0, 0.123, 0), 0.058, 0.053, "503a31")
	b.link(club, "IronCollar", Vector3(-0.026, 0.404, 0.01), Vector3(-0.044, 0.485, 0.01), 0.103, 0.119, "544f46", 9)
	b.oval(club, "Rivet", Vector3(-0.048, 0.452, 0.124), Vector3(0.073, 0.071, 0.028), "c4a077")
	b.oval(club, "Burr", Vector3(0.064, 0.569, 0.014), Vector3(0.135, 0.184, 0.123), "8b6343", Vector3(-8, 0, -21))
	b.marker(club, "Tip", Vector3(-0.069, 0.705, 0))

func _boot(b: Brush, leg: Kit.Leg) -> void:
	b.oval(leg.top, "TrouserLeg", Vector3(0, -0.097, 0), Vector3(0.248, 0.415, 0.252), "545039")
	b.link(leg.shin, "WoolHose", Vector3(0, 0.040, 0), Vector3(0, -leg.l2, 0), 0.087, 0.069, "ad915e")
	b.link(leg.shin, "AnkleWrap", Vector3(0, -0.155, 0), Vector3(0, -0.245, 0), 0.081, 0.082, "79513c")
	b.oval(leg.paw, "Boot", Vector3(0, -0.040, 0.062), Vector3(0.218, 0.153, 0.362), "493b34", Vector3.ZERO, 10)
	b.oval(leg.paw, "Toecap", Vector3(0, -0.052, 0.157), Vector3(0.213, 0.112, 0.167), "654839")
	b.marker(leg.paw, "Sole", Vector3(0, -0.1165, 0.062))
