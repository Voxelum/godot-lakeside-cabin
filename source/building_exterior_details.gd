extends RefCounted
## The accessories never create another room or a second set of windows.
const Shape := preload("res://source/building_structure.gd")
const Batch := preload("res://art/building_trial/mesh_batch.gd")
const Trim := preload("res://art/content_batch/buildings/roof_trim.gd")
const Join := preload("res://art/building_trial/joinery.gd")
const Props := preload("res://art/building_trial/street_props.gd")
const Smith := preload("res://art/content_batch/buildings/blacksmith.gd")
const Lot := preload("res://art/building_trial/building_lot.gd")

static func make(p: Shape, kit, shell: Node3D, hit: StaticBody3D) -> void:
	match p.data.get("attachment", "none"):
		"rain_porch": _porch(p, kit, shell, hit)
		"barn_lean_to": _lean_to(p, kit, hit)
		"awning": _awning(p, kit, shell)
		"smith_bay": _smith(p, kit, shell)
	if p.data.get("sign", "") == "guild":
		preload("res://source/guild_facade.gd").make(p, kit, shell, hit)
	elif not String(p.data.get("sign", "")).is_empty():
		_trade_sign(p, kit.get_layer("hardware"), shell)
	if p.kind == "cabin":
		var window := shell.get_node_or_null("Opening_kitchen") as Marker3D
		if window != null:
			_flower_box(kit.get_layer("timber"), kit.get_layer("garden"), window.transform, p.color("timber"))
	if not p.bay.is_empty():
		_oriel_brackets(p, kit.get_layer("timber"))
		_peg(shell,"Oriel",p.frame(5,0,p.upper+1.0)*Vector3(0,0,.18))

static func _peg(shell: Node3D, label: String, p: Vector3) -> void:
	var peg := Marker3D.new()
	peg.name = label
	peg.position = p
	shell.add_child(peg)

static func _box(body: StaticBody3D, label: String, p: Vector3, size: Vector3) -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.name = label
	collider.position = p
	body.add_child(collider, true)

static func _roof_hit(hit: StaticBody3D, label: String, rim: Array) -> void:
	var node := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for pt: Vector3 in rim:
		points.append(pt)
		points.append(pt - Vector3.UP*.085)
	shape.points = points
	node.shape = shape
	node.name = label
	hit.add_child(node, true)

static func _porch(p: Shape, kit, shell: Node3D, hit: StaticBody3D) -> void:
	var z := p.depth*.5
	var y := p.eave-.04
	var low := y-.38
	var left := -p.width*.5-.09
	var right := p.width*.18
	if p.door.u > 0.0:
		left = -p.width*.18
		right = p.width*.5+.09
	var wood := p.color("timber")
	var stone := p.color("stone")
	var rim := [Vector3(left,low,z+1.32), Vector3(right,low,z+1.32), Vector3(left,y,z-.19), Vector3(right,y,z-.19)]
	Trim.slope(kit.get_layer("roof_tile"), rim[0], rim[1], rim[2], rim[3], p.color("roof").darkened(.075), wood, 5)
	_roof_hit(hit, "PorchCanopy", rim)
	_peg(shell,"PorchEave",Vector3((left+right)*.5,low+.05,z+1.37))
	var b: Batch = kit.get_layer("timber")
	var foot_z := z+1.01
	b.box(Vector3((left+right)*.5,low-.126,foot_z),Vector3(right-left,.17,.19),wood,1)
	for x: float in [left+.16,right-.16]:
		var foot := Vector3(x,-p.rise,foot_z)
		var tall := low-.10+p.rise
		kit.get_layer("masonry").box(foot+Vector3.UP*.079,Vector3(.32,.158,.32),stone)
		b.box(foot+Vector3.UP*tall*.5,Vector3(.164,tall,.174),wood,1)
		b.bar(Vector3(x,low-.54,foot_z),Vector3(x+signf((left+right)*.5-x)*.39,low-.11,foot_z),.112,.123,wood.lightened(.06),Vector3.BACK,1)
		_box(hit,"PorchPost",foot+Vector3.UP*tall*.5,Vector3(.25,tall,.25))
	var planter := Vector3(-signf(p.door.u)*p.width*.376,-p.rise,z+.39)
	Props.pot(kit.get_layer("garden"),planter,.79)
	_box(hit,"PorchPot",planter+Vector3.UP*.126,Vector3(.34,.26,.34))

