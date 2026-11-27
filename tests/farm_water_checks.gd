extends SceneTree
const Ledger := preload("res://scripts/foundation/village_ledger.gd")
func _initialize() -> void:
	var single := Ledger.new(); single.d.auto_farm=false; single.tend(); single.tend()
	var double := Ledger.new(); double.d.auto_farm=false; double.tend(); double.tend(); double.tend()
	var dry := Ledger.new(); dry.d.auto_farm=false; dry.tend()
	for dawn in [1,2]:
		for l in [single,double,dry]: l.elapsed(120.)
		print("dawn ",dawn," stages(single/double/dry) ", [single.d.crop,double.d.crop,dry.d.crop]," reserves ",[single.d.water,double.d.water,dry.d.water])
		var stages := [2,2,1] if dawn==1 else [2,3,0]
		if [single.d.crop,double.d.crop,dry.d.crop]!=stages or double.d.water!=2-dawn: quit(1); return
	double.tend()
	if double.d.wheat!=4 or dry.d.withered!=1: quit(1); return
	print("harvest=4; dry plot deaths=1"); quit(0)
