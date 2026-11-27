extends SceneTree
## Windowed Godot integration checks. Each chain has a separate slot. Run
## door-write then door-read in different processes with the same --run=<GUID>.
const MAIN := preload("res://Main.tscn")
const State := preload("res://scripts/foundation/world_state.gd")
var main
var session
var state: State
var slot: String
var mode := "regions"
var failed := 0
var attacks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error("play_checks / %s: %s" % [mode, label])

func _run() -> void:
	var token := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): mode = arg.trim_prefix("--case=")
		if arg.begins_with("--run="): token = arg.trim_prefix("--run=")
	if mode in ["regions", "table-menu"] and token.is_empty(): token = Crypto.new().generate_random_bytes(16).hex_encode()
	if mode not in ["regions", "door-write", "door-read", "table-menu"] or token.length() != 32 or not token.is_valid_hex_number(false):
		printerr("Expected --case=regions|table-menu|door-write|door-read --run=<32 hex digits> after --")
		quit(2); return
	if mode in ["door-write", "table-menu"] and DisplayServer.get_name() == "headless":
		printerr("Door proof needs a real render loop for the iris."); quit(2); return
	slot = "user://play_check_%s.slot" % token
	if FileAccess.file_exists(slot) != (mode == "door-read"):
		printerr("Use a fresh run ID for write; read needs the preceding writer's slot."); quit(2); return
	main = MAIN.instantiate()
	session = main.get_node("Session")
	session.slot_path = slot
	main.get_node("BindingPanel").settings_path = "user://play_check_%s.cfg" % token
	session.attack_requested.connect(func() -> void: attacks += 1)
	root.add_child(main)
	state = session.state
	await _ticks(4)
	match mode:
		"door-write": await _door_write()
		"door-read": _door_read()
		"regions": await _regions()
		"table-menu": await _table_menu()
	if (mode != "door-write" or failed != 0) and FileAccess.file_exists(slot):
		_check(DirAccess.remove_absolute(slot) == OK, "remove own test slot")
	print("play_checks / %s: %d failures" % [mode, failed])
	quit(int(failed != 0))

func _ticks(n: int) -> void:
	for i in n: await physics_frame

func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code; e.physical_keycode = code; e.pressed = pressed
		Input.parse_input_event(e); Input.flush_buffered_events()

func _mouse(button: MouseButton) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = Vector2(root.size) * 0.5; e.global_position = e.position
		e.button_index = button; e.pressed = pressed
		Input.parse_input_event(e); Input.flush_buffered_events()

func _steer(direction: Vector3) -> void:
	# Drive the actual camera-relative Walker through the baked collisions, never teleport it.
	var right: Vector3 = main.active_actor().get_viewport().get_camera_3d().global_basis.x.slide(Vector3.UP).normalized()
	var axis := Vector2(direction.dot(right), direction.dot(right.cross(Vector3.UP)))
	var amounts := [-axis.x, axis.x, -axis.y, axis.y]
	var actions := [&"walk_left", &"walk_right", &"walk_up", &"walk_down"]
	for i in actions.size():
		if amounts[i] > 0.001: Input.action_press(actions[i], amounts[i])
		else: Input.action_release(actions[i])

