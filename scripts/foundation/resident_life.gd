extends RefCounted
## Only ledger elapsed() advances these records. Renderers can query an unopened
## room or redraw the same instant any number of times without settling anything.
const Routes := preload("res://scripts/foundation/resident_routes.gd")
const Jobs := preload("res://scripts/foundation/farm_jobs.gd")
const FIELD := "field"
const IDS := ["farmer","LakesideCompanion","HazelTender","WellPotter","BakeryRunner","NetMender","Lamplighter","CaravanMerchant"]
const HOMES := {"farmer":"place.orchard_house","LakesideCompanion":"place.inn","HazelTender":"place.lime_house","WellPotter":"place.copper_loft","BakeryRunner":"place.bakery","NetMender":"place.sill_house","Lamplighter":"place.inn"}
const MERCHANT := "CaravanMerchant"
const PRICES := {"egg":1,"milk":1,"bread":2}
const ACTIVITIES := ["sleep","walk","work","shop","eat","sold_out","no_money","off_duty","away","travel","trade","camp"]
static func _new(id:String) -> Dictionary:
	var start:="dock" if id==MERCHANT else "bed."+id
	return {"at":start,"to":start,"meters":0.0,"activity":"away" if id==MERCHANT else "sleep","food":"","bought":-1,"ate":-1,"miss":-1,"chew":0.0}
const Slots := preload("res://scripts/foundation/world_slots.gd")

static func _at_own_bed(id: String, r: Dictionary) -> bool:
	var bed: String = Routes.BEDS.get(id, "")
	return Slots.accepts(bed, Slots.USE, id) and r.at == "bed." + id and r.to == r.at and r.meters == 0.0

static func bed_occupant(d: Dictionary, slot: String) -> String:
	var id: Variant = Routes.BEDS.find_key(slot)
	if id == null: return ""
	var r: Dictionary = d.life.get(id, _new(id))
	return id if r.activity == "sleep" and _at_own_bed(id, r) else ""

static func valid(v:Variant) -> bool:
	if not v is Dictionary: return false
	if v.is_empty(): return true
	if v.size()!=IDS.size(): return false
	Routes.setup()
	for id:String in IDS:
		var r:Variant=v.get(id); if not r is Dictionary or r.size()!=9: return false
		for k in ["at","to"]:
			if not r.get(k) is String or not Routes.ids.has(r[k]): return false
		if r.at!=r.to and not Routes.graph.are_points_connected(Routes.ids[r.at],Routes.ids[r.to]): return false
		if not r.get("meters") is float or not is_finite(r.meters) or r.meters<0 or r.meters>Routes.pos(r.at).distance_to(Routes.pos(r.to))+.0001: return false
		if r.get("activity") not in ACTIVITIES or r.get("food") not in ["","bread","milk","egg"]: return false
		if r.activity=="sleep" and not _at_own_bed(id,r): return false
		for k in ["bought","ate","miss"]:
			if not r.get(k) is int or r[k]<-1 or r[k]>1000000000: return false
		if r.ate>r.bought or (r.food!="" and r.ate==r.bought): return false
		if not r.get("chew") is float or not is_finite(r.chew) or r.chew<0 or r.chew>1: return false
	return true
static func _buy(d:Dictionary,r:Dictionary,account:String,day:int) -> void:
	if r.bought>=day or r.food!="": return
	var stocked:=false
	for food:String in PRICES:
		if d.store[food]<=0: continue
		stocked=true; var cost:int=PRICES[food]; if d.purse[account]<cost: continue
		d.store[food]-=1; d.purse[account]-=cost; d.purse.village+=cost
		r.bought=day; r.food=food; r.chew=1.0; r.activity="eat"; d.shop_result=1; return
	r.activity="no_money" if stocked else "sold_out"; d.shop_result=2 if stocked else 4
static func _chew(r:Dictionary,dt:float) -> void:
	r.activity="eat"; r.chew=maxf(0,r.chew-dt)
	if r.chew<=.0000001: r.ate=r.bought; r.food=""; r.chew=0.0
static func _goal(d:Dictionary,id:String,r:Dictionary,h:int,sec:float,day:int) -> String:
	if h>=19 or h<6: return "bed."+id
	var slot:=IDS.find(id)
	if h>=12+slot%3 and r.bought<day: return "shop"+str(slot)
	if id!="farmer": return "job."+id
	if h<=7: return "field"
	if h in [8,9]: return ["hen","cow","sheep"][mini(2,int(sec*3/5))]
	return "apron"
