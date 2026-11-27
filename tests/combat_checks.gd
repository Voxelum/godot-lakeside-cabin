extends SceneTree

const Main := preload("res://Main.tscn")
const Bindings := preload("res://scripts/controls/binding_store.gd")
var main
var session
var player
var driver
var failures := 0
var use_calls := 0
var center: Vector2

func _initialize() -> void:
	call_deferred(&"_run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	send(event)

func tap(code: Key) -> void:
	key(code, true)
	key(code, false)

func pad(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	send(event)

func tap_pad(button: JoyButton) -> void:
	pad(button, true)
	pad(button, false)

func click(control: Control) -> void:
	var previous := center
	center = control.get_global_rect().get_center()
	attack()
	center = previous

func mouse(button: MouseButton, pressed: bool, ctrl := false) -> void:
	var event := InputEventMouseButton.new()
	event.position = center
	event.global_position = center
	event.button_index = button
	event.pressed = pressed
	event.ctrl_pressed = ctrl
	send(event)

func attack() -> void:
	mouse(MOUSE_BUTTON_LEFT, true)
	mouse(MOUSE_BUTTON_LEFT, false)

func ticks(n: int) -> void:
	for i in n: await physics_frame

func _run() -> void:
	var id := Crypto.new().generate_random_bytes(12).hex_encode()
	var save := "user://combat_%s.slot" % id
	var config := "user://combat_%s.cfg" % id
	main = Main.instantiate()
	session = main.get_node("Session")
	session.slot_path = save
	main.get_node("BindingPanel").settings_path = config
	root.add_child(main)
	root.size = Vector2i(320, 180) if "--320" in OS.get_cmdline_user_args() else Vector2i(480, 270)
	await ticks(4)
	center = main.get_node("Screen").get_rect().get_center()
	player = main.field_actor
	driver = player.combat
	var target: Node
	for enemy in get_nodes_in_group(&"prototype_combat_target"):
		if enemy.get_script() == preload("res://scripts/foundation/field_combat.gd") and enemy.view.look == 1: target = enemy
	# Isolated rig fixture for the original passive-target adapter contract. The
	# real farm flower is now hostile, armored and cannot be hit outside its pen.
	var dummy := preload("res://art/field_cast/RootMaw.tscn").instantiate()
	main.field.get_node("Clearing").add_child(dummy)
	var plant := preload("res://scripts/foundation/field_combat.gd").new()
	plant.install(dummy,dummy.get_node("Model"),preload("res://scripts/foundation/actor_stats.gd").new(),true)
	check(target != null and plant != null, "F5 humanoid and the original isolated non-humanoid adapter are available")
	if target == null or plant == null:
		quit(1); return
	# Move test actors to accessible, deterministic separations on the F5 map.
	var start: Vector3 = player.global_position
	var front := Vector3.RIGHT
	target.actor.global_position = start + front * .98
	plant.actor.global_position = start - front * .98
	driver.face(front)
	await ticks(3)
	attack()
	check(driver.action == &"jab", "stowed weapon routes left to unarmed")
	await ticks(14)
	check(target.stats.hp() == 35 and target.action == &"hurt", "one real humanoid HP hit with shared action")
	check(absf(target.view.rotation.x) > .02, "humanoid visual adapter samples hurt motion")
	check(plant.stats.hp() == 40, "one directional hit; excludes target behind")
	await ticks(32)
	check(target.stats.hp() == 35, "strike cannot deal repeated damage in recovery")
	tap(KEY_R)
	check(driver.action == &"idle" and driver.weapon.is_empty(), "R cannot draw from empty main hand")
	var kg: float = session.state.inventory_weight_kg()
	check(not session.state.equip("off_hand", "item.sword"), "wrong slot rejected")
	tap(KEY_TAB)
	var card: Panel = session.hud.get_node("InventoryOverlay/Parchment")
	var items: ItemList = card.get_node("Items")
	check(items.item_count == 2 and items.has_focus(), "starter weapons in focused bag")
	tap_pad(JOY_BUTTON_DPAD_DOWN)
	tap_pad(JOY_BUTTON_A)
	check(session.state.equipment.get("main_hand") == "item.sword" and not driver.drawn and is_equal_approx(kg, session.state.inventory_weight_kg()), "equip moves one item and preserves carried weight without drawing")
	tap(KEY_TAB)
	tap(KEY_R)
	await ticks(27)
	check(driver.drawn and driver.weapon == &"sword", "R draws equipped sword")
	driver.face(front)
	attack()
	check(driver.action == &"slash", "drawn sword maps to slash")
	await ticks(40)
	check(target.stats.hp() == 26, "sword damage reaches ActorStats")
	tap(KEY_R)
	await ticks(27)
	tap(KEY_Q)
	check(driver.weapon == &"sword", "Q no longer switches weapons")
	tap(KEY_TAB)
	check(session.hud._slot_buttons.size() == 9 and items.visible and session.hud._attributes.visible, "unified panel shows all nine slots, bag and attributes together")
	tap_pad(JOY_BUTTON_DPAD_RIGHT)
	check(session.hud._attributes.has_focus(), "D-pad moves from bag to attributes")
	tap_pad(JOY_BUTTON_DPAD_LEFT)
	check(items.has_focus(), "D-pad returns to the bag")
	tap_pad(JOY_BUTTON_DPAD_LEFT)
	check(card.get_node("Slot_main_hand").has_focus(), "D-pad moves from bag to paper doll")
	tap_pad(JOY_BUTTON_A)
	check(driver.weapon.is_empty() and session.state.inventory.get("item.sword") == 1, "unloading returns weapon to bag")
	click(card.get_node("EquipmentAction"))
	check(driver.weapon == &"spear" and not driver.drawn, "equip spear from bag")
	tap(KEY_TAB)
	tap(KEY_R)
	await ticks(27)
	check(driver.drawn and driver.weapon == &"spear", "stow, select spear, redraw")
	driver.face(-front)
	attack()
	check(driver.action == &"thrust", "drawn spear maps to thrust")
	await ticks(27) # Spear contact is after the load, at 60% of the thrust.
	check(plant.stats.hp() == 29 and plant.action == &"hurt" and plant.view._jaw.rotation.x < -.15, "non-humanoid applies damage and jaw reaction through same interface")
	await ticks(25)
	target.set_guard(true)
	var before_target: int = target.stats.hp()
	check(target.receive_damage(9, target.forward) == 3 and target.stats.hp() == before_target - 3 and target.action == &"guard", "NPC shares frontal guard and actual damage")
	target.set_guard(false)
	mouse(MOUSE_BUTTON_RIGHT, true)
	check(driver.action == &"guard", "right hold guards")
	tap(KEY_F8)
	var stats = session.state.player_stats
	check(stats.hp() == 38 and stats.damage_taken() == 2, "defense reduces actual HP and toughness credits")
	mouse(MOUSE_BUTTON_RIGHT, false)
	check(driver.action == &"idle", "right release clears guard")
	tap(KEY_F8)
	check(stats.hp() == 33 and stats.damage_taken() == 7, "no guard takes full damage")
	await ticks(20)
	main.developer_camera = true
	key(KEY_CTRL, true)
	mouse(MOUSE_BUTTON_LEFT, true, true)
	check(main.orbit.dragging and driver.action == &"idle", "Ctrl+left enters camera but no strike/roll")
	key(KEY_CTRL, false)
	mouse(MOUSE_BUTTON_LEFT, false)
	check(not main.orbit.dragging and driver.action == &"idle", "camera chord release does not roll")
	driver.face(Vector3.BACK)
	var before_roll: Vector3 = player.global_position
	tap(KEY_CTRL)
	check(driver.action == &"roll", "standalone Ctrl release starts roll")
	await ticks(8)
	tap(KEY_F8)
	check(stats.hp() == 33 and player.global_position.distance_to(before_roll) > .2, "roll uses collision movement and damage immunity window")
	await ticks(25)
	session.set_dialogue_handler(func() -> bool:
		use_calls += 1
		session.set_dialogue_modal(true)
		return true)
	tap(KEY_F)
	check(use_calls == 1 and player.locked and session.is_modal(), "F starts dialogue first and locks actor")
	attack(); tap(KEY_CTRL); tap(KEY_R); tap(KEY_F); tap(KEY_TAB); tap(KEY_F5); tap(KEY_F8)
	check(use_calls == 1 and driver.action == &"idle" and driver.drawn and stats.hp() == 33 and not FileAccess.file_exists(save) and not session.hud.inventory_open, "dialogue blocks field shortcuts but not GUI routing")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	check(not session.handle_event(enter), "Enter is not consumed by field while dialogue is open")
	session.set_dialogue_modal(false)
	session.set_dialogue_handler(Callable())
	tap(KEY_F5)
	check(FileAccess.file_exists(save), "existing save works after dialogue")
	tap(KEY_F8); tap(KEY_F9)
	check(stats.hp() == 33 and driver.action == &"idle" and not driver.drawn, "load restores HP and cancels combat action")
	tap(KEY_F9)
	check(session.state.inventory == {"item.sword": 1} and session.state.equipment == {"main_hand": "item.spear"} and is_equal_approx(kg, session.state.inventory_weight_kg()), "repeated load does not duplicate or recount equipped weapon")
	main.show_place(true, main.room_entry.global_position, false)
	check(main.active_actor().combat.stats == stats and not main.active_actor().combat.drawn and main.active_actor().combat.weapon == &"spear", "Guest shares restored equipment; draw state is transient")
	var bindings := Bindings.snapshot()
	bindings[&"draw_weapon"][0] = Vector2i(1, KEY_G)
	check(Bindings.save_bindings(config, bindings) == OK and Bindings.load_bindings(config) == OK, "new actions save and reload through rebinding store")
	tap(KEY_R)
	check(main.active_actor().combat.action == &"idle", "old draw binding removed")
	tap(KEY_G)
	check(main.active_actor().combat.action == &"draw", "new draw binding used in field dispatcher")
	for file in [save, config]:
		if FileAccess.file_exists(file): DirAccess.remove_absolute(file)
	print("combat_checks %s %s: %d failures" % [main.field.size, DisplayServer.get_name(), failures])
	quit(int(failures != 0))
