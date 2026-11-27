extends RefCounted
## Authored enclosed structure in building-local metres. +Z is the street,
## Y=0 the finished ground floor; u runs right when looking from the street side.
const SIDES := ["south", "east", "north", "west", "bay_left", "bay_front", "bay_right"]
const ARCHETYPE := ["farm", "town", "shop", "barn", "cabin", "smith"]
const PROFILES := ["", "sweep", "hip", "steep", "clipped", "gambrel"]
const Rules := preload("res://art/building_trial/lot_rules.gd")
const Roof := preload("res://art/building_trial/roof_profiles.gd")
const Parts := preload("res://source/building_components.gd")
const BODY_RADIUS := .31 # world/Walker.tscn
const BODY_HEIGHT := 1.68
const STEP_CLEAR := .05
const LANDING := 2.0 * BODY_RADIUS + STEP_CLEAR
const EPS := .001
const COPPER_STYLE := {
	"facade": "d8bb9c", "timber": "644435", "stone": "a09182", "roof": "92533e",
	"door": "416b68", "lining": "bfb39f", "interior_timber": "70534a", "floor": "a77f59",
}
const REQUIRED_PAINT := ["facade", "timber", "stone", "roof", "door", "lining", "interior_timber", "floor"]

var data: Dictionary
var source_revision := "" # Changes only with the authored geometry/coordinates.
var authored_revision := "" # Also covers art choices, for checking both bakes.
var width: float
var depth: float
var wall: float
var upper := 0.0
var slab: float
var eave: float
var rise: float
var roof_rise: float
var roof: Roof
var floors: Array[float] = []
var stair: Dictionary
var bay: Dictionary
var hole: Rect2
var inside: Rect2
var openings: Array[Dictionary] = []
var partitions: Array[Dictionary] = []
var front_roof: Array[Dictionary] = []
var door: Dictionary
var style: Dictionary
var kind: String
var floor_finish: String
var wall_panel: String
var origin: Vector2

static func _has_numbers(d: Dictionary, keys: Array) -> bool:
	for k in keys:
		var value: Variant = d.get(k)
		if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value)):
			return false
	return true

