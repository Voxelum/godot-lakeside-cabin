extends SceneTree
## Native F5 viewport crops: rows = sword then spear, facing +Z/+X/-Z;
## columns = loaded / contact / follow-through / recovery. No camera override.
const MAIN := preload("res://Main.tscn")
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or out.is_empty() or FileAccess.file_exists(out):
		quit(2)
		return
	var main = MAIN.instantiate()
	var uid := Crypto.new().generate_random_bytes(8).hex_encode()
	main.get_node("Session").slot_path = "user://weapon_%s.slot" % uid
	main.get_node("BindingPanel").settings_path = "user://weapon_%s.cfg" % uid
	root.add_child(main)
	for i in 12: await physics_frame
	var actor = main.field_actor
	actor.set_physics_process(false)
	var driver = actor.combat
	var sheet := Image.create_empty(4*72, 6*72, false, Image.FORMAT_RGB8)
	var row := 0
	for item in [&"sword", &"spear"]:
		for face in [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD]:
			driver.reset()
			driver.weapon = item
			driver.drawn = true
			driver.face(face)
			driver.attack()
			var prev := 0.0
			var col := 0
			for phase: float in [.28, driver.Motion.CONTACT[driver.action], .72, .90]:
				driver.tick((phase-prev)*float(driver.Motion.DURATIONS[driver.action]))
				prev = phase
				for i in 2: await RenderingServer.frame_post_draw
				var frame: Image = main.field.get_texture().get_image()
				frame.convert(Image.FORMAT_RGB8)
				var center: Vector2 = main.orbit.unproject_position(actor.global_position + Vector3.UP*.9)
				sheet.blit_rect(frame,Rect2i(Vector2i(center)-Vector2i(36,36),Vector2i(72,72)),Vector2i(col*72,row*72))
				col += 1
			row += 1
	print("weapon frames: ", main.field.size, " -> ", out)
	quit(int(sheet.save_png(out) != OK))
