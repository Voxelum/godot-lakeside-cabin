extends SceneTree
## Run with --script res://tests/growth_checks.gd; optional -- --320.
## Windowed runs additionally exercise the real iris and GUI pointer routing.
const Main := preload("res://Main.tscn")
const State := preload("res://scripts/foundation/world_state.gd")
const Stats := preload("res://scripts/foundation/actor_stats.gd")
var failures := 0
var checks := 0
var attacks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _press(event: InputEvent) -> void:
	for down in [true, false]:
		event.pressed = down
		Input.parse_input_event(event.duplicate())
		Input.flush_buffered_events()

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	_press(event)

func _pad(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	_press(event)

func _click(at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = button
	_press(event)

func _rewrite(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(var_to_bytes(data))
	file.close()

func _movement_checks(main, state: State) -> void:
	state.inventory.clear() # Fixture for unloaded training.
	var player := state.player_stats
	var actor: CharacterBody3D = main.active_actor()
	var original := actor.global_position
	for i in 4: await physics_frame
	Input.action_press(&"walk_right")
	for i in 6: await physics_frame
	Input.action_release(&"walk_right")
	_check(player.load_metres() == 0.0, "empty bag does not train")
	state.inventory = {"item.bread": 2, "item.cup": 1}
	_check(is_equal_approx(state.inventory_weight_kg(), 0.95), "unit weight times stack size")
	Input.action_press(&"walk_right")
	for i in 6: await physics_frame
	Input.action_release(&"walk_right")
	_check(player.load_metres() == 0.0, "subthreshold bag does not train")
	state.inventory = {"item.sample": 2}
	main.show_place(false, original, false)
	for i in 4: await physics_frame
	_check(player.load_metres() == 0.0, "teleport and idle do not train")
	var start := actor.global_position
	Input.action_press(&"walk_right")
	for i in 12: await physics_frame
	Input.action_release(&"walk_right")
	var distance := (actor.global_position - start).slide(Vector3.UP).length()
	_check(distance > 0.1 and is_equal_approx(player.load_metres(), distance * 3.0), "loaded walk trains actual planar distance at the prototype multiplier")
	var direction := actor.get_viewport().get_camera_3d().global_basis.x.slide(Vector3.UP).normalized()
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.1, 4.0, 4.0)
	collider.shape = box
	wall.add_child(collider)
	actor.get_parent().add_child(wall)
	wall.global_transform = Transform3D(Basis(direction, Vector3.UP, direction.cross(Vector3.UP)), actor.global_position + direction * 0.85)
	Input.action_press(&"walk_right")
	for i in 75: await physics_frame
	var blocked := player.load_metres()
	for i in 15: await physics_frame
	Input.action_release(&"walk_right")
	_check(is_equal_approx(player.load_metres(), blocked), "head-on blocked input grants no growth after wall contact")
	wall.queue_free()
	main.show_place(false, original, false)
	_key(KEY_TAB)
	_check(main.get_node("FieldHUD")._total.text.contains("3.00 kg"), "inventory displays derived load")
	_key(KEY_ESCAPE)

func _run() -> void:
	var fixture := Crypto.new().generate_random_bytes(16).hex_encode()
	var slot := "user://growth_check_%s.slot" % fixture
	var main := Main.instantiate()
	var session = main.get_node("Session")
	session.slot_path = slot
	main.get_node("BindingPanel").settings_path = "user://growth_check_%s.cfg" % fixture
	session.attack_requested.connect(func() -> void: attacks += 1)
	root.add_child(main)
	var low := "--320" in OS.get_cmdline_user_args()
	root.size = Vector2i(320, 180) if low else Vector2i(480, 270)
	await process_frame
	await process_frame
	_check(main.field.size == (Vector2i(320, 180) if low else Vector2i(480, 270)), "internal pixel preset")
	var state: State = session.state
	var player := state.player_stats
	var npc_entity := Node.new()
	npc_entity.name = "TestResident"
	main.add_child(npc_entity)
	var npc := Stats.new(2)
	npc_entity.set_meta(&"stats", npc)
	_check(player.hp() == 40 and npc.hp() == 28, "fresh independent actor stats")
	_check(not player.record_practice(&"unknown"), "unknown practice rejected")
	for i in 5:
		_check(player.record_practice(Stats.PRACTICE_ID), "completed test practice recorded")
	_check(player.max_hp() == 44 and player.hp() == 40 and npc.max_hp() == 28, "practice derives more max HP without autoheal or NPC change")
	_check(player.change_hp(-1000) == -40 and player.hp() == 0, "damage clamps to zero")
	_check(player.change_hp(1000) == 44 and player.hp() == 44, "healing clamps to max")
	player.set_base_toughness(3)
	_check(player.hp() == 36 and player.max_hp() == 36, "lower derived cap clamps current HP")
	player.change_hp(-9)
	npc.change_hp(-2)
	var npc_path := "user://growth_check_%s.resident" % fixture
	_rewrite(npc_path, npc.snapshot())
	var npc_copy := Stats.new()
	_check(npc_copy.restore(bytes_to_var(FileAccess.get_file_as_bytes(npc_path))) and npc_copy.hp() == 26 and npc_copy.max_hp() == 28 and player.hp() == 27, "test resident disk round trip uses the identical snapshot API")
	_check(DirAccess.remove_absolute(npc_path) == OK, "remove isolated resident fixture")

	var hud = session.hud
	var sheet = hud.actor_sheet
	_check(sheet._health.text.contains("27/36"), "HUD reads current and max")
	var dial: Rect2 = main.get_node("Dial").get_global_rect()
	_check(not sheet._tag.get_global_rect().intersects(dial), "HUD does not cover the field sundial")
	_key(KEY_F7)
	_check(hud.inventory_open and session.is_modal() and main.active_actor().locked and hud._attributes.has_focus(), "keyboard opens focused modal and locks movement")
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(hud._card.get_global_rect()), "sheet fits window")
	_check(hud._card.theme == null and hud.theme == preload("res://scripts/ui/parchment_theme.tres") and hud._card.has_node("Vellum"), "shared control theme with character-specific paper")
	_key(KEY_F5)
	_click(Vector2(root.size) / 2.0)
	_key(KEY_F)
	_click(Vector2(root.size) / 2.0, MOUSE_BUTTON_RIGHT)
	_check(attacks == 0 and state.inventory.size() == 2 and not FileAccess.file_exists(slot) and hud.inventory_open, "modal suppresses attack/use/save/inventory")
	_key(KEY_ESCAPE)
	_check(not hud.inventory_open and not main.active_actor().locked, "cancel returns field control")
	_pad(JOY_BUTTON_Y)
	_check(hud.inventory_open and hud._attributes.has_focus(), "gamepad opens and focuses attributes")
	_pad(JOY_BUTTON_B)
	_check(not hud.inventory_open, "gamepad cancel closes the unified panel")
	await _movement_checks(main, state)
	_check(not npc.record_practice(Stats.PRACTICE_ID) and npc.take_damage(5) == 5 and npc.damage_taken() == 0, "resident shares damage API but growth is off by default")
	_check(player.damage_taken() == 0, "raw HP edits and cap changes grant no toughness")
	var before_damage := player.snapshot()
	_key(KEY_F8)
	_check(player.hp() == 22 and player.damage_taken() == 5 and player.max_hp() == 40, "F8 deals controlled damage and cap gain does not heal")
	player.change_hp(-20)
	_check(player.take_damage(1000) == 2 and player.damage_taken() == 7 and player.take_damage(5) == 0 and player.damage_taken() == 7, "overkill only trains actual HP lost; zero HP grants no credit")
	player.restore(before_damage)
	_key(KEY_F8)
	var before_door := player.snapshot()
	if DisplayServer.get_name() != "headless":
		_click(sheet.launcher.get_global_rect().get_center())
		_check(hud.inventory_open and attacks == 0, "pointer launcher opens without firing attack")
		_click(hud._close.get_global_rect().get_center())
		_check(not hud.inventory_open and attacks == 0, "pointer close does not fire attack")
		main._trip()
		_check(not session.hud.visible and main.crossing, "HUD hides immediately at transition")
		_key(KEY_F7)
		_check(not hud.inventory_open, "transition suppresses attribute shortcut")
		for i in 240:
			if not main.crossing: break
			await physics_frame
		_check(main.indoors and not main.crossing and session.hud.visible, "actual iris reaches cabin and restores HUD")
	else:
		main.show_place(true, main.room_entry.global_position, true)
	_check(state.player_stats == player and player.snapshot() == before_door and sheet._health.text.contains("22/40"), "door preserves growth and HUD without awarding displacement")
	var structure: Node3D = main.building_structure()
	var foot: Vector3 = main.active_actor().global_position + Vector3(0.16, 0.0, 0.0)
	main.active_actor().global_position = foot
	_key(KEY_F5)
	_check(FileAccess.file_exists(slot), "F5 writes isolated slot")
	var data: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(slot))
	_check(data.version == State.BUILDING_VERSION and data.building_revision == structure.get_meta("building_revision") and data.position.is_equal_approx(structure.to_local(foot)), "indoor v3 writes revision and building-local feet alongside growth")
	player.change_hp(1000)
	player.record_loaded_stride(50.0, 3.0)
	_check(player.strength_bonus() > 0, "weighted metres convert to strength at threshold")
	_key(KEY_F9)
	_check(state.player_stats == player and player.snapshot() == before_door and sheet._health.text.contains("22/40") and main.active_actor().global_position.is_equal_approx(foot), "F9 restores local feet and both progress tracks without new credit")
	_key(KEY_F7)
	var attrs: RichTextLabel = hud._attributes
	_check(hud._total.text.contains("3.00 kg") and hud._stat_values[0].text == "22/40" and hud._stat_values[1].text == "+%d" % player.strength_bonus() and hud._stat_values[2].text == "4" and hud._stat_values[2].get_parent().tooltip_text.contains("0 / 5 实际掉血"), "panel reads restored load, gains and partial progress")
	await process_frame
	var rows: Array[Control] = []
	var page_inner: Rect2 = hud._card.get_global_rect().grow(-8 * hud._card.scale.x)
	for child in hud._card.get_children():
		if not child is Control or child.name == &"Vellum" or not child.visible or child.size == Vector2.ZERO: continue
		_check(page_inner.encloses(child.get_global_rect()), "paper bounds %s %s" % [child.name, child.get_global_rect()])
		for row in rows:
			_check(not row.get_global_rect().intersects(child.get_global_rect()), "overlap %s %s against %s %s" % [child.name, child.get_global_rect(), row.name, row.get_global_rect()])
		rows.append(child)
	var unenabled := 0
	var mana := 0
	for child in attrs.get_children():
		if child is Label:
			unenabled += int(child.text == "未启用")
			mana += int(child.text in ["法力", "未开放"])
		if child is Control:
			_check(attrs.get_global_rect().encloses(child.get_global_rect()), "attribute row fits")
	_check(unenabled == 3 and mana == 2, "three inactive attributes and a mana placeholder")
	_check(data.player_stats == before_door and data.player_stats.size() == 5, "display-only statuses do not enter the slot")
	_check(hud._attributes.has_focus(), "attributes retain focus on F7")
	_key(KEY_ESCAPE)
	_check(not hud.inventory_open and not main.active_actor().locked, "keyboard cancels panel")
	for i in 4: await physics_frame
	Input.action_press(&"walk_right")
	for i in 8: await physics_frame
	Input.action_release(&"walk_right")
	_check(player.load_metres() > before_door.load_metres, "indoor Walker continues training on the same actor")
	_key(KEY_F9)
	data.player_stats.load_metres = NAN
	_rewrite(slot, data)
	_check(not state.load_slot(slot).is_empty() and player.snapshot() == before_door, "invalid growth rejected without mutation")
	data.erase("building_revision")
	data.version = 2
	data.position = Vector3(99, 99, 99)
	data.player_stats = {"toughness": 3, "conditioning": 5, "hp": 27}
	_rewrite(slot, data)
	_key(KEY_F9)
	_check(player.hp() == 27 and player.growth_enabled and player.damage_taken() == 0 and player.load_metres() == 0 and main.active_actor().global_position.is_equal_approx(main.room_entry.global_position), "legacy indoor v2 restores HP and falls back to entry with zero new growth")
	data.erase("player_stats")
	data.version = 1
	_rewrite(slot, data)
	_check(state.load_slot(slot).is_empty() and player.hp() == 40 and player.practice_points() == 0 and state.location_id == "place.cabin", "v1 slot migrates to fresh full HP while preserving location")
	_check(DirAccess.remove_absolute(slot) == OK, "remove isolated slot")
	print("growth_checks: %d checks, %d failures" % [checks, failures])
	quit(int(failures != 0))
