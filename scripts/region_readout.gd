extends Node3D
## A tiny, disposable chunk presentation: no collisions, inventory, timer or writeback.
const State := preload("res://scripts/foundation/world_state.gd")
var region_id: String

func display(id: String, state: State) -> void:
	region_id = id
	var title := "湖岸" if id == State.BANK else "坡上"
	var quantity := state.stock(id)
	$Sample.visible = quantity > 0
	$Tag/Stock.text = "%s  ·  库存 %d  |  t=%d" % [title, quantity, state.simulated_until]
