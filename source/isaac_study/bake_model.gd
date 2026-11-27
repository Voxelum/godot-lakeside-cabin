extends SceneTree
## Offline, deterministic native Godot scene bake. No reads from ref/, images,
## external executables or add-ons. Output is an editable Rig + AnimationPlayer.
## godot --headless --path . --script res://source/isaac_study/bake_model.gd -- --output=<new .tscn>
const Sculpt := preload("res://source/isaac_study/sculpt.gd")
const WALK_Z := [.243,.063,-.151,-.246,-.091,.143]
const WALK_LIFT := [0.0,0.0,0.0,.012,.100,.103]
const WALK_PITCH := [-.13,.01,.14,.33,.04,-.14]
const RUN_Z := [.333,.061,-.277,-.292,-.015,.245]
const RUN_LIFT := [.022,0.0,.045,.164,.230,.121]
const RUN_PITCH := [-.23,.02,.39,.66,.32,-.21]
var sculpt := Sculpt.new()

func _initialize() -> void: _bake.call_deferred()

func _bake() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=")
	if out.is_empty() or out.get_extension() != "tscn" or FileAccess.file_exists(out):
		printerr("Supply a NEW .tscn via --output=. Refusing to overwrite."); quit(2); return
	var model := sculpt.build(); root.add_child(model)
	var player := AnimationPlayer.new(); player.name = "Motion"; model.add_child(player)
	var library := AnimationLibrary.new()
	var idle := Animation.new(); idle.resource_name = "Idle · planted watch and blink"; idle.length = 8.4; idle.loop_mode = Animation.LOOP_LINEAR
	var ts := [0.,2.47,2.68,3.54,3.61,3.72,4.37,4.45,4.54,5.54,5.76,6.02,6.27,6.55,7.85,8.4]
	var shift := [0.,0.,.55,.55,.55,.55,.55,.55,.55,.55,.95,.58,.08,.55,.52,0.]
	var lid := [1.,1.,1.,1.,.13,1.,1.,.11,1.,1.,1.,1.,1.,1.,1.,1.]
	for i in ts.size(): _key(idle,ts[i],_pose(-1,false,shift[i],lid[i]))
	library.add_animation(&"idle",idle)
	for sprint in [false,true]:
		var clip := Animation.new(); clip.resource_name = "Run · six beats" if sprint else "Walk · six beats"
		clip.length = .60 if sprint else .72; clip.loop_mode = Animation.LOOP_LINEAR
		for k in 7: _key(clip,k*clip.length/6.0,_pose(k%6,sprint,0.0,1.0))
		library.add_animation(&"run" if sprint else &"walk",clip)
	player.add_animation_library(&"",library)
	for node in model.find_children("*","",true,false): node.owner = model
	var packed := PackedScene.new(); var result := packed.pack(model)
	if result == OK: result = ResourceSaver.save(packed,out,ResourceSaver.FLAG_BUNDLE_RESOURCES)
	print("Isaac native model, ",sculpt.rig.get_bone_count()," bones, ",model.find_children("*","MeshInstance3D",true,false).size()," solid parts; ",library.get_animation_list()," -> ",out," / ",result)
	quit(int(result != OK))

