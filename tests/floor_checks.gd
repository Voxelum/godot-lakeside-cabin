extends SceneTree
## Run with a window: godot --path . --script res://tests/floor_checks.gd
## Legacy cabin grain diagnostic kept for the original art asset. F5's baked
## slabs/material roles are now covered by building_roster_checks.gd.

var viewport: SubViewport

func _initialize() -> void:
	call_deferred("check")

func frame_image() -> Image:
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

# Reject extended dark edges; a speck needs at least seven brighter ring samples.
# Merge adjacent candidate pixels so a two-pixel speck is only counted once.
func spots(image: Image, mask: Image, region: Rect2i, threshold := 0.045) -> Vector2i:
	var candidates := {}
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var p := Vector2i(x, y)
			var surface := mask.get_pixelv(p)
			if surface.r < 0.8 and surface.g < 0.8:
				continue # occluding furniture, rug, walls and background
			var dark := image.get_pixelv(p).get_luminance()
			var brighter := 0
			for dy in [-2, 0, 2]:
				for dx in [-2, 0, 2]:
					if image.get_pixelv(p + Vector2i(dx, dy)).get_luminance() - dark > threshold:
						brighter += 1
			if brighter >= 7:
				candidates[p] = surface.g > 0.8
	var count := Vector2i.ZERO
	for seed in candidates.keys():
		if not candidates.has(seed):
			continue
		var touches_seam: bool = candidates[seed]
		candidates.erase(seed)
		var pending: Array[Vector2i] = [seed]
		while not pending.is_empty():
			var p: Vector2i = pending.pop_back()
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var next := p + Vector2i(dx, dy)
					if candidates.has(next):
						touches_seam = touches_seam or bool(candidates[next])
						candidates.erase(next)
						pending.push_back(next)
		if touches_seam:
			count.y += 1
		else:
			count.x += 1
	return count

