@tool
extends Node3D
## A closed limewashed store and an open, roofed smithing bay. No shop, interior,
## fire simulation or gameplay script. Y=0 is grade; +Z is the street face.
const Batch := preload("res://art/building_trial/mesh_batch.gd")
const Roof := preload("res://art/building_trial/roof_profiles.gd")
const Rules := preload("res://art/building_trial/lot_rules.gd")
const Join := preload("res://art/building_trial/joinery.gd")
const Props := preload("res://art/building_trial/street_props.gd")
const Trim := preload("res://art/content_batch/buildings/roof_trim.gd")
const Ink := preload("res://world/outskirts/outskirts_shell.gdshader")
const LIME := Color("d6bd99")
const WOOD := Color("634737")
const TILE := Color("a05741")
const STONE := Color("a0917e")
const IRON := Color("514e52")
const BLUE := Color("436860")
const CORE := -1.53
const DEPTH := 1.85
const ENTRY := -2.14
const RISE := .17

@export var lot_id: StringName
var archetype := 4 # Authored function shell; the four regular lot recipes are 0–3.
var door_width := 1.03 # Read by the existing Outskirts path builder.
var mesh_view: MeshInstance3D
var _generated: Node3D
var _anchors: Node3D
var _solid: StaticBody3D

func marker(label: String) -> Marker3D:
	return _anchors.get_node_or_null(label) as Marker3D if is_instance_valid(_anchors) else null

func _ready() -> void:
	_generated = Node3D.new()
	_generated.name = "Generated"
	add_child(_generated)
	_anchors = Node3D.new()
	_anchors.name = "Anchors"
	_generated.add_child(_anchors)
	_solid = StaticBody3D.new()
	_solid.name = "ShellAndLanding"
	_solid.collision_mask = 0
	_generated.add_child(_solid)
	var b := Batch.new()
	_store(b)
	_stoop(b)
	_shelter(b)
	_hearth(b)
	_tools(b)
	_sign_and_lamp(b)
	var paint := ShaderMaterial.new()
	paint.shader = Ink
	mesh_view = b.add_to(_generated,"PaintedShell",paint)
	mesh_view.add_to_group(&"clearing_extension_occluder")

func _store(b: Batch) -> void:
	const H := 2.67
	const W := 3.25
	b.box(Vector3(CORE,.225,0),Vector3(W,.45,DEPTH*2),STONE.darkened(.16))
	b.box(Vector3(CORE,(H+.446)*.5,0),Vector3(W,H-.44,DEPTH*2),LIME)
	_box_shape("StoreWalls",Vector3(CORE,H*.5,0),Vector3(W,H,DEPTH*2))
	for side in 4:
		var f := Transform3D(Basis(Vector3.UP,side*PI*.5),Vector3(CORE,0,0))
		var span := W if side%2==0 else DEPTH*2
		var z := DEPTH if side%2==0 else W*.5
		f = f.translated_local(Vector3(0,0,z))
		for j in 2:
			var n := ceili(span/.48)
			for i in range(-1,n):
				var l := maxf(-span*.5,(i+j*.5)*span/n-span*.5+.011)
				var r := minf(span*.5,(i+1+j*.5)*span/n-span*.5-.011)
				if r-l < .06: continue
				Join.panel(b,f,Vector3((r+l)*.5,.117+.223*j,.029),Vector3(r-l,.196,.081),Batch.tone(STONE,.12*sin(i*3.1+j*2.7+side)))
		Join.panel(b,f,Vector3(0,H-.09,.019),Vector3(span+.09,.19,.15),WOOD,1)
		for s: float in [-1,1]:
			Join.panel(b,f,Vector3(s*(span*.5-.074),(H+.44)*.5,.035),Vector3(.158,H-.44,.128),WOOD,1)
			Join.timber(b,f,Vector3(s*(span*.5-.093),H-.61,.063),Vector3(s*(span*.5-.56),H-.14,.063),Vector2(.086,.098),WOOD.lightened(.08))
		if side in [2,3]:
			Join.window(b,f.translated_local(Vector3(.10,.99,.001)),.72,.87,WOOD,BLUE,STONE,true)
	var cap := Batch.new()
	Roof.new(Rules.FARM,Rules.HIP,Vector4(W,DEPTH*2,H,1.35),H,17201).crown(cap,TILE,WOOD.darkened(.13))
	for p in cap.points: b.points.append(p+Vector3(CORE,0,0))
	b.normals.append_array(cap.normals)
	b.colors.append_array(cap.colors)
	b.finishes.append_array(cap.finishes)
	Join.entry(b,Transform3D(Basis.IDENTITY,Vector3(ENTRY,RISE,DEPTH)),door_width,1.94,WOOD,BLUE,STONE,true,false)
	Join.window(b,Transform3D(Basis.IDENTITY,Vector3(-.72,1.055,DEPTH)),.64,.82,WOOD,BLUE,STONE)

