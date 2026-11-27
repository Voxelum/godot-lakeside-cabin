extends Node3D
## Open roadside paddock. The lane-facing side stays open to walkers.
const STALLS := [Vector2(28.9,17.8),Vector2(33.4,18.2),Vector2(31.8,20.3)]
const FIELD := Rect2(29,2.8,18,11.2)
const GRASS := Rect2(27.3,16.6,14.5,6.3)
const Space := preload("res://world/outskirts/settlement_space.gd")
const TRACK := [preload("res://world/outskirts/outskirts_profile.gd").ROUTE[11],Vector2(19.4,24.8),Vector2(20.5,20.4),Vector2(23.8,20.1),Vector2(27.1,15.35),Vector2(33,15.35),Vector2(40,15.35),Vector2(47.95,15.35),Vector2(47.95,2),Vector2(28.1,2),Vector2(28.1,15.35),Vector2(27.1,15.35)]
const Batch := preload("res://art/building_trial/mesh_batch.gd")
const Survey := preload("res://world/outskirts/outskirts_profile.gd")
var grain:MeshInstance3D

func feature(id:String, label:String, kind:String, center:Vector2, size:Vector2) -> Node3D:
	var node:=Node3D.new(); add_child(node); node.position=Survey.point(center)
	node.add_to_group("village_map_landmark"); node.set_meta("map_label",label); node.set_meta("map_id",id); node.set_meta("map_kind",kind); node.set_meta("map_size",size)
	return node

func solid(host:Node3D, at:Vector3, dims:Vector3, ink:Color) -> void:
	part(host,at,dims,ink,true)
	var body:=StaticBody3D.new(); host.add_child(body); body.position=at
	var c:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=dims; c.shape=shape; body.add_child(c)

func shed(label:String, center:Vector2, width:float, depth:float, hen:bool) -> void:
	var h:=feature("henhouse" if hen else "stock_shed",label,"shelter",center,Vector2(width,depth)); var high:=1.18 if hen else 2.0
	for x:float in [-1.,1.]:
		for z:float in [-1.,1.]: solid(h,Vector3(x*(width*.5-.08),high*.5,z*(depth*.5-.08)),Vector3(.13,high,.13),WOOD)
	solid(h,Vector3(0,high*.42,-depth*.5),Vector3(width,high*.84,.14),WOOD)
	for k in 2:
		var sign_x:=float(k*2-1); part(h,Vector3(sign_x*width*.25,high+.16,0),Vector3(width*.58,.14,depth+.35),Color("ab6744") if hen else Color("67756d"),true); h.get_child(-1).rotation.z=-sign_x*.34
	if hen:
		solid(h,Vector3(0,.47,-.17),Vector3(width-.24,.66,depth*.60),Color("b58c50")); part(h,Vector3(0,.55,depth*.14),Vector3(.34,.4,.03),DARK,true)
		part(h,Vector3(0,.22,.70),Vector3(.38,.07,.82),Color("bc975f"),true); h.get_child(-1).rotation.x=.42
		for j in 4: part(h,Vector3(0,.33-j*.061,.47+j*.14),Vector3(.40,.045,.055),WOOD,true)
	else:
		solid(h,Vector3(width*.5,.66,0),Vector3(.10,.10,depth),WOOD)
		solid(h,Vector3(0,high-.18,depth*.48),Vector3(width,.18,.14),WOOD)
		solid(h,Vector3(0,.24,-depth*.33),Vector3(width*.76,.39,.4),Color("b59b66"))

