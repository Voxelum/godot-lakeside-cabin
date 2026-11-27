extends SceneTree
## Offline only. Validate and pack all selected pairs before replacing any file.
const Shape := preload("res://source/building_structure.gd")
const Baker := preload("res://source/building_baker.gd")
const DIR := "res://world/interiors/structures/"
const STEMS := {
	"cabin": "Cottage", "lime_house": "LimeHouse", "orchard_house": "OrchardHouse",
	"hay_barn": "HayBarn", "smith_stock": "SmithStock", "copper_loft": "CopperLoft",
	"sill_house": "SillHouse", "bakery": "Bakery",
	"guild": "Guild", "inn": "Inn", "tavern": "Tavern", "general_store": "GeneralStore",
}

func recipes() -> Array:
	return STEMS.keys()

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var projects := recipes()
	for arg in args:
		if arg.begins_with("--only="):
			var id := arg.trim_prefix("--only=")
			if not id in projects:
				_fail("Unknown building recipe: " + id)
				return
			projects = [id]
	var outputs := {}
	for id: String in projects:
		var path := DIR + id + ".json"
		var input: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not input is Dictionary or input.get("room_id") != "place." + id:
			_fail("Invalid building JSON or room ID: " + path)
			return
		var shape := Shape.new()
		var error := shape.configure(input)
		if not error.is_empty():
			_fail(id + ": " + error)
			return
		for outside in [true, false]:
			var target: String = DIR + STEMS[id] + ("Exterior.scn" if outside else "Structure.scn")
			if FileAccess.file_exists(target) and not "--replace" in args:
				_fail("Refusing to overwrite %s without --replace" % target)
				return
			var node := Baker.make(shape, outside)
			var scene := PackedScene.new()
			var result := scene.pack(node)
			node.free()
			if result != OK:
				_fail(error_string(result))
				return
			outputs[target] = scene
	for path in outputs:
		var result := ResourceSaver.save(outputs[path], path, ResourceSaver.FLAG_COMPRESS)
		if result != OK:
			_fail("%s: %s; rebake the pair before playing" % [path, error_string(result)])
			return
		print(path)
	quit()

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
