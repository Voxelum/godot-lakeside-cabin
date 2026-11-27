extends SceneTree
## The same random --token is used by independent write/read Godot processes.
const MAIN := preload("res://Main.tscn")
var errors := 0
func check(ok: bool, detail: String) -> void:
	if not ok: errors += 1; push_error(detail)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=2 or args[0] not in ["write","read"] or args[1].length()!=32 or not args[1].is_valid_hex_number(): quit(2); return
	var readback := args[0]=="read"
	var slot := "user://entity-check-"+args[1]+".slot"
	if FileAccess.file_exists(slot)!=readback: quit(2); return
	var main := MAIN.instantiate(); var session = main.get_node("Session")
	session.slot_path = slot; main.get_node("BindingPanel").settings_path=slot+".cfg"; root.add_child(main)
	var state = session.state; var reg = state.entities; var player = reg.records.player
	check(is_same(player.inventory,state.inventory) and player.stats==state.player_stats and player.body()==main.active_actor(), "shared player authorities")
	for person in get_nodes_in_group("village_person"):
		var e = reg.records["resident:"+person.person_id]; check(e.body()==person and person.get_meta("entity")==e,"resident binding")
	for fighter in session.farm.fighters:
		var e = fighter.actor.get_meta("entity"); check(e.stats==fighter.stats and e.inventory==null and e.body()==fighter.actor,"monster binding")
	var farmer = reg.records["resident:farmer"]; var merchant = reg.records["resident:CaravanMerchant"]
	var foe = session.farm.fighters[0]; var hen = reg.records["livestock:hen.01"]
	if readback:
		check(farmer.inventory=={"item.cup":1} and merchant.inventory.is_empty(),"private inventory persisted, not shared")
		check(farmer.stats.hp()==farmer.stats.max_hp()-3 and hen.affection==9 and hen.last_pet_day==2,"durable attributes/bond")
		check(foe.stats.hp()==foe.stats.max_hp(),"fresh encounter after process restart")
		var file := FileAccess.open(slot,FileAccess.READ)
		var data: Dictionary = bytes_to_var(file.get_buffer(file.get_length())); file.close()
		data.entities[hen.id].affection=101
		file=FileAccess.open(slot,FileAccess.WRITE); file.store_buffer(var_to_bytes(data)); file.close()
		check(state.load_slot(slot)!="" and hen.affection==9 and farmer.inventory=={"item.cup":1},"reject malformed affection without partial restore")
		data.erase("entities") # Existing v2/v3 saves do not carry this optional section.
		file=FileAccess.open(slot,FileAccess.WRITE); file.store_buffer(var_to_bytes(data)); file.close()
		check(state.load_slot(slot)=="" and hen.affection==0 and hen.last_pet_day==-1 and farmer.inventory.is_empty(),"legacy save resets live persistent components")
		check(is_same(player.inventory,state.inventory),"legacy restore does not detach the pack")
		DirAccess.remove_absolute(slot)
	else:
		farmer.inventory["item.cup"]=1; farmer.stats.take_damage(3); foe.stats.take_damage(3); hen.affection=9; hen.last_pet_day=2
		main.restore_place("place.orchard_house",Vector3.ZERO)
		check(player.body()==main.room_actor and player.body().get_meta("entity")==player and is_same(player.inventory,state.inventory),"indoor player rebind")
		check(farmer.inventory=={"item.cup":1} and merchant.inventory.is_empty() and foe.stats.hp()==foe.stats.max_hp()-3,"door does not reset owners")
		main.restore_place("place.clearing",Vector3.ZERO); check(player.body()==main.field_actor,"return to original body")
		check(not state.entities.snapshot().has("player") and not state.entities.snapshot().has(foe.actor.get_meta("entity").id),"no duplicate player or saved training bout")
		check(state.save_slot(slot)=="","write fixture")
	print("F5 entities ",args[0],": ",errors," failures"); quit(int(errors!=0))