func _cross() -> bool:
	var inside: bool = main.indoors
	var door: Marker3D = main.room_door if inside else main.field_door
	var actor: CharacterBody3D = main.active_actor()
	var beyond := door.global_position + Vector3.BACK * (0.4 if inside else -0.4)
	for i in 280:
		if main.crossing: break
		_steer((beyond - actor.global_position).slide(Vector3.UP).normalized())
		await physics_frame
	if not main.crossing:
		_check(false, "did not walk across door plane: %s vs %s" % [actor.global_position, door.global_position]); return false
	var phases := {}
	var old_bag := state.inventory.duplicate()
	var digest := FileAccess.get_sha256(slot) if FileAccess.file_exists(slot) else ""
	var old_attacks := attacks
	var previous := ""
	var source: Vector3; var guest: Vector3
	var locked := true
	for i in 400:
		if not main.crossing: break
		var phase: String = main.shutter_phase
		locked = locked and main.field_actor.locked and main.room_actor.locked and not session.hud.visible
		if phase == previous:
			locked = locked and source == main.field_actor.global_position and guest == main.room_actor.global_position
		if not phases.has(phase):
			phases[phase] = true
			_key(KEY_F); _mouse(MOUSE_BUTTON_LEFT)
			for code in [KEY_TAB, KEY_F2, KEY_F5, KEY_F6, KEY_F9]: _key(code)
		source = main.field_actor.global_position; guest = main.room_actor.global_position; previous = phase
		await process_frame
	_check(phases.has_all(["close", "black_source", "black_destination", "open"]), "rendered phases: %s" % phases)
	_check(locked and not main.crossing and main.indoors != inside, "both actors stay locked during iris")
	_check(not session.is_modal() and old_bag == state.inventory and state.simulated_until == 0 and old_attacks == attacks, "iris discarded gameplay/UI inputs")
	_check((FileAccess.get_sha256(slot) if FileAccess.file_exists(slot) else "") == digest, "no explicit or implicit disk write during door")
	var at: Vector3 = main.active_actor().global_position
	await _ticks(4)
	_check((at - main.active_actor().global_position).slide(Vector3.UP).length() < 0.001 and not main.crossing, "held input cannot reverse door")
	_steer(Vector3.ZERO); await _ticks(3)
	return main.indoors != inside and not main.crossing

func _count() -> int:
	return state.inventory.get(State.SAMPLE.definition_id, 0)

func _door_write() -> void:
	_check(_count() == 0 and not main.indoors, "new game starts outdoors with no stones")
	# Fixture only: temporarily give the slightly farther overlapping source a
	# rarer copy. The shipped map and every inventory stack still use one definition.
	var rare = main.get_node("Pixels/Clearing/AmberB")
	rare.definition = State.SAMPLE.duplicate()
	rare.definition.rarity += 1
	_key(KEY_F)
	_check(_count() == 1 and rare.amount(state) == 0 and not rare.visible, "actual use picks only the rarer source")
	rare.definition = State.SAMPLE
	if not await _cross(): return
	_key(KEY_F); _key(KEY_F)
	_check(_count() == 4 and state.remaining("cabin.entry_chest", 3) == 0, "Guest takes whole chest once only")
	if not await _cross(): return
	_check(_count() == 4 and main.active_actor() == main.field_actor, "Traveler sees same pack")
	if not await _cross(): return
	_check(not FileAccess.file_exists(slot), "three crossings did not save")
	_key(KEY_F)
	_check(_count() == 4 and main.get_node("RoomPixels/Interior/EntryChest/LidHinge").rotation.x < -1.0, "empty on return, lid open")
	# A restored position must not simply be the standard door arrival.
	_steer(Vector3.FORWARD); await _ticks(13)
	_steer(Vector3.ZERO); await _ticks(3)
	_check((main.room_actor.global_position - main.room_entry.global_position).slide(Vector3.UP).length() > 0.25, "save away from entry")
	_key(KEY_TAB)
	var card: Panel = session.hud.get_node("InventoryOverlay/Parchment")
	var entries: ItemList = card.get_node("Items")
	for i in entries.item_count:
		if entries.get_item_text(i).begins_with("长枪"):
			entries.select(i)
			entries.item_selected.emit(i)
	_click(card.get_node("EquipmentAction"))
	_key(KEY_TAB)
	_key(KEY_F5)
	_check(FileAccess.file_exists(slot), "explicit F5 saved")
	await _ticks(3) # Let the post-menu held-input gate observe neutral movement.
	if not await _cross(): return
	_key(KEY_F9)
	_door_read()

func _door_read() -> void:
	_check(main.indoors and main.active_actor() == main.room_actor and state.location_id == "place.cabin", "restore active indoor place")
	var disk := State.new()
	_check(disk.load_slot(slot).is_empty() and main.room_actor.global_position.distance_to(disk.position) < 0.03 and (disk.position - main.room_entry.global_position).slide(Vector3.UP).length() > 0.25, "restore saved feet, not the default entry")
	_check(disk.loaded_building_revision.length() == 64 and state.equipment == {"main_hand": "item.spear"} and not state.inventory.has("item.spear") and main.room_actor.combat.weapon == &"spear" and not main.room_actor.combat.drawn, "indoor revision and undrawn equipment restore without duplicate")
	_check(_count() == 4 and state.remaining("bank.sample_b", 1) == 0 and state.remaining("cabin.entry_chest", 3) == 0, "restore stack and depleted sources")
	_key(KEY_F)
	_check(_count() == 4 and not main.crossing, "restored box refuses second transfer without cutscene")

