extends SceneTree
## Run from the existing project. Rebuilds just these two native PackedScenes;
## by default an existing scene is never replaced.
const GiantRat := preload("res://art/content_batch/source/giant_rat.gd")
const SkeletonSentry := preload("res://art/content_batch/source/skeleton_sentry.gd")
const DEST := "res://art/content_batch/creatures/"

func _initialize() -> void:
	var jobs := {"GiantRat.tscn": GiantRat, "SkeletonSentry.tscn": SkeletonSentry}
	if not "--replace" in OS.get_cmdline_user_args():
		for name: String in jobs:
			if FileAccess.file_exists(DEST+name):
				printerr("Will not overwrite ", DEST+name, ". Only use --replace when discarding changes to the baked scenes is intended.")
				quit(2)
				return
	for name: String in jobs:
		var scene: PackedScene = jobs[name].new().build()
		if not scene or ResourceSaver.save(scene,DEST+name) != OK:
			printerr("Could not bake ",name)
			quit(1)
			return
		print("Baked ",DEST+name)
	quit()
