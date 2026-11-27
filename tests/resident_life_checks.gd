extends SceneTree
const Life:=preload("res://scripts/foundation/resident_life.gd")
const Ledger:=preload("res://scripts/foundation/village_ledger.gd")
var errors:=0
func check(b:bool,why:String) -> void:
	if not b: push_error(why); errors+=1
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var l:=Ledger.new(); var beds:={}; var works:={}; var bought:={}; var stepped:=false
	for id:String in Life.HOMES:
		var p:=Life.pose(l.d,id); check(p.scene==Life.HOMES[id] and not beds.has(p.bed),"stable unique cot "+id); beds[p.bed]=true
	var bed: String = Life.Routes.BEDS.farmer
	check(Life.bed_occupant(l.d,bed)=="farmer" and not Life.Slots.accepts(bed,Life.Slots.USE,"item.bread"),"bed holds resident, not item")
	check(not Life.Slots.accepts(bed,Life.Slots.USE,"Lamplighter"),"wrong resident rejected")
	var seeded:=Ledger.new(); seeded.elapsed(.01)
	var saved:Dictionary=bytes_to_var(var_to_bytes(seeded.d)); check(Life.bed_occupant(saved,bed)=="farmer","occupied bed survives restoration without scene")
	saved.life.farmer.at="bed.Lamplighter"; saved.life.farmer.to=saved.life.farmer.at
	check(not Life.valid(saved.life) and Life.bed_occupant(saved,bed)=="","wrong-bed sleep rejected")
	for i in 500:
		l.elapsed(.2); check(Ledger.valid(l.d),"valid live record %d"%i)
		for id:String in Life.HOMES:
			var p:=Life.pose(l.d,id); var r:Dictionary=l.d.life[id]
			if p.activity=="work": works[id]=true
			if r.food!="" and not bought.has(id):
				bought[id]=true; check(r.at.begins_with("shop"),"purchase at counter")
				var copy:=Ledger.new(); copy.d=bytes_to_var(var_to_bytes(l.d)); var cash:int=copy.d.purse.family
				for n in 6: Life.pose(copy.d,id)
				check(copy.d.purse.family==cash and copy.d==l.d,"snapshot and redraw side-effect free")
			if id=="farmer" and r.meters>0: stepped=true
	for id:String in Life.HOMES:
		check(works.has(id),"reached work "+id); check(Life.pose(l.d,id).activity=="sleep","asleep at night "+id)
	check(stepped and bought.size()>0,"actual journeys and meal purchases"); check(l.d.fed==7 and l.d.collected==7,"all farm arrivals")
	for mode in ["sold_out","no_money"]:
		var m:=Ledger.new(); m.elapsed(.01); m.d.hour=17; var r:Dictionary=m.d.life.farmer; r.at="shop0"; r.to=r.at; r.meters=0.; r.activity="shop"
		if mode=="sold_out": m.d.store.bread=0
		else: m.d.purse.village+=m.d.purse.family; m.d.purse.family=0
		var stock:Dictionary=m.d.store.duplicate(); var purse:Dictionary=m.d.purse.duplicate(); m.elapsed(.1); check(r.activity==mode and m.d.store==stock and m.d.purse==purse and r.food=="","failed sale atomic "+mode)
	var m:=Ledger.new(); m.elapsed(.01); m.d.hour=17; var r:Dictionary=m.d.life.farmer; r.at="shop0"; r.to=r.at; r.meters=0.; m.elapsed(.1); var snap:Dictionary=bytes_to_var(var_to_bytes(m.d)); var penny:int=m.d.purse.family; var bread:int=m.d.store.bread; m.d=snap; m.elapsed(1.2); check(m.d.life.farmer.ate==0 and m.d.life.farmer.food=="" and m.d.purse.family==penny and m.d.store.bread==bread,"single purchase/eat across restore")
	print("RESIDENT LIFE: ",errors," failures, work=",works.keys()," purchased=",bought.keys()); quit(int(errors>0))
