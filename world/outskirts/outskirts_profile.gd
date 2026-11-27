extends RefCounted
## Clearing-local XZ, in metres. The walked lane, terrain baker and fixtures use
## the same survey. The original southern apron stays exactly as shipped.
const JOIN_Z := 40.0
const ROUTE := [
	Vector2(-1.15, 6.25), Vector2(-.76, 8.15), Vector2(-.30, 10.46),
	Vector2(.22, 12.77), Vector2(.92, 14.94), Vector2(1.82, 16.27),
	Vector2(3.12, 18.33), Vector2(5.20, 20.48), Vector2(7.92, 22.25),
	Vector2(11.04, 24.14), Vector2(14.55, 25.36), Vector2(18.14, 25.76),
	Vector2(20.64, 27.66), Vector2(21.10, 31.72), Vector2(19.15, 36.27),
	Vector2(15.96, 39.71), Vector2(13.45, 43.20), Vector2(12.54, 46.57),
	Vector2(13.23, 49.57), Vector2(15.50, 53.42), Vector2(17.68, 57.51),
	Vector2(18.25, 61.68), Vector2(19.25, 65.39), Vector2(21.61, 69.06),
	Vector2(24.67, 71.92), Vector2(28.55, 73.68), Vector2(32.42, 74.39),
	Vector2(35.58, 74.43),
]
const WIDTH := [2.4, 2.4, 2.4, 2.4, 2.4, 2.57, 2.35, 2.32, 2.52, 2.83, 2.94, 2.89, 2.41, 2.16,
	2.01, 2.02, 1.92, 1.91, 2.03, 2.01, 2.10, 2.18, 2.43, 3.22, 3.84, 4.28, 4.61, 4.42]

# First stations meet the ends of the old Near wall (its local z=9.2).
# The two hedges then open out into paddocks and meet at the town's far end.
const WEST_VERGE := [
	Vector2(-2.328, 12.567), Vector2(-3.64, 16.31), Vector2(-4.52, 21.67), Vector2(-2.56, 27.74),
	Vector2(1.09, 32.76), Vector2(4.01, 37.82), Vector2(3.21, 43.05), Vector2(2.18, 49.30),
	Vector2(2.94, 54.07), Vector2(5.85, 60.72), Vector2(8.27, 66.31), Vector2(13.68, 72.20),
	Vector2(18.16, 77.14), Vector2(25.73, 79.68), Vector2(33.97, 79.46), Vector2(37.99, 77.32),
]
const EAST_VERGE := [
	Vector2(1.785, 10.192), Vector2(4.60, 13.00), Vector2(10.21, 13.47), Vector2(15.63, 14.66),
	Vector2(21.85, 16.52), Vector2(26.56, 22.49), Vector2(27.15, 29.44), Vector2(25.36, 36.06),
	Vector2(22.84, 39.72), Vector2(21.26, 44.88), Vector2(22.58, 50.70), Vector2(24.83, 55.59),
	Vector2(26.65, 60.62), Vector2(28.46, 63.53), Vector2(35.07, 64.09), Vector2(39.14, 67.59),
	Vector2(39.80, 72.04), Vector2(37.99, 77.32),
]

# Market spur on the dry shoulder behind the old Stone Street. The entrance
# cuts only the far rail; none of the original walk stations or lot datums move.
const MARKET_LEVEL := 1.12
const MARKET_PAD := Rect2(15.0, 80.0, 22.4, 21.3)
const MARKET_ROUTE := [
	Vector2(25.43, 74.16), Vector2(25.23, 76.70), Vector2(25.44, 79.43),
	Vector2(25.73, 82.40), Vector2(25.96, 86.06), Vector2(25.86, 89.46),
	Vector2(25.15, 93.74), Vector2(25.18, 97.31), Vector2(26.25, 100.20),
]
const MARKET_WIDTH := [1.95, 2.12, 2.52, 2.74, 3.03, 3.23, 3.31, 3.25, 2.70]
# Endpoints interpolate the old fence segments; the interior points run around
# all four lots with space behind roofs, and no new fence across the approach.
const MARKET_VERGE := [
	Vector2(23.55, 78.949), Vector2(20.64, 79.09), Vector2(16.55, 79.25),
	Vector2(13.71, 81.51), Vector2(13.65, 89.41), Vector2(14.20, 98.42),
	Vector2(17.16, 102.24), Vector2(25.30, 103.15), Vector2(34.85, 102.78),
	Vector2(38.91, 100.29), Vector2(39.15, 91.78), Vector2(38.12, 83.10),
	Vector2(34.91, 80.91), Vector2(27.30, 79.638),
]

