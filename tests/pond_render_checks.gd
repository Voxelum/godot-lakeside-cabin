extends SceneTree
## Windowed: godot --path . --script res://tests/pond_render_checks.gd
## Optional -- --capture writes a contact sheet to an unused filename in the OS temp folder.

const DIAGNOSTIC := """
shader_type spatial;
render_mode unshaded;
uniform sampler2D field_map : filter_linear, repeat_disable;
uniform vec4 field_rect;
varying vec2 land;
void vertex() { land = VERTEX.xz; }
void fragment() {
	vec2 uv = (land-field_rect.xy)/field_rect.zw;
	vec2 field = texture(field_map, uv).rg;
	ALBEDO = vec3(0.0);
	if (all(greaterThan(uv,vec2(0))) && all(lessThan(uv,vec2(1))) && field.g < .31) {
		if (field.r < .57) { ALBEDO = vec3(0,1,0); }
		else if (field.r > .95) { ALBEDO = vec3(1,0,0); }
	}
}
"""

var view: SubViewport
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func grab() -> Image:
	for i in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	return view.get_texture().get_image()

func xz(v: Vector3) -> Vector2:
	return Vector2(v.x,v.z)

func read_field(image: Image, rect: Rect2, p: Vector2) -> Color:
	if not rect.has_point(p):
		return Color.WHITE
	var texel := (p-rect.position)/rect.size*Vector2(image.get_size())-Vector2(.5,.5)
	var i := Vector2i(texel.floor()).clamp(Vector2i.ZERO,image.get_size()-Vector2i(2,2))
	var t := (texel-Vector2(i)).clamp(Vector2.ZERO,Vector2.ONE)
	return image.get_pixelv(i).lerp(image.get_pixelv(i+Vector2i.RIGHT),t.x).lerp(
		image.get_pixelv(i+Vector2i.DOWN).lerp(image.get_pixelv(i+Vector2i(1,1)),t.x),t.y)

# Physical depth gap at the XZ boundary and just underneath the water, not
# an inference from color. Shore rocks/reeds intentionally interrupt the rim.
func meadow_height(triangles: PackedVector3Array, p: Vector2) -> float:
	var height := -INF
	var origin := Vector3(p.x,2.0,p.y)
	for i in range(0,triangles.size(),3):
		var a := triangles[i]; var b := triangles[i+1]; var c := triangles[i+2]
		if p.x < minf(a.x,minf(b.x,c.x)) or p.x > maxf(a.x,maxf(b.x,c.x)):
			continue
		if p.y < minf(a.z,minf(b.z,c.z)) or p.y > maxf(a.z,maxf(b.z,c.z)):
			continue
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin,Vector3.DOWN,a,b,c)
		if hit != null:
			height = maxf(height,hit.y)
	return height

func geometry(pool: Node3D, land: Node3D, field: Texture2D, params: Vector4) -> void:
	var edge: CollisionPolygon3D = pool.get_node("PoolBarrier/Shoreline")
	var water: MeshInstance3D = pool.get_node("Water")
	var shore := PackedVector2Array()
	for p in edge.polygon:
		shore.append(xz(land.to_local(edge.to_global(Vector3(p.x,p.y,0)))))
	var arrays := water.mesh.surface_get_arrays(0)
	var rim: Dictionary[Vector2,bool] = {}
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		if arrays[Mesh.ARRAY_COLOR][i].r > .99:
			var p := xz(land.to_local(water.to_global(arrays[Mesh.ARRAY_VERTEX][i])))
			rim[p] = true
	check(rim.size()==shore.size(), "water rim count matches shoreline")
	for p in shore:
		check(rim.has(p), "water rim coincides with shoreline vertex %s" % p)

	var rect := Rect2(params.x,params.y,params.z,params.w)
	var image := field.get_image()
	var widths := Vector2(INF,-INF)
	var ground: MeshInstance3D = land.get_node("Meadow")
	var triangles := (land.global_transform.affine_inverse()*ground.global_transform)*ground.mesh.get_faces()
	var water_y := land.to_local(water.to_global(arrays[Mesh.ARRAY_VERTEX][0])).y
	var min_depth_gap := INF
	for i in shore.size():
		var a := shore[i]; var b := shore[(i+1)%shore.size()]
		var normal := (b-a).orthogonal().normalized()
		var mid := a.lerp(b,.5)
		if Geometry2D.is_point_in_polygon(mid+normal*.05,shore):
			normal = -normal
		for f in [.25,.5,.75]:
			var p := a.lerp(b,f)
			var at_edge := read_field(image,rect,p)
			check(absf(at_edge.r-.5)<.055 and at_edge.g<.04, "wet pigment follows rim %s" % p)
			for distance in [0.0,-.045,-.20]:
				var height := meadow_height(triangles,p+normal*float(distance))
				check(is_finite(height),"continuous soil under rim near %s" % p)
				min_depth_gap = minf(min_depth_gap, water_y-height)
			var width := 0.0
			while width < 1.4 and read_field(image,rect,p+normal*width).g<.53:
				width += .02
			widths.x = minf(widths.x,width)
			widths.y = maxf(widths.y,width)
	check(widths.x>=.22 and widths.y<1.3 and widths.y-widths.x>.40,"varied, bounded mud width")
	check(min_depth_gap>.04,"soil/water depth separation around rim")
	var intrusions := 0
	var tested := 0
	for node in land.get_children():
		if not (node.name.begins_with("Wild_Border_") or node.name.begins_with("Bellflowers_") or node.name==&"Thyme_In_The_Joints"):
			continue
		if not node.mesh:
			continue
		for vertex: Vector3 in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var p := xz(land.to_local(node.to_global(vertex)))
			if rect.has_point(p):
				tested += 1
				if read_field(image,rect,p).g < .68:
					intrusions += 1
	check(tested > 0 and intrusions == 0,"land vegetation vertices outside mud and water")
	print("geometry: %d edge probes; mud width %.2f–%.2f m; min gap below water %.4f m (%d probes); %d nearby vegetation vertices, %d intrusions" % [shore.size()*3,widths.x,widths.y,min_depth_gap,shore.size()*9,tested,intrusions])

