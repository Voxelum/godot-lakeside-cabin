@tool
extends Node3D
## The seven furnished rooms share this cutaway kit. Local south and the door
## never move; the other three edges can grow independently of the markers.

@export var west := -3.90:
	set(value):
		west = value
		_queue_rebuild()
@export var east := 3.90:
	set(value):
		east = value
		_queue_rebuild()
@export var north := -2.91:
	set(value):
		north = value
		_queue_rebuild()
@export var wall_height := 2.64:
	set(value):
		wall_height = value
		_queue_rebuild()
@export_enum("Oak", "Flagstone", "Brick") var floor_finish := 0:
	set(value):
		floor_finish = value
		_queue_rebuild()
@export var wall_ink := Color("bfaa88"):
	set(value):
		wall_ink = value
		_queue_rebuild()
@export var timber_ink := Color("77503a"):
	set(value):
		timber_ink = value
		_queue_rebuild()
@export var window_x := -0.65:
	set(value):
		window_x = value
		_queue_rebuild()
@export var window_width := 1.50:
	set(value):
		window_width = value
		_queue_rebuild()

const SOUTH := 3.15
const DOOR_X := -1.0
const DOOR_HALF := .91
const WALL := .18
var _kit: Node3D
var _queued := false
var _inks := {}

func _ready() -> void:
	_rebuild()

func _queue_rebuild() -> void:
	if is_node_ready() and not _queued:
		_queued = true
		_rebuild.call_deferred()

func _rebuild() -> void:
	_queued = false
	if _kit != null:
		remove_child(_kit)
		_kit.queue_free()
	_kit = Node3D.new()
	_kit.name = "CutawayKit"
	add_child(_kit)
	_inks.clear()
	var width := east - west
	var depth := SOUTH - north
	var mid := (west + east) / 2.0
	var z_mid := (north + SOUTH) / 2.0
	var base := Vector3(width + WALL, .24, depth + .44)
	_box("Foundation", Vector3(mid, -.144, z_mid + .13), base, timber_ink.darkened(.50))
	_solid("FloorBody", Vector3(mid, -.10, z_mid + .13), Vector3(base.x, .20, base.z))
	_floor(width, depth, mid, z_mid)

	var lo := window_x - window_width / 2.0
	var hi := window_x + window_width / 2.0
	var frame_low := 1.48
	var frame_high := wall_height - .37
	_panel("NorthWainscot", west, east, 0, .90, timber_ink.lightened(.13))
	_panel("NorthApron", west, east, .90, frame_low, wall_ink)
	_panel("NorthLeft", west, lo, frame_low, frame_high, wall_ink)
	_panel("NorthRight", hi, east, frame_low, frame_high, wall_ink)
	_panel("NorthLintel", west, east, frame_high, wall_height, wall_ink)
	_solid("NorthWallBody", Vector3(mid, wall_height / 2, north), Vector3(width, wall_height, WALL))
	_box("SashGlass", Vector3(window_x, (frame_high+frame_low)/2, north+.022), Vector3(window_width, frame_high-frame_low, .055), Color("a5c5ce"), true)
	for x: float in [lo, window_x, hi]:
		_box("SashUpright", Vector3(x, (frame_high+frame_low)/2, north+.13), Vector3(.075, frame_high-frame_low, .10), timber_ink.darkened(.22))
	_box("SashCrosspiece", Vector3(window_x, (frame_high+frame_low)/2, north+.14), Vector3(window_width, .068, .09), timber_ink.darkened(.14))
	_box("SashSill", Vector3(window_x, frame_low, north+.17), Vector3(window_width+.19, .12, .32), timber_ink)
	_box("SashHead", Vector3(window_x, frame_high, north+.13), Vector3(window_width+.17, .11, .13), timber_ink)

	_box("WestWainscot", Vector3(west, .45, z_mid), Vector3(WALL, .9, depth), timber_ink.lightened(.13))
	_box("WestPlaster", Vector3(west, (wall_height+.9)/2, z_mid), Vector3(WALL, wall_height-.90, depth), wall_ink.darkened(.05))
	_solid("WestWallBody", Vector3(west, wall_height/2, z_mid), Vector3(WALL, wall_height, depth))
	for y: float in [.115, .90, wall_height]:
		_box("NorthRail", Vector3(mid, y, north+.10), Vector3(width+.22, .13, .22), timber_ink.darkened(.17))
		_box("WestRail", Vector3(west+.04, y, z_mid), Vector3(.24, .13, depth+.18), timber_ink.darkened(.17))
	for x: float in [west+.10, lerpf(west, lo, .5), lerpf(hi, east, .53), east-.06]:
		_box("NorthPost", Vector3(x, wall_height/2, north+.13), Vector3(.15, wall_height, .16), timber_ink)
	for t: float in [.34, .68, 1.0]:
		_box("WestPost", Vector3(west+.12, wall_height/2, lerpf(north, SOUTH, t)), Vector3(.17, wall_height, .16), timber_ink)

	_cut_wall("EastCut", Vector3(east, 0, z_mid), Vector2(WALL, depth+.17), .58)
	var left_edge := DOOR_X - DOOR_HALF
	var right_edge := DOOR_X + DOOR_HALF
	_cut_wall("SouthWestCut", Vector3((west+left_edge)/2, 0, SOUTH), Vector2(left_edge-west, WALL), .39)
	_cut_wall("SouthEastCut", Vector3((east+right_edge)/2, 0, SOUTH), Vector2(east-right_edge, WALL), .39)
	for x: float in [left_edge-.045, right_edge+.045]:
		_box("DoorJamb", Vector3(x, .41, SOUTH), Vector3(.15, .82, .28), timber_ink)
		_box("DoorFoot", Vector3(x, .08, SOUTH), Vector3(.22, .16, .33), timber_ink.darkened(.28))
	_box("Threshold", Vector3(DOOR_X, -.017, SOUTH), Vector3(2.0, .035, .36), timber_ink.lightened(.22))