func configure(d: Dictionary) -> String:
	data = d
	openings.clear()
	partitions.clear()
	front_roof.clear()
	floors.clear()
	door = {}
	stair = {}
	bay = {}
	hole = Rect2()
	for key in ["building_id", "room_id"]:
		if not d.get(key) is String or d[key].is_empty(): return "Missing stable " + key
	if not d.get("size") is Array or d.size.size() != 2 or not d.get("floors") is Array or d.floors.size() not in [1, 2]:
		return "Expected a footprint and one or two floor levels"
	upper = d.floors[1] if d.floors.size() == 2 and _has_numbers({"y": d.floors[1]}, ["y"]) else 0.0
	if not _has_numbers({"w": d.size[0], "d": d.size[1], "ground": d.floors[0]}, ["w", "d", "ground"]) or d.floors[0] != 0:
		return "Expected finite width, depth and floor levels (ground = 0)"
	if not _has_numbers(d, ["wall_thickness", "stoop_rise", "eave_height", "roof_rise", "slab_thickness"]):
		return "Missing/non-finite wall, entry, roof, slab or area dimensions"
	if d.has("interior_clear_size") or d.has("interior_area_multiplier"):
		return "Interior plan is derived from the shell; remove the interior size override"
	width = d.size[0]; depth = d.size[1]
	wall = d.wall_thickness; rise = d.stoop_rise; eave = d.eave_height; roof_rise = d.roof_rise; slab = d.slab_thickness
	if width <= 2.0 * wall + LANDING or depth <= 2.0 * wall + LANDING or wall < .08 or slab < .10 or slab > .35 or rise < .10 or rise > .36 or roof_rise <= .20 or eave < BODY_HEIGHT + STEP_CLEAR:
		return "Unwalkable footprint or floor/roof dimensions"
	for what in ["stoop_run", "stoop_landing"]:
		if d.has(what) and (not _has_numbers(d, [what]) or d[what] < (.68 if what == "stoop_run" else .35) or d[what] > 1.4):
			return "Invalid stoop dimension: " + what
	var center: Variant = d.get("center", [0, 0])
	if not center is Array or center.size() != 2 or not _has_numbers({"x":center[0], "z":center[1]}, ["x", "z"]): return "Malformed lot center"
	origin = Vector2(center[0], center[1])
	inside = Rect2(-width * .5 + wall, -depth * .5 + wall, width - 2 * wall, depth - 2 * wall)
	var look: Variant = d.get("style", COPPER_STYLE)
	if not look is Dictionary: return "Missing paint palette"
	for paint in REQUIRED_PAINT + ["shutter", "glass", "window_trim", "fascia"]:
		if (paint in REQUIRED_PAINT or look.has(paint)) and (not look.get(paint) is String or not Color.html_is_valid(look[paint])):
			return "Invalid paint for " + paint
	style = look
	kind = d.get("kind", "town")
	floor_finish = d.get("floor_finish", "boards")
	if not d.get("wall_panel", "") is String or not Parts.WALLS.has(Parts.wall_type(d)): return "Invalid wall panel component"
	wall_panel = Parts.wall_type(d)
	var profile := PROFILES.find(d.get("roof_profile", "steep"))
	var axis: Variant = d.get("ridge_axis", "z")
	if kind not in ARCHETYPE or floor_finish not in ["boards", "flags", "brick"] or profile < 1 or axis not in ["x", "z"]:
		return "Invalid house, roof or floor profile"
	if d.get("upper_floor_finish", floor_finish) not in ["boards", "flags", "brick"]: return "Invalid upper floor finish"
	if d.get("entry_style", "arched") not in ["arched", "square", "double"] or d.get("chimney", "legacy") not in ["none", "legacy", "left", "right", "cabin"]:
		return "Invalid entry or chimney type"
	if d.get("attachment", "none") not in ["none", "rain_porch", "barn_lean_to", "smith_bay", "awning"]:
		return "Invalid exterior attachment"
	if d.has("seed") and not _has_numbers(d, ["seed"]): return "Invalid appearance seed"
	roof = Roof.new(Rules.FARM if axis == "x" else Rules.TOWN, profile, Vector4(width, depth, eave, roof_rise), eave, int(d.get("seed", 77193)))
	floors.append(0.0)
	if d.floors.size() == 2:
		var cross_run := depth if roof.along_x else width
		var min_head := eave + roof_rise * roof._grade((wall + Rules.EAVE) / (cross_run * .5 + Rules.EAVE)) - .10 - upper
		if upper - slab < BODY_HEIGHT + STEP_CLEAR or eave <= upper or min_head < BODY_HEIGHT + STEP_CLEAR:
			return "Insufficient headroom below upper deck or roof"
		floors.append(upper)
	elif d.has("stairs"):
		return "A single floor cannot declare stairs"
	if d.has("bay"):
		if floors.size() != 2 or not d.bay is Dictionary or not _has_numbers(d.bay, ["center", "neck", "front", "projection"]):
			return "The oriel needs an upper storey and finite dimensions"
		bay = d.bay
		if bay.front <= 4.0*wall or bay.neck <= bay.front or bay.projection < .70 or absf(bay.center) + bay.neck*.5 > width*.5-wall-.10 or eave-upper < BODY_HEIGHT + .10:
			return "Unsuitable oriel portal, depth or headroom"
	if not d.get("openings") is Array: return "Missing openings array"
	var ids := {}
	for op: Variant in d.openings:
		if not op is Dictionary or not _has_numbers(op, ["u", "floor", "sill", "width", "height"]): return "Malformed wall opening"
		if not op.get("id") is String or not op.id.is_valid_identifier() or ids.has(op.id): return "Opening IDs must be unique identifiers"
		ids[op.id] = true
		var side := SIDES.find(op.get("side"))
		if side < 0 or op.get("kind") not in ["door", "window", "vent"] or float(op.floor) not in ([0.0] if floors.size() == 1 else [0.0, 1.0]):
			return "Invalid side, kind or floor: " + op.id
		var o := op.duplicate() as Dictionary
		o.side_index = side
		o.floor = int(op.floor)
		o.y = floors[o.floor] + op.sill
		o.rect = Rect2(op.u - op.width * .5, o.y, op.width, op.height)
		o.gable = op.get("gable", false)
		if not o.gable is bool: return "Invalid gable opening: " + op.id
		if side >= 4 and (bay.is_empty() or o.floor != 1 or o.gable): return "Bay opening without an upper bay wall: " + op.id
		var span := wall_span(side)
		var top := upper - slab if o.floor == 0 and floors.size() == 2 else eave
		var edge := (.075 if side >= 4 else wall + .07)
		if o.gable:
			if floors.size() != 1 or not gabled(side) or o.y < eave+.06: return "Gable lights belong to the unpartitioned roof volume: " + op.id
			top = minf(gable_top(side, o.rect.position.x), gable_top(side, o.rect.end.x))
		if op.width < .25 or op.height < .25 or o.rect.position.x < -span * .5 + edge or o.rect.end.x > span * .5 - edge or op.sill < 0 or o.rect.end.y > top - .015:
			return "Opening outside its wall or crossing a slab: " + op.id
		if side == 0 and o.floor == 1 and not bay.is_empty() and o.rect.intersects(bay_portal()): return "South opening overlaps oriel connection: " + op.id
		for other in openings:
			if other.side_index == side and other.rect.grow(.025).intersects(o.rect): return "Overlapping openings: " + op.id
		if op.kind == "door":
			if not door.is_empty() or side != 0 or op.floor != 0 or op.sill != 0 or op.width < LANDING or op.height < BODY_HEIGHT + .10:
				return "Expected one walkable ground-floor south door"
			door = o
		else:
			if op.sill < .40 or (op.has("panes") and (not _has_numbers(op, ["panes"]) or float(op.panes) not in [2.0, 3.0])) or (op.has("shutters") and not op.shutters is bool):
				return "Invalid sill or sash style: " + op.id
		if op.kind != "door":
			if not op.get("component", "") is String: return "Invalid opening component: " + op.id
			o.component = Parts.opening_type(op)
			if not Parts.WINDOWS.has(o.component) or (op.kind == "vent") != (o.component == "louver"):
				return "Incompatible opening component: " + op.id
		openings.append(o)
	if door.is_empty(): return "Missing front door"
	var roof_error := _configure_front_roof(d.get("front_roof", []), ids)
	if not roof_error.is_empty(): return roof_error
	if d.get("sign") == "guild" or d.has("portico"):
		var port: Variant = d.get("portico")
		if not port is Dictionary or not _has_numbers(port, ["width", "steps_width", "columns", "project", "roof"]) or not _has_numbers(d, ["stoop_landing", "stoop_run"]) or d.get("sign") != "guild" or not front_roof.any(func(b: Dictionary) -> bool: return not b.has("window")):
			return "Invalid guild portico"
		if port.width > width-.30 or port.steps_width > port.width or port.columns+.33 > port.steps_width*.5 or port.columns-.33 < door.width*.5+.15 or port.project < .85 or port.roof < door.height+.24:
			return "Portico must cover both piers and leave the double portal clear"
	if floors.size() == 2:
		var error := _configure_stair(d)
		if not error.is_empty(): return error
	var partition_error := _configure_partitions(d.get("partitions", []))
	if not partition_error.is_empty(): return partition_error
	if d.get("sign", "") not in ["", "guild", "inn", "tavern", "general_store"]:
		return "Invalid facade emblem"
	var canonical := d.duplicate(true)
	for paint_key in ["style", "seed", "floor_finish", "upper_floor_finish", "chimney", "entry_style", "attachment", "wall_panel", "sign"]:
		canonical.erase(paint_key)
	for op: Dictionary in canonical.openings: op.erase("component")
	source_revision = ("shared-shell/1\n" + JSON.stringify(canonical, "", true, true)).sha256_text()
	authored_revision = JSON.stringify(d, "", true, true).sha256_text()
	return ""

