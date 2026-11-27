extends Resource
## Authoring inputs only; Main loads the finished mesh/collision, not this script.
const Tier := preload("ridge_tier.gd")
@export var origin := Vector3.ZERO
@export var seed := 71103
@export_range(72, 192, 1) var sectors := 96
@export var tiers: Array[Tier] = [] # Lowest to highest.
@export var trail := PackedVector2Array() # Local XZ; can be empty.
@export var trail_widths := PackedFloat32Array() # Full width at each trail point.
@export var rock_tone := Color("99958a")

func validation_error() -> String:
	if not origin.is_finite() or sectors < 72 or sectors > 192 or tiers.is_empty():
		return "Provide a finite origin, 72–192 sectors and at least one tier."
	var last := 0.0
	for tier in tiers:
		if tier == null:
			return "Empty tier."
		for number: float in [tier.height, tier.crest_radius, tier.cliff_run, tier.rock_relief,
			tier.ramp_bearing, tier.ramp_arc, tier.ramp_splay, tier.ramp_run]:
			if not is_finite(number):
				return "Non-finite tier parameter."
		if tier.height <= last or tier.crest_radius < .8 or tier.cliff_run < .25 \
			or tier.cliff_run >= (tier.height - last) or tier.rock_relief < 0.0 or tier.rock_relief > 1.0:
			return "Tiers must rise and their rock faces must be steep."
		if tier.lobes.size() < 4:
			return "Give each crest at least four radial anchors."
		for lobe in tier.lobes:
			if not is_finite(lobe) or lobe < .48 or lobe > 1.65:
				return "Crest anchors must be within .48–1.65."
		if tier.ramp_arc < 6.0 or tier.ramp_splay < 6.0 or tier.ramp_arc + tier.ramp_splay > 70.0 \
			or tier.ramp_run * .82 < 1.5 * (tier.height - last):
			return "Increase the ramp arc, splay or run: its eased centre must stay comfortably below 45 degrees."
		last = tier.height
	if trail.size() != trail_widths.size() or trail.size() == 1:
		return "A trail needs at least two points and exactly one width per point (or neither)."
	for i in trail.size():
		if not trail[i].is_finite() or not is_finite(trail_widths[i]) or trail_widths[i] < .35:
			return "Trail points must be finite and widths at least .35 m."
		if i > 0 and trail[i].distance_to(trail[i-1]) < .30:
			return "Trail points must be at least .30 m apart."
	return ""
