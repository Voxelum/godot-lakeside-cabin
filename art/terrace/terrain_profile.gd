extends RefCounted
## Bare soil height, excluding the ~75 mm walking envelope of the flagstones.
## The baked collision samples this at 0.125 m within the rise.
static func soil(x: float, z: float) -> float:
	var south := 1.0 - smoothstep(2.42, 6.20, z)
	var north := smoothstep(-7.3, -4.25, z)
	var east := 1.0 - smoothstep(4.95, 7.10, x)
	var west_edge := -4.34 + 0.18 * sin(z * 1.13) + 0.08 * sin(z * 2.71)
	var west := smoothstep(west_edge - 1.65, west_edge, x)
	# A shorter, irregular shoulder on either side of the main approach.
	var flank := smoothstep(-0.2, 2.2, x)
	var shoulder := 1.0 - smoothstep(2.52, 4.65 + 0.22 * sin(x * 2.0), z)
	# Keep the original inner shoreline at datum. Points trace its dry-side
	# rim in Clearing world coordinates (the pool mesh is rotated).
	var shoreline := PackedVector2Array([Vector2(1.93,7.05),Vector2(2.07,5.89),Vector2(3.04,4.87),Vector2(3.84,4.15),Vector2(5.07,3.39),Vector2(6.13,2.92),Vector2(7.10,2.63)])
	var bank := 1.0
	if x > shoreline[0].x and x < shoreline[-1].x:
		for i in range(shoreline.size()-1):
			var a := shoreline[i]; var b := shoreline[i+1]
			if x > b.x: continue
			var lip := lerpf(a.y,b.y,inverse_lerp(a.x,b.x,x))
			bank = smoothstep(.10,.99,lip-z)
			break
	return 0.92 * lerpf(south, shoulder, flank) * north * east * west * bank