func _walk_region(dest: String) -> bool:
	# F9 intentionally has the same held-input gate as a door: issue a neutral
	# physics sample before this *new* walk, not a held stick during restore.
	_steer(Vector3.ZERO); await _ticks(2)
	var actor: CharacterBody3D = main.active_actor()
	var prev := actor.global_position
	var continuous := true
	_steer(Vector3.FORWARD if dest == State.RISE else Vector3.BACK)
	for i in 180:
		await physics_frame
		continuous = continuous and main.active_actor() == actor and not actor.locked and not main.crossing and prev.distance_to(actor.global_position) < 0.16
		prev = actor.global_position
		if session.region_view.region_id == dest: break
	_steer(Vector3.ZERO); await _ticks(2)
	_check(continuous and session.region_view.region_id == dest, "continuous walk to " + dest)
	return session.region_view.region_id == dest

func _rise_shows_stock() -> bool:
	var view: Node3D = session.region_view
	var label: Label = view.get_node("Tag/Stock")
	return view.get_world_3d() == main.field_actor.get_world_3d() and view.global_position == session.rise_anchor.global_position and view.get_node("Sample").is_visible_in_tree() and label.text.contains("库存 1  |  t=1") and Rect2(Vector2.ZERO, Vector2(main.field.size)).encloses(label.get_global_rect())

func _regions() -> void:
	_check(session.region_layer.get_child_count() == 1 and session.region_view.region_id == State.BANK and state.stock(State.RISE) == 0, "no rise presentation at start")
	_key(KEY_2); _key(KEY_3)
	_check(state.simulated_until == 0, "lighting has no world-time side effects")
	_key(KEY_F6); _key(KEY_F6)
	_check(session.region_view.region_id == State.BANK and state.stock(State.BANK) == 11 and state.stock(State.RISE) == 1 and state.simulated_until == 1, "one offscreen delivery")
	_key(KEY_F5)
	for i in 2:
		if not await _walk_region(State.RISE): return
		_check(session.region_layer.get_child_count() == 1 and _rise_shows_stock(), "newly mounted rise reads result")
		var old: WeakRef = weakref(session.region_view)
		if not await _walk_region(State.BANK): return
		await process_frame
		_check(old.get_ref() == null and state.stock(State.RISE) == 1, "destination view freed without altering authority")
	if not await _walk_region(State.RISE): return
	_key(KEY_F9); _key(KEY_F6)
	_check(session.region_view.region_id == State.BANK and state.simulated_until == 1, "load bank, replay same interval")
	if not await _walk_region(State.RISE): return
	_check(state.stock(State.RISE) == 1 and _rise_shows_stock(), "re-entry after load did not reseed or reapply")

func _click(control: Control) -> void:
	var pos := control.get_global_rect().get_center()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
		event.position = pos; event.global_position = pos
		Input.parse_input_event(event); Input.flush_buffered_events()

