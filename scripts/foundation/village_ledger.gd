extends RefCounted
## Only this ledger settles village transactions. A renderer may read but never tick it.
const FarmJobs := preload("res://scripts/foundation/farm_jobs.gd")
const ResidentLife := preload("res://scripts/foundation/resident_life.gd")
const INITIAL := {"life":{},"field_done":false,"hour":6,"seconds":0.0,"visit":-1.0,"road":true,"auto_farm":true,"crop":0,"wet":false,"water":0,"dry":0,"withered":0,"fed":0,"collected":0,"health":10,"missed":0,"grass":3,"hay":3,"seed":2,"wheat":0,"flour":0,"meal":0,"basket":0,"basket_eta":0,"shop_result":0,"hungry_days":0,"shed":{"bread":0,"egg":0,"milk":0,"wool":0,"tool":0},"cart":{"bread":0,"egg":0,"milk":0,"wool":0,"tool":0},"cart_eta":0,"paid_in":0,"paid_out":0,"cargo":[],"purse":{"village":24,"family":12,"caravan":120},"store":{"bread":3,"egg":0,"milk":0,"wool":0,"iron":0,"tool":0},"wagon":{"bread":24,"egg":0,"milk":0,"wool":0,"iron":16,"tool":0}}
var d: Dictionary = INITIAL.duplicate(true)
const FOODS := ["bread","egg","milk"]
const PRICE := {"bread":2,"egg":1,"milk":1,"wool":3,"iron":2,"tool":5}

func elapsed(seconds: float) -> void:
	# Split the one authoritative clock at hour boundaries, so fast-forward and
	# ordinary frames dispatch the same visit, loading, and market events.
	while seconds > 0.0:
		var left := 5.0 - float(d.seconds)
		var dt := minf(seconds, left)
		ResidentLife.advance(d,dt)
		_travel(dt)
		seconds -= dt
		if dt == left:
			d.seconds = 0.0
			_hour()
		else:
			d.seconds += dt

const DOCK := 10.0
const LEAVE := 15.0
const HOME := 25.0

func _travel(dt: float) -> void:
	if not d.road or d.visit < 0.0: return
	var old := float(d.visit)
	d.visit = old + dt
	for edge: float in [DOCK, LEAVE, HOME]:
		if absf(float(d.visit) - edge) < 1.0e-9: d.visit = edge
	if old < DOCK and d.visit >= DOCK:
		_trade()
	if d.visit >= DOCK:
		for job in d.cargo: job.eta = clampi(ceili((HOME-float(d.visit))/5.0), 1, 3)
	if d.visit >= HOME:
		for job in d.cargo:
			var dest: Dictionary = d.store if job["import"] else d.wagon
			dest[job.item] += job.qty
		d.cargo.clear()
		d.visit = -1.0

func tend() -> String:
	return FarmJobs.tend(d)

func cut() -> String:
	if d.grass < 1: return "无草可割"
	d.grass -= 1; d.hay += 1
	return "割草入干草棚 +1"

func funds(source: String, dest: String, qty: int) -> void:
	d.purse[source] -= qty; d.purse[dest] += qty

func shipment(item: String, amount: int, importing: bool) -> void:
	var src: Dictionary = d.wagon if importing else d.store
	var buyer := "village" if importing else "caravan"
	var budget:int=d.purse[buyer] if importing else maxi(0,d.purse[buyer]-2) # driver's meal reserve
	var qty := mini(mini(amount,src[item]),floori(float(budget)/PRICE[item]))
	if qty <= 0: return
	var cost: int = qty * PRICE[item]
	funds(buyer,"caravan" if importing else "village",cost)
	if importing: d.paid_out += cost
	else: d.paid_in += cost
	src[item] -= qty
	d.cargo.append({"item":item,"qty":qty,"import":importing,"eta":3})

func _trade() -> void:
	# Pay the driver for the completed trip, from village funds (never mint money).
	funds("village","caravan",mini(2,d.purse.village))
	var food: int = d.store.bread+d.store.egg+d.store.milk
	shipment("bread",maxi(0,8-food),true)
	shipment("iron",maxi(0,2-d.store.iron),true)
	for item in ["tool","wool","egg","milk","bread"]:
		var spare: int = d.store[item]
		if item in FOODS: spare = mini(spare,maxi(0,food-8)); food -= spare
		shipment(item,spare,false)

func step() -> void:
	elapsed(5.0)