func _stoop(b: Batch) -> void:
	var from := DEPTH-.04
	var flat := DEPTH+.42
	var toe := flat+.84
	var half := (door_width+.41)*.5
	var points := PackedVector3Array()
	for x: float in [ENTRY-half,ENTRY+half]:
		for yz in [Vector2(-.076,from),Vector2(RISE,from),Vector2(RISE,flat),Vector2(0,toe),Vector2(-.076,toe)]:
			points.append(Vector3(x,yz.x,yz.y))
	var ramp := ConvexPolygonShape3D.new()
	ramp.points = points
	var shape := CollisionShape3D.new()
	shape.name = "SlopedStoop"
	shape.shape = ramp
	_solid.add_child(shape)
	for j in 4:
		var z0 := from if j==0 else lerpf(flat,toe,(j-1)/3.0)
		var z1 := flat if j==0 else lerpf(flat,toe,j/3.0)
		var y0 := RISE+.004 if j==0 else lerpf(RISE+.004,.004,(j-1)/3.0)
		var y1 := RISE+.004 if j==0 else lerpf(RISE+.004,.004,j/3.0)
		for i in 3:
			var a := lerpf(ENTRY-half,ENTRY+half,i/3.0)
			var c := lerpf(ENTRY-half,ENTRY+half,(i+1)/3.0)
			b.quad(Vector3(a,y0,z0),Vector3(c,y0,z0),Vector3(c,y1,z1),Vector3(a,y1,z1),Vector3.UP,Batch.tone(STONE,.18+.12*sin(j*6.+i*2.)) )
		for s: float in [-1,1]:
			var x := ENTRY+half*s
			b.quad(Vector3(x,y0,z0),Vector3(x,y1,z1),Vector3(x,0,z1),Vector3(x,0,z0),Vector3.RIGHT*s,STONE.darkened(.10))
		if j>0:
			b.quad(Vector3(ENTRY-half,y0+.003,z0),Vector3(ENTRY+half,y0+.003,z0),Vector3(ENTRY+half,y0+.0004,z0+.033),Vector3(ENTRY-half,y0+.0004,z0+.033),Vector3.UP,STONE.darkened(.18))
	_anchor("DoorAnchor",Vector3(ENTRY,RISE,DEPTH+.103))
	_anchor("Landing",Vector3(ENTRY,RISE,DEPTH+.375))
	_anchor("Approach",Vector3(ENTRY,0,toe+.18))

