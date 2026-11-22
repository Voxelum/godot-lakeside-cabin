extends RefCounted
## Brook Slime: offset crown, scalloped skirt and a painted glaze rather than alpha sorting.
const Kit := preload("res://art/monster_trial/source/rig.gd")

func build() -> PackedScene:
	var k := Kit.new("Slime")
	var b := k.b
	var jelly := k.rig
	b.loft(jelly, "ScallopedJelly", [
		[0.012, Vector2(0, 0.01), Vector2(0.43, 0.34), "17494c"],
		[0.060, Vector2(0, 0.01), Vector2(0.63, 0.48), "287972"],
		[0.166, Vector2(0.012, 0.01), Vector2(0.70, 0.54), "419d86"],
		[0.338, Vector2(-0.02, 0.006), Vector2(0.632, 0.52), "48ab99"],
		[0.522, Vector2(-0.036, -0.014), Vector2(0.511, 0.442), "59bba5"],
		[0.676, Vector2(-0.075, -0.051), Vector2(0.339, 0.312), "7dc7af"],
		[0.769, Vector2(-0.09, -0.071), Vector2(0.15, 0.16), "a7ddbd"],
		[0.804, Vector2(-0.102, -0.083), Vector2(0.06, 0.07), "c9edcb"],
	], 18, Vector3.AXIS_Y, 0.044, true)
	var eyes: Array[Node3D] = []
	for side in [-1, 1]:
		var eye := b.joint(jelly, "EyeL" if side < 0 else "EyeR", Vector3(side * 0.207, 0.328, 0.477), Vector3(-5, side * 16, side * -4))
		eyes.append(eye)
		b.oval(eye, "Ink", Vector3.ZERO, Vector3(0.136, 0.153, 0.067), "172a37", Vector3.ZERO, 9)
		b.oval(eye, "Catchlight", Vector3(-0.025, 0.039, 0.029), Vector3(0.045, 0.045, 0.025), "e1f4ce")
	b.oval(jelly, "Dimples", Vector3(0.012, 0.228, 0.528), Vector3(0.115, 0.041, 0.026), "2c6160", Vector3(6, 0, -7))
	b.oval(jelly, "LongGlaze", Vector3(-0.126, 0.602, 0.345), Vector3(0.225, 0.080, 0.028), "cceec6", Vector3(-40, -8, 24), 11, true)
	b.oval(jelly, "ShortGlaze", Vector3(0.061, 0.572, 0.373), Vector3(0.059, 0.032, 0.023), "a4e0bb", Vector3(-36, 8, 20), 8, true)
	b.oval(jelly, "Mottle", Vector3(0.474, 0.215, 0.393), Vector3(0.101, 0.079, 0.027), "71c9a8", Vector3(0, 36, -18), 8, true)
	b.marker(jelly, "Look", Vector3(0, 0.44, 0.22))
	k.bind([jelly, eyes[0], eyes[1]])
	k.clip(&"idle", 2.4, true, func(p: float) -> void:
		var breathe := sin(p * TAU)
		jelly.scale = Vector3(1.0 - 0.025 * breathe, 1.0 + 0.062 * breathe, 1.0 - 0.025 * breathe)
		jelly.rotation.z = 0.048 * breathe
		var blink := 1.0 - 0.9 * exp(-pow((p - 0.70) * 29.0, 2.0))
		for eye in eyes:
			eye.scale.y = blink
	)
	k.clip(&"move", 0.76, true, func(p: float) -> void:
		var v := Kit.curve([
			[0.00, 0.000, 1.00, 1.00, 1.00, 0.0],
			[0.17, 0.007, 1.13, 0.70, 1.20, 7.0],
			[0.34, 0.082, 0.85, 1.22, 1.03, -6.0],
			[0.51, 0.217, 0.95, 1.08, 1.05, 2.0],
			[0.72, 0.086, 0.98, 1.03, 1.01, 11.0],
			[0.84, 0.025, 1.16, 0.74, 1.14, 4.0],
			[1.00, 0.000, 1.00, 1.00, 1.00, 0.0],
		], p)
		_apply(jelly, v)
	)
	k.clip(&"rebound", 1.56, false, func(p: float) -> void:
		# Pause at the deepest squash so the rebound has a readable anticipation.
		var v := Kit.curve([
			[0.00, 0.000, 1.00, 1.00, 1.00, 0.0],
			[0.22, 0.000, 1.31, 0.48, 1.23, -1.0],
			[0.34, 0.000, 1.38, 0.36, 1.24, 0.0],
			[0.47, 0.232, 0.76, 1.53, 0.80, -8.0],
			[0.57, 0.375, 0.88, 1.29, 0.90, 2.0],
			[0.70, 0.216, 0.95, 1.20, 0.95, 9.0],
			[0.79, 0.010, 1.30, 0.52, 1.18, 2.0],
			[0.89, 0.020, 0.95, 1.12, 0.95, -2.0],
			[0.96, 0.001, 1.05, 0.92, 1.06, 1.0],
			[1.00, 0.000, 1.00, 1.00, 1.00, 0.0],
		], p)
		_apply(jelly, v)
		for eye in eyes:
			eye.scale.y = lerpf(0.42, 1.0, smoothstep(0.43, 0.83, v[2]))
	)
	var result := k.pack()
	k.root.free()
	return result

func _apply(jelly: Node3D, v: PackedFloat32Array) -> void:
	jelly.position.y = v[0]
	jelly.scale = Vector3(v[1], v[2], v[3])
	jelly.rotation_degrees.x = v[4]
