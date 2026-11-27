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
var shelter_roofs:Array[Node3D]=[]
@onready var observer:=get_node_or_null("../../Traveler") as Node3D

func _process(_delta:float) -> void:
	if not observer: return
	for roof in shelter_roofs:
		var p:=roof.to_local(observer.global_position)
		var half_width:float=roof.get_parent().get_meta("map_size").x*.5
		var pad:=.2 if roof.visible else .55 # hysteresis at the service apron
		roof.visible=not (absf(p.x)<half_width+pad and p.z> -1.8-pad and p.z<2.55+pad)

func feature(id:String, label:String, kind:String, center:Vector2, size:Vector2) -> Node3D:
	var node:=Node3D.new(); add_child(node); node.position=Survey.point(center)
	node.add_to_group("village_map_landmark"); node.set_meta("map_label",label); node.set_meta("map_id",id); node.set_meta("map_kind",kind); node.set_meta("map_size",size)
	return node

func solid(host:Node3D, at:Vector3, dims:Vector3, ink:Color) -> void:
	part(host,at,dims,ink,true)
	var body:=StaticBody3D.new(); host.add_child(body); body.position=at
	var c:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=dims; c.shape=shape; body.add_child(c)

func shed(label:String, center:Vector2, width:float, depth:float, hen:bool) -> void:
	var h:=feature("henhouse" if hen else "stock_shed",label,"shelter",center,Vector2(width,depth)); var high:=1.55 if hen else 2.48
	h.rotation.y=PI # Both open fronts face the existing field track.
	# One hooded lantern per entrance, not a warm wash across the meadow.
	var hook:=Vector3(width*.5-.15,high*.78,depth*.5+.10)
	part(h,hook,Vector3(.21,.31,.19),Color("dcb76a"),true)
	part(h,hook+Vector3.UP*.18,Vector3(.29,.08,.26),Color("344847"),true)
	var lamp:=OmniLight3D.new(); h.add_child(lamp); lamp.position=hook+Vector3.FORWARD*.16
	lamp.light_color=Color("ffdb92"); lamp.light_energy=.65; lamp.omni_range=2.3; lamp.shadow_enabled=false; lamp.add_to_group("night_omni")
	for x:float in [-1.,1.]:
		for z:float in [-1.,1.]: solid(h,Vector3(x*(width*.5-.08),high*.5,z*(depth*.5-.08)),Vector3(.13,high,.13),WOOD)
	# Rear service opening leaves a sightline from the normal F5 camera.
	for side:float in [-1.,1.]:
		solid(h,Vector3(side*width*.34,high*.27,-depth*.5),Vector3(width*.32,high*.54,.14),WOOD)
	var canopy:=Node3D.new(); h.add_child(canopy); shelter_roofs.append(canopy)
	for k in 2:
		var sign_x:=float(k*2-1); part(canopy,Vector3(sign_x*width*.25,high+.16,0),Vector3(width*.58,.14,depth+.35),Color("976750") if hen else Color("506e67"),true); canopy.get_child(-1).rotation.z=-sign_x*.34
	if hen:
		# Ridge vent gives the short chicken roof a stepped silhouette.
		var perch:=Vector3(0,high+.63,-.25)
		part(canopy,perch,Vector3(.64,.52,.64),Color("b48e63"),true)
		part(canopy,perch+Vector3(0,0,-.33),Vector3(.28,.23,.03),DARK,true)
		part(canopy,perch+Vector3.UP*.30,Vector3(.83,.12,.80),Color("495956"),true)
		solid(h,Vector3(0,.47,-.17),Vector3(width-.24,.66,depth*.60),Color("b58c50")); part(h,Vector3(0,.55,depth*.14),Vector3(.34,.4,.03),DARK,true)
		part(h,Vector3(0,.22,.70),Vector3(.38,.07,.82),Color("bc975f"),true); h.get_child(-1).rotation.x=.42
		for j in 4: part(h,Vector3(0,.33-j*.061,.47+j*.14),Vector3(.40,.045,.055),WOOD,true)
		for side:float in [-1.,1.]:
			var x:=side*1.05
			solid(h,Vector3(x,.52,.47),Vector3(.85,.14,.55),Color("e0b56a"))
			part(h,Vector3(x,.68,.53),Vector3(.20,.27,.21),CREAM)
			part(h,Vector3(x+.22,.67,.54),Vector3(.19,.25,.20),CREAM)
	else:
		for side:float in [-1.,1.]:
			var x:=side*2.05
			solid(h,Vector3(x,.29,.82),Vector3(2.7,.48,.56),WOOD)
			part(h,Vector3(x,.54,.82),Vector3(2.53,.13,.46),Color("cbaf65"))
			for j in 5: part(h,Vector3(x+(j-2)*.51,.71,.63),Vector3(.065,.49,.075),WOOD,true)
		# Staging: stave milk churn and tied wool pack by the rear wall.
		part(h,Vector3(2.5,.42,-.65),Vector3(.48,.77,.48),Color("9faea6"),true)
		part(h,Vector3(2.5,.85,-.65),Vector3(.30,.12,.30),DARK,true)
		part(h,Vector3(-2.5,.38,-.65),Vector3(.75,.71,.67),CREAM)
		part(h,Vector3(-2.5,.4,-.65),Vector3(.10,.72,.68),WOOD,true)
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