func _pose(beat: int, sprint: bool, shift: float, lid: float) -> Dictionary:
	var motion := beat >= 0
	var p := maxi(0,beat); var cycle := TAU*p/6.0
	var hips := Sculpt.H
	var drift := 0.0
	var sole_y := [0.0,0.0]; var sole_z := [0.0,0.0]; var pitch := [0.0,0.0]
	if motion:
		# The two leading-foot contacts in the diagonal run are the compact,
		# compressed drawings; don't put the deepest crouch on the next key.
		hips += ([-.174,-.052,-.084,-.174,-.052,-.084] if sprint else [-.079,-.092,-.042,-.079,-.092,-.042])[p]
		drift = .027 if sprint else .008
	else: hips -= .011*shift
	for i in 2:
		var k := (p+3*i)%6
		pitch[i] = (RUN_PITCH if sprint else WALK_PITCH)[k] if motion else 0.0
		var theta: float = pitch[i]
		# Rotating the shoe about its load-bearing heel/toe, not the ankle,
		# keeps the physical sole on the floor on the support beats.
		var contact := .187 if theta>=0 else -.056
		var off := Vector3(0,-.075,contact).rotated(Vector3.RIGHT,theta)
		sole_y[i] = ((RUN_LIFT if sprint else WALK_LIFT)[k] if motion else 0.0)-off.y
		sole_z[i] = ((RUN_Z if sprint else WALK_Z)[k] if motion else (.040 if i==0 else -.037))+contact-off.z
		var z: float = sole_z[i]-drift
		hips = minf(hips,sole_y[i]+sqrt(maxf(.02,pow(Sculpt.A+Sculpt.B-.003,2)-z*z)))
	var posture := {"Hip:y":Vector3(.012*sin(cycle) if motion else .007*shift,hips,drift)}
	var lean := ((.30+.082*cos(cycle*2.0) if sprint else .095) + .015*sin(cycle*2.0)) if motion else .018-.052*shift
	posture["Trunk:r"] = Vector3(lean,(.119 if sprint else .073)*cos(cycle) if motion else .075*shift,.025*sin(cycle) if motion else -.031*shift)
	posture["Head:r"] = Vector3(-lean*(.34 if sprint else .60)+(.018*cos(cycle*2.0) if motion else -.042*shift),-.055*cos(cycle) if motion else -.108*shift,.018*sin(cycle) if motion else .030*shift)
	posture["Muffler:r"] = Vector3((.39 if sprint else .17)+.12*sin(cycle-.35) if motion else .061*shift,0.,.10*sin(cycle-.60) if motion else -.045*shift)
	posture["Eyes:s"] = Vector3(1,lid,1)
	for i in 2:
		var s := "L" if i==0 else "R"; var sign_x := -1.0 if i==0 else 1.0
		var z: float = sole_z[i]-drift; var down: float = hips-sole_y[i]
		var r := clampf(Vector2(z,down).length(),.03,Sculpt.A+Sculpt.B-.001)
		var hip := -atan2(z,down)-acos(clampf((Sculpt.A*Sculpt.A+r*r-Sculpt.B*Sculpt.B)/(2*Sculpt.A*r),-1,1))
		var knee := PI-acos(clampf((Sculpt.A*Sculpt.A+Sculpt.B*Sculpt.B-r*r)/(2*Sculpt.A*Sculpt.B),-1,1))
		posture["Hip"+s+":r"] = Vector3(hip,0,0)
		posture["Knee"+s+":r"] = Vector3(knee,0,0)
		posture["Foot"+s+":r"] = Vector3(pitch[i]-hip-knee,0,0)
		var swing := cos(cycle+PI*i-.14)
		posture["Arm"+s+":r"] = Vector3(-.10+(swing*(.86 if sprint else .52) if motion else -.067*shift),sign_x*.020,sign_x*(.174+(.042 if sprint else .0)))
		posture["Elbow"+s+":r"] = Vector3(-.17-(maxf(0.,-swing)*(.85 if sprint else .32) if motion else .077*shift),0,0)
	return posture

func _key(anim: Animation, time: float, pose: Dictionary) -> void:
	for channel: String in pose:
		var items := channel.split(":"); var path := NodePath("Rig:"+items[0]); var rot := items[1]=="r"; var pos := items[1]=="y"
		var type := Animation.TYPE_ROTATION_3D if rot else (Animation.TYPE_POSITION_3D if pos else Animation.TYPE_SCALE_3D)
		var track := anim.find_track(path,type)
		if track < 0: track = anim.add_track(type); anim.track_set_path(track,path)
		var sample: Vector3 = pose[channel]
		if rot: anim.rotation_track_insert_key(track,time,Quaternion.from_euler(sample))
		elif pos: anim.position_track_insert_key(track,time,sample)
		else: anim.scale_track_insert_key(track,time,sample)
