extends SceneTree
## Godot --path . --script res://art/building_trial/review_checks.gd
## Optional -- --capture writes new native buffers to review/ (never overwrites).
const Preview = preload("res://art/building_trial/building_preview.gd")
const Site = preload("res://art/building_trial/trial_site.gd")
const Lot = preload("res://art/building_trial/building_lot.gd")
const Rules = preload("res://art/building_trial/lot_rules.gd")
const Scene = preload("res://art/building_trial/BuildingPreview.tscn")
const ACTIONS := [&"walk_left", &"walk_right", &"walk_up", &"walk_down"]
const REVIEW := "res://art/building_trial/review/"

var preview: Preview
var checks := 0
var failures := 0
var walked := 0
var images: Dictionary[String, Image] = {}

func _initialize() -> void:
	_run.call_deferred()

func _expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _plans() -> void:
	var parcel := Vector2(8,6)
	for kind in 4:
		var roof_set := {}
		var masses := {}
		var palettes := {}
		for seed in range(300,332):
			var a := Rules.resolve(kind,parcel,seed,0,0,0,0,0,0,0)
			var other := Rules.resolve(kind,parcel,seed,0,0,0,0,0,0,0)
			_expect(a == other and a.valid and a.roof in Rules.ROOFS[kind], "repeatable keyed plan %d/%d" % [kind,seed])
			roof_set[a.roof] = true
			masses[a.body] = true
			palettes[a.ink[0]] = true
		_expect(roof_set.size()==2 and masses.size()==2 and palettes.size()==3,"size, silhouette and paint vary independently for %d" % kind)
	var wrong := Rules.resolve(Rules.FARM,Vector2(5.5,4.24),45,1,Rules.GAMBREL,0,0,2,2,0)
	_expect(wrong.valid and wrong.body == Rules.BODIES[Rules.FARM][1] and wrong.roof in [Rules.SWEEP,Rules.HIP] and not wrong.wing and wrong.door != 2 and wrong.warnings.size()==4,"reject incompatible locked size/roof/wing/door without illegal combinations")
	var impossible := Rules.resolve(Rules.BARN,Vector2(2,2),1,0,0,0,0,0,0,0)
	_expect(not impossible.valid,"undersized plot rejects shell")
	var locked_a := Rules.resolve(Rules.BARN,parcel,3,1,Rules.GAMBREL,2,1,2,2,1)
	var locked_b := Rules.resolve(Rules.BARN,parcel,123,1,Rules.GAMBREL,2,1,2,2,1)
	_expect(locked_a == locked_b and locked_a.wing,"valid locks persist when appearance seed changes")

func _tick(n: int) -> void:
	for i in n:
		await physics_frame

func _stop() -> void:
	for key in ACTIONS:
		Input.action_release(key)

func _foot(p: Vector3) -> void:
	_stop()
	preview.actor.global_position = p + Vector3.UP*.039
	preview.actor.call(&"settle_input")
	await _tick(12)

func _walk(target: Vector3, tolerance: float, budget := 0) -> bool:
	var actor := preview.actor
	var right := preview.site.camera.global_basis.x.slide(Vector3.UP).normalized()
	var down := right.cross(Vector3.UP)
	var start := target - actor.global_position
	var frames := budget if budget > 0 else ceili(start.slide(Vector3.UP).length()*27.5)+27
	for i in frames:
		var d := (target - actor.global_position).slide(Vector3.UP)
		if d.length() <= tolerance:
			_stop()
			await _tick(2)
			return true
		var axis := Vector2(d.dot(right),d.dot(down)).normalized()
		var axes := [-axis.x,axis.x,-axis.y,axis.y]
		for k in ACTIONS.size():
			if axes[k]>0.0:
				Input.action_press(ACTIONS[k],axes[k])
			else:
				Input.action_release(ACTIONS[k])
		await physics_frame
	_stop()
	await _tick(2)
	return false

func _lane_point(p: Vector2) -> Vector3:
	return Vector3(p.x,0,p.y)