func labels(mask: Image) -> Array[PackedVector2Array]:
	var tags: Array[PackedVector2Array] = [PackedVector2Array(),PackedVector2Array(),PackedVector2Array()]
	for y in mask.get_height():
		for x in mask.get_width():
			var c := mask.get_pixel(x,y)
			if c.r>.99 and c.g<.01 and c.b<.01: tags[0].append(Vector2(x,y))
			if c.g>.99 and c.r<.01 and c.b<.01: tags[1].append(Vector2(x,y))
			if c.b>.99 and c.r<.01 and c.g<.01: tags[2].append(Vector2(x,y))
	return tags

func color_gap(a: Color, b: Color) -> float:
	return (Vector3(a.r,a.g,a.b)-Vector3(b.r,b.g,b.b)).length()

func compare(after: Image, original: Image, still: Array[Image], tags: Array[PackedVector2Array], mirror_off: Image, label: String) -> int:
	var means := Vector3.ZERO
	var land_drift := 0
	var reflection := 0
	var wet_water_delta := 0.0
	var wet_water_pairs := 0
	var water_pixels := {}
	for p in tags[2]:
		water_pixels[Vector2i(p)] = true
	var land_albedo := [Color(0,0,0,0), Color(0,0,0,0)]
	for j in tags.size():
		for p in tags[j]:
			var v := Vector2i(p)
			var c := after.get_pixelv(v)
			if j < 2:
				means[j] += color_gap(c,original.get_pixelv(v))
				land_albedo[j] += c
				if j == 1:
					for dir in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
						var neighbor: Vector2i = v + 2*dir
						if water_pixels.has(neighbor):
							wet_water_delta += color_gap(c,after.get_pixelv(neighbor))
							wet_water_pairs += 1
							break
				for img in still:
					if color_gap(c,img.get_pixelv(v)) > .055:
						land_drift += 1
						break
			elif color_gap(c,mirror_off.get_pixelv(v)) > .13:
				reflection += 1
		if j < 2 and not tags[j].is_empty():
			means[j] /= tags[j].size()
			land_albedo[j] /= tags[j].size()
	var layer_delta := color_gap(land_albedo[0],land_albedo[1])
	var water_delta := wet_water_delta/maxi(wet_water_pairs,1)
	print("%s: dry/wet/water pixels %d/%d/%d; grass→mud %.3f/%.3f; dry↔wet %.3f; wet↔water %.3f (%d); coast drift %d; mirror Δ pixels %d" % [label,tags[0].size(),tags[1].size(),tags[2].size(),means.x,means.y,layer_delta,water_delta,wet_water_pairs,land_drift,reflection])
	check(tags[0].size()>45 and tags[1].size()>28 and tags[2].size()>400, label+" exposed bank and water")
	check(means.x>.045 and means.y>.06 and layer_delta>.030, label+" distinguishable dry/wet and grass")
	check(wet_water_pairs>20 and water_delta>.055,label+" visible contact between wet mud and water")
	check(land_drift<=2, label+" fixed bank pixels stable over sampled frames")
	return reflection

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Windowed renderer required; pond render checks not run.")
		quit(2)
		return
	view = SubViewport.new()
	view.size = Vector2i(480,270)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var preview := TextureRect.new()
	preview.texture = view.get_texture()
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.size = Vector2(960,540)
	root.add_child(preview)
	var world := (load("res://world/Clearing.tscn") as PackedScene).instantiate()
	view.add_child(world)
	var land: Node3D = world.get_node("Land")
	var pool: Node3D = world.get_node("Pool")
	var cam: Camera3D = world.get_node("Camera")
	cam.set_process(false)
	var clock: Node = world.get_node("Almanac")
	var meadow: MeshInstance3D = land.get_node("Meadow")
	var grass := meadow.get_active_material(0).duplicate() as ShaderMaterial
	meadow.material_override = grass
	var water: MeshInstance3D = pool.get_node("Water")
	var ripple := water.material_override as ShaderMaterial
	var field: Texture2D = grass.get_shader_parameter("shore_field")
	var rect: Vector4 = grass.get_shader_parameter("shore_rect")
	if field==null or rect.z<=0.0:
		printerr("Missing baked shoreline field")
		quit(1)
		return
	geometry(pool,land,field,rect)
	var shader := Shader.new()
	shader.code = DIAGNOSTIC
	var marked := ShaderMaterial.new()
	marked.shader = shader
	marked.set_shader_parameter("field_map",field)
	marked.set_shader_parameter("field_rect",rect)
	var blue := StandardMaterial3D.new()
	blue.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blue.albedo_color = Color.BLUE
	blue.cull_mode = BaseMaterial3D.CULL_DISABLED
	var clear := Image.create_empty(1,1,false,Image.FORMAT_RGBA8)
	var no_reflection := ImageTexture.create_from_image(clear)
	var mirror: Texture2D = ripple.get_shader_parameter("mirror_tex")
	var mirror_views := Vector3i.ZERO
	var sheet := Image.create_empty(480*3,270*3,false,Image.FORMAT_RGB8)
	var row := 0
	for pose in [
		[30.0,36.0,13.4,Vector3(6.7,.1,3.95),Vector2i(480,270)],
		[-48.0,41.0,10.85,Vector3(7,.1,3.9),Vector2i(480,270)],
		[136.0,49.0,6.2,Vector3(6.25,.1,5.75),Vector2i(320,180)],
	]:
		var basis := Basis.from_euler(Vector3(-deg_to_rad(pose[1]),deg_to_rad(pose[0]),0))
		view.size = pose[4]
		cam.size = pose[2]
		cam.global_transform = Transform3D(basis,pose[3]+basis.z*23.0)
		var column := 0
		for hour in [14.0,18.66667,1.0]:
			clock.hour = hour
			clock._advance_sky()
			meadow.material_override = marked
			water.material_override = blue
			var tags := labels(await grab())
			meadow.material_override = grass
			water.material_override = ripple
			var delivered := await grab()
			var still: Array[Image] = []
			for i in 3:
				still.append(await grab())
			grass.set_shader_parameter("shore_rect",Vector4.ZERO)
			var original := await grab()
			grass.set_shader_parameter("shore_rect",rect)
			ripple.set_shader_parameter("mirror_tex",no_reflection)
			var mirror_off := await grab()
			ripple.set_shader_parameter("mirror_tex",mirror)
			if compare(delivered,original,still,tags,mirror_off,"yaw %.0f / size %.2f / hour %.2f" % [pose[0],pose[2],hour])>10:
				mirror_views[column] += 1
			check(ripple.get_shader_parameter("mirror_ready") and ripple.get_shader_parameter("mirror_resolution")==Vector2(view.size),"mirror sync at viewport resolution")
			var tile := delivered.duplicate() as Image
			tile.convert(Image.FORMAT_RGB8)
			tile.resize(480,270,Image.INTERPOLATE_NEAREST)
			sheet.blit_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),Vector2i(480*column,270*row))
			column += 1
		row += 1
	check(mirror_views.x>0 and mirror_views.y>0 and mirror_views.z>0,"visible reflection contribution at all tested times")
	if "--capture" in OS.get_cmdline_user_args():
		var path := OS.get_temp_dir().path_join("pond-render-%d.png" % OS.get_process_id())
		var saved := not FileAccess.file_exists(path) and sheet.save_png(path)==OK
		check(saved,"save optional contact sheet")
		if saved:
			print("capture: ",path)
	print("pond_render_checks: %d failures; visible reflection views %s" % [failures,mirror_views])
	quit(0 if failures==0 else 1)