# South-facing cross-gables enter the existing upper volume. The recipe has
# no extra floor; the same resolved plan cuts are used for roofing and glazing.
func _configure_front_roof(input: Variant, ids: Dictionary) -> String:
	if not input is Array: return "Expected an array of front roof bays"
	if input.is_empty(): return ""
	if floors.size() != 2 or not roof.along_x or roof.profile != Rules.STEEP:
		return "Front roof bays need a two-storey straight cross roof with no attic deck"
	for spec: Variant in input:
		if not spec is Dictionary or not _has_numbers(spec, ["u", "width", "setback", "shoulder", "peak"]):
			return "Malformed front roof bay"
		var id: Variant = spec.get("id")
		if not id is String or not id.is_valid_identifier() or ids.has(id): return "Roof bay IDs must be unique identifiers"
		ids[id] = true
		var b: Dictionary = spec.duplicate(true)
		b.z = depth*.5-float(b.setback)
		var half: float = b.width*.5
		var base := roof_y(minf(b.z,roof.half_cross))
		if b.width < .76 or absf(b.u)+half > width*.5-.16 or b.z > roof.half_cross+.27 or b.z < roof.half_cross*.52 or b.shoulder < base+.015 or b.peak < b.shoulder+.28 or b.peak > eave+roof_rise-.30:
			return "Front bay does not intersect the main roof: " + id
		for other in front_roof:
			if absf(other.u-b.u) < half+other.width*.5+.15: return "Overlapping roof bays: " + id
		if b.has("window"):
			var w: Variant = b.window
			if not w is Dictionary or not _has_numbers(w, ["width", "base", "height"]): return "Malformed dormer sash: " + id
			if b.z > depth*.5-.25 or w.width < .40 or w.width > b.width-.33 or w.base < base+.13 or w.height < .30 or w.base+w.height > b.shoulder-.05:
				return "Dormer sash must open through its face into the upper room: " + id
			var opening := {"id":id, "kind":"window", "side":"south", "u":b.u, "side_index":0,
				"floor":1, "sill":w.base-upper, "y":w.base, "width":w.width, "height":w.height,
				"gable":true, "component":"casement", "roof_z":b.z}
			b.opening = opening
			openings.append(opening)
		front_roof.append(b)
	return ""

