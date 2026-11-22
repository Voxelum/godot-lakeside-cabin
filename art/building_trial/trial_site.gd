@tool
extends Node3D
## Art-only blockout dressing. Lot transforms and their route links live in the scene;
## continuous ground, road pigment, prop batches and colliders are rebuilt from source.
const Batch = preload("res://art/building_trial/mesh_batch.gd")
const Lot = preload("res://art/building_trial/building_lot.gd")
const Props = preload("res://art/building_trial/street_props.gd")
const PIGMENT = preload("res://art/building_trial/trial_pigment.gdshader")

const LANE := [Vector2(-19,2.52),Vector2(-12,1.80),Vector2(-8,2.20),Vector2(-3,2.50),Vector2(1,2.68),Vector2(5,2.57),Vector2(8,2.06),Vector2(12,1.67),Vector2(19,1.23)]
const STREET := [Vector2(-19,1.49),Vector2(-6,1.61),Vector2(-1,1.64),Vector2(4,1.70),Vector2(8,1.88),Vector2(12,.25),Vector2(19,-.25)]
const ALLEY := [Vector2(.60,1.88),Vector2(.34,-2.0),Vector2(.08,-5.7),Vector2(-.43,-8.70)]
const VIEW_YAW := 30.0
const VIEW_PITCH := 36.0
const ZOOM := [6.2, 7.55, 8.95, 10.85, 13.4, 15.0]

@export_enum("Village lane", "Town corner") var setting := 0
@export var wide_focus := Vector3(.10, 1.33, .28)
@export_tool_button("Refresh dressing and approach links") var refresh := _queue_build
@onready var camera: Camera3D = $Camera
@onready var spawn: Marker3D = $ScaleSpawn
@onready var sun: DirectionalLight3D = $Sun
@onready var air: WorldEnvironment = $Air

var pigment := ShaderMaterial.new()
var _generated: Node3D
var _solid: StaticBody3D
var _queued := false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	for lot in lots():
		lot.layout_changed.connect(_queue_build)
	_rebuild()
	view_at(wide_focus, 4, 270)
	lighting(false, false)

func lots() -> Array[Lot]:
	var result: Array[Lot] = []
	for node in $Lots.get_children():
		if node is Lot:
			result.append(node)
	return result

func road_link(lot: Lot) -> Marker3D:
	return get_node_or_null("Links/"+String(lot.name)) as Marker3D

func road() -> Array:
	return LANE if setting == 0 else STREET

func _faces_link(door: Marker3D, link: Marker3D) -> bool:
	return (link.global_position-door.global_position).slide(Vector3.UP).dot(door.global_basis.z) > .90

func _get_configuration_warnings() -> PackedStringArray:
	var notes := PackedStringArray()
	if not is_node_ready():
		return notes
	for lot in lots():
		var link := road_link(lot)
		var door := lot.marker("DoorAnchor")
		if link == null:
			notes.append("Add Links/%s at the accessible street edge." % lot.name)
		elif door != null and not _faces_link(door,link):
			notes.append("%s must face its road link. Turn Street Face or move the link." % lot.name)
	return notes

func view_at(focus: Vector3, zoom: int, pixels_high: int) -> void:
	var axes := Basis.from_euler(Vector3(-deg_to_rad(VIEW_PITCH),deg_to_rad(VIEW_YAW),0))
	camera.size = ZOOM[clampi(zoom,0,ZOOM.size()-1)]
	var texel := camera.size / float(pixels_high)
	var u := focus.dot(axes.x)
	var v := focus.dot(axes.y)
	var aligned := focus + axes.x*(snappedf(u,texel)-u) + axes.y*(snappedf(v,texel)-v)
	camera.global_transform = Transform3D(axes, aligned + axes.z*23.0)

func lighting(dusk: bool, clay: bool) -> void:
	# Compare the same camera and geometry. No clock, save state or main scene.
	var override: StandardMaterial3D = null
	if clay:
		override = StandardMaterial3D.new()
		override.albedo_color = Color("d2c4b8")
		override.metallic_specular = 0.0
		override.roughness = 1.0
	for lot in lots():
		lot.set_review(override, dusk)
	pigment.set_shader_parameter(&"dusk", dusk)
	if dusk:
		sun.rotation_degrees = Vector3(-26,-55,0)
		sun.light_color = Color("bcb0d9")
		sun.light_energy = .59
		air.environment.ambient_light_color = Color("a7aed7")
		air.environment.ambient_light_energy = .47
	else:
		sun.rotation_degrees = Vector3(-52,-34,0)
		sun.light_color = Color("fff3db")
		sun.light_energy = 1.03
		air.environment.ambient_light_color = Color("c4d2dd")
		air.environment.ambient_light_energy = .69

