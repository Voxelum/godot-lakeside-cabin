extends Node3D
## Visible ground, trail and rails are drawn from the exact same survey as the AI.
## No second map or hidden collision gate. Only the terrain past the old X=40 edge is added.
const L := preload("farm_layout.gd")
const Catalog := preload("farm_catalog.gd")
const Species := preload("farm_species.gd")
const Brush := preload("res://art/building_trial/mesh_batch.gd")
const OAK := Color("78573f")
const CUT := Color("ae865c")
const REED := Color("467c6b")
const OCHRE := Color("b06c3d")
const STONE := Color("948674")
var ink := ShaderMaterial.new()
var solids := StaticBody3D.new()
var boards := Brush.new()
var dirt := Brush.new()
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 7359231
	ink.shader = preload("res://art/woods/pigments.gdshader")
	solids.name = "RailsAndFixtures"
	solids.collision_mask = 0
	add_child(solids)
	_meadow()
	_path("ParkApproach","SouthLane",L.FORK, L.RECOVERY, .91)
	_path("ParkAisle","ParkApproach",L.RECOVERY, Vector2(L.END-.65,L.AISLE), 1.08)
	_rail(L.NORTH_JOIN, Vector2(L.START,L.AISLE-L.HALF_AISLE))
	_rail(L.SOUTH_JOIN, Vector2(L.START,L.AISLE+L.HALF_AISLE))
	_rail(Vector2(L.END,L.AISLE-L.HALF_AISLE), Vector2(L.END,L.AISLE+L.HALF_AISLE))
	for row in 2:
		var tier := row+1
		var side := L.side(tier)
		var color := REED if tier==1 else OCHRE
		var first := L.gate(tier,0)
		var rear_z := first.y + side * L.DEPTH
		_rail(Vector2(L.START, rear_z), Vector2(L.END, rear_z))
		for col in L.COLUMNS+1:
			var x := L.START + col*L.STRIDE
			_rail(Vector2(x,first.y),Vector2(x,rear_z))
		for col in L.COLUMNS:
			var g := L.gate(tier,col)
			_rail(g-Vector2.RIGHT*L.STRIDE*.5, g-Vector2.RIGHT*L.GATE_HALF)
			_rail(g+Vector2.RIGHT*L.GATE_HALF, g+Vector2.RIGHT*L.STRIDE*.5)
			_gate_post(g-Vector2.RIGHT*L.GATE_HALF, color, tier)
			_gate_post(g+Vector2.RIGHT*L.GATE_HALF, color, 0)
			_path("Pen%d_%d"%[tier,col],"ParkAisle",g-Vector2(0,side*.91),g+Vector2(0,side*2.06),.57)
			if col < Catalog.ROWS[row].size():
				var d: Species = Catalog.ROWS[row][col]
				_bed(g,side,d.soil,col+row*6)
				_backdrop(g+Vector2(-2.68,side*(L.DEPTH+.41)), d.id)
			else:
				_picnic(g+Vector2(1.4,side*3.8))
	_entrance()
	boards.add_to(self,"SplitOakAndPaintedPennants",ink)
	var ground := dirt.add_to(self,"GravelBedsAndWheelRuts",ink,false)
	ground.layers = 2

func _meadow() -> void:
	# BanksideRise already supplies level visible & physical ground through x=40,
	# z=40. The east edge meets it exactly; nothing coplanar under the old road.
	var b := Brush.new()
	b.quad(Vector3(40,0,-30),Vector3(105,0,-30),Vector3(105,0,40),Vector3(40,0,40),Vector3.UP,Color.WHITE)
	# Outside the rear rail SouthVerge still rolls. Reuse every metre of its
	# actual east seam; a flat quad here left a thin sky-colored fissure at x=65.
	const Survey := preload("res://world/outskirts/outskirts_profile.gd")
	for z in range(40,72):
		var a := Survey.point(Vector2(65,z)); var c := Survey.point(Vector2(65,z+1))
		b.quad(a,Vector3(105,a.y,z),Vector3(105,c.y,z+1),c,Vector3.UP,Color.WHITE)
	var turf := ShaderMaterial.new()
	turf.shader = preload("res://art/woods/meadow.gdshader")
	b.add_to(self,"EastMeadow",turf,false).layers = 2
	var soil := StaticBody3D.new()
	soil.name = "EastMeadowSoil"
	soil.collision_mask = 0
	add_child(soil)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(b.points)
	var hit := CollisionShape3D.new()
	hit.shape = shape
	soil.add_child(hit)