func fields() -> void:
	var field:=feature("rotation_field","轮作麦田","field",FIELD.get_center(),FIELD.size); var soil:=Batch.new(); var crop:=Batch.new()
	var rng:=RandomNumberGenerator.new(); rng.seed=857
	for row in 24:
		var x:float=(row-11.5)*.75; soil.box(Vector3(x,.015,0),Vector3(.65,.06,FIELD.size.y),Color("806342").lightened(.025*(row%3)))
		for j in 36:
			var p:=Vector3(x+rng.randf_range(-.13,.13),.04,(j-17.5)*.31); var ht:=rng.randf_range(.44,.72)
			crop.box(p+Vector3.UP*ht*.5,Vector3(.038,ht,.038),Color("99914b")); crop.box(p+Vector3.UP*ht,Vector3(.095,.17,.085),Color("d3aa55").lightened(rng.randf_range(0,.18)))
	var mat:=StandardMaterial3D.new(); mat.vertex_color_use_as_albedo=true; mat.vertex_color_is_srgb=true
	soil.add_to(field,"Furrows",mat); grain=crop.add_to(field,"StandingWheat",mat)
	var paddock:=feature("grazing_meadow","放牧草甸","pasture",GRASS.get_center(),GRASS.size)
	var sod:=Batch.new(); var half:=GRASS.size*.5
	sod.box(Vector3(0,.012,0),Vector3(GRASS.size.x,.026,GRASS.size.y),Color("929851"))
	for tuft in 300:
		var base:=Vector3(rng.randf_range(-half.x,half.x),.026,rng.randf_range(-half.y,half.y)); var tint:=Color("9ea057").lightened(rng.randf_range(0,.13))
		sod.tri(base+Vector3.LEFT*.055,base+Vector3.RIGHT*.055,base+Vector3(.035,.14,.03),Vector3.BACK,tint)
	sod.add_to(paddock,"GrazedSward",mat)
	# Western split rail; leave the eastern side open to the farm track.
	for z:float in [-2.55,0.,2.55]: solid(paddock,Vector3(-half.x,.38,z),Vector3(.14,.76,.14),WOOD)
	for y:float in [.28,.57]: solid(paddock,Vector3(-half.x,y,0),Vector3(.10,.095,5.1),WOOD)
	const RoadBrush := preload("road_brush.gd")
	var road:Path3D=get_parent()._road("FarmLane","field_track",TRACK,Space.uniform(TRACK.size(),Space.FIELD_WIDTH),["SouthLane"])
	RoadBrush.paint(road,Space.FIELD_WIDTH,RoadBrush.Surface.CART_EARTH).name = "FarmTrackSoil"

func grow(stage:int) -> void:
	grain.visible=stage>0; grain.scale.y=[.2,.32,.66,1.0][clampi(stage,0,3)]
const WOOD := Color("8a5739")
const DARK := Color("493427")
const CREAM := Color("fff0cf")
var mats := {}

func part(parent:Node3D, p:Vector3, dims:Vector3, color:Color, box:=false) -> void:
	var n:=MeshInstance3D.new(); var m:PrimitiveMesh
	if box: m=BoxMesh.new()
	else:
		var sphere:=SphereMesh.new(); sphere.radial_segments=10; sphere.rings=5; m=sphere
	if not mats.has(color):
		var mat:=StandardMaterial3D.new(); mat.albedo_color=color; mats[color]=mat
	m.material=mats[color]; n.mesh=m; n.scale=dims; n.position=p; parent.add_child(n)

func _ready() -> void:
	for i in 3:
		var animal:=Node3D.new(); animal.name=["Hen","Cow","Sheep"][i]; add_child(animal)
		animal.position=Vector3(STALLS[i].x,0,STALLS[i].y); animal.rotation.y=[1.0,1.28,.7][i]
		if i==0:
			part(animal,Vector3(0,.39,0),Vector3(.47,.53,.64),Color("df9a42")); part(animal,Vector3(0,.69,.23),Vector3(.32,.4,.33),CREAM); part(animal,Vector3(0,.92,.2),Vector3(.11,.16,.26),Color("bc362c")); part(animal,Vector3(0,.69,.43),Vector3(.13,.09,.18),Color("eab237")); part(animal,Vector3(0,.61,-.32),Vector3(.2,.44,.23),DARK)
			for x in [-.1,.1]: part(animal,Vector3(x,.11,0),Vector3(.05,.22,.07),WOOD,true)
		else:
			var cow:=i==1; animal.scale=Vector3.ONE*(1.0 if cow else .76)
			part(animal,Vector3(0,.95,0),Vector3(.82,.85,1.52),CREAM)
			part(animal,Vector3(0,1.23,.77),Vector3(.55,.63,.62),DARK)
			part(animal,Vector3(0,1.08,1.05),Vector3(.48,.31,.28),Color("d8a28d") if cow else DARK)
			for x:float in [-.28,.28]:
				for z in [-.48,.48]: part(animal,Vector3(x,.35,z),Vector3(.15,.7,.17),DARK,true)
				part(animal,Vector3(x*1.28,1.4,.77),Vector3(.32,.16,.19),DARK)
				if cow:
					part(animal,Vector3(x,1.57,.75),Vector3(.11,.27,.14),CREAM); part(animal,Vector3(x*1.12,1.04,-.18),Vector3(.24,.56,.66),DARK)
				else:
					for z in [-.45,0,.42]: part(animal,Vector3(x,1.09,z),Vector3(.46,.62,.58),CREAM)
		var body:=StaticBody3D.new(); animal.add_child(body); var hit:=CollisionShape3D.new(); var capsule:=CapsuleShape3D.new(); capsule.radius=.18 if i==0 else .38; capsule.height=.6 if i==0 else 1.45; hit.shape=capsule; hit.position.y=capsule.height*.5; body.add_child(hit)
	fields()
	shed("鸡棚",Vector2(28.3,20.1),1.65,1.45,true)
	shed("牛羊舍",Vector2(36.8,21.15),4.1,2.4,false)