func _queue_build() -> void:
	if is_node_ready() and not _queued:
		_queued = true
		_rebuild.call_deferred()

func _rebuild() -> void:
	_queued = false
	if not is_inside_tree():
		return
	if is_instance_valid(_generated):
		remove_child(_generated)
		_generated.queue_free()
	_generated = Node3D.new()
	_generated.name = "GroundAndDressing"
	add_child(_generated)
	_solid = StaticBody3D.new()
	_solid.name = "WalkableGroundAndPropBlocks"
	_solid.collision_mask = 0
	_generated.add_child(_solid)
	_block(Vector3(0,-.215,0),Vector3(128,.43,128))
	for x: float in [-16,16]:
		_block(Vector3(x,1,0),Vector3(.32,2.0,24))
	for z: float in [-10.25,8.35]:
		_block(Vector3(0,1,z),Vector3(32.4,2.0,.32))
	_rng.seed = 3259 + setting*1987
	pigment.shader = PIGMENT
	var b := Batch.new()
	var g := Batch.new()
	var base := Color("9da76d") if setting == 0 else Color("9b9b80")
	g.quad(Vector3(-64,0,-64),Vector3(64,0,-64),Vector3(64,0,64),Vector3(-64,0,64),Vector3.UP,base,4)
	if setting == 0:
		_village(g,b)
	else:
		_town(g,b)
	for lot in lots():
		var link := road_link(lot)
		var a := lot.marker("Approach")
		var door := lot.marker("DoorAnchor")
		if link == null or a == null or door == null or not _faces_link(door,link):
			continue
		var start := _xz(to_local(a.global_position - a.global_basis.z*.17))
		var end := _xz(to_local(link.global_position))
		var width := lot.door_width + (.19 if setting == 0 else .30)
		if start.distance_to(end) < .13:
			continue
		_ribbon(g,[start,start.lerp(end,.53),end],width,.026 if setting == 0 else .015,Color("ad9471") if setting == 0 else Color("abad9f"),setting==0)
	g.add_to(_generated,"MeadowLanesAndSetts",pigment,false)
	b.add_to(_generated,"WorkAndStreetProps",pigment)
	update_configuration_warnings()

func _block(p: Vector3, extent: Vector3, yaw := 0.0) -> void:
	var s := BoxShape3D.new()
	s.size = extent
	var body := CollisionShape3D.new()
	body.position = p
	body.rotation.y = yaw
	body.shape = s
	_solid.add_child(body)

func _rails(b: Batch, a: Vector3, c: Vector3) -> void:
	Props.rail(b,a,c)
	var d := c-a
	_block((a+c)*.5+Vector3.UP*.36,Vector3(.16,.76,d.length()+.145),atan2(d.x,d.z))

func _xz(p: Vector3) -> Vector2:
	return Vector2(p.x,p.z)

func _point(p: Vector2, height: float) -> Vector3:
	return Vector3(p.x,height,p.y)

func _ribbon(g: Batch, nodes: Array, width: float, y: float, ink: Color, fray := false) -> void:
	var samples: Array[Vector2] = []
	for i in range(nodes.size()-1):
		var a: Vector2 = nodes[i]
		var c: Vector2 = nodes[i+1]
		var n := maxi(1,ceili(a.distance_to(c)/.48)) if fray else 1
		for j in n:
			samples.append(a.lerp(c,float(j)/n))
	samples.append(nodes.back())
	var last := PackedVector3Array()
	for i in samples.size():
		var drift := (samples[mini(i+1,samples.size()-1)]-samples[maxi(0,i-1)]).normalized().orthogonal()
		var l := width*.5 + (.085*sin(float(i)*2.21) if fray else 0.0)
		var r := width*.5 + (.094*cos(float(i)*1.70+.08) if fray else 0.0)
		var p := samples[i]
		var here := PackedVector3Array([_point(p-drift*l,y),_point(p-drift*l*.61,y),_point(p+drift*r*.66,y),_point(p+drift*r,y)])
		if not last.is_empty():
			for j in 3:
				var shade := Batch.tone(ink,(-.031 if j != 1 and fray else 0.0) + (.025*sin(float(i)*1.17) if fray else 0.0))
				g.quad(last[j],last[j+1],here[j+1],here[j],Vector3.UP,shade,4)
		last = here