func roof_y(z: float) -> float:
	return eave+roof_rise*(1.0-z/roof.half_cross)

func opening_frame(o: Dictionary) -> Transform3D:
	if o.has("roof_z"): return Transform3D(Basis.IDENTITY, Vector3(o.u,o.y,o.roof_z))
	return frame(o.side_index,o.u,o.y)

# The longitudinal coordinate increases with the declared local axis. The
# bounded span can snap to either inner shell face, so shell edits need no
# duplicate partition length. Heights derive from floor and slab/eave.
func _configure_partitions(input: Variant) -> String:
	if not input is Array: return "Expected an array of interior partitions"
	var ids := {}
	for spec: Variant in input:
		if not spec is Dictionary or not _has_numbers(spec, ["floor", "at", "thickness"]):
			return "Missing partition floor, transverse coordinate or thickness"
		var id: Variant = spec.get("id")
		if not id is String or not id.is_valid_identifier() or ids.has(id): return "Partition IDs must be unique identifiers"
		ids[id] = true
		var level := int(spec.floor)
		if spec.floor != level or level < 0 or level >= floors.size() or spec.get("axis") not in ["x", "z"]:
			return "Invalid partition axis or floor: " + id
		var along_x: bool = spec.axis == "x"
		var low := inside.position.x if along_x else inside.position.y
		var high := inside.end.x if along_x else inside.end.y
		var a: Variant = spec.get("from")
		var b: Variant = spec.get("to")
		if a is String and a == "min": a = low
		if b is String and b == "max": b = high
		if not _has_numbers({"a":a, "b":b}, ["a", "b"]) or a < low-EPS or b > high+EPS or b-a < LANDING:
			return "Partition ends outside the clear span: " + id
		var half: float = spec.thickness*.5
		var across := inside.position.y if along_x else inside.position.x
		var across_end := inside.end.y if along_x else inside.end.x
		if half < .04 or half > .14 or spec.at-half < across-EPS or spec.at+half > across_end+EPS:
			return "Invalid partition thickness or embedment: " + id
		var footprint := Rect2(a, spec.at-half, b-a, 2.0*half) if along_x else Rect2(spec.at-half, a, 2.0*half, b-a)
		if level == 0:
			# Safe door arrival cannot land against a partition.
			var entry := Rect2(door.u-float(door.width)*.5, depth*.5-1.0, door.width, 1.0-wall)
			if footprint.intersects(entry): return "Partition blocks the ground entry: " + id
		if not stair.is_empty():
			var approach := Rect2(stair.x-stair.width*.5, stair.top_z-LANDING, stair.width, stair.bottom_z-stair.top_z+2.0*LANDING)
			if footprint.intersects(hole.grow(.03) if level == 1 else approach) or (level == 1 and footprint.intersects(Rect2(approach.position, Vector2(approach.size.x, LANDING)))):
				return "Partition blocks the stair or landing: " + id
		var top := (floors[level+1]-slab if level+1 < floors.size() else eave) - floors[level]
		var passages: Array[Dictionary] = []
		if not spec.get("passages", []) is Array: return "Expected a partition passages array: " + id
		for passage: Variant in spec.get("passages", []):
			if not passage is Dictionary or not _has_numbers(passage, ["u", "width", "height"]): return "Malformed partition passage: " + id
			var peg: Variant = passage.get("id")
			if not peg is String or not peg.is_valid_identifier() or ids.has(peg): return "Passage IDs must be unique identifiers"
			ids[peg] = true
			var left: float = passage.u-passage.width*.5
			var right: float = passage.u+passage.width*.5
			if passage.width < LANDING or passage.height < BODY_HEIGHT+.12 or passage.height > top-.065 or left < a+.13 or right > b-.13:
				return "Partition passage lacks head, jamb or walking clearance: " + peg
			passages.append(passage)
		passages.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.u < y.u)
		for i in range(1, passages.size()):
			var first := passages[i-1]
			var second := passages[i]
			if second.u-second.width*.5 < first.u+first.width*.5+.13: return "Overlapping partition passages: " + id
		partitions.append({"id":id, "floor":level, "axis":spec.axis, "at":spec.at, "from":a, "to":b,
			"thickness":spec.thickness, "height":top, "passages":passages})
	return ""