func check() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Windowed renderer required; floor check skipped.")
		quit(2)
		return
	var main := (load("res://Main.tscn") as PackedScene).instantiate()
	var room_config := main.get_node("RoomPixels") as SubViewport
	var outdoor_config := main.get_node("Pixels") as SubViewport
	var config_ok: bool = room_config.msaa_3d == Viewport.MSAA_4X \
		and room_config.size == Vector2i(480, 270) \
		and outdoor_config.msaa_3d == Viewport.MSAA_DISABLED \
		and main.get_node("Screen").texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
	viewport = SubViewport.new()
	viewport.size = room_config.size
	var delivered_aa := room_config.msaa_3d
	main.free()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var preview := TextureRect.new()
	preview.texture = viewport.get_texture()
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.size = Vector2(960, 540)
	root.add_child(preview)
	var room := (load("res://world/interiors/CabinShell.tscn") as PackedScene).instantiate()
	var furnished := (load("res://world/Interior.tscn") as PackedScene).instantiate()
	for label in ["Hearth", "Textiles", "Pantry", "EntryChest", "Dining", "SouthChair", "NorthChair"]:
		var prop := furnished.get_node(label)
		prop.owner = null
		furnished.remove_child(prop)
		room.add_child(prop)
	# Recreate the legacy chest pose for a consistent desk-side diagnostic.
	room.get_node("EntryChest").position = Vector3(.02,.035,1.92)
	furnished.free()
	viewport.add_child(room)
	var floor := room.get_node("Floorboards")
	var backing := floor.get_node("SeamBacking") as MeshInstance3D
	var light := room.get_node("WarmKey") as DirectionalLight3D
	var rug := room.get_node("Textiles/Rug") as MeshInstance3D
	var camera := room.get_node("Camera") as Camera3D
	var walking := room.get_node("Architecture/WalkingSurfaceBody/Shape") as CollisionShape3D
	var boards := 0
	var grains: Array[MeshInstance3D] = []
	var board_top := -INF
	var board_by_suffix := {}
	var contained := true
	var old_light := flat(Color(0.678, 0.472, 0.318))
	var old_dark := flat(Color(0.566, 0.376, 0.25))
	for old in [old_light, old_dark]:
		old.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		old.roughness = 0.94
	for mesh in floor.get_children():
		if mesh.name.begins_with("Board_"):
			boards += 1
			board_by_suffix[String(mesh.name).trim_prefix("Board_")] = mesh
			board_top = maxf(board_top, mesh.position.y + mesh.mesh.size.y / 2.0)
		elif mesh.name.begins_with("Grain_"):
			grains.push_back(mesh)
	for mesh in grains:
		var parts := String(mesh.name).split("_")
		var board: MeshInstance3D = board_by_suffix[parts[1] + "_" + parts[2]]
		for axis in [Vector3.AXIS_X, Vector3.AXIS_Z]:
			contained = contained and (absf(mesh.position[axis] - board.position[axis])
				+ mesh.mesh.size[axis] / 2.0 <= board.mesh.size[axis] / 2.0)
	var recess: float = board_top - (backing.position.y + backing.mesh.size.y / 2.0)
	var fixed := await frame_image()
	viewport.msaa_3d = Viewport.MSAA_2X
	var aa2 := await frame_image()
	viewport.msaa_3d = delivered_aa
	var aa4 := await frame_image()
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	# Restore the pre-fix grain colors and widths in memory for the control.
	for mesh in grains:
		mesh.scale.x = 0.5
		mesh.material_override = old_dark if mesh.mesh.material.albedo_color.r < 0.66 else old_light
	var backing_only := await frame_image()
	backing.hide()
	var original := await frame_image()
	var casters := {}
	for mesh in floor.get_children():
		casters[mesh] = mesh.cast_shadow
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var no_floor_casting := await frame_image()
	for mesh in casters:
		mesh.cast_shadow = casters[mesh]
	var bias := light.shadow_normal_bias
	light.shadow_normal_bias = bias + 0.6
	var biased := await frame_image()
	light.shadow_normal_bias = bias
	for mesh in grains:
		mesh.hide()
	var no_grain := await frame_image()
	for mesh in room.get_node("Textiles").get_children():
		if mesh.name.begins_with("Tassel"):
			mesh.hide()
	for mesh in grains:
		mesh.show()
	var no_tassels := await frame_image()
	for mesh in room.get_node("Textiles").get_children():
		if mesh.name.begins_with("Tassel"):
			mesh.show()

	# Classify visible board vs gap centers independently of their lit color.
	# Occluders remain present, so furniture or rug pixels aren't counted as floor.
	var black := flat(Color.BLACK)
	var red := flat(Color.RED)
	var green := flat(Color.GREEN)
	backing.show()
	for mesh in room.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = black
		if mesh.get_parent() == floor:
			mesh.material_override = green if mesh == backing else red
	var mask := await frame_image()
	var total_before := Vector2i.ZERO
	var total_after := Vector2i.ZERO
	var severe := Vector4i.ZERO # original, local fix, 2x, delivered 4x
	var markers := {"dining side": Vector3(-2.25, 0, 0.75), "door lane": Vector3(-0.95, 0, 2.45),
		"rug edge": Vector3(0.37, 0, 1.6), "rug near tassels": Vector3(1.61, 0, 2.45)}
	print("Each pair = (board surface, seam). Columns: original, backing only, floor cast off, bias+0.6, grain hidden, tassels hidden, local fix (no AA)")
	for label in markers:
		var p := Vector2i(camera.unproject_position(markers[label]))
		var half := Vector2i(21, 8 if label == "rug near tassels" else 12)
		var region := Rect2i(p - half, 2 * half)
		var counts := []
		for frame in [original, backing_only, no_floor_casting, biased, no_grain, no_tassels, fixed]:
			counts.push_back(spots(frame, mask, region))
		print(label, " ", region, ": ", counts)
		for threshold in [0.045, 0.09]:
			var compare := []
			for frame in [original, fixed, aa2, aa4]:
				compare.push_back(spots(frame, mask, region, threshold))
			print("  contrast > ", threshold, " original / local fix no AA / 2x / 4x: ", compare)
			if threshold == 0.09:
				for i in range(4):
					severe[i] += compare[i].x + compare[i].y
		total_before += counts[0]
		total_after += counts[-1]
	print("boards=", boards, " grain=", grains.size(), " recess=", recess,
		" grain within boards=", contained, " light shadows=", light.shadow_enabled, " rug visible=", rug.visible,
		" walking collision enabled=", not walking.disabled, " spots ", total_before, " -> ", total_after)
	var ok := boards == 81 and grains.size() == 243 and is_equal_approx(recess, 0.002) \
		and contained and light.shadow_enabled and rug.visible and not walking.disabled \
		and total_after.x < total_before.x and total_after.y <= total_before.y
	print("Severe totals (original / local fix / 2x / delivered 4x): ", severe,
		" RoomPixels configuration matches: ", config_ok)
	ok = ok and config_ok and severe.w * 2 < severe.y and severe.w * 2 < severe.z
	quit(0 if ok else 1)
