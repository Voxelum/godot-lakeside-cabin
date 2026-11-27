extends Node3D
## The hosts are still Clearing, its compass/camera, and Main's FieldSession.
## This node only dresses the surveyed lane and adds ordinary static collision.
const Survey := preload("res://world/outskirts/outskirts_profile.gd")
const Batch := preload("res://art/building_trial/mesh_batch.gd")
const Props := preload("res://art/building_trial/street_props.gd")
const COLOR_BRUSH := preload("res://art/woods/pigments.gdshader")
const OAK := Color("806246")
@export var mountain_branch := false
@export var farm_branch := false
var _props_hit: StaticBody3D
var _ink := ShaderMaterial.new()

const Space := preload("res://world/outskirts/settlement_space.gd")

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
	var west := Survey.WEST_VERGE
	if mountain_branch:
		west = west.slice(0, 2) + Survey.MOUNTAIN_VERGE + west.slice(3)
	# Replace the far corner run by the perimeter of Market Court, leaving
	# its two gateway ends on the old rails.
	var seam := west.find(Survey.WEST_VERGE[-3])
	_rail_verge(dressing, "WestVerge", west.slice(0, seam) + Survey.MARKET_VERGE + west.slice(seam+1))
	if farm_branch:
		# The smithy-side break leads directly to the farm's visible approach rails.
		const Park := preload("res://world/farm/farm_layout.gd")
		_rail_verge(dressing, "EastVergeVillage", Survey.EAST_VERGE.slice(0, 5) + [Vector2(25.8,12.4),Vector2(26.1,.6),Vector2(49.6,.5),Vector2(50.1,17.8),Vector2(48.5,23.1),Vector2(42.3,23.25),Vector2(30.8,23.25),Survey.EAST_VERGE[5],Survey.EAST_VERGE[6],Park.NORTH_JOIN])
		_rail_verge(dressing, "EastVergeTown", [Park.SOUTH_JOIN] + Survey.EAST_VERGE.slice(7))
	else: _rail_verge(dressing, "EastVerge", Survey.EAST_VERGE)
	_settlement_props(dressing)
	_waymarks(dressing)
	_approaches(dressing)
	var labels := {"LimeHouse":"灰泥农舍","OrchardHouse":"果园民居","HayBarn":"草料仓","Blacksmith":"铁匠作坊","CopperLoft":"铜顶镇屋","SillHouse":"凸窗民居","Bakery":"面包作坊","GeneralStore":"杂货铺","Tavern":"酒馆","Inn":"旅馆","Guild":"公会"}
	for lot in $Lots.get_children():
		lot.add_to_group("village_map_landmark")
		lot.set_meta("map_label", labels.get(str(lot.name), str(lot.name)))
		lot.set_meta("map_kind", "building")
	_road("SouthLane","cart_street",Survey.ROUTE,Survey.WIDTH,[])
	_road("MarketStreet","stone",Survey.MARKET_ROUTE,Survey.MARKET_WIDTH,["SouthLane"])
	_road("TownAlley","stone",Survey.ALLEY,Space.ALLEY_WIDTH,["SouthLane"])
	# The old barn's hardstanding is now the village exchange, not the distant town shops.
	var unloading := [Survey.ROUTE[11],Vector2(18.88,24.52),Vector2(19.48,22.34)]
	_road("ExchangeApron","cart_apron",unloading,Space.uniform(unloading.size(),Space.APRON_WIDTH),["SouthLane"])
	var yard:=Batch.new()
	for i in unloading.size()-1:
		var a:Vector2=unloading[i]; var b:Vector2=unloading[i+1]; var side:=(b-a).normalized().orthogonal()*Space.APRON_WIDTH*.5
		yard.quad(Survey.point(a-side,.022),Survey.point(a+side,.022),Survey.point(b+side,.022),Survey.point(b-side,.022),Vector3.UP,Color("ab9979"))
	yard.add_to(self,"ExchangeCartApron",_ink,false)
	var freight := _path("MarketFreight", Survey.ROUTE.slice(3,11) + unloading)
	freight.add_to_group("village_caravan_route")
	var stall:=Node3D.new(); stall.name="MarketWeighStall"; add_child(stall)
	stall.position=freight.curve.get_point_position(freight.curve.point_count-1)+Vector3(1.80,0,0)
	stall.add_to_group("village_map_landmark"); stall.set_meta("map_label","集市秤棚"); stall.set_meta("map_kind","market"); stall.set_meta("map_size",Vector2(1.55,1.86))
	var frame:=Batch.new()
	for x:float in [-.55,.55]:
		for z:float in [-.74,.74]: frame.box(Vector3(x,.95,z),Vector3(.095,1.90,.095),OAK,1)
	frame.box(Vector3(0,.79,0),Vector3(1.20,.13,1.60),OAK,1)
	for i in 6: frame.box(Vector3(0,1.91,(i-2.5)*.31),Vector3(1.55,.13,.31),Color("728774") if i%2 else Color("dac598"))
	Props.crate(frame,Vector3(0,.86,.28),.48,.08); frame.add_to(stall,"CanvasAndScales",_ink)
	_box(stall.position+Vector3.UP*.45,Vector3(1.18,.88,1.58))
	var pasture := preload("res://world/outskirts/village_pasture.gd").new()
	pasture.name = "VillageFarm"
	add_child(pasture)
	# Local food comes out of the relocated barn. Follow its doorstep path
	# and the public lane back to the exchange, not the inbound caravan.
	var barn_foot:=Survey.xz($Lots/HayBarn.marker("Approach").global_position)
	var link:=Survey.nearest_track(barn_foot); var segment:=0
	for i in range(Survey.ROUTE.size()-1):
		if Geometry2D.get_closest_point_to_segment(link,Survey.ROUTE[i],Survey.ROUTE[i+1]).is_equal_approx(link): segment=i; break
	var stops:=[barn_foot,link]
	for i in range(segment,10,-1): stops.append(Survey.ROUTE[i])
	stops.append_array(unloading.slice(1)); _path("LocalProduceRoute",stops)
	if OS.is_debug_build(): _validate_layout.call_deferred()