func _box(p: Vector3, size: Vector3, yaw := 0.0) -> void:
	var hit := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	hit.shape = shape
	hit.position = p
	hit.rotation.y = yaw
	solids.add_child(hit)

func _rail(from: Vector2, to: Vector2) -> void:
	var parts := maxi(1, roundi(from.distance_to(to) / 1.52))
	var direction := (to-from).normalized()
	for i in parts + 1:
		var a := L.foot(from.lerp(to, float(i)/parts),0)
		var wood := Brush.tone(OAK,.09*sin(a.x*3.2+a.z))
		boards.box(a+Vector3.UP*.40, Vector3(.13,.8,.15),wood,1)
		boards.lathe(a,Vector3.UP,PackedVector2Array([Vector2(.79,.105),Vector2(.86,0)]),4,CUT,1)
		if i < parts:
			var b := L.foot(from.lerp(to,float(i+1)/parts),0)
			for height: float in [.28,.58]: boards.bar(a+Vector3.UP*height,b+Vector3.UP*(height+.018*sin(i)),.092,.09,wood.lightened(.08),Vector3.UP,1)
	_box(L.foot((from+to)*.5,.38),Vector3(.15,.82,from.distance_to(to)+.13),atan2(direction.x,direction.y))

func _gate_post(p: Vector2, paint: Color, marks: int) -> void:
	var foot := L.foot(p,0)
	boards.box(foot+Vector3.UP*.50, Vector3(.17,1.01,.18), OAK,1)
	boards.box(foot+Vector3.UP*.88, Vector3(.185,.20,.19), paint,1)
	if marks > 0:
		boards.box(foot+Vector3.UP*1.03,Vector3(.48,.27,.18),paint,1)
		for j in marks:
			boards.box(foot+Vector3((j - (marks-1)*.5)*.13,1.03,0),Vector3(.053,.16,.192),Color("eed699"))

func _path(id:String, join:String, a: Vector2, b: Vector2, width: float) -> void:
	var lane:=Path3D.new(); lane.curve=Curve3D.new(); lane.curve.add_point(L.foot(a)); lane.curve.add_point(L.foot(b)); add_child(lane); lane.add_to_group("village_map_road")
	lane.set_meta("space_road",preload("res://world/outskirts/settlement_space.gd").road(id,"park_trail",[a,b],[2*width,2*width],[join]))
	var n := maxi(1,ceili(a.distance_to(b)/.60))
	var side := (b-a).normalized().orthogonal()
	var cuts := [-1.0,-.74,-.39,.39,.74,1.0]
	var last := PackedVector3Array()
	for i in n+1:
		var point := a.lerp(b,float(i)/n)
		var strip := PackedVector3Array()
		for j in cuts.size(): strip.append(L.foot(point+side*(cuts[j]*width+rng.randf_range(-.074,.074)), .017))
		if i>0:
			for j in cuts.size()-1:
				var tint := Color("a99c71") if j in [0,4] else (Color("c1af85") if j in [1,3] else Color("afa17b"))
				dirt.quad(last[j],last[j+1],strip[j+1],strip[j],Vector3.UP,Brush.tone(tint,rng.randf_range(-.045,.042)))
		if i%3==0:
			var chip := L.foot(point+side*rng.randf_range(-.80,.80)*width,.021)
			dirt.tri(chip+Vector3(.13,0,.03),chip+Vector3(-.09,0,.10),chip+Vector3(-.12,0,-.065),Vector3.UP,Color("d0bf98"))
		last = strip

