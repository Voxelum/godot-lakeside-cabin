extends RefCounted
## Apply only from an authoritative farmer arrival (or explicit player tending).
const ANIMALS := ["hen","cow","sheep"]
# Eggs and fleece are units; milk is accounted in individual meal portions per milking.
const YIELDS := [1,7,1]
const PRODUCTS := ["egg","milk","wool"]

static func tend(d:Dictionary) -> String:
	if d.crop == 0:
		if d.seed < 1: return "没有麦种"
		d.seed -= 1; d.crop = 1; d.dry = 0
		return "已播麦，仍需浇水"
	if d.crop == 3:
		d.crop = 0; d.wheat += 4; d.seed += 1; d.dry = 0
		return "收获小麦 ×4，留种 ×1"
	if d.water >= 2: return "土壤水量已满"
	d.water += 1; d.wet = true
	return "已浇水 · 土壤储水 %d/2" % d.water

static func arrive(d:Dictionary, station:String, collect:bool) -> void:
	if station == "field":
		if not d.auto_farm or d.health <= 0 or d.field_done: return
		d.field_done = true
		if d.crop == 3: tend(d)
		if d.crop == 0: tend(d)
		if d.crop > 0: tend(d)
		return
	var i := ANIMALS.find(station)
	if i < 0: return
	var bit := 1 << i
	if collect:
		if (int(d.fed)&bit) and not (int(d.collected)&bit):
			d.shed[PRODUCTS[i]] += YIELDS[i]; d.collected |= bit
	elif not (int(d.fed)&bit):
		if d.grass > 0: d.grass -= 1
		elif d.hay > 0: d.hay -= 1
		else: return
		d.fed |= bit