# Wait for siblings (park, cottage) to finish publishing their authored records.
func _validate_layout() -> void:
	if not is_inside_tree(): return
	var errors:=Space.validate(Space.snapshot(get_parent()))
	assert(errors.is_empty(),"Invalid settlement: "+str(errors))

func worker_station(hour:int) -> Vector3:
	var p:Vector3
	if hour<7 or hour>=18: p=$Lots/OrchardHouse.marker("Approach").global_position
	elif hour<9: p=$VillageFarm.to_global(Survey.point(preload("res://world/outskirts/village_pasture.gd").FIELD.get_center()))
	elif hour<11: p=$Lots/Blacksmith.marker("Approach").global_position
	else:
		var path:Path3D=$LocalProduceRoute
		p=path.to_global(path.curve.get_point_position(path.curve.point_count-1))+Vector3(.2,0,.8)
	return p

func _road(id:String, kind:String, stations:Array, widths:Array, joins:Array) -> Path3D:
	var record:=Space.road(id,kind,stations,widths,joins)
	var lane:=_path(id,Array(record.points)); lane.set_meta("space_road",record); lane.add_to_group("village_map_road")
	return lane

func _path(label: String, stations: Array) -> Path3D:
	var lane := Path3D.new()
	lane.name = label
	lane.curve = Curve3D.new()
	for p:Vector2 in stations: lane.curve.add_point(Survey.point(p))
	add_child(lane)
	return lane

