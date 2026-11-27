extends Resource
## One nested ledge, in metres above the shared local datum. Angles start
## at +X and turn toward +Z. One wide cut through the rock carries the trail.
@export var height := 1.6
@export var crest_radius := 6.3
@export var lobes := PackedFloat32Array([1., 1., 1., 1., 1., 1., 1., 1.])
@export var cliff_run := .62
@export_range(0., 1.) var rock_relief := .70
@export var ramp_bearing := 0.0
@export var ramp_arc := 12.0 # Degrees from centre to either full-width edge.
@export var ramp_splay := 15.0 # Additional fade to the narrow rock face.
@export var ramp_run := 3.8

func ramp_weight(angle: float) -> float:
	var offset := absf(rad_to_deg(angle_difference(deg_to_rad(ramp_bearing), angle)))
	return 1.0 - smoothstep(ramp_arc, ramp_arc + ramp_splay, offset)

func radius_at(angle: float) -> float:
	var key := fposmod(angle, TAU) / TAU * lobes.size()
	var i := floori(key)
	var t := key - i
	var n := lobes.size()
	# Periodic Catmull-Rom: anchors change the long silhouette, not the facets.
	return crest_radius * cubic_interpolate(lobes[i], lobes[(i + 1) % n],
		lobes[posmod(i - 1, n)], lobes[(i + 2) % n], t)

func section(angle: float, phase: float) -> Vector3:
	var cut := ramp_weight(angle)
	var rock := rock_relief * (1.0 - cut)
	var rag := .13 * sin(angle * 11.0 + phase) + .09 * cos(angle * 19.0 - phase)
	var lip := lerpf(radius_at(angle), radius_at(deg_to_rad(ramp_bearing)), cut) + rock * rag
	var run := lerpf(cliff_run * (1.0 + rock * .22 * sin(angle * 7.0 - phase)), ramp_run, cut)
	return Vector3(lip, run, cut)