func _configure_stair(d: Dictionary) -> String:
	if not d.get("stairs") is Dictionary: return "Upper floor needs a stair"
	stair = d.stairs.duplicate(true)
	if not _has_numbers(stair, ["x", "width", "bottom_z", "top_z", "steps"]): return "Malformed stair"
	if not stair.get("opening") is Dictionary: return "Upper floor needs a stairwell opening"
	var cut: Dictionary = stair.opening
	if not _has_numbers(cut, ["min_x", "max_x", "min_z", "max_z"]): return "Malformed stairwell opening"
	# Signed offsets in metres from the east and south inner wall faces.
	stair.x += width * .5 - wall
	stair.bottom_z += depth * .5 - wall
	stair.top_z += depth * .5 - wall
	for key in ["min_x", "max_x"]: cut[key] += width * .5 - wall
	for key in ["min_z", "max_z"]: cut[key] += depth * .5 - wall
	hole = Rect2(cut.min_x, cut.min_z, cut.max_x - cut.min_x, cut.max_z - cut.min_z)
	var run: float = stair.bottom_z - stair.top_z
	var count: float = stair.steps
	if run < upper / tan(deg_to_rad(44.0)) or stair.width < LANDING + .08 or count < 2 or count > 40 or count != floorf(count) or upper / count > .21 or run / count < .16:
		return "Stair is too steep/narrow, or has invalid treads"
	if hole.size.x <= 0 or hole.size.y <= 0 or not inside.grow(EPS).encloses(hole) or hole.position.x - inside.position.x < LANDING + .06 or hole.end.x < stair.x + stair.width * .5 or hole.position.x > stair.x - stair.width * .5:
		return "Stair opening must fit the shaft, leaving a usable upper aisle"
	if (stair.x - stair.width*.5) - hole.position.x > .10 or hole.end.x - (stair.x + stair.width*.5) > .10 or inside.end.x - hole.end.x > .10:
		return "Straight stair needs a close-fitting shaft against the east wall"
	if absf(hole.position.y - float(stair.top_z)) > EPS or stair.top_z - inside.position.y < LANDING + .02:
		return "Opening must meet a solid upper landing with turning clearance"
	var under_lip := clampf((stair.bottom_z - hole.end.y + BODY_RADIUS) / run, 0., 1.) * upper
	if upper - slab - under_lip < BODY_HEIGHT + STEP_CLEAR:
		return "Stair opening too short for headroom below the front slab edge"
	var entry_x: float = door.u
	var aisle_edge: float = stair.x - stair.width * .5
	if stair.bottom_z > inside.end.y - BODY_RADIUS - .11 or entry_x - inside.position.x < BODY_RADIUS + STEP_CLEAR or aisle_edge - entry_x < BODY_RADIUS + .005:
		return "Stair blocks the front entry or lacks a lower approach"
	return ""