func _distance(p: Vector2, path: Array) -> float:
	var d := INF
	for j in range(path.size()-1):
		d = minf(d,p.distance_to(Geometry2D.get_closest_point_to_segment(p,path[j],path[j+1])))
	return d

func _in_frontage(p: Vector2, space: float) -> bool:
	for lot in lots():
		var link := road_link(lot)
		var a := lot.marker("Approach")
		var d := lot.marker("DoorAnchor")
		if link == null or a == null:
			continue
		if _distance(p,[_xz(to_local(d.global_position)),_xz(to_local(a.global_position)),_xz(to_local(link.global_position))]) < lot.door_width*.52+space:
			return true
	return false

func _village(g: Batch, b: Batch) -> void:
	_ribbon(g,LANE,3.32,.006,Color("9f8d67"),true)
	_ribbon(g,LANE,2.92,.012,Color("b29b74"),true)
	var shift_left: Array[Vector2] = []
	var shift_right: Array[Vector2] = []
	for p: Vector2 in LANE:
		shift_left.append(p + Vector2(0,-.64))
		shift_right.append(p + Vector2(0,.66))
	_ribbon(g,shift_left,.39,.016,Color("b6a17d"),true)
	_ribbon(g,shift_right,.45,.016,Color("b9a17c"),true)
	for i in 940:
		var p := Vector2(_rng.randf_range(-18,18),_rng.randf_range(-9.7,8.1))
		var d := _distance(p,LANE)
		if d < 1.44 and _rng.randf() < .67:
			stone(g,p,.019,_rng.randf_range(.047,.127),_rng.randf_range(.036,.090),Batch.tone(Color("ad9475"),_rng.randf_range(-.079,.16)))
		elif d > 1.57 and not _in_frontage(p,.40):
			var h := _rng.randf_range(.059,.275)
			var ink := Batch.tone(Color("778858"),_rng.randf_range(-.10,.235))
			for j in 3:
				var q := _point(p+Vector2(_rng.randf_range(-.12,.12),_rng.randf_range(-.11,.11)),.009)
				b.tri(q,q+Vector3(.057,0,.026),q+Vector3(_rng.randf_range(-.058,.083),h*_rng.randf_range(.57,1.0),-_rng.randf_range(.01,.08)),Vector3.UP,ink)
			if i%17==0:
				var q := _point(p,h*.72)
				b.roller(q,Vector3.UP,.035,.062,5,Color("ddb779") if i%2==0 else Color("eee0b4"))
	var p := Vector3(-2.39,0,-.55)
	Props.well(b,p)
	_block(p+Vector3.UP*.33,Vector3(1.37,.68,1.38))
	for tree in [Vector4(-11.25,0,-2.88,1.02),Vector4(-10.2,0,-6.02,.92),Vector4(4.21,0,-6.18,.88),Vector4(12.81,0,-2.23,.86)]:
		p = Vector3(tree.x,0,tree.z)
		Props.orchard_tree(b,p,tree.w,tree.x)
		_block(p+Vector3.UP*1.03,Vector3(.34,2.08,.33))
	_rails(b,Vector3(-12.72,0,-.11),Vector3(-10.16,0,.33))
	_rails(b,Vector3(-12.72,0,-.11),Vector3(-12.1,0,-3.39))
	_rails(b,Vector3(12.71,0,-1.12),Vector3(14.98,0,-.91))
	Props.garden(b,Vector3(3.78,0,4.62))
	_rails(b,Vector3(1.87,0,4.19),Vector3(1.87,0,5.92))
	_rails(b,Vector3(1.87,0,5.92),Vector3(5.58,0,5.92))
	_rails(b,Vector3(5.58,0,5.92),Vector3(5.58,0,3.72))
	p = Vector3(-4.89,0,-.29)
	Props.woodpile(b,p)
	_block(p+Vector3.UP*.27,Vector3(1.18,.56,.63))
	Props.pot(b,Vector3(-5.71,0,-.38),.83)
	_block(Vector3(-5.71,.19,-.38),Vector3(.35,.38,.35))
	p = Vector3(9.92,0,-.42)
	Props.straw(b,p,.11)
	Props.straw(b,p+Vector3(.38,0,.611),-.18)
	Props.straw(b,p+Vector3(.15,.43,.102),.31)
	_block(p+Vector3(.18,.42,.25),Vector3(1.25,.84,1.11))
	p = Vector3(8.82,0,-.057)
	Props.crate(b,p,.60,-.18)
	_block(p+Vector3.UP*.23,Vector3(.62,.48,.56),-.18)