# The mountain branch folds one short stretch of the existing west boundary
# around level meadow. Its end points lie on the two old verge segments.
const MOUNTAIN_VERGE := [
	Vector2(-4.254, 20.05), Vector2(-5.30, 18.40), Vector2(-5.85, 16.22),
	Vector2(-7.35, 14.72), Vector2(-9.45, 12.65), Vector2(-12.55, 11.86),
	Vector2(-16.15, 12.00), Vector2(-20.95, 14.70),
	Vector2(-23.10, 18.50), Vector2(-23.70, 23.70), Vector2(-21.15, 28.0),
	Vector2(-17.05, 30.40), Vector2(-12.15, 31.52), Vector2(-9.20, 30.15),
	Vector2(-7.02, 26.92), Vector2(-6.20, 24.62), Vector2(-4.132, 22.87),
]

# Each little habitat sits across a walkable open shoulder, not on the road.
const HABITATS := [Vector2(14.72, 36.22), Vector2(8.78, 45.23), Vector2(12.64, 57.57)]
const PULLOUTS := [Vector2(17.34, 36.45), Vector2(10.84, 45.84), Vector2(15.14, 58.00)]
const HABITAT_SOILS := [Color("a4a17b"), Color("a59276"), Color("a49b85")]
const ALLEY := [Vector2(26.31, 72.62), Vector2(26.32, 70.34), Vector2(26.59, 67.71), Vector2(26.46, 65.63)]
const WELLSIDE := Vector2(12.94, 27.89)
const GARDEN := Vector2(6.32, 23.89)

static func point(p: Vector2, lift := 0.0) -> Vector3:
	return Vector3(p.x, surface(p) + lift, p.y)

static func xz(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)

static func _shoulder(p: Vector2, origin: Vector2, radii: Vector2) -> float:
	return 1.0 - smoothstep(.10, 1.0, ((p - origin) / radii).length())

static func _grade(p: Vector2) -> float:
	if p.y <= JOIN_Z:
		return 0.0
	var h := .18 + .09 * sin(p.x * .31 + p.y * .31) + .08 * cos(p.y * .39 - p.x * .18)
	h += 1.36 * _shoulder(p, Vector2(2.5, 48.0), Vector2(9.2, 11.2))
	h += .91 * _shoulder(p, Vector2(23.4, 50.4), Vector2(6.6, 12.5))
	h += 1.79 * _shoulder(p, Vector2(9.9, 65.9), Vector2(9.1, 10.3))
	h += 1.00 * _shoulder(p, Vector2(27.9, 61.0), Vector2(8.2, 6.3))
	h += 2.47 * _shoulder(p, Vector2(20.4, 90.5), Vector2(22., 14.7))
	h += 1.39 * _shoulder(p, Vector2(42.4, 77.5), Vector2(11.7, 17.2))
	# Set the inhabited stone bench level under lots, ramps and alley.
	var to_bench := (p - Vector2(30, 70)).abs() - Vector2(9.5, 6.2)
	h = lerpf(h, .27, 1.0 - smoothstep(0.0, 3.20, maxf(to_bench.x, to_bench.y)))
	if p.y >= 77.0:
		var to_market := (p - MARKET_PAD.get_center()).abs() - MARKET_PAD.size*.5
		# Retain the old grade through the original fence, including the last
		# grid row that supported old outdoor saves. The new ramp is beyond it.
		var original_edge := ceilf(_old_street_edge_z(p.x))
		var blend := smoothstep(original_edge, original_edge+1.0, p.y)
		h = lerpf(h, MARKET_LEVEL, blend * (1.0 - smoothstep(0.0, 3.0, maxf(to_market.x, to_market.y))))
	return h * smoothstep(JOIN_Z, 45.7, p.y)

static func _old_street_edge_z(x: float) -> float:
	for i in range(WEST_VERGE.size()-5,WEST_VERGE.size()-1):
		var a: Vector2 = WEST_VERGE[i]
		var b: Vector2 = WEST_VERGE[i+1]
		if x <= b.x: return lerpf(a.y,b.y,clampf(inverse_lerp(a.x,b.x,x),0.0,1.0))
	return WEST_VERGE[-1].y

# Same lower-left -> upper-right split as the original terrace, sampled on the
# extension's 1 m grid. This matches the dry soil bake even between vertices.
static func surface(p: Vector2) -> float:
	if p.y <= JOIN_Z:
		return 0.0
	var q := p.floor()
	var f := p - q
	var a := _grade(q)
	var d := _grade(q + Vector2.ONE)
	if f.x >= f.y:
		return a*(1.0-f.x) + _grade(q+Vector2.RIGHT)*(f.x-f.y) + d*f.y
	return a*(1.0-f.y) + _grade(q+Vector2.DOWN)*(f.y-f.x) + d*f.x

static func nearest_track(p: Vector2) -> Vector2:
	return nearest_on(p, ROUTE)

static func nearest_on(p: Vector2, path: Array) -> Vector2:
	var nearest: Vector2 = path[0]
	for i in range(path.size()-1):
		var q := Geometry2D.get_closest_point_to_segment(p, path[i], path[i+1])
		if p.distance_squared_to(q) < p.distance_squared_to(nearest):
			nearest = q
	return nearest