func _shelter(b: Batch) -> void:
	const FRONT := 1.59
	const LOW := 2.24
	b.box(Vector3(1.62,.001,.12),Vector3(2.98,.039,3.86),Color("797363"))
	for j in 7:
		for i in 5:
			var x := .36+i*.595 + .037*sin(j*2.9)
			var z := -1.42+j*.53+.039*sin(i*2.5+j)
			b.box(Vector3(x,.022,z),Vector3(.50+.04*cos(i*3.+j),.032,.432+.034*sin(j+i)),Batch.tone(STONE.darkened(.16),.14*sin(j*4.+i*2.2)))
	# The eave ends just behind the apron. The projected anvil and lower embers
	# remain visible from the steep F5 camera rather than vanishing under a roof.
	Trim.slope(b,Vector3(-.05,LOW,1.88),Vector3(3.38,LOW,1.88),Vector3(-.05,2.95,-1.98),Vector3(3.38,2.95,-1.98),TILE.darkened(.11),WOOD,10)
	var p := Vector3(1.60,LOW-.064,FRONT)
	b.box(p,Vector3(3.28,.181,.198),WOOD,1)
	for x: float in [.29,3.09]:
		b.box(Vector3(x,.133,FRONT),Vector3(.33,.266,.32),STONE)
		b.box(Vector3(x,1.19,FRONT),Vector3(.187,1.94,.188),WOOD,1)
		_box_shape("BayPost",Vector3(x,1.13,FRONT),Vector3(.25,2.26,.25))
		b.bar(Vector3(x,1.75,FRONT),Vector3(x+signf(1.65-x)*.43,2.21,FRONT),.105,.13,WOOD.lightened(.09),Vector3.BACK,1)
		b.bar(Vector3(x,1.72,FRONT),Vector3(x,2.30,1.39),.104,.106,WOOD,Vector3.RIGHT,1)
		b.bar(Vector3(x,2.22,FRONT),Vector3(x,2.85,-1.62),.146,.146,WOOD,Vector3.RIGHT,1)
	b.box(Vector3(1.64,.25,-1.75),Vector3(3.06,.50,.23),STONE.darkened(.16))
	b.box(Vector3(1.64,1.61,-1.78),Vector3(3.02,2.21,.17),WOOD.darkened(.19),1)
	_box_shape("WeatherScreen",Vector3(1.66,1.39,-1.76),Vector3(3.02,2.78,.22))
	for i in 13:
		b.box(Vector3(.26+i*.227,1.61,-1.687),Vector3(.212,2.23,.041),Batch.tone(WOOD.lightened(.04),.115*sin(i*2.16)),1)
	for y: float in [.59,1.93,2.64]:
		b.box(Vector3(1.63,y,-1.632),Vector3(2.98,.127,.089),WOOD,1)
	b.box(Vector3(2.98,1.47,-1.64),Vector3(.18,2.74,.19),WOOD,1)

func _hearth(b: Batch) -> void:
	const X := 1.27
	const BACK := -.38
	const FACE := .33
	var mortar := Color("75665e")
	var soot := Color("4d3e37")
	b.box(Vector3(X,.30,BACK),Vector3(1.74,.58,1.37),mortar)
	b.box(Vector3(X,1.03,BACK-.48),Vector3(1.58,1.48,.33),soot.darkened(.18))
	for s: float in [-1,1]:
		b.box(Vector3(X+s*.69,.905,BACK),Vector3(.32,1.31,1.32),mortar)
		for i in 4:
			var t := Batch.tone(STONE,.13*sin(i*2.7+s)).darkened(.10)
			b.box(Vector3(X+s*.67,.48+i*.265,FACE-.025),Vector3(.39,.247,.16),t)
			b.box(Vector3(X+s*.855,.48+i*.265,BACK-.016),Vector3(.077,.25,1.22),t.darkened(.08))
	b.box(Vector3(X,.559,FACE+.12),Vector3(1.48,.155,.38),STONE.lightened(.07))
	b.quad(Vector3(X-.52,.635,FACE+.112),Vector3(X+.52,.635,FACE+.112),Vector3(X+.52,.635,BACK-.45),Vector3(X-.52,.635,BACK-.45),Vector3.UP,soot)
	# Recessed mouth, with a stone arch above the ember bed.
	for i in 9:
		var p := PI*float(i)/9
		var q := PI*float(i+1)/9
		var u := Vector3(cos(p),sin(p),0)
		var v := Vector3(cos(q),sin(q),0)
		var o := Vector3(X,1.03,FACE+.024)
		var a := o+u*.53
		var c := o+v*.53
		var d := o+v*.735
		var e := o+u*.735
		b.quad(a,c,d,e,Vector3.BACK,Batch.tone(STONE.darkened(.18),.10*sin(i*3.)))
		b.quad(a,a+Vector3.FORWARD*.79,c+Vector3.FORWARD*.79,c,-(u+v),soot)
	for i in 11:
		var p := Vector3(X+.42*sin(i*4.29),.644+.014*sin(i*3.1),.096+.23*cos(i*2.47))
		b.roller(p,Vector3.UP,.055+.047*absf(sin(i*5.)),.069+.032*cos(i*8.),5,Color("ca754b") if i%3==0 else Color("964c3d") if i%3==1 else soot,3 if i%3<2 else 0)
	# Corbelled shoulders and the tall stone stack are visible above the canopy.
	var shoulder := Vector3(X,1.73,BACK)
	for j in 5:
		var width := 1.71-.132*j
		var depth := 1.39-.108*j
		_masonry_row(b,shoulder+Vector3.UP*(j*.183),width,depth,.181,j,STONE.darkened(.12))
	for j in 8:
		var taper := (1.-.032*j)
		_masonry_row(b,Vector3(X,2.684+j*.224,BACK),1.01*taper,.81*taper,.221,j+5,STONE.darkened(.015))
	b.box(Vector3(X,4.425,BACK),Vector3(.94,.16,.79),STONE.lightened(.08))
	b.box(Vector3(X,4.519,BACK),Vector3(.82,.09,.69),STONE.darkened(.19))
	for s: float in [-1,1]:
		b.box(Vector3(X+s*.302,4.645,BACK),Vector3(.202,.19,.59),mortar)
	b.box(Vector3(X,4.758,BACK),Vector3(1.0,.13,.86),STONE.lightened(.07))
	_box_shape("Hearth",Vector3(X,1.34,BACK),Vector3(1.71,2.68,1.4))
	_anchor("Hearth",Vector3(X+.23,.682,FACE-.048))