func _walk_site(site: Site) -> void:
	var lane := site.road()
	var p: Vector2 = lane[0].lerp(lane[1],.91)
	await _foot(_lane_point(p))
	for i in range(1,lane.size()-1):
		var ok := await _walk(_lane_point(lane[i]),.12)
		_expect(ok and preview.actor.is_on_floor(),"main lane segment %s/%d" % [site.name,i])
	if site.setting == 1:
		await _foot(_lane_point(Site.ALLEY[0]))
		for i in range(1,Site.ALLEY.size()):
			var ok := await _walk(_lane_point(Site.ALLEY[i]),.12)
			_expect(ok and preview.actor.is_on_floor(),"walk from town main street to rear court, section %d" % i)
	for lot in site.lots():
		var link := site.road_link(lot).global_position
		var approach := lot.marker("Approach")
		var landing := lot.marker("Landing")
		var door := lot.marker("DoorAnchor")
		_expect((link-door.global_position).slide(Vector3.UP).dot(door.global_basis.z) > .9, "%s faces its linked street" % lot.lot_id)
		await _foot(link)
		var got_path := await _walk(approach.global_position,.054)
		var got_landing := await _walk(landing.global_position,.043)
		var height := preview.actor.global_position.y - lot.global_position.y
		var on_ramp := absf(height-lot.threshold_rise) <= .028 and preview.actor.is_on_floor()
		_expect(got_path and got_landing and on_ramp,"%s actual Walker from route to landing (foot %.3f; target %.2f)" % [lot.lot_id,height,lot.threshold_rise])
		var crossed := await _walk(door.global_position-door.global_basis.z*.69,.09,32)
		var front := (preview.actor.global_position-door.global_position).dot(door.global_basis.z)
		_expect(not crossed and front > .16,"%s closed shell stops Walker" % lot.lot_id)
		var down := await _walk(approach.global_position,.065)
		var back := await _walk(link,.092)
		_expect(down and back and absf(preview.actor.global_position.y-lot.global_position.y)<.022,"%s descends continuously to street" % lot.lot_id)
		if got_path and got_landing and on_ramp and down and back:
			walked += 1
			print("walked ",lot.lot_id," rise ","%.2f m" % height)

func _grab() -> Image:
	for i in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	return preview.pixels.get_texture().get_image()

func _frame_bounds(lot: Lot, camera: Camera3D) -> Rect2:
	var surface: Array = lot.mesh_view.mesh.surface_get_arrays(0)
	var bounds := Rect2(camera.unproject_position(lot.mesh_view.global_position), Vector2.ZERO)
	for vertex: Vector3 in surface[Mesh.ARRAY_VERTEX]:
		bounds = bounds.expand(camera.unproject_position(lot.mesh_view.to_global(vertex)))
	return bounds

func _visible_probes(site: Site, size_x: int) -> void:
	var pixel_size := Vector2(preview.pixels.size)
	var tests: Dictionary[String,Vector3] = {}
	var actual := Rect2(Vector2(2,2),pixel_size-Vector2(4,4))
	var frame := site.camera.global_basis
	for lot in site.lots():
		var door := lot.marker("DoorAnchor")
		tests[String(lot.name)+" door"] = door.global_position + door.global_basis.z*.132 + Vector3.UP*.84
		tests[String(lot.name)+" foot"] = lot.marker("Landing").global_position + Vector3.UP*.053
		var signboard := lot.marker("Sign")
		if signboard:
			tests[String(lot.name)+" sign"] = signboard.global_position + signboard.global_basis.z*.081
		var bounds := _frame_bounds(lot,site.camera)
		_expect(actual.encloses(bounds),"%s silhouette in frame at %d: %s" % [lot.name,size_x,bounds])
	var lane := site.road()
	for i in range(2,lane.size()-1):
		tests["street segment %s" % i] = _lane_point(lane[i])+Vector3.UP*.08
	if site.setting == 1:
		for i in range(1,Site.ALLEY.size()):
			tests["alley segment %s" % i] = _lane_point(Site.ALLEY[i])+Vector3.UP*.08
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ff17f7")
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var probe_mesh := QuadMesh.new()
	probe_mesh.size = Vector2(.137,.137)
	probe_mesh.material = material
	var layer := Node3D.new()
	site.add_child(layer)
	for point: Vector3 in tests.values():
		var probe := MeshInstance3D.new()
		probe.mesh = probe_mesh
		probe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.add_child(probe)
		probe.global_transform = Transform3D(frame,point)
	var image := await _grab()
	var good := 0
	for key: String in tests:
		var pixel := Vector2i(site.camera.unproject_position(tests[key]).round())
		var hits := 0
		for dx in range(-1,2):
			for dy in range(-1,2):
				var pos := (pixel+Vector2i(dx,dy)).clamp(Vector2i.ZERO,image.get_size()-Vector2i.ONE)
				var col := image.get_pixelv(pos)
				if col.r>.90 and col.b>.76 and col.g<.24:
					hits += 1
		_expect(hits>0,"%s view at %d: %s (%s) is in-frame and not occluded" % [site.name,size_x,key,pixel])
		good += int(hits>0)
	print(site.name," ",size_x," view: ",good,"/",tests.size()," unobscured depth-tested feature probes")
	site.remove_child(layer)
	layer.queue_free()

