extends SceneTree
## Native F5 physics + UI/input; a private scratch slot, no player saves/preferences.
## --route walks from spawn through every gate and back; default tests encounters + saves.
const MAIN := preload("res://Main.tscn")
const L := preload("res://world/farm/farm_layout.gd")
const Farm := preload("res://world/farm/monster_farm.gd")
const Fighter := preload("res://world/farm/farm_fighter.gd")
const Specimen := preload("res://art/monster_variants/specimen.gd")
const Survey := preload("res://world/outskirts/outskirts_profile.gd")
const Actions := [&"walk_left",&"walk_right",&"walk_up",&"walk_down"]
var main
var player: CharacterBody3D
var farm: Farm
var stats
var s
var slot: String
var checks := 0
var failures := 0
var unsupported := 0
var max_step := 0.0
var escaped := false
var size_px := Vector2i(480,270)

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func frames(n: int) -> void:
	for _i in n: await physics_frame

func tap(code: Key) -> void:
	for down in [true,false]:
		var e := InputEventKey.new()
		e.pressed=down; e.keycode=code; e.physical_keycode=code
		Input.parse_input_event(e); Input.flush_buffered_events()

func mouse(button: MouseButton, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.pressed=down; e.button_index=button
	e.position=main.get_node("Screen").get_rect().get_center(); e.global_position=e.position
	Input.parse_input_event(e); Input.flush_buffered_events()

func attack() -> void:
	mouse(MOUSE_BUTTON_LEFT,true); mouse(MOUSE_BUTTON_LEFT,false)

func drive(axis: Vector2) -> void:
	var right: Vector3 = main.orbit.global_basis.x.slide(Vector3.UP).normalized()
	var wanted := Vector3(axis.x,0,axis.y)
	var x := wanted.dot(right); var y := wanted.dot(right.cross(Vector3.UP))
	var v := [-x,x,-y,y]
	for i in 4:
		if v[i]>.001: Input.action_press(Actions[i],v[i])
		else: Input.action_release(Actions[i])
	if axis.length_squared()>.001: Input.action_press(&"sprint")
	else: Input.action_release(&"sprint")

func walk(dest: Vector2) -> bool:
	var old := player.global_position
	var limit := ceili(L.xz(old).distance_to(dest)*60.0/player.sprint_speed)+85
	for _i in limit:
		var from := player.global_position
		var delta := dest-L.xz(from)
		if delta.length()<.078:
			drive(Vector2.ZERO)
			return true
		drive(delta.normalized())
		await physics_frame
		max_step = maxf(max_step,from.distance_to(player.global_position))
		unsupported += int(not player.is_on_floor())
		if main.crossing or main.indoors: break
	drive(Vector2.ZERO)
	printerr("walk stuck: ",old," -> ",dest," at ",player.global_position)
	return false

func scan_bounds() -> void:
	if not farm: return
	for foe in farm.fighters:
		if not foe.box.grow(-foe.edge_clearance+.025).has_point(L.xz(foe.actor.global_position)): escaped = true

func stage(p: Vector2) -> void:
	drive(Vector2.ZERO)
	main.show_place(false,L.foot(p,.008),false)
	main.sync_control(true)

func wait_phase(who: Fighter, wanted: Fighter.Phase, n := 185) -> bool:
	for i in n:
		if who.phase==wanted: return true
		await physics_frame
	return false

func equip(id: String) -> void:
	if s.state.equipment.get("main_hand","")!=id:
		s.state.equip("main_hand",id)
	s._sync_equipped_weapon()
	tap(KEY_R)
	await frames(28)
	check(player.combat.drawn,"equipped weapon drawn: "+id)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var token := Crypto.new().generate_random_bytes(12).hex_encode()
	slot="user://farm-%s.slot"%token
	if "--320" in args: size_px=Vector2i(320,180)
	main=MAIN.instantiate(); s=main.get_node("Session"); s.slot_path=slot
	main.get_node("BindingPanel").settings_path="user://farm-%s.cfg"%token
	root.add_child(main)
	if DisplayServer.get_name()!="headless":
		root.mode=Window.MODE_WINDOWED
		root.size=size_px*2
	player=main.field_actor; stats=s.state.player_stats; farm=s.farm
	physics_frame.connect(scan_bounds)
	await frames(7)
	check(main.field.size==size_px and main.active_actor()==player and player.is_on_floor(),"F5 native pixel preset, real grounded Walker")
	_roster()
	if "--damage-marks" in args: await _damage_marks()
	elif "--route" in args: await _route()
	else:
		await _bouts()
		await _saving()
	check(not escaped,"every physical frame all 33 bodies stayed within their own fence")
	if FileAccess.file_exists(slot): DirAccess.remove_absolute(slot)
	print("Farm ","route" if "--route" in args else "combat/save"," ",size_px," ",DisplayServer.get_name(),": ",checks-failures,"/",checks,"; airborne ",unsupported,", max stride ",max_step)
	quit(int(failures!=0))

func _roster() -> void:
	var residents: Dictionary={}
	var hp_pools: Dictionary={}
	var tiers := [0,0]
	for pen in farm.pens:
		var available: bool = pen.residents.size()==3
		for who: Fighter in pen.residents:
			available = available and who.stats.hp()==pen.entry.health and who.actor.solid.shape!=null and who.model.find_children("*","MeshInstance3D",true,false).size()>0
			available = available and (who.actor.variant==who.coat if who.actor is Specimen else who.model.variant_index==who.coat and who.animator.has_animation(&"attack"))
			residents[who.actor.name]=true; hp_pools[who.stats.get_instance_id()]=true
		check(available,"actual models, coats, hit bodies and fresh per-instance HP: "+pen.entry.title)
		tiers[pen.entry.tier-1]+=1
	check(tiers==[5,6] and residents.size()==33 and hp_pools.size()==33,"5 + 6 unique species, 33 actual actors with independent pools")
	check(not main.field.has_node("Clearing/Outskirts/Habitats") and not main.field.has_node("Clearing/MonsterField"),"no duplicate roadside specimens")

func _route() -> void:
	var spawn := L.xz(player.global_position)
	var start_hp: int=stats.hp()
	for i in range(1,14):
		if not await walk(Survey.ROUTE[i]): check(false,"road outbound"); return
	check(await walk(L.RECOVERY),"walk through smith-side opening from the cabin")
	check(farm.opponent==null,"visitor aisle safe")
	# Run into a side rail (not its opening). The contacted collider is the visible farm rail.
	var obstacle := L.gate(1,0)-Vector2(2.3,0)
	check(await walk(Vector2(obstacle.x,L.AISLE)),"approach closed section of the first rail")
	var contact := false
	for i in 54:
		drive(Vector2.UP); await physics_frame
		for j in player.get_slide_collision_count(): contact = contact or player.get_slide_collision(j).get_collider()==farm.get_node("Grounds/RailsAndFixtures")
	drive(Vector2.ZERO)
	check(contact and L.xz(player.global_position).y>obstacle.y and farm.opponent==null,"real fence blocks the walker and prevents combat outside")
	var gates := 0
	for col in L.COLUMNS:
		for tier in [1,2]:
			if tier==1 and col==5: continue
			var point := L.gate(tier,col)
			var aisle := Vector2(point.x,L.AISLE)
			if not await walk(aisle): check(false,"aisle"); return
			if not await walk(point+Vector2(0,L.side(tier)*.74)): check(false,"threshold "+str([tier,col])); return
			await frames(2)
			check(farm._pen_at(L.xz(player.global_position)).entry.tier==tier and (farm.opponent == null or farm.opponent.definition.tier == tier),"enter correct pen "+str([tier,col]))
			if not await walk(aisle): check(false,"retreat through pen opening"); return
			await frames(2)
			check(farm.opponent==null,"no pursuit on safe path "+str([tier,col]))
			gates+=1
	check(gates==11 and await walk(Vector2(L.END-.89,L.AISLE)),"all eleven gates both ways, reach far side")
	if not await walk(L.RECOVERY) or not await walk(L.FORK): check(false,"farm exit"); return
	for i in range(12,-1,-1):
		if not await walk(Survey.ROUTE[i]): check(false,"road inbound"); return
	check(spawn.distance_to(L.xz(player.global_position))<.10 and stats.hp()==start_hp and unsupported==0 and max_step<.13 and not FileAccess.file_exists(slot),"complete no-transition return on solid ground, no retaliation or autosave")

func _stand(who: Fighter, gap: float) -> void:
	var side := L.side(who.definition.tier)
	stage(L.xz(who.home)-Vector2(0,side*gap))
	player.combat.face(Vector3(0,0,side))

func _bouts() -> void:
	# Every species must actually wind up, hit and cool down, against the real defending Walker.
	for pen in farm.pens:
		if pen.residents.is_empty(): check(false,"absent species: "+pen.entry.title); continue
		var who: Fighter=pen.residents[0]
		farm.reset_encounters()
		stats.change_hp(stats.max_hp())
		_stand(who,who.definition.reach-.13)
		await frames(3)
		mouse(MOUSE_BUTTON_RIGHT,true)
		var initial: int=stats.hp()
		var began := await wait_phase(who,Fighter.Phase.TELL)
		check(began and who.cue.visible and stats.hp()==initial,who.definition.title+" readable pre-contact tell")
		var struck := await wait_phase(who,Fighter.Phase.SWING)
		await frames(2)
		var correct := initial-ceili(who.definition.power*.25)
		check(struck and stats.hp()==correct and player.combat.action==&"guard",who.definition.title+" true frontal mitigation "+str([stats.hp(),correct,who.phase]))
		await frames(ceili(who.definition.follow_through*60)+10)
		check(who.phase==Fighter.Phase.RECOVER and stats.hp()==correct,who.definition.title+" single contact + recovery")
		if struck and who.definition.id == &"giant_spider":
			for arg in OS.get_cmdline_user_args():
				if not arg.begins_with("--moment="): continue
				var capture := arg.trim_prefix("--moment=")
				await wait_phase(who,Fighter.Phase.TELL); await frames(13); await RenderingServer.frame_post_draw
				var expected_digest := ""
				for opt in OS.get_cmdline_user_args():
					if opt.begins_with("--previous-sha256="): expected_digest=opt.trim_prefix("--previous-sha256=").to_lower()
				check((not FileAccess.file_exists(capture) or (not expected_digest.is_empty() and FileAccess.get_sha256(capture)==expected_digest)) and root.get_texture().get_image().save_png(capture)==OK,"save actual composed second windup after a real block; protect existing files")
		mouse(MOUSE_BUTTON_RIGHT,false)
	var slime: Fighter=farm.pens[0].residents[0]
	# Walk away from a *moving* enemy in the committed window; not a staged exit.
	farm.reset_encounters()
	var gate := Vector2(slime.home.x,L.gate(1,0).y)
	stage(gate+Vector2.UP*.57); await frames(3)
	check(await wait_phase(slime,Fighter.Phase.TELL) and slime.actor.global_position.distance_to(slime.home)>.45,"live opponent closes distance before tell")
	var safe_hp: int=stats.hp()
	check(await walk(gate+Vector2.DOWN*1.42),"retreat on foot through gate during windup")
	await frames(130)
	check(stats.hp()==safe_hp and farm.opponent==null and slime.actor.global_position.distance_to(slime.home)<.05,"real retreat cancels damage and leashes home")
	# Real roll input late in a committed attack (no debug hit). Roll toward the
	# attacking body so collision prevents simply outranging the check.
	_stand(slime,.99); await wait_phase(slime,Fighter.Phase.TELL)
	await frames(ceili((slime.definition.windup-.16)*60)); tap(KEY_CTRL)
	check(await wait_phase(slime,Fighter.Phase.SWING) and player.combat.action==&"roll" and stats.hp()==safe_hp,"late roll counters a real committed monster hit")
	stage(gate+Vector2.DOWN*1.42); await frames(90)
	farm.reset_encounters(); _stand(slime,.99); await frames(3)
	var reserve: Fighter=farm.pens[0].residents[1]
	attack(); await frames(26)
	check(slime.stats.hp()==slime.definition.health-1 and reserve.stats.hp()==reserve.definition.health,"physical armor, minimum one hurt; a jab does not damage a second body")
	# Exit and re-enter. Enemy winds up but a menu cannot let it finish a strike.
	stage(Vector2(slime.home.x,L.AISLE)); await frames(90)
	check(slime.stats.hp()==slime.stats.max_hp() and slime.phase==Fighter.Phase.WATCH,"disengagement returns home and restores the encounter")
	_stand(slime,.98)
	check(await wait_phase(slime,Fighter.Phase.TELL),"slime enters fresh tell")
	var hp: int=stats.hp()
	tap(KEY_TAB); attack(); await frames(100)
	check(s.is_modal() and farm.opponent==null and stats.hp()==hp and not slime.cue.visible and s.hud._hint_text.is_empty(),"inventory cancels tell / queued damage / farm HUD")
	tap(KEY_TAB); await frames(5)
	check(not s.is_modal() and stats.hp()==hp and slime.phase!=Fighter.Phase.SWING,"closing the menu cannot release an old hit")
	check(await wait_phase(slime,Fighter.Phase.TELL),"new warning before next attack")
	tap(KEY_ESCAPE); attack(); await frames(80)
	check(s.book.opened and not slime.cue.visible and stats.hp()==hp and farm.opponent==null,"settings book suppresses both combat directions")
	tap(KEY_ESCAPE); await wait_phase(slime,Fighter.Phase.TELL)
	s.set_dialogue_modal(true); attack(); await frames(80)
	check(s.is_modal() and farm.opponent==null and stats.hp()==hp,"dialogue modal blocks an in-flight encounter")
	s.set_dialogue_modal(false); await wait_phase(slime,Fighter.Phase.TELL)
	main.show_place(true,main.room_entry.global_position,false); main.sync_control(true); await frames(90)
	check(main.indoors and main.active_actor()!=player and farm.opponent==null and stats.hp()==hp,"the inactive outdoor world cannot strike the indoor Guest")
	stage(Vector2(slime.home.x,L.AISLE)); await frames(85)
	check(stats.hp()==hp and slime.actor.global_position.distance_to(slime.home)<.06,"retreat through gate evades committed hit; attacker never follows into aisle")
	await equip("item.sword"); _stand(slime,1.47); await frames(3)
	attack(); await frames(30)
	check(slime.stats.hp()==slime.stats.max_hp()-2,"sword strike resolves defense once")
	stage(Vector2(slime.home.x,L.AISLE)); await frames(95)
	await equip("item.spear")
	# Every one of all 33 bodies gets a real weapon input; no untouchable display dolls.
	for pen in farm.pens:
		for coat in 3:
			var alt: Fighter=pen.residents[coat]
			var untouched: Fighter=pen.residents[(coat+1)%3]
			farm.reset_encounters(); _stand(alt,1.47); await frames(3)
			attack(); await frames(39)
			check(alt.stats.hp()==alt.definition.health-maxi(1,11-alt.definition.armor) and untouched.stats.hp()==alt.definition.health,alt.display_name+" is a real directional target with its own HP")
	var flower: Fighter=farm.pens[9].residents[0]
	farm.reset_encounters(); _stand(flower,1.93); await frames(4)
	var far_hp: int=stats.hp()
	var strikes := ceili(float(flower.definition.health)/(11-flower.definition.armor))
	for i in strikes: attack(); await frames(40)
	check(flower.phase==Fighter.Phase.DOWN and flower.stats.hp()==0 and flower.actor.solid.disabled and flower.model.rotation.z>.8 and flower.actor.global_position.distance_to(flower.home)<.02 and stats.hp()==far_hp,"spear outranges rooted ambush; real down pose, disabled body, no strike back")
	stage(Vector2(flower.home.x,L.AISLE)); await frames(90)
	check(flower.stats.hp()==flower.stats.max_hp() and not flower.actor.solid.disabled,"exit revives the same plant exactly once")
	# One close unguarded Orc impact drops an injured hero; only farm-local recovery restores them.
	var orc: Fighter=farm.pens[5].residents[0]
	stats.change_hp(1-stats.hp()); _stand(orc,1.30)
	check(await wait_phase(orc,Fighter.Phase.SWING),"orc attack resolves without debug damage")
	await frames(2)
	check(stats.hp()==0 and player.combat.action==&"down", "actual enemy attack knocks player down")
	await frames(112)
	check(stats.hp()==stats.max_hp() and L.xz(player.global_position).distance_to(L.RECOVERY)<.10 and player.combat.action==&"idle" and s.state.equipment.get("main_hand")=="item.spear","automatic farm-gate recovery, original inventory/equipment preserved")
	stats.take_damage(3); tap(KEY_F)
	check(stats.hp()==stats.max_hp(),"use at near-side trough really restores HP")

func _saving() -> void:
	var sample: Fighter=farm.fighters[0]
	var foot := Vector2(sample.home.x,L.AISLE)
	stage(foot); await frames(4)
	stats.take_damage(3)
	var saved_hp: int=stats.hp()
	tap(KEY_F5)
	check(FileAccess.file_exists(slot),"farm uses original explicit save")
	var snapshot: Dictionary=bytes_to_var(FileAccess.get_file_as_bytes(slot))
	check(snapshot.version==2 and not snapshot.has("farm") and not snapshot.has("opponent"),"unchanged v2 outdoor schema; no mid-attack state")
	_stand(sample,1.1); await frames(3); sample.receive_damage(11,Vector3.ZERO)
	tap(KEY_F9); await frames(4)
	check(stats.hp()==saved_hp and L.xz(player.global_position).distance_to(foot)<.04 and sample.stats.hp()==sample.stats.max_hp() and farm.opponent==null and not player.combat.drawn,"F9 restores exact safe foot and player HP; all encounters fresh")
	snapshot.position=sample.home+Vector3.RIGHT*1.03
	_write_snapshot(snapshot); tap(KEY_F9); await frames(2)
	check(L.xz(player.global_position).distance_to(L.xz(snapshot.position))<.05,"safe near-combat foot is not needlessly relocated on load")
	snapshot.position=sample.home
	_write_snapshot(snapshot); tap(KEY_F9); await frames(4)
	check(L.xz(player.global_position).distance_to(foot)<.06,"new save on displaced enemy's spawn safely relocates to own gate")
	for version in [1,2]:
		var old: Dictionary=snapshot.duplicate(true)
		old.position=Survey.point(Survey.PULLOUTS[1],.004); old.version=version; old.erase("equipment")
		if version==1: old.erase("player_stats")
		_write_snapshot(old); tap(KEY_F9); await frames(4)
		check(L.xz(player.global_position).distance_to(Survey.PULLOUTS[1])<.05 and farm.opponent==null and (stats.hp()==40 if version==1 else stats.hp()==saved_hp),"v%d old roadside save keeps exact foot, state, peaceful route"%version)

func _write_snapshot(data: Dictionary) -> void:
	var f := FileAccess.open(slot,FileAccess.WRITE)
	f.store_buffer(var_to_bytes(data)); f.close()

func _damage_marks() -> void:
	var slime: Fighter = farm.pens[0].residents[0]
	_stand(slime,.99); await frames(5)
	var before := slime.stats.hp()
	var hero_hp: int = stats.hp()
	attack()
	for i in 40:
		await physics_frame
		if slime.stats.hp() < before: break
	check(slime.stats.hp()==before-1 and slime.damage_spark.visible,"jab creates monster contact mark with actual HP loss")
	await _capture_mark("monster")
	check(await wait_phase(slime,Fighter.Phase.SWING),"real enemy commits its counterattack")
	check(stats.hp()<hero_hp and player.combat.damage_spark.visible and not slime.damage_spark.visible,"hero takes actual damage after monster mark expires")
	await _capture_mark("player")
	await frames(20)
	check(not player.combat.damage_spark.visible and not slime.damage_spark.visible,"both marks expired")

func _capture_mark(label: String) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mark-dir="):
			var dest := arg.trim_prefix("--mark-dir=").path_join(label+".png")
			await RenderingServer.frame_post_draw
			check(not FileAccess.file_exists(dest) and main.field.get_texture().get_image().save_png(dest)==OK,"save native victim frame: "+label)