func _table_menu() -> void:
	var book = session.book
	var tip: Panel = session.hud.get_node("PickupTip")
	var tag_before := tip.get_global_rect().get_center()
	var feet_before: Vector3 = main.field_actor.global_position
	_mouse(MOUSE_BUTTON_WHEEL_UP); await _ticks(6)
	_check(tip.is_visible_in_tree() and tip.get_global_rect().get_center().distance_to(tag_before) > 0.5 and feet_before.distance_to(main.field_actor.global_position) < 0.04, "pickup tag follows zoom while Walker stands still")
	_mouse(MOUSE_BUTTON_WHEEL_DOWN)
	# Real mouse events on the menu tab must not also issue a left-button attack.
	_click(book.launcher)
	_check(book.opened and book._load.disabled and attacks == 0, "clickable settings tab; empty slot disables load")
	_click(book._back)
	await _ticks(3)
	if not await _cross(): return
	var chest = main.get_node("RoomPixels/Interior/EntryChest")
	_check(chest.get_node("LidHinge").rotation.x < -1.0 and _count() == 0, "near box opens without looting")
	var actor: CharacterBody3D = main.room_actor
	var aisle := Vector3(-1.30, 0, -0.60)
	for i in 140:
		var toward := (aisle - actor.global_position).slide(Vector3.UP)
		if toward.length() < 0.035: break
		_steer(toward.normalized()); await physics_frame
	_steer(Vector3.ZERO); await _ticks(4)
	_check((actor.global_position - aisle).slide(Vector3.UP).length() < 0.1, "walk from doorway to the dining table: %s" % actor.global_position)
	_check(chest.get_node("LidHinge").rotation.x > -0.01, "walking away recloses unlooted chest")
	var tip_text: String = tip.get_child(0).text
	_check(tip.is_visible_in_tree() and tip_text.begins_with("◆ 茶杯") and tip_text.contains("面包"), "rendered table tag lists both real items: " + tip_text)
	var cup = main.get_node("RoomPixels/Interior/Dining/Tabletop/CabinSetting/CupPickup")
	var bread = main.get_node("RoomPixels/Interior/Dining/Tabletop/CabinSetting/BreadPickup")
	_key(KEY_F)
	_check(not cup.visible and is_instance_valid(cup._flight) and state.inventory == {"item.cup": 1, "item.sword": 1, "item.spear": 1}, "first actual use sends cup flying, owns it immediately")
	if is_instance_valid(cup._flight):
		var start: Vector3 = cup._flight.global_position
		var torso := actor.to_global(Vector3(0, 1.05, 0))
		await _ticks(5)
		_check(is_instance_valid(cup._flight) and cup._flight.global_position.y > start.y and cup._flight.global_position.distance_to(torso) < start.distance_to(torso), "the visible cup lifts off the table and approaches the torso")
	_key(KEY_ESCAPE)
	_check(book.opened and actor.locked and not tip.is_visible_in_tree(), "book locks player and hides anchored tag")
	_click(book._save)
	_check(FileAccess.file_exists(slot) and not book._load.disabled, "save while first pickup is in flight")
	_click(book._back); _key(KEY_F)
	_check(not bread.visible and is_instance_valid(bread._flight) and not tip.is_visible_in_tree() and state.inventory.size() == 4, "next use picks bread; exhausted table has no tag")
	_key(KEY_TAB)
	var items: ItemList = session.hud.get_node("InventoryOverlay/Parchment/Items")
	_check(items.item_count == 4 and items.get_item_icon(0) != items.get_item_icon(1), "two distinct inventory icons")
	_key(KEY_ESCAPE); _key(KEY_ESCAPE)
	_click(book._load)
	_check(state.inventory.size() == 4 and book.opened, "load awaits confirmation")
	_click(book._load)
	_check(not book.opened and not is_instance_valid(bread._flight) and bread.visible and not cup.visible and state.inventory == {"item.cup": 1, "item.sword": 1, "item.spear": 1}, "load restores just cup; no ghost or double delivery")
	_check(tip.is_visible_in_tree() and tip.get_child(0).text.contains("面包") and not tip.get_child(0).text.contains("茶杯"), "restored paper tag matches authority")
	# A confirmed click is required before replacing a slot. A bad read is
	# reported inside the open book without changing the live table or bag.
	_key(KEY_F); _key(KEY_ESCAPE)
	var before := FileAccess.get_sha256(slot)
	_click(book._save); _key(KEY_ESCAPE)
	_check(book.opened and book._confirm.is_empty() and FileAccess.get_sha256(slot) == before, "cancel overwrite keeps previous slot")
	_click(book._save); _click(book._save)
	var disk := State.new()
	_check(disk.load_slot(slot).is_empty() and disk.inventory == state.inventory and disk.inventory.size() == 4, "confirmed overwrite saved both items")
	var bad := FileAccess.open(slot, FileAccess.WRITE)
	bad.close() # empty, isolated test file (not the player's slot)
	_click(book._load); _click(book._load)
	_check(book.opened and actor.locked and not book._status.text.is_empty() and state.inventory.size() == 4 and not bread.visible, "bad read stays in book and leaves live state intact")