func _bed(g: Vector2, side: float, tint: Color, seed_id: int) -> void:
	# A scuffed training hollow under each trio. Low habitat detail lives at the
	# back edges so the playable lane and the three home points remain clear.
	var centre := g+Vector2(0,side*3.55)
	var rim := PackedVector3Array()
	for i in 19:
		var d := Vector2.from_angle(TAU*i/19.)
		rim.append(L.foot(centre + d*Vector2(3.5,2.14)*rng.randf_range(.90,1.04), .010))
	for i in rim.size(): dirt.tri(L.foot(centre,.01),rim[i],rim[(i+1)%rim.size()],Vector3.UP,Brush.tone(tint,rng.randf_range(-.046,.065)))
	for j in 19:
		var u := rng.randf_range(-3.82,3.82)
		var base := L.foot(g+Vector2(u,side*rng.randf_range(5.16,5.67)),.012)
		var h := rng.randf_range(.12,.29)
		if seed_id in [0,4,8]:
			boards.roller(base+Vector3.UP*h*.37,Vector3.UP,h*.74,.026,5,CUT)
			boards.lathe(base,Vector3.UP,PackedVector2Array([Vector2(h*.68,.105),Vector2(h,.036)]),6,Color("bd9459") if seed_id!=4 else STONE)
		elif seed_id in [2,3,6,7]:
			boards.lathe(base,Vector3.UP,PackedVector2Array([Vector2(0,.14),Vector2(h*.62,.105),Vector2(h*.74,.022)]),5,STONE)
		else:
			for k in 3:
				var d := Vector3(cos(k*2.3+u),0,sin(k*2.3+u))
				boards.tri(base-d*.075,base+d*.075,base+d*.10+Vector3.UP*h,Vector3.UP+Vector3.FORWARD,Color("78955b"))

func _backdrop(p: Vector2, species: StringName) -> void:
	# Tiny habitats stand just OUTSIDE each back rail: a readable landmark per
	# species, never an invisible obstacle on a combat approach.
	var a := L.foot(p,0)
	match species:
		&"reed_slime", &"root_maw":
			for i in 7:
				var stalk := a+Vector3(rng.randf_range(-.65,.65),0,rng.randf_range(-.16,.16))
				var top := stalk+Vector3(.10*sin(i),rng.randf_range(.42,.82),.03)
				boards.bar(stalk,top,.04,.04,Color("777c49"))
				boards.roller(top,Vector3.UP,.19 if species==&"reed_slime" else .085,.05 if species==&"reed_slime" else .12,6,Color("926c41") if species==&"reed_slime" else Color("ca765f"))
		&"fern_goblin", &"rawhide_orc":
			boards.box(a+Vector3.UP*.57,Vector3(.13,1.14,.17),OAK,1)
			boards.bar(a+Vector3(-.42,.83,0),a+Vector3(.45,.93,0),.082,.10,CUT)
			var face := a+Vector3(0,.90,.11)
			boards.roller(face,Vector3.BACK,.11,.37,8,Color("a58a5b"))
			boards.roller(face+Vector3.BACK*.062,Vector3.BACK,.029,.22,8,Color("9e624a"))
			boards.roller(face+Vector3.BACK*.082,Vector3.BACK,.02,.106,8,Color("d6af74"))
		&"skeleton_sentry", &"ragged_zombie":
			for i in 2:
				var s := a+Vector3(i*.65,0,-.12*i)
				var h := .75-.16*i
				boards.box(s+Vector3.UP*.09,Vector3(.61,.18,.37),STONE.darkened(.13))
				boards.box(s+Vector3.UP*(h*.5+.13),Vector3(.40,h,.18),STONE)
				boards.lathe(s+Vector3.UP*(h+.12),Vector3.UP,PackedVector2Array([Vector2(0,.22),Vector2(.15,.12)]),4,STONE.lightened(.04))
		&"giant_bee":
			boards.box(a+Vector3.UP*.19,Vector3(.63,.38,.48),OAK,1)
			for j in 3: boards.roller(a+Vector3.UP*(.37+j*.115),Vector3.UP,.106,.40-j*.03,8,Color("c1a15f"))
			boards.lathe(a+Vector3.UP*.65,Vector3.UP,PackedVector2Array([Vector2(0,.35),Vector2(.18,.05)]),8,Color("9a7948"))
		&"giant_spider":
			var high := a+Vector3(-.64,.93,0); var low := a+Vector3(.79,.16,0); var tip := a+Vector3(.36,.77,0)
			boards.bar(a-Vector3.RIGHT*.64,high,.091,.08,OAK)
			boards.bar(a+Vector3.RIGHT*.79,tip,.077,.074,OAK)
			for end: Vector3 in [low,tip]: boards.bar(high,end,.021,.024,Color("c6c1a4"))
			for t: float in [.29,.58,.84]: boards.bar(high.lerp(low,t),high.lerp(tip,t),.017,.022,Color("c6c1a4"))
		&"lesser_imp":
			boards.lathe(a,Vector3.UP,PackedVector2Array([Vector2(0,.31),Vector2(.30,.21),Vector2(.42,.39),Vector2(.52,.40),Vector2(.46,.28)]),7,Color("7e756e"))
			boards.roller(a+Vector3.UP*.46,Vector3.UP,.042,.25,7,Color("a46448"))
		_:
			boards.roller(a+Vector3.UP*.20,Vector3.RIGHT.rotated(Vector3.UP,.15),1.38,.22,7,Color("795b40"),1)
			boards.roller(a+Vector3(-.44,.22,-.13),Vector3(.3,.92,-.14).normalized(),.44,.072,6,CUT,1)