func _masonry_row(b: Batch, p: Vector3, w: float, d: float, h: float, row: int, color: Color) -> void:
	b.box(p,Vector3(w-.041,h,d-.041),color.darkened(.30))
	for side in 4:
		var f := Transform3D(Basis(Vector3.UP,PI*.5*side),p)
		var span := w if side%2==0 else d
		var z := d*.5 if side%2==0 else w*.5
		var n := maxi(2,roundi(span/.49))
		for i in range(-1,n):
			var l := maxf(-span*.5,(i+.5*(row%2))*span/n-span*.5+.013)
			var r := minf(span*.5,(i+1+.5*(row%2))*span/n-span*.5-.013)
			if r-l < .065: continue
			var tint := Batch.tone(color,.128*sin(row*2.37+i*3.31+side*.77))
			Join.panel(b,f,Vector3((l+r)*.5,0,z-.013),Vector3(r-l,h-.018,.065),tint)

func _tools(b: Batch) -> void:
	var p := Vector3(1.76,.032,1.05)
	b.lathe(p,Vector3.UP,PackedVector2Array([Vector2(0,0),Vector2(0,.325),Vector2(.11,.29),Vector2(.61,.235),Vector2(.66,.27),Vector2(.66,0)]),9,WOOD.lightened(.17),1)
	b.roller(p+Vector3.UP*.11,Vector3.UP,.07,.307,9,IRON)
	b.box(p+Vector3.UP*.69,Vector3(.55,.114,.40),IRON.darkened(.19))
	b.box(p+Vector3.UP*.815,Vector3(.31,.22,.28),IRON)
	b.box(p+Vector3(-.063,.965,0),Vector3(.59,.13,.41),Color("737980"))
	b.box(p+Vector3(-.375,.962,0),Vector3(.16,.116,.265),IRON)
	b.lathe(p+Vector3(.22,.948,0),Vector3.RIGHT,PackedVector2Array([Vector2(0,.163),Vector2(.13,.130),Vector2(.31,.074),Vector2(.51,.012),Vector2(.528,0)]),8,Color("737980"))
	b.box(p+Vector3(-.085,1.036,.016),Vector3(.61,.017,.302),Color("93989a"))
	_box_shape("AnvilAndStump",p+Vector3(.07,.53,0),Vector3(1.23,1.06,.61))
	_anchor("Anvil",p+Vector3(0,1.067,.01))
	var tub := Vector3(2.72,.026,.64)
	b.lathe(tub,Vector3.UP,PackedVector2Array([Vector2(0,0),Vector2(0,.285),Vector2(.12,.329),Vector2(.65,.374),Vector2(.67,.328),Vector2(.22,.268),Vector2(.22,0)]),12,Color("87674d"),1)
	b.roller(tub+Vector3.UP*.544,Vector3.UP,.026,.328,12,Color("5d7773"))
	for y: float in [.128,.579]: b.roller(tub+Vector3.UP*y,Vector3.UP,.055,.34+y*.081,12,IRON)
	_box_shape("QuenchTub",tub+Vector3.UP*.335,Vector3(.76,.67,.76))
	var bench := Vector3(2.64,.012,-1.245)
	for x: float in [-.42,.42]:
		for z: float in [-.18,.18]:
			b.box(bench+Vector3(x,.401,z),Vector3(.097,.82,.113),WOOD,1)
	b.box(bench+Vector3.UP*.85,Vector3(1.08,.135,.55),WOOD.lightened(.20),1)
	b.box(bench+Vector3(0,.31,-.02),Vector3(.94,.09,.45),WOOD,1)
	_box_shape("Workbench",bench+Vector3.UP*.457,Vector3(1.08,.92,.55))
	for j in 3:
		var start := bench+Vector3(-.35,.942,.14-.109*j)
		b.bar(start,start+Vector3(.63+.069*j,.010,-.061),.041,.051,Color("919397"),Vector3.UP)
	b.box(Vector3(2.53,1.58,-1.605),Vector3(.90,.091,.088),WOOD.lightened(.24),1)
	var t := Vector3(2.71,1.51,-1.559)
	b.bar(t,t+Vector3(.075,-.345,.062),.065,.044,WOOD.lightened(.32),Vector3.BACK,1)
	b.box(t+Vector3(0,.011,.032),Vector3(.23,.115,.118),IRON.lightened(.25))
	for s: float in [-1,1]:
		b.bar(Vector3(2.25,1.44,-1.515),Vector3(2.25+s*.073,1.07,-1.506),.038,.040,IRON.lightened(.24),Vector3.BACK)
	Props.crate(b,Vector3(-2.87,.002,2.087),.45,-.06)
	_box_shape("StockCrate",Vector3(-2.91,.191,2.092),Vector3(.43,.39,.39))

