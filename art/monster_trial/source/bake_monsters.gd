extends SceneTree
## godot --headless --path . --script res://art/monster_trial/source/bake_monsters.gd
## Add -- --replace only when intentionally replacing all three generated scenes.

const ROOT := "res://art/monster_trial/"
const BUILDERS := {
	"Slime": preload("res://art/monster_trial/source/slime_model.gd"),
	"Goblin": preload("res://art/monster_trial/source/goblin_model.gd"),
	"Wolf": preload("res://art/monster_trial/source/wolf_model.gd"),
}

func _initialize() -> void:
	call_deferred("_bake")

func _bake() -> void:
	if not OS.get_cmdline_user_args().has("--replace"):
		for label: String in BUILDERS:
			if FileAccess.file_exists(ROOT + label + ".tscn"):
				printerr("Existing scene; stopped before writing any file: ", label)
				quit(2)
				return
	for label: String in BUILDERS:
		var scene: PackedScene = BUILDERS[label].new().build()
		var path := ROOT + label + ".tscn"
		if scene == null or ResourceSaver.save(scene, path) != OK:
			printerr("Could not bake ", path)
			quit(1)
			return
		print("BAKED ", path)
	quit()
