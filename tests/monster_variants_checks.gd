extends "res://tests/farm_checks.gd"
## The original art-only resource tests are independent of the map. The F5
## presentation regression now walks to the actual park (not obsolete shoulders).
var photos: Array[Image] = []
var matte := StandardMaterial3D.new()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--assets-only" in args:
		_check_independent_assets()
		print("monster assets: %d/%d independent scenes, meshes, poses and prop overrides"%[checks-failures,checks])
		quit(int(failures!=0)); return
	var out := ""
	var previous_sha := ""
	for arg in args:
		if arg.begins_with("--sheet="): out=arg.trim_prefix("--sheet=")
		if arg.begins_with("--previous-sha256="): previous_sha=arg.trim_prefix("--previous-sha256=").to_lower()
	if (not out.is_empty() and FileAccess.file_exists(out) and (previous_sha.is_empty() or FileAccess.get_sha256(out)!=previous_sha)) or DisplayServer.get_name()=="headless":
		printerr("Use an actual window and a new --sheet=<path>. For headless art checks pass --assets-only."); quit(2); return
	if "--320" in args: size_px=Vector2i(320,180)
	var token := Crypto.new().generate_random_bytes(12).hex_encode()
	main=MAIN.instantiate(); s=main.get_node("Session"); slot="user://farm-photo-%s.slot"%token
	s.slot_path=slot; main.get_node("BindingPanel").settings_path="user://farm-photo-%s.cfg"%token
	root.add_child(main); root.mode=Window.MODE_WINDOWED; root.size=size_px*2
	player=main.field_actor; farm=s.farm
	var sun=main.field.get_node("Clearing/Almanac"); sun.hour=14.0; sun.halted=true; sun._advance_sky()
	matte.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; matte.albedo_color=Color.MAGENTA
	await frames(6)
	check(main.field.size==size_px,"native F5 resolution with default camera")
	_roster()
	for i in range(1,14):
		if not await walk(Survey.ROUTE[i]): check(false,"walk to village"); quit(1); return
	if not await walk(L.RECOVERY): check(false,"walk into park"); quit(1); return
	main.orbit.align_at_subject()
	photos.append(await _grab())
	for pen in farm.pens:
		var side := L.side(pen.entry.tier)
		var perch := Vector2(pen.gate.x+.66,pen.gate.y-side*.49)
		if not await walk(Vector2(perch.x,L.AISLE)) or not await walk(perch): check(false,"walk to sightline "+pen.entry.title); quit(1); return
		check(farm.opponent==null,"safe viewing verge "+pen.entry.title)
		main.orbit.align_at_subject(); main.orbit.set_process(false); farm.set_physics_process(false)
		for who: Fighter in pen.residents:
			if who.actor is Specimen:
				who.actor.set_display_pose(who.actor.signature(),.42+.04*who.coat)
			else:
				who.animator.play(&"attack"); who.animator.seek(who.animator.get_animation(&"attack").length*(.33+.045*who.coat),true)
		var real := await _grab()
		photos.append(real)
		for who: Fighter in pen.residents: await _silhouette(who,real)
		main.orbit.set_process(true); farm.set_physics_process(true)
	if not out.is_empty() and photos.size()==12 and failures==0:
		if FileAccess.file_exists(out) and (previous_sha.is_empty() or FileAccess.get_sha256(out)!=previous_sha):
			printerr("The previous sheet is not this run's known revision"); quit(2); return
		var page:=Image.create_empty(size_px.x*3,size_px.y*4,false,photos[0].get_format())
		for i in photos.size(): page.blit_rect(photos[i],Rect2i(Vector2i.ZERO,size_px),Vector2i(i%3*size_px.x,floori(i/3.0)*size_px.y))
		check(page.save_png(out)==OK,"native park contact sheet saved")
	check(photos.size()==12 and not FileAccess.file_exists(slot) and unsupported==0,"all eleven live pens + entrance, continuously reached")
	print("Farm folio ",size_px,": ",checks-failures,"/",checks,"; ",out)
	quit(int(failures!=0))

func _grab() -> Image:
	for i in 2:
		await process_frame
		await RenderingServer.frame_post_draw
	return main.field.get_texture().get_image()

func _silhouette(who: Fighter, real: Image) -> void:
	var model := who.model
	model.hide(); var bg:=await _grab(); model.show()
	var parts := model.find_children("*","MeshInstance3D",true,false)
	var overrides: Array[Material]=[]
	for part: MeshInstance3D in parts:
		overrides.append(part.material_override); part.material_override=matte
	var mask:=await _grab()
	for j in parts.size(): parts[j].material_override=overrides[j]
	var visible_pixels:=0; var contrasted:=0; var region:=Rect2i()
	for y in mask.get_height():
		for x in mask.get_width():
			var c:=mask.get_pixel(x,y)
			if c.r<.93 or c.g>.10 or c.b<.93: continue
			var p:=Vector2i(x,y)
			region=Rect2i(p,Vector2i.ONE) if visible_pixels==0 else region.merge(Rect2i(p,Vector2i.ONE))
			visible_pixels+=1
			var diff:=real.get_pixel(x,y)-bg.get_pixel(x,y)
			contrasted+=int(maxf(absf(diff.r),maxf(absf(diff.g),absf(diff.b)))>=.085)
	var share:=float(contrasted)/maxi(1,visible_pixels)
	print("  %s · %d native px · %.0f%% contrast"%[who.actor.name,visible_pixels,share*100.])
	check(visible_pixels>=40 and region.size.x>=7 and region.size.y>=6 and Rect2i(Vector2i(2,2),size_px-Vector2i(4,4)).encloses(region) and share>=.50,"readable 3D silhouette: "+who.display_name)

func _check_independent_assets() -> void:
	var scenes := ["Slime","Goblin","Wolf","GiantRat","Skeleton","RootMaw","Orc","Zombie"]
	for species in scenes.size():
		var packed := load("res://art/monster_variants/%s.tscn"%scenes[species]) as PackedScene
		for variant in 3:
			var unit := packed.instantiate() as Specimen
			unit.variant = variant
			var held := species in [1,4,6,7]
			if held: unit.weapon = [3,5,8][variant] # spear, axe and sickle
			root.add_child(unit)
			var meshes := unit.model.find_children("*","MeshInstance3D",true,false)
			var volume := false
			for part: MeshInstance3D in meshes:
				var size := part.get_aabb().size
				volume = volume or minf(size.x,minf(size.y,size.z))>.02
			var valid := meshes.size()>=2 and volume and unit.model.find_children("*","SpriteBase3D",true,false).is_empty() and unit.species==species and is_instance_valid(unit.solid)
			valid = valid and unit.set_display_pose(unit.signature(),.37) and not unit.set_display_pose(&"bogus",.4)
			if held: valid = valid and unit.main_grip.has_node("DisplayProp")
			check(valid,"standalone %s/%d geometry, collision, pose and prop selection"%[scenes[species],variant])
			unit.free()
