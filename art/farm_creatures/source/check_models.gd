extends SceneTree
## Render the packed models through a real Compatibility viewport (no test map).
## Optional --proofs=<existing directory> exports two contact sheets of the exact
## sampled texels. Existing sheets require an explicit --replace-proofs.
const Scenes := [preload("res://art/farm_creatures/Spider.tscn"),preload("res://art/farm_creatures/Bee.tscn"),preload("res://art/farm_creatures/Imp.tscn")]
const Durations := [[2.4,.72,1.02],[.80,.48,.84],[1.80,.68,1.14]]
const Tell := [.38,.28,.45]
const Strike := [.53,.43,.62]
const Cell := Vector2i(126,104)
var field := SubViewport.new()
var cam := Camera3D.new()
var checks := 0
var failures := 0
var pages: Array[Image] = []
var min_pose_px := [99999,99999,99999,99999]
var min_look_px := [99999,99999,99999,99999]

func _initialize() -> void: run.call_deferred()

func check(ok:bool, label:String) -> void:
	checks+=1
	if not ok:
		printerr("FAIL ",label)
		failures+=1

func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("A real display is required; no placeholder pixels accepted")
		quit(2); return
	var out:=""
	for opt in OS.get_cmdline_user_args():
		if opt.begins_with("--proofs="): out=opt.trim_prefix("--proofs=")
	if not out.is_empty() and not "--replace-proofs" in OS.get_cmdline_user_args():
		for width in [480,320]:
			if FileAccess.file_exists(out.path_join("%d.png"%width)):
				printerr("Refusing to overwrite proof"); quit(2); return
	field.own_world_3d=true; field.transparent_bg=true
	field.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(field)
	var display:=TextureRect.new()
	display.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	display.texture=field.get_texture(); root.add_child(display)
	var sky:=WorldEnvironment.new(); sky.environment=Environment.new()
	sky.environment.background_mode=Environment.BG_COLOR
	sky.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	sky.environment.ambient_light_color=Color(.78,.84,.90); sky.environment.ambient_light_energy=.69
	field.add_child(sky)
	var sun:=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-52,-34,0)
	sun.light_color=Color(1.,.953,.84); sun.light_energy=1.03; field.add_child(sun)
	cam.projection=Camera3D.PROJECTION_ORTHOGONAL; cam.size=13.4
	field.add_child(cam); cam.current=true
	cam.rotation_degrees=Vector3(-36,30,0)
	for grade in 2:
		var atlas:=Image.create_empty(5*(126+70),Cell.y*9,false,Image.FORMAT_RGBA8)
		atlas.fill(Color("4e5849")); pages.append(atlas)
	for tier in 4:
		cam.size=6.2 if tier>=2 else 13.4
		field.size=Vector2i(320,180) if tier%2==1 else Vector2i(480,270)
		root.mode=Window.MODE_WINDOWED; root.size=field.size
		for species in 3: await review(tier,species)
	if failures==0 and not out.is_empty():
		for grade in 2: check(pages[grade].save_png(out.path_join("%d.png"%[480,320][grade]))==OK,"write proof")
	print("CHECK ",checks-failures,"/",checks," · default 480/320, close 480/320 min changed pixels tell → hit: ",min_pose_px,"; between rest looks: ",min_look_px)
	quit(int(failures!=0))