func _town(g: Batch,b: Batch) -> void:
	_ribbon(g,STREET,4.14,.010,Color("888982"))
	_ribbon(g,ALLEY,2.65,.011,Color("888982"))
	_ribbon(g,[Vector2(-9.70,-.34),Vector2(-6,-.302),Vector2(-1.22,-.28)],1.00,.014,Color("a99e8d"))
	_ribbon(g,[Vector2(1.50,-.41),Vector2(4.8,-.52),Vector2(9.03,-.52)],1.20,.014,Color("b3a79a"))
	for row in range(-24,17):
		for i in range(-38,39):
			var p := Vector2((i+(row%2)*.5)*.49,row*.352)
			if _distance(p,STREET)>1.94 and _distance(p,ALLEY)>1.22:
				continue
			var jitter := Vector2(_rng.randf_range(-.019,.019),_rng.randf_range(-.012,.012))
			var ink := Batch.tone(Color("a6a7a3").lerp(Color("a99a86"),_rng.randf_range(.0,.54)),_rng.randf_range(-.100,.106))
			stone(g,p+jitter,.024,.232,.162,ink)
	for i in range(-16,14):
		var x := i*.61
		if x > -1.68 and x < 1.23:
			continue
		stone(g,Vector2(x,-.295+x*.008),.028,.298,.224,Batch.tone(Color("bbae97"),.073*sin(float(i)*1.8)))
	for i in 166:
		var p := Vector2(_rng.randf_range(-15,15),_rng.randf_range(-8.8,7.4))
		if _distance(p,STREET)>2.10 and _distance(p,ALLEY)>1.44 and not _in_frontage(p,.27):
			stone(g,p,.017,_rng.randf_range(.045,.15),_rng.randf_range(.05,.13),Batch.tone(Color("a5a08c"),_rng.randf_range(-.06,.08)))
	var p := Vector3(8.57,0,-.165)
	Props.crate(b,p,.62,.173,true)
	Props.crate(b,p+Vector3(.63,0,.205),.70,-.16)
	Props.crate(b,p+Vector3(.62,.608,.179),.41,.132,true)
	Props.cask(b,p+Vector3(.49,0,-.68),.98)
	_block(p+Vector3(.32,.43,.10),Vector3(1.30,.87,.82))
	_block(p+Vector3(.49,.27,-.68),Vector3(.49,.55,.49))
	for q: Vector3 in [Vector3(-4.58,0,-.20),Vector3(9.39,0,-1.06),Vector3(-7.93,0,.18)]:
		Props.pot(b,q,1.17)
		_block(q+Vector3.UP*.20,Vector3(.47,.42,.47))
	p = Vector3(7.29,0,3.92)
	Props.street_lamp(b,p)
	_block(p+Vector3.UP*.94,Vector3(.26,1.88,.26))
	Props.cask(b,Vector3(-7.95,0,-.46),.69)
	_block(Vector3(-7.95,.19,-.46),Vector3(.36,.38,.36))
	p = Vector3(2.42,0,-7.3)
	Props.orchard_tree(b,p,.73,.11)
	_block(p+Vector3.UP*.84,Vector3(.29,1.68,.29))
	_rails(b,Vector3(1.88,0,-8.71),Vector3(4.56,0,-8.71))
	_rails(b,Vector3(-3.70,0,-7.90),Vector3(-1.21,0,-7.90))

func stone(g: Batch,p: Vector2,y: float,rx: float,rz: float,ink: Color) -> void:
	var a := _point(p+Vector2(-rx*.72,-rz),y)
	var c := _point(p+Vector2(rx*.79,-rz),y)
	var d := _point(p+Vector2(rx,-rz*.62),y)
	var e := _point(p+Vector2(rx,rz*.62),y)
	var f := _point(p+Vector2(rx*.76,rz),y)
	var h := _point(p+Vector2(-rx*.79,rz),y)
	var i := _point(p+Vector2(-rx,rz*.56),y)
	var j := _point(p+Vector2(-rx,-rz*.57),y)
	g.fan(PackedVector3Array([a,c,d,e,i,j]),Vector3.UP,ink)
	g.quad(i,h,f,e,Vector3.UP,ink.darkened(.13))
