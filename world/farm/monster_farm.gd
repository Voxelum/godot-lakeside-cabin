extends Node3D
## Scene-local opponent selection, safe walkway, visitor recovery and HUD. This
## region has no save schema of its own: bouts are repeatable, not world changes.
const Layout := preload("farm_layout.gd")
const Catalog := preload("farm_catalog.gd")
const Species := preload("farm_species.gd")
const Fighter := preload("farm_fighter.gd")
const FieldBody := preload("res://art/field_cast/field_body.gd")
const Specimen := preload("res://art/monster_variants/specimen.gd")
var fighters: Array[Fighter] = []
var pens: Array[Dictionary] = []
var opponent: Fighter
var player: CharacterBody3D
var session: Node
var down_time := 0.0
var _hint := ""

func _ready() -> void:
	for row in Catalog.ROWS.size():
		for col in Catalog.ROWS[row].size():
			var entry: Species = Catalog.ROWS[row][col]
			var pocket := Node3D.new()
			pocket.name = entry.id
			$Pens.add_child(pocket)
			var box := Layout.pen(entry.tier,col)
			var pen := {"entry":entry, "box":box, "gate":Layout.gate(entry.tier,col), "residents":[]}
			pens.append(pen)
			if entry.model_scene == null:
				push_error("农场缺少实际模型：" + entry.title)
				continue # missing art is never replaced or counted as a live animal
			for coat in 3:
				var art := entry.model_scene.instantiate() as Node3D
				var body: FieldBody
				var view: Node3D
				if art is Specimen:
					body = art
					art.variant = coat
				else:
					body = FieldBody.new()
					body.use_capsule(entry.solid_radius,entry.solid_height)
					body.body_center.y += entry.body_lift
					art.set(&"variant_index",coat)
					art.name = "Model"
					body.add_child(art)
				body.name = entry.body_names[coat]
				body.position = Layout.foot(Layout.home(entry.tier,col,coat))
				body.rotation.y = (0.0 if row==0 else PI) + [.13,.43,-.39][coat]
				pocket.add_child(body)
				view = body.model if body is Specimen else art
				var encounter := Fighter.new()
				encounter.install(self,body,view,entry,coat,box)
				fighters.append(encounter)
				pen.residents.append(encounter)

func bind(field_session: Node, walker: CharacterBody3D) -> void:
	session = field_session
	player = walker

func playable() -> bool:
	return player != null and not player.locked and not session.host.indoors and not session.host.crossing and not session.is_modal() and player.combat.stats.hp() > 0

func _pen_at(p: Vector2) -> Dictionary:
	if p.x < Layout.START or p.x >= Layout.END: return {}
	var col := floori((p.x - Layout.START) / Layout.STRIDE)
	if p.y > Layout.AISLE-Layout.HALF_AISLE and p.y < Layout.AISLE+Layout.HALF_AISLE: return {}
	var tier := 1 if p.y < Layout.AISLE else 2
	if col >= Catalog.ROWS[tier-1].size() or not Layout.pen(tier,col).has_point(p): return {}
	return pens[col + (0 if tier==1 else Catalog.ROWS[0].size())]

func challenge(who: Fighter) -> void:
	if opponent == null and who.can_be_hit_by(player): opponent = who

func _select(p: Vector2, pen: Dictionary) -> void:
	if opponent and (opponent.stats.hp() == 0 or not opponent.box.has_point(p) or (opponent.definition.speed == 0 and p.distance_to(Layout.xz(opponent.home)) > opponent.definition.notice)):
		opponent = null
	if opponent or pen.is_empty(): return
	var closest := INF
	for who: Fighter in pen.residents:
		var gap := p.distance_to(Layout.xz(who.actor.global_position))
		if who.stats.hp() > 0 and gap <= who.definition.notice and gap < closest:
			closest = gap
			opponent = who

func report_contact(who: Fighter, lost: int) -> void:
	if player.combat.stats.hp() == 0: session.hud.feedback("倒下了 · 即将在园门水槽旁醒来")
	elif lost == 0: session.hud.feedback("闪避 · 躲开了%s" % who.display_name)
	else: session.hud.feedback("%s%s · 失去 %d 生命" % [who.display_name,"（格挡）" if player.combat.action == &"guard" else "",lost])

