extends RefCounted
## View-neutral motion vocabulary. Rigs sample it; only the combat driver owns timing.
const DURATIONS := {&"jab": .40, &"slash": .63, &"thrust": .59, &"roll": .42, &"draw": .36, &"sheathe": .36, &"hurt": .26, &"down": .40}
const STRIKES := {&"jab": [5, 1.10, .67], &"slash": [9, 1.63, .34], &"thrust": [11, 2.20, .87]}

const CONTACT := {&"jab": .43, &"slash": .51, &"thrust": .60}

# Negative = loaded over rear foot, positive = committed over lead foot.
static func slash_yaw(p: float) -> float:
	return lerpf(lerpf(.22, 1.60, smoothstep(0, .28, p)), -1.60, smoothstep(.31, .71, p))

static func weight(action: StringName, p: float) -> float:
	if action != &"slash" and action != &"thrust": return 0.0
	var release := smoothstep(.31, .66 if action == &"thrust" else .70, p)
	return lerpf(-.52 * smoothstep(0, .26, p), 1.0, release) * (1.0 - smoothstep(.71, 1.0, p))

static func sample(action: StringName, progress: float) -> Vector4:
	# X: forward lean, Y: torso twist, Z: dominant arm pitch, W: off-arm pitch.
	var pulse := sin(PI * progress)
	var hit := smoothstep(.10, .44, progress) * (1.0 - smoothstep(.54, 1.0, progress))
	match action:
		&"jab": return Vector4(.24 * hit, -.44 * hit, -1.60 * hit, -.55 * pulse)
		&"slash":
			var w := weight(action, progress)
			return Vector4(.22*w, -1.35*w, -1.55*pulse, -.52*pulse + .40*w)
		&"thrust":
			var w := weight(action, progress)
			return Vector4(.38*w, -.35*w, -1.68*w - .26*pulse, -.87*pulse + .31*w)
		&"guard": return Vector4(.12, -.18, -1.39, -1.46)
		&"draw", &"sheathe": return Vector4(0, .34 * pulse, -.91 * pulse, -.27 * pulse)
		&"roll": return Vector4(TAU * smoothstep(0, 1, progress), 0, -.62 * pulse, -.62 * pulse)
		&"hurt": return Vector4(-.34 * pulse, .24 * pulse, .39 * pulse, .26 * pulse)
		&"down": return Vector4(1.43 * progress, 0, .37 * progress, .37 * progress)
	return Vector4.ZERO
