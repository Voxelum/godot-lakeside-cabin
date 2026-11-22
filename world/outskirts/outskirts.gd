extends Node3D
## The hosts are still Clearing, its compass/camera, and Main's FieldSession.
## This node only dresses the surveyed lane and adds ordinary static collision.
const Survey := preload("res://world/outskirts/outskirts_profile.gd")
const Batch := preload("res://art/building_trial/mesh_batch.gd")
const Props := preload("res://art/building_trial/street_props.gd")
const COLOR_BRUSH := preload("res://art/woods/pigments.gdshader")
const OAK := Color("806246")
var _props_hit: StaticBody3D
var _ink := ShaderMaterial.new()

func _ready() -> void:
	_ink.shader = COLOR_BRUSH
	for branch in [$Trees, $Lanterns]:
		for prop: Node3D in branch.get_children():
			prop.position.y = Survey.surface(Survey.xz(prop.position))
	for mesh: MeshInstance3D in $Trees.find_children("*", "MeshInstance3D", true, false):
		mesh.add_to_group(&"clearing_extension_occluder")
	var dressing := Node3D.new()
	dressing.name = "LaneDressing"
	add_child(dressing)
	_props_hit = StaticBody3D.new()
	_props_hit.name = "VisiblePropsAndRails"
	_props_hit.collision_mask = 0
	dressing.add_child(_props_hit)
	_rail_verge(dressing, "WestVerge", Survey.WEST_VERGE)
	_rail_verge(dressing, "EastVerge", Survey.EAST_VERGE)
	_settlement_props(dressing)
	_waymarks(dressing)
	_approaches(dressing)

func _box(p: Vector3, extent: Vector3, yaw := 0.0) -> void:
	var c := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = extent
	c.shape = shape
	c.position = p
	c.rotation.y = yaw
	_props_hit.add_child(c)

func _rail_verge(parent: Node3D, label: String, path: Array) -> void:
	var stations := PackedVector3Array()
	for i in path.size()-1:
		var a: Vector2 = path[i]; var b: Vector2 = path[i+1]
		var n := maxi(1, roundi(a.distance_to(b)/1.44))
		for j in n:
			stations.append(Survey.point(a.lerp(b,float(j)/n)))
	stations.append(Survey.point(path[-1]))
	# Split the rail at readily culled groups, while keeping corners closed.
	var batch := Batch.new()
	for i in stations.size():
		var a := stations[i]
		var oak := Batch.tone(OAK,.12*sin(i*1.72))
		batch.box(a+Vector3.UP*.343,Vector3(.138,.749,.143),oak,1)
		batch.lathe(a,Vector3.UP,PackedVector2Array([Vector2(.703,.102),Vector2(.792,0)]),4,oak.lightened(.18),1)
		if i < stations.size()-1:
			var b := stations[i+1]
			var direction := Survey.xz(b-a)
			for row: float in [.257,.502]:
				var sag := (a+b)*.5+Vector3.UP*(row-.036)
				batch.bar(a+Vector3.UP*row,sag,.102,.107,oak.lightened(.08),Vector3.UP,1)
				batch.bar(sag,b+Vector3.UP*row,.094,.102,oak,Vector3.UP,1)
			_box((a+b)*.5+Vector3.UP*.33,Vector3(.14,.86+absf(a.y-b.y),direction.length()+.16),atan2(direction.x,direction.y))
		if (i+1)%11 == 0 or i == stations.size()-1:
			batch.add_to(parent,label+"_%02d"%(i/11+1),_ink)
			batch = Batch.new()