func _floor(width: float, depth: float, mid: float, z_mid: float) -> void:
	var colors := [Color("a77f59"), Color("777a76"), Color("ad8068")]
	var pitch := [.42, .83, .59]
	var row_count := ceili(width / pitch[floor_finish])
	var stride := width / row_count
	var step: float = [1.73, .90, .77][floor_finish]
	var c: Color = colors[floor_finish]
	_box("SeamBacking", Vector3(mid, -.012, z_mid+.055), Vector3(width, .02, depth+.18), c.darkened(.32))
	for row in row_count:
		var x := west + (row+.5)*stride
		var start := north
		var seg := 0
		while start < SOUTH+.15-.012:
			var run := step * (0.50 if seg == 0 and row % 2 == 0 else 1.0)
			var end := minf(SOUTH+.15, start+run)
			var length := end-start
			var at := Vector3(x, -.014, (start+end)/2)
			var tint := c.lerp(Color.WHITE if (row+seg)%2 == 0 else Color.BLACK, float((row*7+seg*3)%11)*.010)
			_box("FloorTile", at, Vector3(stride-.011, .028, maxf(.012,length-.013)), tint, true)
			if floor_finish == 0 and length > .42:
				_box("WoodGrain", at + Vector3(((row+seg)%3-1)*.075,.0146,.04), Vector3(.023,.002,length*.51), tint.darkened(.10), true)
			start = end
			seg += 1

func _panel(label: String, from_x: float, to_x: float, from_y: float, to_y: float, ink: Color) -> void:
	_box(label, Vector3((from_x+to_x)/2, (from_y+to_y)/2, north), Vector3(to_x-from_x, to_y-from_y, WALL), ink)

func _cut_wall(label: String, center: Vector3, footprint: Vector2, height: float) -> void:
	var p := center + Vector3.UP*height/2
	var extent := Vector3(footprint.x, height, footprint.y)
	_box(label, p, extent, wall_ink.darkened(.23))
	_solid(label+"Body", p, extent)
	_box(label+"Cap", center+Vector3.UP*height, Vector3(footprint.x+.048,.076,footprint.y+.048), timber_ink)

func _box(label: String, pos: Vector3, extent: Vector3, ink: Color, no_shadow := false) -> void:
	var key := ink.to_rgba32()
	if not _inks.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = ink
		mat.roughness = .94
		_inks[key] = mat
	var mesh := BoxMesh.new()
	mesh.size = extent
	mesh.material = _inks[key]
	var piece := MeshInstance3D.new()
	piece.name = label
	piece.mesh = mesh
	piece.position = pos
	if no_shadow: piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_kit.add_child(piece, true)

func _solid(label: String, pos: Vector3, extent: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = pos
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = extent
	collider.shape = shape
	body.add_child(collider)
	_kit.add_child(body)