func _hint_at(p: Vector2, pen: Dictionary) -> String:
	if opponent and opponent.stats.hp()>0:
		return "%s　生命 %d/%d · 攻 %d 防 %d · %s" % [opponent.display_name,opponent.stats.hp(),opponent.stats.max_hp(),opponent.definition.power,opponent.definition.armor,Fighter.WORDS[opponent.phase]]
	if not pen.is_empty(): return "%s栏 · 移近迎战；退到步道即可脱战" % pen.entry.title
	if p.distance_to(Layout.REST)<1.75: return "园门水槽 · %s 休整并重置各栏" % session._use_binding_names()
	if p.distance_to(Layout.FORK) < 3.7: return "魔物园 → 沿绿爪木牌的碎石支路进入"
	if p.x >= Layout.START and p.x <= Layout.END and absf(p.y-Layout.AISLE) <= Layout.HALF_AISLE+.05:
		var col := clampi(floori((p.x-Layout.START)/Layout.STRIDE),0,Layout.COLUMNS-1)
		var first: String = Catalog.ROWS[0][col].title if col<Catalog.ROWS[0].size() else "休憩草地"
		return "安全步道 · 绿牌 %s　|　铜牌 %s" % [first,Catalog.ROWS[1][col].title]
	return "魔物园 · 绿牌一阶，铜牌二阶；跨过栏口才会接敌" if Layout.on_farm(p) else ""

func _set_hint(text: String) -> void:
	if _hint == text: return
	_hint = text
	session.hud.set_hint(text)

func pause_bout() -> void:
	# Menu/iris cancels even a pending impact. After release a fresh tell is required.
	if opponent and session: session.hud.feedback("")
	opponent = null
	for who in fighters:
		if who.phase not in [Fighter.Phase.WATCH,Fighter.Phase.DOWN]: who.disengage()
	if session: _set_hint("")

func reset_encounters() -> void:
	opponent = null
	down_time = 0.0
	for who in fighters: who.reset_to_home()

func safe_loaded_foot(at: Vector3) -> Vector3:
	# A saved foot can occupy the old (moved or downed) monster's spawn.
	# Only that overlap is relocated, to the same pen's safe gate.
	var p := Layout.xz(at)
	var pen := _pen_at(p)
	if not pen.is_empty():
		for who: Fighter in pen.residents:
			if who.home_overlaps_walker(at,player.get_node("Body")):
				return Layout.foot(Vector2(pen.gate.x, Layout.AISLE),.005)
	return at

func rest_if_near() -> bool:
	if not playable() or Layout.xz(player.global_position).distance_to(Layout.REST)>1.75: return false
	player.combat.stats.change_hp(player.combat.stats.max_hp())
	player.combat.reset()
	reset_encounters()
	session.hud.feedback("水槽边休整 · 生命已补满，各栏已归位")
	return true

func _physics_process(dt: float) -> void:
	if not player: return
	if session.host.indoors or session.host.crossing or session.is_modal() or player.locked:
		if opponent or not _hint.is_empty(): pause_bout()
		return
	var p := Layout.xz(player.global_position)
	var alive: bool = player.combat.stats.hp()>0
	if not alive and Layout.on_farm(p):
		down_time += dt
		_set_hint("倒下 · 园门水槽休整")
		if down_time >= 1.55:
			player.combat.stats.change_hp(player.combat.stats.max_hp())
			reset_encounters()
			session.host.show_place(false,Layout.foot(Layout.RECOVERY,.004),false)
			session.host.sync_control(true)
			session.hud.feedback("已在园门醒来 · 装备与行囊保留，可再次挑战")
			return
	else: down_time = 0
	var pen := _pen_at(p) if alive else {}
	_select(p,pen)
	if not alive: opponent = null
	# All 33 HP pools persist in memory; no offscreen search/pathfinding.
	for who in fighters:
		var near_camera := p.distance_squared_to(Layout.xz(who.home)) < 20.0*20.0
		if near_camera or who.phase != Fighter.Phase.WATCH or who.stats.hp() < who.stats.max_hp():
			who.tick(dt,who == opponent,who.box.has_point(p),near_camera)
	if alive: _set_hint(_hint_at(p,pen))