func _hour() -> void:
	d.hour += 1
	if d.road:
		if d.cart_eta > 0:
			d.cart_eta -= 1
			if d.cart_eta == 0:
				for id in d.cart:
					d.store[id] += d.cart[id]; d.cart[id] = 0
		for i in range(d.cargo.size()-1 if d.visit < 0.0 else -1,-1,-1):
			var job: Dictionary = d.cargo[i]; job.eta -= 1
			if job.eta == 0:
				var dest: Dictionary = d.store if job["import"] else d.wagon
				dest[job.item] += job.qty; d.cargo.remove_at(i)
	match int(d.hour)%24:
		6:
			d.grass = mini(9,d.grass+3)
			d.fed = 0; d.collected = 0; d.field_done = false
			if d.crop > 0:
				if d.water > 0:
					d.water -= 1; d.crop = mini(3,d.crop+1); d.dry = 0
				else:
					d.dry += 1
					if d.dry >= 2: d.crop = 0; d.dry = 0; d.withered += 1
			d.wet = d.water > 0

		9:
			if d.health > 0:
				d.flour += d.wheat; d.wheat = 0
		10:
			if d.health > 0:
				d.shed.bread += d.flour; d.flour = 0
				if d.store.iron > 0: d.store.iron -= 1; d.shed.tool += 1
			# Household wages: up to two coins per working resident, capped at today's food budget.
			if d.field_done or d.collected!=0 or d.shed.tool>0 or d.shed.bread>0:
				funds("village","family",mini(d.purse.village,maxi(0,ResidentLife.HOMES.size()*2-d.purse.family)))
		11:
			if d.road and d.cart_eta==0:
				for id in d.cart:
					d.cart[id] = d.shed[id]; d.shed[id]=0
					if d.cart[id]>0: d.cart_eta=2
		12:
			if d.road and d.visit < 0.0 and d.cargo.is_empty(): d.visit = 0.0

func duty() -> String:
	var h := int(d.hour)%24
	if h < 7 or h >= 19: return "在家 · 吃饭休息"
	if h == 7: return "村田 · 浇麦" if d.auto_farm and d.health>0 else "田边 · 歇工"
	if h in [8,9]:
		var i := mini(2,floori(float(d.seconds)*3./5.))
		return ["鸡棚 · 喂鸡","牛栏 · 喂牛","羊栏 · 喂羊"][i] if h==8 else ["鸡棚 · 收蛋","牛栏 · 挤奶","羊栏 · 剪毛"][i]
	if h < 12: return "作坊 · 磨面烤面包、打铁领薪"
	if h < 17: return "市集 · 收发货物"
	return "市集 → 家 · 买晚饭"

static func upgrade(old:Dictionary) -> Dictionary:
	var value := old.duplicate(false)
	if not value.has("life"): value.life = {}
	if not value.has("field_done"): value.field_done = value.get("hour",0) is int and int(value.hour)%24 >= 7
	if not value.has("visit"): value.visit = -1.0
	if not value.has("water") and value.get("wet") is bool:
		# Old 08:00 slots already received all products; do not replay them.
		value.merge({"water":int(value.wet),"dry":0,"withered":0,"fed":0,"collected":0})
		if value.get("hour") is int and int(value.hour)%24 in [8,9]:
			value.fed = 7; value.collected = 7
	return value

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	value = upgrade(value)
	if value.size()!=INITIAL.size(): return false
	if not value.visit is float or not is_finite(value.visit) or (value.visit != -1.0 and (value.visit < 0 or value.visit >= HOME)): return false
	for k in INITIAL:
		if not value.has(k) or typeof(value[k])!=typeof(INITIAL[k]): return false
		if typeof(value[k])==TYPE_INT and (value[k]<0 or value[k]>1000000000): return false
		if k == "life":
			if not ResidentLife.valid(value.life): return false
			continue
		if INITIAL[k] is Dictionary:
			if value[k].size()!=INITIAL[k].size(): return false
			for id in INITIAL[k]:
				if not value[k].get(id) is int or value[k][id]<0 or value[k][id]>1000000000: return false
	if not is_finite(value.seconds) or value.seconds<0 or value.seconds>=5 or value.shop_result>4 or value.basket_eta>1 or value.basket+value.meal>3 or value.cart_eta>2 or value.crop>3 or value.health>10 or value.meal>3 or value.cargo.size()>7: return false
	if value.water>2 or value.wet!=(value.water>0) or value.dry>1 or value.fed>7 or value.collected>7 or (int(value.collected)&int(value.fed))!=value.collected: return false
	if value.purse.family+value.purse.village+value.purse.caravan!=156: return false
	for job in value.cargo:
		if not job is Dictionary or job.size()!=4 or not PRICE.has(job.get("item")) or not job.get("qty") is int or job.qty<1 or job.qty>1000000000 or not job.get("import") is bool or not job.get("eta") is int or job.eta not in [1,2,3]: return false
	return true
