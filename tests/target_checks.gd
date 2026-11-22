extends SceneTree
## Fixture-only rarity variants; don't add permanent definitions just for sorting tests.
const State := preload("res://scripts/foundation/world_state.gd")
const Target := preload("res://scripts/interaction/stack_target.gd")
const Choice := preload("res://scripts/interaction/target_choice.gd")
var failed := 0
var state := State.new()

func _initialize() -> void:
	call_deferred("_run")

func _pile(id: String, rarity: int, at: float) -> Target:
	var p := Target.new()
	p.instance_id = id
	p.definition = State.SAMPLE.duplicate()
	p.definition.rarity = rarity
	root.add_child(p)
	p.position = Vector3(at, 0, 0)
	return p

func _check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
		push_error(what)

func _run() -> void:
	var common := _pile("test.common", 1, 0.1)
	var rare := _pile("test.rare", 7, 0.3)
	var tied := _pile("test.a", 7, -0.3)
	var far := _pile("test.out_of_range", 99, Choice.REACH + 0.01)
	var empty := _pile("test.empty", 100, 0.01)
	state.take_stack(empty.instance_id, empty.definition.definition_id, 1)
	var invalid := _pile("test.invalid", 101, 0.0)
	invalid.valid_source = false
	var all := [common, rare, far, empty, invalid]
	_check(Choice.options(all, state, Vector3.ZERO) == [rare], "eligibility before rarity; rare before nearer common")
	all.append(tied)
	_check(Choice.options(all, state, Vector3.ZERO) == [tied], "equal rarity/distance: stable ID")
	all.reverse()
	_check(Choice.options(all, state, Vector3.ZERO) == [tied], "order independent")
	rare.position.x = 0.2
	_check(Choice.options(all, state, Vector3.ZERO) == [rare], "equal rarity: nearer before ID")
	_check(rare.take(state, Vector3(7, 0, 0), Choice.REACH) == 0, "revalidate distance at transfer")
	_check(rare.take(state, Vector3.ZERO, Choice.REACH) == 1 and rare.take(state, Vector3.ZERO, Choice.REACH) == 0, "one transfer per source")
	var box := _pile("test.box", 0, 0.2)
	box.is_pickup = false
	all.append(box)
	_check(Choice.options(all, state, Vector3.ZERO).size() == 2, "do not assign cross-kind priority")
	print("target_checks: ", failed, " failures")
	quit(int(failed != 0))