const WORK_POINTS := {"field":Vector2(33,14.45), "hen":Vector2(29.4,19.45), "cow":Vector2(36.1,19.1), "sheep":Vector2(40.1,19.1)}
func farm_station(id:String) -> Vector3:
	return to_global(Survey.point(WORK_POINTS[id]))

const FLOCK := [[Vector2(28.9,17.8),Vector2(30.25,17.3),Vector2(30.7,18.8),Vector2(28.45,18.6),Vector2(31.45,18.05)], [Vector2(33.4,18.2),Vector2(35.35,17.6),Vector2(37.65,18.0)], [Vector2(31.8,20.3),Vector2(33.5,21.25),Vector2(39.3,17.55),Vector2(41,18.0)]]
func _ready() -> void:
	for i in 3:
		for j in FLOCK[i].size(): animal_at(i,j)
	fields()
	shed("鸡舍 · 产蛋巢格",Vector2(29.45,21.4),3.65,2.35,true)
	shed("牛羊棚 · 双饲槽",Vector2(38,21.45),7.45,2.75,false)

func animal_at(i:int,j:int) -> void:
		var body:=StaticBody3D.new(); body.name="%s%02d" % [["Hen","Cow","Sheep"][i],j+1]; add_child(body)
		body.set_meta("livestock_id","livestock:%s.%02d" % [["hen","cow","sheep"][i],j+1]); body.set_meta("species",i); body.set_meta("ordinal",j); body.set_meta("label",NAMES[i][j]); animals.append(body)
		var animal:=Node3D.new(); animal.name="Model"; body.add_child(animal)
		body.position=Survey.point(FLOCK[i][j]); body.rotation.y=[1.0,1.28,.7][i]+[0.,-.85,1.25,-1.6,.55][j]
		if i==0:
			part(animal,Vector3(0,.39,0),Vector3(.47,.53,.64),Color(["df9a42","a56d41","ca8039","e0b86a","b48961"][j])); part(animal,Vector3(0,.69,.23),Vector3(.32,.4,.33),CREAM); part(animal,Vector3(0,.92,.2),Vector3(.11,.16,.26),Color("bc362c")); part(animal,Vector3(0,.69,.43),Vector3(.13,.09,.18),Color("eab237")); part(animal,Vector3(0,.61,-.32),Vector3(.2,.44,.23),DARK)
			for x in [-.1,.1]: part(animal,Vector3(x,.11,0),Vector3(.05,.22,.07),WOOD,true)
		else:
			var cow:=i==1; animal.scale=Vector3.ONE*(1.0 if cow else .76)
			var coat:=Color(["fff0cf","d9cab3","cdae86"][j] if cow else ["fff0cf","e7d2b0","c0b4a1","b8a58c"][j])
			part(animal,Vector3(0,.95,0),Vector3(.82,.85,1.52),coat)
			part(animal,Vector3(0,1.23,.77),Vector3(.55,.63,.62),DARK)
			part(animal,Vector3(0,1.08,1.05),Vector3(.48,.31,.28),Color("d8a28d") if cow else DARK)
			for x:float in [-.28,.28]:
				for z in [-.48,.48]: part(animal,Vector3(x,.35,z),Vector3(.15,.7,.17),DARK,true)
				part(animal,Vector3(x*1.28,1.4,.77),Vector3(.32,.16,.19),DARK)
				if cow:
					part(animal,Vector3(x,1.57,.75),Vector3(.11,.27,.14),CREAM); part(animal,Vector3(x*1.12,1.04,-.18),Vector3(.24,.56,.66),DARK)
				else:
					for z in [-.45,0,.42]: part(animal,Vector3(x,1.09,z),Vector3(.46,.62,.58),coat)
		var hit:=CollisionShape3D.new(); hit.name="CollisionShape3D"; var shape:=BoxShape3D.new(); shape.size=[Vector3(.39,.72,.57),Vector3(.73,1.42,1.55),Vector3(.59,1.03,1.14)][i]; hit.shape=shape; hit.position=Vector3(0,shape.size.y*.5,.04); body.add_child(hit)