func _render_site(idx: int) -> void:
	preview.actor.call(&"settle_input")
	preview.reset_position()
	await _tick(16)
	preview.actor.set("locked",true)
	var site := preview.site
	var place := "village" if idx==0 else "town"
	for width: int in [480,320]:
		preview.set_pixel_size(width)
		_expect(preview.pixels.msaa_3d == Viewport.MSAA_DISABLED and preview.screen.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,"outdoor viewport has no AA and nearest-neighbour scaling")
		_expect(is_equal_approx(site.camera.size,13.4) and absf(site.camera.rotation_degrees.y-Site.VIEW_YAW)<.001 and absf(site.camera.rotation_degrees.x+Site.VIEW_PITCH)<.001,"game yaw/pitch and default zoom")
		var base := preview.pixels.size
		var k := maxi(1,floori(minf(preview.size.x/base.x,preview.size.y/base.y)))
		_expect(preview.screen.size==Vector2(base)*k,"integer letterbox display")
		await _visible_probes(site,width)
		var variants := ["day", "clay", "dusk"] if width==480 else ["day"]
		for label: String in variants:
			preview.clay = label=="clay"
			preview.dusk = label=="dusk"
			preview.apply_look()
			_store(await _grab(),place,label,width)
		preview.clay = false
		preview.dusk = false
		preview.apply_look()
	var day := images["%s_day_480.png" % place].get_data()
	for label in ["clay", "dusk"]:
		_expect(day!=images["%s_%s_480.png" % [place,label]].get_data(),"%s %s mode changes the actual readback" % [place,label])
	await _closeup(site,idx,place)

func _store(img: Image, place: String, label: String, width: int) -> void:
	var valid := not img.is_empty() and img.get_size()==preview.pixels.size
	_expect(valid and img.get_width()==width,"native render readback")
	if not valid:
		return
	var palette := {}
	var mean := 0.0
	var count := 0
	for y in range(0,img.get_height(),5):
		for x in range(0,img.get_width(),5):
			var texel := img.get_pixel(x,y)
			palette[texel.to_rgba32()] = true
			mean += texel.get_luminance()
			count += 1
	_expect(palette.size()>90 and mean/count>.09 and mean/count<.90,"nonblank exposure: %s %s" % [place,label])
	images["%s_%s_%d.png" % [place,label,width]] = img
	print("sampled ",place,"/",label," ",img.get_size()," : ",palette.size()," colors; mean luma ","%.3f" % (mean/count))

func _closeup(site: Site, idx: int, place: String) -> void:
	var lot: Lot = site.get_node("Lots/OrchardFarm" if idx==0 else "Lots/BakersCorner")
	var foot := lot.marker("Approach").global_position.lerp(site.road_link(lot).global_position,.20)
	preview.actor.set("locked",false)
	await _foot(foot)
	preview.actor.set("locked",true)
	preview.set_process(false)
	preview.set_pixel_size(480)
	var aim := lot.global_position + (Vector3(.27,2.025,1.79) if idx==0 else Vector3(.14,2.16,1.72))
	site.view_at(aim,2,270)
	var bounds := _frame_bounds(lot,site.camera)
	_expect(is_equal_approx(site.camera.size,8.95) and Rect2(2,2,476,266).encloses(bounds),"%s entire hero shell at the game near-zoom step: %s" % [place,bounds])
	_store(await _grab(),place,"stoop" if idx==0 else "shop",480)
	preview.set_process(true)

func _run() -> void:
	var rendered := DisplayServer.get_name() != "headless"
	var capture := "--capture" in OS.get_cmdline_user_args()
	if capture and not rendered:
		printerr("--capture requires a real renderer, not --headless")
		quit(2)
		return
	_plans()
	preview = Scene.instantiate() as Preview
	root.add_child(preview)
	await _tick(3)
	var ids := {}
	for idx in 2:
		preview.show_site(idx)
		var geometry := {}
		for lot in preview.site.lots():
			_expect(lot.plan.valid and lot.plan.warnings.is_empty() and lot.marker("Lamp")!=null and not ids.has(lot.lot_id),"valid unique authored lot %s" % lot.lot_id)
			ids[lot.lot_id] = true
			geometry[lot.lot_id] = lot.mesh_view.mesh.surface_get_arrays(0)
		preview.show_site(idx)
		for lot in preview.site.lots():
			_expect(geometry[lot.lot_id]==lot.mesh_view.mesh.surface_get_arrays(0),"same mesh and paint after re-instantiation: %s" % lot.lot_id)
		await _walk_site(preview.site)
		if rendered:
			await _render_site(idx)
	_stop()
	if capture and failures==0:
		for name: String in images:
			var file := REVIEW+name
			if FileAccess.file_exists(file):
				print("kept existing ",file)
			else:
				_expect(images[name].save_png(file)==OK,"save %s" % file)
				print("capture ",file)
	print("BUILDING TRIAL: ",checks-failures,"/",checks," checks; ",walked,"/6 thresholds walked; ",images.size()," native renders.")
	quit(int(failures != 0))
