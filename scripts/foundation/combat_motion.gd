extends RefCounted
## View-neutral motion vocabulary. Rigs sample it; only the combat driver owns timing.
const DURATIONS := {&"jab": .40, &"slash": .63, &"thrust": .59, &"roll": .42, &"draw": .36, &"sheathe": .36, &"hurt": .26, &"down": .40}
const STRIKES := {&"jab": [5, 1.10, .67], &"slash": [9, 1.63, .34], &"thrust": [11, 2.20, .87]}

static func sample(action: StringName, progress: float) -> Vector4:
	# X: forward lean, Y: torso twist, Z: dominant arm pitch, W: off-arm pitch.
	var pulse := sin(PI * progress)
	var hit := smoothstep(.10, .44, progress) * (1.0 - smoothstep(.54, 1.0, progress))
	match action:
		&"jab": return Vector4(.24 * hit, -.44 * hit, -1.60 * hit, -.55 * pulse)
		&"slash": return Vector4(.10 * pulse, .98 * pulse - 1.86 * hit, -1.41 * pulse, -.39 * pulse)
		&"thrust": return Vector4(.34 * hit, -.17 * hit, -1.51 * hit, -1.04 * hit)
		&"guard": return Vector4(.12, -.18, -1.39, -1.46)
		&"draw", &"sheathe": return Vector4(0, .34 * pulse, -.91 * pulse, -.27 * pulse)
		&"roll": return Vector4(TAU * smoothstep(0, 1, progress), 0, -.62 * pulse, -.62 * pulse)
		&"hurt": return Vector4(-.34 * pulse, .24 * pulse, .39 * pulse, .26 * pulse)
		&"down": return Vector4(1.43 * progress, 0, .37 * progress, .37 * progress)
	return Vector4.ZERO