const NAMES := [["母鸡·金栗","母鸡·小穗","母鸡·琥珀","母鸡·麦芽","母鸡·杏仁"],["奶牛·白露","奶牛·墨点","奶牛·榛子"],["绵羊·棉团","绵羊·云朵","绵羊·雪耳","绵羊·卷毛"]]
var animals:Array[StaticBody3D]=[]
var session
var responses:Dictionary={}

func bind_session(owner_session) -> void:
	session=owner_session
	for body in animals:
		session.state.entities.bind_livestock(str(body.get_meta("livestock_id")),body)

func nearby() -> StaticBody3D:
	if not session or session.host.indoors or session.host.crossing or session.is_modal(): return null
	var actor:CharacterBody3D=session.host.active_actor()
	var best:StaticBody3D; var distance:=1.45*1.45
	for body in animals:
		var ds:=actor.global_position.distance_squared_to(body.global_position)
		if ds>=distance: continue
		var eye:=actor.global_position+Vector3.UP*.72
		var ray:=PhysicsRayQueryParameters3D.create(eye,body.global_position+Vector3.UP*.43,1,[actor.get_rid()]); ray.hit_from_inside=true
		var hit:=actor.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider!=body: continue
		best=body; distance=ds
	return best

func tip(body:StaticBody3D) -> PackedStringArray:
	var record=body.get_meta(&"entity")
	return PackedStringArray([str(body.get_meta("label")),"亲密度 %d / 100" % record.affection])

func pet_nearby() -> bool:
	var body:=nearby()
	if not body: return false
	var record=body.get_meta(&"entity")
	var day:=floori(float(session.state.village.d.hour)/24.0)
	var before:int=record.affection
	if record.last_pet_day!=day:
		record.affection=mini(100,before+1); record.last_pet_day=day
	var actor=session.host.active_actor()
	actor.artwork.stroke_animal(body.global_position-actor.global_position,int(body.get_meta("species"))==0)
	var model:=body.get_node("Model") as Node3D
	if responses.has(body): responses[body].kill()
	var tw:=model.create_tween(); responses[body]=tw
	tw.tween_property(model,"rotation:x",-.20,.13); tw.tween_property(model,"rotation:x",.10,.18); tw.tween_property(model,"rotation:x",0.,.16)
	session.hud.feedback("抚摸%s · %s（%d/100）" % [body.get_meta("label"),"亲密度 +1" if record.affection>before else "它亲昵地蹭了蹭你",record.affection]); return true