func color(role: String, fallback := Color("81a6a6")) -> Color:
	return Color(style[role]) if style.has(role) else fallback

func bay_rim() -> PackedVector3Array:
	var z := depth*.5
	var x: float = bay.center
	var a: float = bay.neck*.5
	var b: float = bay.front*.5
	return PackedVector3Array([Vector3(x-a,0,z), Vector3(x-b,0,z+bay.projection), Vector3(x+b,0,z+bay.projection), Vector3(x+a,0,z)])

func bay_portal() -> Rect2:
	return Rect2(bay.center-bay.neck*.5, upper, bay.neck, eave-upper)

func wall_span(side: int) -> float:
	if side >= 4:
		var rim := bay_rim()
		return rim[side-4].distance_to(rim[side-3])
	return width if side % 2 == 0 else depth

func frame(side: int, u := 0.0, y := 0.0, inset := 0.0) -> Transform3D:
	if side >= 4:
		var rim := bay_rim()
		var a := rim[side-4]; var b := rim[side-3]
		var right := (b-a).normalized()
		var basis := Basis(right, Vector3.UP, right.cross(Vector3.UP))
		return Transform3D(basis, (a+b)*.5 + basis*Vector3(u, y, -inset))
	var basis := Basis(Vector3.UP, PI * .5 * side)
	var normal_span := depth if side % 2 == 0 else width
	return Transform3D(basis, basis * Vector3(u, y, normal_span * .5 - inset))

func gabled(side: int) -> bool:
	return side < 4 and (side % 2 == 1) == roof.along_x and roof.profile != Rules.HIP

func gable_top(side: int, u: float) -> float:
	if not gabled(side): return eave
	var t := 1.0-absf(u)/roof.half_cross
	if roof.profile == Rules.CLIPPED:
		t = minf(t, .7 + .3*Rules.EAVE/roof.hip)
	return maxf(eave, eave+roof_rise*roof._grade(t)-.095)

## Both presentations share the source geometry; no plan scaling.
func interior_data() -> Dictionary:
	return data.duplicate(true)