func review(tier:int, species:int) -> void:
	cam.position=Vector3(0,[.41,1.24,.78][species],.07)+cam.basis.z*23.
	var n:Node3D=Scenes[species].instantiate()
	n.set("variant_index",2) # before ready, then live swap without respawning.
	field.add_child(n)
	var a:=n.get_node("AnimationPlayer") as AnimationPlayer
	check(a!=null and a.get_parent()==n,"direct player")
	check(n.get_class()=="Node3D" and n.find_children("*","CollisionObject3D",true,false).is_empty() and n.find_children("*","SpriteBase3D",true,false).is_empty(),"visual mesh root only; no collision, areas or sprite substitute")
	a.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for j in 3:
		var anim:=a.get_animation([&"idle",&"move",&"attack"][j])
		check(anim!=null and is_equal_approx(anim.length,Durations[species][j]) and (anim.loop_mode==Animation.LOOP_LINEAR)==(j!=2),"clip duration / loop")
		for t in anim.get_track_count(): check(n.has_node(anim.track_get_path(t)),"resolved track %s"%anim.track_get_path(t))
	var looks:Array[Image]=[]
	var other:Node3D=Scenes[species].instantiate(); field.add_child(other); other.hide()
	for look in 3:
		a.play(&"attack"); a.seek(.2,true); n.set("variant_index",look)
		check(is_equal_approx(a.current_animation_position,.2) and other.get("variant_index")==0,"live switch; no timeline or instance cross-talk")
		var skins:=n.find_children("Skin","MeshInstance3D",true,false)
		for skin:MeshInstance3D in skins:
			check(skin.mesh!=null and skin.mesh==skin.get_meta(&"looks")[look],"all rigid surfaces switched")
		n.rotation.y=0.
		var idle:=await capture(a,&"idle",0.)
		var breath:=await capture(a,&"idle",Durations[species][0]*.22)
		check(changed(idle,breath)>2,"idle visibly breathes or hovers")
		var walk1:=await capture(a,&"move",0.)
		var walk2:=await capture(a,&"move",Durations[species][1]*.22)
		check(changed(walk1,walk2)>3,"move distinct within cycle")
		await capture(a,&"idle",0.)
		if tier==0: print(n.name," look ",look," min/max XYZ ",bounds(n))
		var prep:=await capture(a,&"attack",Tell[species]); var hit:=await capture(a,&"attack",Strike[species])
		check(n.transform.is_equal_approx(Transform3D.IDENTITY),"no actor-root motion at impact")
		var pose_px:=changed(prep,hit); min_pose_px[tier]=mini(min_pose_px[tier],pose_px)
		check(pose_px>22 and changed(idle,prep)>12,"readable anticipation and hit")
		check(idle.get_used_rect().size.x>=11 and idle.get_used_rect().size.y>=9,"visible rest silhouette at default F5 zoom")
		for old in looks:
			var d:=changed(old,idle); min_look_px[tier]=mini(min_look_px[tier],d)
			check(d>15,"visible variant differences from both other skins")
		looks.append(idle)
		n.rotation.y=PI*.79
		var back:=await capture(a,&"idle",0.)
		check(changed(idle,back)>14,"turns in depth")
		var seq:=[idle,walk2,prep,hit,back]
		for j in 5:
			var slot:=Vector2i(126 if tier>=2 else 70, Cell.y)
			var src:=Rect2i((Cell-slot)/2,slot)
			check(src.encloses((seq[j] as Image).get_used_rect()),"atlas plate encloses whole pose")
			var dst:=Vector2i((0 if tier>=2 else 630)+j*slot.x,(species*3+look)*Cell.y)
			var col:Color=[Color("79866a"),Color("7d8b77"),Color("77846b")][species]
			pages[tier%2].fill_rect(Rect2i(dst+Vector2i.ONE,slot-Vector2i(2,2)),col)
			pages[tier%2].blend_rect(seq[j],src,dst)
	other.free(); n.free()

func capture(a:AnimationPlayer,clip:StringName,t:float) -> Image:
	a.play(clip); a.seek(t,true); a.advance(0.)
	await process_frame; await RenderingServer.frame_post_draw
	var image:=field.get_texture().get_image()
	check(image!=null and image.get_size()==field.size,"real pixels for requested tier")
	var small:=image.get_region(Rect2i((field.size-Cell)/2,Cell)); small.convert(Image.FORMAT_RGBA8)
	check(small.get_used_rect().has_area() and Rect2i(Vector2i.ONE,Cell-2*Vector2i.ONE).encloses(small.get_used_rect()),"%s %s @ %.2f: used=%s, native=%s" % [a.get_parent().name,clip,t,small.get_used_rect(),field.size])
	return small

func changed(a:Image,b:Image) -> int:
	var n:=0
	for y in Cell.y:
		for x in Cell.x:
			var l:=a.get_pixel(x,y); var r:=b.get_pixel(x,y)
			if absf(l.a-r.a)>.4 or (l.a>.65 and r.a>.65 and absf(l.r-r.r)+absf(l.g-r.g)+absf(l.b-r.b)>.14): n+=1
	return n

func bounds(n:Node3D) -> Array:
	var lo:=Vector3.INF; var hi:=-Vector3.INF
	for skin:MeshInstance3D in n.find_children("Skin","MeshInstance3D",true,false):
		for v in skin.mesh.get_faces():
			var p:=skin.global_transform*v
			lo=lo.min(p); hi=hi.max(p)
	return [lo,hi]