static func _resident(d:Dictionary,id:String,r:Dictionary,dt:float,h:int,sec:float,day:int) -> void:
	if r.food!="": _chew(r,dt); return
	var goal:=_goal(d,id,r,h,sec,day); var speed:=7.8 if id=="farmer" and h<=9 else 3.8
	var left:=dt
	while left>.00000001:
		if r.at==r.to:
			if r.at==goal:
				if goal.begins_with("shop"): _buy(d,r,"family",day)
				elif _at_own_bed(id,r): r.activity="sleep"
				else:
					r.activity="work"
					if id=="farmer" and (h==7 or h in [8,9]): Jobs.arrive(d,goal,h==9)
				break
			r.to=Routes.next(r.at,goal)
			if r.to==r.at: break
		r.activity="walk"
		var length:=Routes.pos(r.at).distance_to(Routes.pos(r.to)) if Routes.scenes[r.at]==Routes.scenes[r.to] else .22
		var take:=minf(left*speed,maxf(0,length-r.meters)); r.meters+=take; left-=take/speed
		if r.meters+.0000001>=length: r.at=r.to; r.meters=0.0
		else: break
	if h>=21 and r.ate<day and r.miss<day:
		r.miss=day; d.missed+=1; d.health=maxi(0,d.health-1)
static func _merchant(d:Dictionary,r:Dictionary,dt:float,h:int,day:int,visit:float) -> void:
	if visit<0: r.activity="away"; return
	if r.food!="": _chew(r,dt); return
	if not d.road and (h>=20 or h<6): r.activity="camp"; return
	if visit>=10.9 and visit<14.0 and h>=6 and h<20:
		r.activity="trade"; _buy(d,r,"caravan",day)
	else: r.activity="travel"
static func advance(d:Dictionary,dt:float) -> void:
	Routes.setup()
	if d.life.is_empty():
		for id:String in IDS: d.life[id]=_new(id)
	# Canonical 30 Hz elapsed-time ticks. Rendering, frame partitions and N/hour
	# jumps must not change priority at a contested counter or spend twice.
	var h:=int(d.hour)%24; var day:=floori(float(d.hour)/24)
	var first:=floori(float(d.seconds)*30+.000001); var last:=floori((float(d.seconds)+dt)*30+.000001)
	for tick in range(first,last):
		var sec:=tick/30.0
		for id:String in HOMES: _resident(d,id,d.life[id],1./30.,h,sec+.0000001,day)
		var age:=float(d.visit); if age>=0 and d.road: age+=sec-float(d.seconds)
		_merchant(d,d.life[MERCHANT],1./30.,h,day,age)
		if h==21 and tick==0:
			var fed:=true
			for id:String in HOMES: fed=fed and int(d.life[id].ate)==day
			if fed: d.health=mini(10,d.health+2); d.hungry_days=0
			else: d.hungry_days+=1
static func pose(d:Dictionary,id:String) -> Dictionary:
	Routes.setup(); var r:Dictionary=d.get("life",{}).get(id,_new(id)); var p:=Routes.pos(r.at); var scene:String=Routes.scenes[r.at]
	var direction:=Vector3.ZERO
	if id==MERCHANT:
		var age:=float(d.visit); scene="away" if age<0 else FIELD
		var frac:=clampf(age/10. if age<10 else 1. if age<15 else (25-age)/10.,0,1); var dist:=frac*Routes.freight.get_baked_length()
		p=Routes.freight.sample_baked(dist)
		direction=Routes.freight.sample_baked(minf(dist+.05,Routes.freight.get_baked_length()))-Routes.freight.sample_baked(maxf(dist-.05,0))
		if age>=15: direction=-direction
		var stop:=clampf(minf((age-10.)/.9,(15.-age)/1.),0.,1.)
		p+=Vector3(.83*stop,1.04*(1.-stop),-.35*stop)
	elif r.to!=r.at and Routes.scenes[r.at]==Routes.scenes[r.to]:
		direction=p.direction_to(Routes.pos(r.to)); p+=direction*float(r.meters)
	return {"scene":scene,"position":p,"activity":r.activity,"direction":direction,"home":HOMES.get(id,"wagon"),"bed":Routes.BEDS.get(id,"wagon"),"food":r.food}
