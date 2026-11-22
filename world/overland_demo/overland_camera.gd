extends "res://scripts/orbit_camera.gd"
## Use the same orbit lens, six zoom steps and texel snap; follow the traveler
## rather than always looking back at the original cottage once far away.

func wanted_focus() -> Vector3:
	var wide := clampf((size - 6.2) / 7.2, 0.0, 1.0)
	return subject.global_position + Vector3.UP * lerpf(.96, 1.72, wide)