static func _lean_to(p: Shape, kit, hit: StaticBody3D) -> void:
	var l := p.width*.5-.08
	var r := p.width*.5+1.62
	var f := p.depth*.5-.077
	var z0 := -.68
	var high := p.eave-.27
	var low := high-.48
	var wood := p.color("timber")
	var b: Batch = kit.get_layer("timber")
	for z: float in [z0+.11,f-.12]:
		var foot := Vector3(r-.16,-p.rise,z)
		var tall := low+p.rise
		b.box(foot+Vector3.UP*tall*.50,Vector3(.164,tall,.163),wood,1)
		kit.get_layer("masonry").box(foot+Vector3.UP*.11,Vector3(.235,.22,.236),p.color("stone"))
		_box(hit,"WingPost",foot+Vector3.UP*tall*.50,Vector3(.206,tall,.206))
		b.bar(foot+Vector3.UP*(tall-.45),foot+Vector3(-.41,tall-.065,0),.104,.097,wood,Vector3.BACK,1)
	var rim := [Vector3(r,low,z0), Vector3(r,low,f), Vector3(l,high,z0), Vector3(l,high,f)]
	Trim.slope(kit.get_layer("roof_tile"), rim[0], rim[1], rim[2], rim[3], p.color("roof"), wood, 4)
	_roof_hit(hit,"WingCanopy",rim)

static func _awning(p: Shape, kit, shell: Node3D) -> void:
	var b: Batch = kit.get_layer("awning_cloth")
	var wood := p.color("timber")
	var front := p.depth*.5+1.055
	var back := p.depth*.5+.075
	var high := minf(2.57,p.eave-.20)
	var low := high-.43
	var extent := p.width*.461
	var timber: Batch = kit.get_layer("timber")
	timber.box(Vector3(0,high+.11,back),Vector3(extent*2.07,.23,.17),wood,1)
	for i in 11:
		var ink := p.color("door") if i%2 == 0 else Color("ead6ab")
		var x0 := lerpf(-extent,extent,float(i)/11)
		var x1 := lerpf(-extent,extent,float(i+1)/11)
		var a := Vector3(x0,high,back)
		var c := Vector3(x1,high,back)
		var d := Vector3(x0,low,front)
		var e := Vector3(x1,low,front)
		var m := Vector3((x0+x1)*.5,low-.012,front+.066)
		b.quad(a,a.lerp(c,.5),m,d,Vector3.UP,ink)
		b.quad(a.lerp(c,.5),c,e,m,Vector3.UP,ink.darkened(.07))
		b.quad(a-Vector3.UP*.03,d-Vector3.UP*.03,e-Vector3.UP*.03,c-Vector3.UP*.03,Vector3.DOWN,ink.darkened(.40))
		var dip := Vector3.DOWN*.208
		b.quad(d,m,m+dip,d+dip*.74,Vector3.BACK,ink.darkened(.13))
		b.quad(m,e,e+dip*.74,m+dip,Vector3.BACK,ink.darkened(.17))
	for s: float in [-1,1]:
		timber.bar(Vector3(s*extent,low-.031,front),Vector3(s*extent,high-.76,back),.073,.093,wood,Vector3.RIGHT,1)
	if String(p.data.get("sign", "")).is_empty():
		# Retain the original bakery's loaf sign.
		var sign_recipe := Lot.new()
		sign_recipe._wood = wood
		sign_recipe._accent = p.color("door")
		var sign := Vector3(p.width*.446,high+.28,front+.126)
		sign_recipe._hanging_sign(kit.get_layer("hardware"),sign,back-.13)
		sign_recipe.free()
		_peg(shell,"Sign",sign)