# Outdoor saves use world metres. An old meadow coordinate can now be
# *inside* a moved, hollow exterior without touching any physics surface.
func safe_village_foot(foot:Vector3, actor:CharacterBody3D) -> Vector3:
	for id in ["OrchardHouse","HayBarn","Inn"]:
		var lot:Node3D=$Lots.get_node(id); var datum:=lot.get_node("GroundDatum") as Node3D
		var local:=Survey.xz(datum.to_local(foot)); var size:Vector2=lot.get_meta("net_footprint")
		if Rect2(-size*.5,size).grow(.19).has_point(local): return lot.marker("Approach").global_position
	# Only newly installed roadside fixtures; ordinary clear outdoor saves
	# (including a walker standing *under* an open stock shed) are untouched.
	var probe:=PhysicsShapeQueryParameters3D.new(); var capsule:=actor.get_node("Body") as CollisionShape3D
	probe.shape=capsule.shape; probe.transform=Transform3D(Basis.IDENTITY,foot+capsule.position+Vector3.UP*.06); probe.exclude=[actor.get_rid()]
	for hit in actor.get_world_3d().direct_space_state.intersect_shape(probe,32):
		if $VillageFarm.is_ancestor_of(hit.collider) or (hit.collider==_props_hit and foot.distance_to($MarketWeighStall.global_position)<1.42):
			var nearest:=Survey.nearest_track(Survey.xz(foot)); return Survey.point(nearest,.003)
	return foot

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
	var court := Batch.new()
	var store_side := Survey.point(Vector2(22.90, 85.97))
	Props.crate(court,store_side,.50,.23)
	_box(store_side+Vector3.UP*.23,Vector3(.50,.46,.49),.23)
	var tap_side := Survey.point(Vector2(33.34, 88.63))
	Props.cask(court,tap_side,1.08)
	_box(tap_side+Vector3.UP*.31,Vector3(.55,.62,.55))
	Props.pot(court,Survey.point(Vector2(33.65, 99.61)),1.19)
	Props.pot(court,Survey.point(Vector2(23.01, 95.34)),.98)
	court.add_to(parent,"MarketCourtGoods",_ink)

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
	var market_gate := Survey.point(Vector2(23.90, 77.04))
	var frame := Transform3D(Basis(Vector3.UP,.50),market_gate)
	b.roller(market_gate+Vector3.UP*.09,Vector3.UP,.23,.22,7,Color("9d9b84"))
	b.box(frame*Vector3(0,.64,0),Vector3(.14,1.28,.14),OAK,1,frame.basis)
	b.box(frame*Vector3(0,1.32,0),Vector3(.70,.40,.12),Color("57676d"),1,frame.basis)
	for u: float in [-.20,0,.20]:
		b.box(frame*Vector3(u,1.32,.078),Vector3(.094,.23,.043),Color("e3c88a"),0,frame.basis)
	_box(market_gate+Vector3.UP*.59,Vector3(.25,1.18,.25))
	b.add_to(parent,"PaintedWaymarks",_ink)

func _approaches(parent: Node3D) -> void:
	var walk := Batch.new()
	for lot in $Lots.get_children():
		var leg: Marker3D = lot.marker("Approach")
		if not leg: continue
		var p := Survey.xz(leg.global_position-leg.global_basis.z*.21)
		var market: bool = String(lot.lot_id).begins_with("clearing.market_court.")
		var end := Survey.nearest_on(p, Survey.MARKET_ROUTE if market else Survey.ROUTE)
		var width: float = lot.door_width*.5+.13
		_road(str(lot.name)+"Footpath","doorstep",[end,p],[2*width,2*width],["MarketStreet" if market else "SouthLane",str(lot.lot_id)])
		var lateral := (end-p).normalized().orthogonal()*width
		var stations := maxi(1,ceili(p.distance_to(end)/.32))
		for i in stations:
			var a := p.lerp(end,float(i)/stations)
			var b := p.lerp(end,float(i+1)/stations)
			var tint := Color("b2a288").lightened(.061*cos(i*2.35)) if p.y>64.0 else Color("aa986e").lightened(.044*sin(i*2.0))
			walk.quad(Survey.point(a-lateral,.021),Survey.point(a+lateral,.021),Survey.point(b+lateral,.021),Survey.point(b-lateral,.021),Vector3.UP,tint)
	walk.add_to(parent,"DoorstepFootpaths",_ink,false).layers = 2
