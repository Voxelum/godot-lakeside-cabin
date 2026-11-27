extends RefCounted
## Use the baked/placed collision boxes to recognize obstructed pre-refit saves,
## even on the first frame when the incoming World3D hasn't stepped physics yet.
static func overlaps(foot: Vector3, box: CollisionShape3D, radius: float, height: float) -> bool:
	if box.disabled or not box.shape is BoxShape3D: return false
	var point := box.to_local(foot)
	var half := (box.shape as BoxShape3D).size*.5
	# The Guild's furniture and portico boxes are upright and unscaled.
	var y_gap := maxf(0,maxf(point.y+radius-half.y,-half.y-(point.y+height-radius)))
	var distance := Vector3(maxf(0,absf(point.x)-half.x),y_gap,maxf(0,absf(point.z)-half.z))
	return distance.length_squared() < radius*radius