static func _trade_sign(p: Shape, b: Batch, shell: Node3D) -> void:
	# Meter-scale painted silhouettes, not typography that disappears in 320px.
	var awning: bool = p.data.get("attachment", "none") == "awning"
	var wall_z := p.depth*.5
	var y := minf(p.eave-.36, float(p.door.height)+.36)
	var center := Vector3(p.door.u, 2.45 if awning else y, wall_z + (1.18 if awning else .105))
	var wood := p.color("timber")
	var lacquer := p.color("door").darkened(.15)
	var brass := Color("ebcd85")
	b.box(center,Vector3(1.16,.54,.089),wood.lightened(.20),1)
	b.box(center+Vector3.BACK*.050,Vector3(1.075,.455,.021),lacquer,1)
	for s: float in [-1,1]:
		b.roller(center+Vector3(s*.493,0,.065),Vector3.BACK,.028,.030,6,brass)
		if awning:
			b.bar(Vector3(center.x+s*.46,2.60,wall_z-.02),center+Vector3(s*.46,.305,0),.048,.058,wood,Vector3.UP,1)
			b.box(center+Vector3(s*.46,.285,0),Vector3(.059,.14,.071),wood,1)
	var face := center+Vector3.BACK*.073
	match p.data.sign:
		"inn":
			b.box(face+Vector3(.02,-.057,0),Vector3(.54,.137,.025),brass)
			b.box(face+Vector3(-.263,-.023,0),Vector3(.056,.256,.025),brass)
			b.box(face+Vector3(-.159,.043,0),Vector3(.114,.077,.025),brass)
			b.box(face+Vector3(.269,-.101,0),Vector3(.048,.159,.025),brass)
		"tavern":
			b.roller(face+Vector3(.158,-.002,0),Vector3.BACK,.030,.119,10,brass)
			b.roller(face+Vector3(.154,-.002,.021),Vector3.BACK,.026,.067,10,lacquer)
			b.box(face+Vector3(-.048,-.026,.038),Vector3(.32,.276,.042),brass)
			b.box(face+Vector3(-.048,.11,.057),Vector3(.35,.076,.031),Color("ffe2ac"))
		"general_store":
			b.box(face+Vector3(0,-.02,0),Vector3(.052,.272,.023),brass)
			b.box(face+Vector3(0,.103,0),Vector3(.57,.050,.023),brass)
			b.box(face+Vector3(0,-.14,0),Vector3(.22,.047,.023),brass)
			for s: float in [-1,1]:
				b.fan(PackedVector3Array([face+Vector3(s*.195,.08,0),face+Vector3(s*.11,-.086,0),face+Vector3(s*.285,-.086,0)]),Vector3.BACK,brass)
	_peg(shell,"Sign",center)

static func _smith(p: Shape, kit, shell: Node3D) -> void:
	# Preserve the original built forge, anvil and working bay exactly at their
	# lot coordinates. Only the closed stockroom is replaced by the shared wall kit.
	var fixture := Node3D.new()
	fixture.name = "OpenForge"
	shell.add_child(fixture)
	fixture.position = Vector3(-p.origin.x,-p.rise,-p.origin.y)
	var collision := StaticBody3D.new()
	collision.name = "ForgeCollision"
	collision.collision_mask = 0
	fixture.add_child(collision)
	var recipe := Smith.new()
	recipe._generated = fixture
	recipe._solid = collision
	recipe._anchors = fixture
	var details := Batch.new()
	recipe._shelter(details)
	recipe._hearth(details)
	recipe._tools(details)
	recipe._sign_and_lamp(details)
	recipe.free()
	# The old live recipe registered this at runtime. A baked lamp needs the
	# persistent group in the PackedScene so Almanac can find it at startup.
	var lantern := fixture.get_node("DoorLantern") as OmniLight3D
	lantern.remove_from_group(&"night_omni")
	lantern.add_to_group(&"night_omni",true)
	var out: Batch = kit.get_layer("forge_attachments")
	for point in details.points: out.points.append(point+fixture.position)
	out.normals.append_array(details.normals)
	out.colors.append_array(details.colors)
	out.finishes.append_array(details.finishes)
	var a := Vector3(-.05,2.24,1.88)
	var b := Vector3(3.38,2.24,1.88)
	var c := Vector3(-.05,2.95,-1.98)
	var d := Vector3(3.38,2.95,-1.98)
	_roof_hit(collision,"ForgeCanopy",[a,b,c,d])

static func _oriel_brackets(p: Shape, b: Batch) -> void:
	for s: float in [-1,1]:
		var x: float = p.bay.center+s*p.bay.front*.45
		b.bar(Vector3(x,p.upper-.51,p.depth*.5+.06),Vector3(x,p.upper-.05,p.depth*.5+p.bay.projection*.79),.14,.15,p.color("timber"),Vector3.RIGHT,1)

static func _flower_box(b: Batch, leaves: Batch, f: Transform3D, wood: Color) -> void:
	Join.panel(b,f,Vector3(0,-.19,.25),Vector3(1.13,.185,.31),wood,1)
	Join.panel(b,f,Vector3(0,-.103,.251),Vector3(1.18,.065,.37),wood.lightened(.16),1)
	for i in 9:
		var x := -.50 + float(i)*.12
		var tip := .021+.107*absf(sin(i*3.71))
		leaves.roller(f*Vector3(x,-.063,.31),Vector3.UP,.14,.12,5,Color("64805b").lightened(.15*cos(i)))
		if i%2 == 0: leaves.roller(f*Vector3(x,tip,.31),Vector3.UP,.060,.062,5,Color("d4ad74") if i%4 == 0 else Color("ae6860"))
