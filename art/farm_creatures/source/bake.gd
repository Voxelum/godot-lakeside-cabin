extends SceneTree
## Offline authoring command. Refuse accidental replacement of baked assets.
const Kit := preload("res://art/monster_trial/source/rig.gd")
const Look := preload("res://art/farm_creatures/look.gd")
const Species := {
	"Spider": preload("res://art/farm_creatures/source/spider.gd"),
	"Bee": preload("res://art/farm_creatures/source/bee.gd"),
	"Imp": preload("res://art/farm_creatures/source/imp.gd"),
}

func _initialize() -> void:
	for label: String in Species:
		var path := "res://art/farm_creatures/%s.tscn" % label
		if FileAccess.file_exists(path) and not "--replace" in OS.get_cmdline_user_args():
			printerr("Refusing to replace ",path)
			quit(2)
			return
		var k := Kit.new(label)
		var artist = Species[label].new()
		artist.build(k)
		k.root.set_script(Look)
		var scene := k.pack()
		if scene == null or ResourceSaver.save(scene,path)!=OK:
			printerr("Could not save ",path)
			quit(1)
			return
		print("Packed ",path)
		k.root.free()
	quit()