func _sign_and_lamp(b: Batch) -> void:
	var p := Vector3(-.40,2.57,2.38)
	b.bar(Vector3(p.x,2.71,1.79),Vector3(p.x,2.71,2.71),.093,.12,IRON,Vector3.UP)
	b.bar(Vector3(p.x,2.13,1.88),Vector3(p.x,2.71,2.53),.064,.070,IRON,Vector3.RIGHT)
	for x: float in [-.21,.21]:
		b.bar(p+Vector3(x,.095,0),p+Vector3(x*.25,.135,0),.049,.057,IRON)
	var plate := p+Vector3(0,-.245,.016)
	var rim := [Vector2(-.38,.26),Vector2(.38,.26),Vector2(.38,-.16),Vector2(.24,-.29),Vector2(-.23,-.29),Vector2(-.38,-.16)]
	var surface := PackedVector3Array()
	var face := PackedVector3Array()
	for q: Vector2 in rim:
		surface.append(plate+Vector3(q.x,q.y,.061))
		face.append(plate+Vector3(q.x*.846,q.y*.80,.064))
	b.fan(surface,Vector3.BACK,IRON.lightened(.27))
	b.fan(face,Vector3.BACK,BLUE.darkened(.18))
	for i in surface.size():
		var a := surface[i]
		var c := surface[(i+1)%surface.size()]
		b.quad(a,c,c+Vector3.FORWARD*.12,a+Vector3.FORWARD*.12,((c-a).cross(Vector3.FORWARD)).normalized(),IRON)
	var reverse := PackedVector3Array()
	for v in surface: reverse.append(v+Vector3.FORWARD*.12)
	b.fan(reverse,Vector3.FORWARD,BLUE.darkened(.13))
	var brass := Color("c4a578")
	var mark := plate+Vector3.BACK*.075
	b.box(mark+Vector3(0,.061,0),Vector3(.336,.081,.017),brass)
	b.tri(mark+Vector3(.136,.102,0),mark+Vector3(.291,.119,0),mark+Vector3(.137,.008,0),Vector3.BACK,brass)
	b.box(mark+Vector3(-.044,-.035,0),Vector3(.115,.121,.016),brass)
	b.box(mark+Vector3(-.049,-.101,0),Vector3(.262,.069,.018),brass)
	_anchor("Sign",mark)
	var p_lamp := Vector3(-2.91,2.02,2.086)
	Join.lantern(b,p_lamp,.92)
	_anchor("Lamp",p_lamp)
	var lamp := OmniLight3D.new()
	lamp.name = "DoorLantern"
	lamp.position = p_lamp+Vector3(0,-.054,.185)
	lamp.light_color = Color("ffd495")
	lamp.light_energy = 1.10
	lamp.omni_range = 3.25
	lamp.visible = false
	lamp.add_to_group(&"night_omni")
	_generated.add_child(lamp)

func _box_shape(label: String, p: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var geom := BoxShape3D.new()
	geom.size = size
	collision.name = label
	collision.shape = geom
	collision.position = p
	_solid.add_child(collision,true)

func _anchor(label: String, p: Vector3) -> void:
	var peg := Marker3D.new()
	peg.name = label
	peg.position = p
	_anchors.add_child(peg)