func _settlement_props(parent: Node3D) -> void:
	var village := Batch.new()
	var well := Survey.point(Survey.WELLSIDE)
	Props.well(village,well)
	_box(well+Vector3.UP*.51,Vector3(1.38,1.08,1.39),.17)
	Props.garden(village,Survey.point(Survey.GARDEN))
	Props.woodpile(village,Survey.point(Vector2(9.00,20.86)))
	_box(Survey.point(Vector2(9.00,20.86),.25),Vector3(1.23,.52,.73))
	Props.cask(village,Survey.point(Vector2(13.12,23.72)),.84)
	_box(Survey.point(Vector2(13.12,23.72),.24),Vector3(.47,.50,.47))
	Props.straw(village,Survey.point(Vector2(22.84,23.68)),.31)
	_box(Survey.point(Vector2(22.84,23.68),.2),Vector3(.78,.44,.60),.31)
	Props.straw(village,Survey.point(Vector2(23.56,24.27)),-.18)
	_box(Survey.point(Vector2(23.56,24.27),.2),Vector3(.78,.44,.60),-.18)
	Props.pot(village,Survey.point(Vector2(4.55,21.64)),.74)
	village.add_to(parent,"WellGardenAndWoodpile",_ink)
	var market := Batch.new()
	var p := Survey.point(Vector2(34.15,72.05))
	Props.crate(market,p,.62,.18,true)
	_box(p+Vector3.UP*.26,Vector3(.62,.54,.56),.18)
	p = Survey.point(Vector2(33.54,72.40))
	Props.crate(market,p,.47,-.28)
	_box(p+Vector3.UP*.2,Vector3(.47,.42,.42),-.28)
	p = Survey.point(Vector2(27.27,70.48))
	Props.cask(market,p,.97)
	_box(p+Vector3.UP*.27,Vector3(.51,.57,.53))
	Props.pot(market,Survey.point(Vector2(22.47,69.20)),.93)
	Props.pot(market,Survey.point(Vector2(31.67,70.36)),.85)
	var rest := Survey.point(Vector2(30.57,77.10))
	for x: float in [-.55,.55]:
		market.box(rest+Vector3(x,.23,0),Vector3(.15,.47,.56),Color("a19883"))
	market.box(rest+Vector3.UP*.48,Vector3(1.67,.128,.60),OAK,1)
	_box(rest+Vector3.UP*.27,Vector3(1.65,.53,.60))
	market.add_to(parent,"BreadCratesAndStoneBench",_ink)

func _waymarks(parent: Node3D) -> void:
	# Painted wood on a stone foot: a junction sign, three tally posts and a
	# return sign, not HUD or use targets.
	var marks := [Vector2(4.09,17.90),Vector2(21.83,26.67),Survey.PULLOUTS[0]+Vector2(-.37,.93),
		Survey.PULLOUTS[1]+Vector2(-.26,.93),Survey.PULLOUTS[2]+Vector2(-.32,.93),Vector2(20.90,67.17),Vector2(36.75,74.75)]
	var b := Batch.new()
	for i in marks.size():
		var p := Survey.point(marks[i])
		var h := .93 if i in [2,3,4] else 1.52
		b.roller(p+Vector3.UP*.09,Vector3.UP,.23,.216,7,Color("9d9b84"))
		b.box(p+Vector3.UP*(h*.48),Vector3(.138,h*.96,.135),OAK,1)
		var f := Transform3D(Basis(Vector3.UP,.32),p)
		var end := 1.0 if i != 6 else -1.0
		if i in [2,3,4]:
			b.box(f*Vector3(0.,h-.12,.072),Vector3(.55,.28,.108),OAK.lightened(.14),1,f.basis)
			var n := i-1
			for j in n:
				b.box(f*Vector3((j-(n-1)*.5)*.103,h-.11,.135),Vector3(.049,.139,.023),Color("e3c88a"),0,f.basis)
		else:
			var wood := Color("a98456")
			b.box(f*Vector3(0.,h-.17,.073),Vector3(.87,.244,.114),wood,1,f.basis)
			var d := f*Vector3(end*.422,h-.17,.133)
			b.tri(d+f.basis.y*.12,d-f.basis.y*.12,d+f.basis.x*end*.22,f.basis.z,wood)
			b.box(f*Vector3(-end*.042,h-.158,.135),Vector3(.55,.052,.025),Color("e1c383"),0,f.basis)
		_box(p+Vector3.UP*.45,Vector3(.23,.90,.23))
	b.add_to(parent,"PaintedWaymarks",_ink)

func _approaches(parent: Node3D) -> void:
	var walk := Batch.new()
	for lot in $Lots.get_children():
		var leg: Marker3D = lot.marker("Approach")
		if not leg: continue
		var p := Survey.xz(leg.global_position-leg.global_basis.z*.21)
		var end := Survey.nearest_track(p)
		var width: float = lot.door_width*.5+.13
		var lateral := (end-p).normalized().orthogonal()*width
		var stations := maxi(1,ceili(p.distance_to(end)/.32))
		for i in stations:
			var a := p.lerp(end,float(i)/stations)
			var b := p.lerp(end,float(i+1)/stations)
			var tint := Color("b2a288").lightened(.061*cos(i*2.35)) if p.y>64.0 else Color("aa986e").lightened(.044*sin(i*2.0))
			walk.quad(Survey.point(a-lateral,.021),Survey.point(a+lateral,.021),Survey.point(b+lateral,.021),Survey.point(b-lateral,.021),Vector3.UP,tint)
	walk.add_to(parent,"DoorstepFootpaths",_ink,false).layers = 2