func _picnic(p: Vector2) -> void:
	var at := L.foot(p,0)
	for x: float in [-.50,.50]: boards.box(at+Vector3(x,.17,0),Vector3(.18,.35,.39),STONE)
	boards.box(at+Vector3.UP*.40,Vector3(1.52,.14,.44),CUT,1)
	_box(at+Vector3.UP*.23,Vector3(1.52,.46,.44))

func _entrance() -> void:
	# Opposed gateposts and a small brass paw on a hanging, gabled board.
	var origin:=Vector3(28.12,0,L.AISLE); var gate_mesh:=Brush.new()
	for s: float in [-1,1]:
		var post := Vector3(0,0,s*1.50)
		gate_mesh.roller(post+Vector3.UP*.12,Vector3.UP,.24,.21,7,STONE)
		gate_mesh.box(post+Vector3.UP*1.12,Vector3(.18,2.24,.20),CUT,1)
		gate_mesh.box(post+Vector3.UP*1.90,Vector3(.19,.16,.21),REED,1)
		_box(origin+post+Vector3.UP*.92,Vector3(.22,1.84,.24))
	var top := Vector3(0,2.26,0)
	gate_mesh.box(top,Vector3(.24,.17,3.35),OAK,1)
	gate_mesh.box(top+Vector3.UP*.21,Vector3(.21,.41,1.39),REED,1)
	for s: float in [-1,1]:
		gate_mesh.bar(top+Vector3(0,.42,0),top+Vector3(0,.35,s*.8),.10,.17,CUT,Vector3.RIGHT,1)
		var face := top+Vector3(s*.116,.19,0)
		gate_mesh.roller(face,Vector3.RIGHT,.042,.125,8,Color("edcf90"))
		for k in 3: gate_mesh.roller(face+Vector3(0,.13+(.04 if k==1 else 0.0),(k-1)*.14),Vector3.RIGHT,.045,.059,6,Color("edcf90"))
	var arch:=gate_mesh.add_to(self,"FarmGate",ink); arch.position=origin; arch.add_to_group("village_map_landmark"); arch.set_meta("map_size",Vector2(.24,3.35)); arch.set_meta("map_kind","gate"); arch.set_meta("map_label","魔物园入口")
	# Enterable open gate (2.5m clearance); open water trough for recovery, not a building.
	var tub := L.foot(L.REST,0)
	boards.box(tub+Vector3.UP*.24,Vector3(1.12,.45,.54),CUT,1)
	boards.box(tub+Vector3.UP*.475,Vector3(.94,.025,.39),Color("72a59b"))
	for dx: float in [-.37,.37]: boards.box(tub+Vector3(dx,.25,0),Vector3(.077,.49,.56),OAK,1)
	_box(tub+Vector3.UP*.24,Vector3(1.14,.49,.56))
	var signpost := Vector3(22.65,0,32.92)
	boards.box(signpost+Vector3.UP*.56,Vector3(.15,1.12,.17),OAK,1)
	boards.box(signpost+Vector3.UP*1.08,Vector3(.96,.29,.13),REED,1)
	var tip := signpost+Vector3(.47,1.08,.071)
	boards.tri(tip+Vector3.UP*.14,tip-Vector3.UP*.14,tip+Vector3.RIGHT*.23,Vector3.BACK,REED)
	boards.box(signpost+Vector3(0,1.08,.074),Vector3(.49,.055,.025),Color("edcf90"))
	_box(signpost+Vector3.UP*.53,Vector3(.19,1.08,.21))
