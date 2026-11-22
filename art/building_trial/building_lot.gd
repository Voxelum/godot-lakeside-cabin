@tool
extends Node3D
## Inspector-edited lot. Generated meshes, markers and collision are unowned:
## the .tscn stores the design inputs, never a stale copy of the output.
const Batch = preload("res://art/building_trial/mesh_batch.gd")
const Rules = preload("res://art/building_trial/lot_rules.gd")
const Roof = preload("res://art/building_trial/roof_profiles.gd")
const Join = preload("res://art/building_trial/joinery.gd")
const PIGMENT = preload("res://art/building_trial/trial_pigment.gdshader")

signal layout_changed

@export var lot_id: StringName = &"":
	set(value):
		lot_id = value
		_queue_build()
@export_enum("Farmhouse", "Narrow townhouse", "Street shop", "Barn / workshop") var archetype := 0:
	set(value):
		archetype = value
		_queue_build()
## Plot width/depth in facade-space, including eaves and side bay, excluding the front approach.
@export var parcel := Vector2(6.6, 4.6):
	set(value):
		parcel = value
		_queue_build()
@export_enum("+Z", "+X", "-Z", "-X") var street_face := 0:
	set(value):
		street_face = value
		_queue_build()
@export_range(.10, .36, .01, "suffix:m") var threshold_rise := .18:
	set(value):
		threshold_rise = clampf(value, .10, .36)
		_queue_build()
@export_group("Appearance overrides", "")
@export var appearance_seed := 104:
	set(value):
		appearance_seed = value
		_queue_build()
@export_enum("Seeded", "Standard", "Compact") var body_lock := 0:
	set(value):
		body_lock = value
		_queue_build()
@export_enum("Seeded", "Swept gable", "Low hip", "Steep gable", "Clipped gable", "Gambrel") var roof_lock := 0:
	set(value):
		roof_lock = value
		_queue_build()
@export_enum("Seeded", "Hearth", "Hedgerow", "Quarry") var palette_lock := 0:
	set(value):
		palette_lock = value
		_queue_build()
@export_enum("Seeded", "None", "Left stack", "Right stack") var chimney_lock := 0:
	set(value):
		chimney_lock = value
		_queue_build()
@export_enum("Seeded", "None", "Right lean-to") var wing_lock := 0:
	set(value):
		wing_lock = value
		_queue_build()
@export_enum("Seeded", "Left", "Center", "Right") var entry_lock := 0:
	set(value):
		entry_lock = value
		_queue_build()
@export_enum("Seeded", "Bare", "Shutters") var shutters_lock := 0:
	set(value):
		shutters_lock = value
		_queue_build()

var plan: Dictionary
var door_width := 1.0
var slope_run := .9
var mesh_view: MeshInstance3D
var pigment := ShaderMaterial.new()
var _queued := false
var _generated: Node3D
var _markers: Node3D
var _solid: StaticBody3D
var _lamp: OmniLight3D
var _w: float
var _d: float
var _h: float
var _rise: float
var _wall: Color
var _wood: Color
var _roof: Color
var _accent: Color
var _stone: Color
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rebuild()

func _queue_build() -> void:
	if is_node_ready() and not _queued:
		_queued = true
		_rebuild.call_deferred()

func _resolve() -> Dictionary:
	return Rules.resolve(archetype, parcel, appearance_seed, body_lock, roof_lock, palette_lock, chimney_lock, wing_lock, entry_lock, shutters_lock)

func _get_configuration_warnings() -> PackedStringArray:
	var msg := PackedStringArray(_resolve().warnings)
	if lot_id.is_empty():
		msg.append("Supply a stable lot ID before placing this shell.")
	return msg

func marker(label: String) -> Marker3D:
	return _markers.get_node_or_null(label) as Marker3D if is_instance_valid(_markers) else null

func set_review(clay: Material, dusk: bool) -> void:
	if not is_instance_valid(mesh_view):
		return
	mesh_view.material_override = clay
	pigment.set_shader_parameter(&"dusk", dusk)
	_lamp.visible = dusk and clay == null

func _rebuild() -> void:
	_queued = false
	if not is_inside_tree():
		return
	if is_instance_valid(_generated):
		remove_child(_generated)
		_generated.queue_free()
	mesh_view = null
	_markers = null
	plan = _resolve()
	update_configuration_warnings()
	if not plan.valid:
		layout_changed.emit()
		return
	var body: Vector4 = plan.body
	_w = body.x
	_d = body.y
	_rise = threshold_rise
	_h = body.z + _rise
	_wall = Color(plan.ink[0])
	_wood = Color(plan.ink[1])
	_roof = Color(plan.ink[2])
	_accent = Color(plan.ink[3])
	_stone = Color(plan.ink[4])
	_rng.seed = appearance_seed ^ 30843
	_generated = Node3D.new()
	_generated.name = "Generated"
	_generated.rotation_degrees.y = Rules.faces(street_face)
	add_child(_generated)
	_solid = StaticBody3D.new()
	_solid.name = "ShellAndLanding"
	_solid.collision_mask = 0
	_generated.add_child(_solid)
	_markers = Node3D.new()
	_markers.name = "Anchors"
	_generated.add_child(_markers)
	var b := Batch.new()
	var roof := Roof.new(archetype, plan.roof, body, _h, appearance_seed)
	_wall_shell(b)
	roof.fill_gables(b, _wall, _wood, archetype == Rules.BARN)
	roof.crown(b, _roof, _wood.darkened(.12))
	if int(plan.stack) > 1:
		_chimney(b, roof)

	var dx := (float(plan.door) - 2.0) * _w * (.249 if archetype == Rules.SHOP else .245)
	var door_height := 1.82 if archetype == Rules.FARM else 1.98
	door_width = 1.03 if archetype == Rules.FARM else .96
	if archetype == Rules.BARN:
		door_width = minf(2.42, _w * .57)
		door_height = 2.19
	Join.entry(b, _face(0, dx, _rise), door_width, door_height, _wood, _accent, _stone, archetype in [Rules.FARM,Rules.TOWN], archetype == Rules.BARN)
	_box_shape("Footprint", Vector3(0, _h*.5, 0), Vector3(_w, _h, _d))
	_landing(b, dx)
	match archetype:
		Rules.FARM: _farm(b, dx)
		Rules.TOWN: _town(b, dx)
		Rules.SHOP: _shop(b)
		Rules.BARN: _barn(b, body.w)
	var lamp_x := dx + (.92 if dx < 0.0 else -.87)
	if archetype == Rules.BARN:
		lamp_x = door_width*.5 + .43
	if archetype == Rules.SHOP:
		lamp_x = _w*.469
	var lamp_pos := Vector3(lamp_x, _rise + 1.85, _d*.5 + .26)
	_anchor("Lamp", lamp_pos)
	Join.lantern(b, lamp_pos)
	_lamp = OmniLight3D.new()
	_lamp.position = lamp_pos + Vector3(0,-.09,.23)
	_lamp.omni_range = 2.85
	_lamp.light_color = Color("ffa66c")
	_lamp.light_energy = .84
	_lamp.visible = false
	_generated.add_child(_lamp)
	pigment.shader = PIGMENT
	mesh_view = b.add_to(_generated, "PaintedShell", pigment)
	layout_changed.emit()

func _anchor(label: String, p: Vector3) -> void:
	var m := Marker3D.new()
	m.name = label
	m.position = p
	_markers.add_child(m)

func _box_shape(label: String, p: Vector3, extent: Vector3) -> void:
	var box := BoxShape3D.new()
	box.size = extent
	var shape := CollisionShape3D.new()
	shape.name = label
	shape.position = p
	shape.shape = box
	_solid.add_child(shape)

func _face(side: int, x := 0.0, y := 0.0, proud := 0.0) -> Transform3D:
	var axes := Basis(Vector3.UP, PI*.5*side)
	var front := (_d if side % 2 == 0 else _w)*.5
	return Transform3D(axes, axes*Vector3(x, y, front + proud))

func _wall_shell(b: Batch) -> void:
	var base := _rise + .18
	b.box(Vector3(0,base*.5,0), Vector3(_w+.04,base,_d+.04), _stone.darkened(.18))
	b.box(Vector3(0,(base+_h)*.5,0), Vector3(_w,_h-base,_d), _wall)
	for side in 4:
		var f := _face(side)
		var w := _w if side % 2 == 0 else _d
		var n := ceili(w / .53)
		for k in 2:
			var row_shift := .5 if k > 0 else 0.0
			for i in range(-1,n):
				var l := maxf(-w*.5,(i+row_shift)*w/n-w*.5 + .014)
				var r := minf(w*.5,(i+row_shift+1)*w/n-w*.5 - .014)
				if r-l < .07:
					continue
				Join.panel(b, f, Vector3((r+l)*.5, (k+.5)*base*.5, .036+_rng.randf_range(-.005,.014)), Vector3(r-l,base*.5-.026,.078), Batch.tone(_stone,_rng.randf_range(-.15,.18)))
		if archetype == Rules.BARN:
			var boards := ceili(w / .26)
			for i in boards:
				var x := lerpf(-w*.5,w*.5,(i+.5)/boards)
				Join.panel(b,f,Vector3(x,(base+_h)*.5,.018),Vector3(w/boards-.016,_h-base-.017,.043+_rng.randf_range(.001,.014)),Batch.tone(_wall,_rng.randf_range(-.18,.18)),1)
		else:
			# Few lime patches at the base read as wear, not tiny texture noise.
			for i in 12:
				var x := _rng.randf_range(-w*.43,w*.43)
				var y := base + _rng.randf_range(.015,.39)
				var a := _rng.randf_range(.09,.28)
				var c := _rng.randf_range(.075,.16)
				b.fan(PackedVector3Array([f*Vector3(x-a,y,.009),f*Vector3(x-.3*a,y+c,.009),f*Vector3(x+.73*a,y+.82*c,.009),f*Vector3(x+a,y+.3*c,.009),f*Vector3(x+.74*a,y-.05,.009)]),f.basis.z,Batch.tone(_wall,_rng.randf_range(-.08,.085)))
		var beam_width := .19 if archetype == Rules.BARN else .132
		Join.panel(b,f,Vector3(0,_h-.094,.027),Vector3(w+.10,.166,.11),_wood,1)
		if archetype in [Rules.TOWN, Rules.BARN]:
			Join.panel(b,f,Vector3(0,base+.075,.036),Vector3(w+.10,.14,.12),_wood,1)
		for side_sign: float in [-1, 1]:
			var corner := side_sign*(w*.5-beam_width*.42)
			Join.panel(b,f,Vector3(corner,(base+_h)*.5,.036),Vector3(beam_width,_h-base,.122),_wood,1)

func _landing(b: Batch, dx: float) -> void:
	var width := door_width + .38
	var za := _d*.5 - .035
	var zb := _d*.5 + .36
	var zc := zb + maxf(.72, _rise*2.7)
	slope_run = zc-zb
	var left := dx - width*.5
	var right := dx + width*.5
	var points := PackedVector3Array()
	for x: float in [left,right]:
		for p in [Vector2(za,_rise),Vector2(zb,_rise),Vector2(zc,0),Vector2(za,-.08),Vector2(zc,-.08)]:
			points.append(Vector3(x,p.y,p.x))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var support := CollisionShape3D.new()
	support.name = "SlopedStoop"
	support.shape = shape
	_solid.add_child(support)
	var n := 5 if archetype == Rules.BARN else 3
	for k in 4:
		var p0 := 0.0 if k == 0 else (k-1)/3.0
		var p1 := 0.0 if k == 0 else k/3.0
		var z0 := za if k == 0 else lerpf(zb,zc,p0)
		var z1 := zb if k == 0 else lerpf(zb,zc,p1)
		var y0 := _rise*(1.0-p0)+.004
		var y1 := _rise*(1.0-p1)+.004
		for i in n:
			var x0 := lerpf(left,right,float(i)/n)
			var x1 := lerpf(left,right,float(i+1)/n)
			b.quad(Vector3(x0,y0,z0), Vector3(x1,y0,z0), Vector3(x1,y1,z1), Vector3(x0,y1,z1), Vector3.UP, Batch.tone(_stone,.17+(k%2)*.07+_rng.randf_range(-.16,.09)))
		b.quad(Vector3(left,0,z0),Vector3(left,y0,z0),Vector3(left,y1,z1),Vector3(left,0,z1),Vector3.LEFT,_stone.darkened(.1))
		b.quad(Vector3(right,0,z0),Vector3(right,0,z1),Vector3(right,y1,z1),Vector3(right,y0,z0),Vector3.RIGHT,_stone.darkened(.06))
		if k < 3:
			var seam := lerpf(zb,zc,minf(1,p1+.043))
			var py := y1 - _rise*(seam-z1)/slope_run
			b.quad(Vector3(left,y1+.003,z1),Vector3(right,y1+.003,z1),Vector3(right,py+.003,seam),Vector3(left,py+.003,seam),Vector3.UP,_stone.darkened(.17))
	_anchor("DoorAnchor", Vector3(dx, _rise, _d*.5+.103))
	_anchor("Landing", Vector3(dx, _rise, _d*.5+.345))
	_anchor("Approach", Vector3(dx, 0, zc+.18))

func _farm(b: Batch, dx: float) -> void:
	Join.window(b,_face(0,-dx*.89,_rise+.85),1.01,.92,_wood,_accent,_stone,plan.shutters)
	Join.window(b,_face(0,-signf(dx)*_w*.406,_rise+.94),.48,.67,_wood,_accent,_stone)
	for side in [1,3]:
		for x: float in [-.84,.77]:
			Join.window(b,_face(side,x,_rise+.84),.67,.88,_wood,_accent,_stone,x < 0 and plan.shutters)
	_porch_braces(b)

func _porch_braces(b: Batch) -> void:
	var f := _face(0,0,_h-.16,.045)
	for s: float in [-1,1]:
		Join.timber(b,f,Vector3(s*_w*.465,-.51,0),Vector3(s*_w*.325,0,0),Vector2(.11,.10),_wood)

func _town(b: Batch, dx: float) -> void:
	var mid := _rise + 2.21
	for side in 4:
		var f := _face(side,0,mid)
		var span := _w if side % 2 == 0 else _d
		Join.panel(b,f,Vector3(0,0,.085),Vector3(span+.23,.211,.228),_wood.darkened(.10),1)
		Join.panel(b,f,Vector3(0,.153,.061),Vector3(span+.115,.062,.141),_wood.lightened(.19),1)
		for s: float in [-1.0,1.0]:
			Join.timber(b,f,Vector3(s*(span*.5-.12),.31,.063),Vector3(s*(span*.5-.51),.112,.063),Vector2(.091,.099),_wood)
	Join.window(b,_face(0,0,mid+.53),_w*.48,1.01,_wood,_accent,_stone,plan.shutters,3)
	var x := -signf(dx)*_w*.252
	if dx != 0.0:
		Join.window(b,_face(0,x,_rise+.89),.55,.72,_wood,_accent,_stone)
	for side in [1,3]:
		for p: float in [-1.16,.79]:
			Join.window(b,_face(side,p,mid+.56),.68,.90,_wood,_accent,_stone,false)
		Join.window(b,_face(side,-.19,_rise+1.03),.49,.78,_wood,_accent,_stone,false)
	var plaque := Vector3(dx+.68,_rise+1.26,_d*.5+.16)
	b.box(plaque,Vector3(.17,.18,.062),Color("735350"))
	b.box(plaque+Vector3(0,0,.041),Vector3(.095,.076,.035),Color("d1b785"))

func _shop(b: Batch) -> void:
	Join.window(b,_face(0,-_w*.168,_rise+.52),_w*.411,1.31,_wood,_accent,_stone,false,3,true)
	Join.window(b,_face(1,.17,_rise+.91),1.38,1.21,_wood,_accent,_stone,false,3,true)
	var back := _d*.5+.075
	var front := back + .98
	var high := _rise + 2.57
	var low := high-.43
	var extent := _w*.461
	var stripes := 11
	var ivory := Color("ead6ab")
	b.box(Vector3(0,high+.11,back),Vector3(extent*2.07,.23,.17),_wood,1)
	b.box(Vector3(0,high+.167,back+.109),Vector3(extent*1.98,.058,.086),Join.BRASS)
	for i in stripes:
		var ink := _accent if i % 2 == 0 else ivory
		var x0 := lerpf(-extent,extent,float(i)/stripes)
		var x1 := lerpf(-extent,extent,float(i+1)/stripes)
		var bend := (x0+x1)*.5
		var a := Vector3(x0,high,back)
		var c := Vector3(x1,high,back)
		var d := Vector3(x0,low,front)
		var e := Vector3(x1,low,front)
		var m := Vector3(bend,low-.012,front+.066)
		b.quad(a,a.lerp(c,.5),m,d,Vector3.UP,ink)
		b.quad(a.lerp(c,.5),c,e,m,Vector3.UP,ink.darkened(.07))
		b.quad(a-Vector3.UP*.03,d-Vector3.UP*.03,e-Vector3.UP*.03,c-Vector3.UP*.03,Vector3.DOWN,ink.darkened(.40))
		var scallop := Vector3(0,-.208,0)
		b.quad(d,m,m+scallop,d+scallop*.74,Vector3.BACK,ink.darkened(.13))
		b.quad(m,e,e+scallop*.74,m+scallop,Vector3.BACK,ink.darkened(.17))
	for s: float in [-1.0,1.0]:
		b.bar(Vector3(s*extent,low-.031,front),Vector3(s*extent,high-.76,back),.073,.093,_wood,Vector3.RIGHT,1)
	var sign_pos := Vector3(_w*.446,high+.28,front+.126)
	_anchor("Sign",sign_pos)
	_hanging_sign(b,sign_pos,back-.13)

func _hanging_sign(b: Batch, p: Vector3, wall_z: float) -> void:
	var hook := p + Vector3(0,.63,0)
	b.bar(Vector3(hook.x,hook.y,wall_z),hook,.093,.092,_wood,Vector3.UP,1)
	b.bar(Vector3(hook.x,hook.y-.43,wall_z),hook-Vector3(0,0,.37),.055,.066,_wood,Vector3.RIGHT,1)
	for x: float in [-.26,.26]:
		b.bar(p+Vector3(x,.23,0),p+Vector3(x*.25,.62,0),.044,.045,Color("59443d"))
	var rim := [Vector2(-.49,-.13), Vector2(-.35,-.28), Vector2(.35,-.28), Vector2(.49,-.13), Vector2(.49,.14), Vector2(.35,.29), Vector2(-.35,.29), Vector2(-.49,.14)]
	var boundary := PackedVector3Array()
	var fill := PackedVector3Array()
	for r: Vector2 in rim:
		boundary.append(p+Vector3(r.x,r.y,.036))
		fill.append(p+Vector3(r.x*.86,r.y*.78,.043))
	b.fan(boundary,Vector3.BACK,Join.BRASS)
	b.fan(fill,Vector3.BACK,_accent.darkened(.47))
	for i in boundary.size():
		var a := boundary[i]
		var c := boundary[(i+1)%boundary.size()]
		b.quad(a,c,c-Vector3.BACK*.103,a-Vector3.BACK*.103,(a+c)*.5-p,_wood)
	b.fan(_back_of_sign(boundary),Vector3.FORWARD,_wood)
	# Raised loaf with three cuts instead of text at this pixel scale.
	var bread := Color("e8b56e")
	var a := p+Vector3(-.29,-.107,.055)
	var loaf := PackedVector3Array([a,p+Vector3(.277,-.107,.055),p+Vector3(.297,.003,.055),p+Vector3(.195,.143,.055),p+Vector3(-.143,.154,.055),p+Vector3(-.266,.071,.055)])
	b.fan(loaf,Vector3.BACK,bread)
	for x: float in [-.153, .005, .161]:
		b.bar(p+Vector3(x-.04,.087,.068),p+Vector3(x+.04,-.032,.068),.042,.019,bread.darkened(.35))

func _back_of_sign(front: PackedVector3Array) -> PackedVector3Array:
	var back := PackedVector3Array()
	for p in front:
		back.append(p-Vector3.BACK*.103)
	return back

func _barn(b: Batch, rise: float) -> void:
	var frame := _face(0,0,_h+rise*.48)
	Join.panel(b,frame,Vector3(0,0,.058),Vector3(.92,.67,.133),_wood,1)
	Join.panel(b,frame,Vector3(0,0,.139),Vector3(.73,.48,.052),Color("493e37"))
	for x: float in [-.227,0,.227]:
		Join.panel(b,frame,Vector3(x,0,.174),Vector3(.042,.49,.063),_wall.lightened(.134),1)
	Join.panel(b,frame,Vector3(0,-.294,.147),Vector3(1.09,.104,.262),_stone.lightened(.15))
	for x: float in [-1.15,1.10]:
		Join.window(b,_face(1,x,_rise+1.19),.54,.59,_wood,_accent,_stone)
	if plan.wing:
		_lean_to(b)

func _lean_to(b: Batch) -> void:
	var l := _w*.5-.08
	var r := _w*.5+Rules.WING+.17
	var f := _d*.5-.077
	var z0 := -.68
	var in_y := _h-.27
	var out_y := in_y-.48
	for z: float in [z0+.11,f-.12]:
		var post := Vector3(r-.16,0,z)
		b.box(post+Vector3.UP*out_y*.50,Vector3(.164,out_y,.163),_wood,1)
		b.box(post+Vector3.UP*.11,Vector3(.235,.22,.236),_stone)
		_box_shape("WingPost",post+Vector3.UP*out_y*.50,Vector3(.206,out_y,.206))
		b.bar(post+Vector3.UP*(out_y-.45),post+Vector3(-.41,out_y-.065,0),.104,.097,_wood,Vector3.BACK,1)
	for i in 7:
		var a := lerpf(z0,f,float(i)/7)
		var c := lerpf(z0,f,float(i+1)/7)-.008
		var ink := Batch.tone(_roof,_rng.randf_range(-.22,.19))
		b.quad(Vector3(l,in_y,a),Vector3(r,out_y,a),Vector3(r,out_y,c),Vector3(l,in_y,c),Vector3.UP,ink,1)
		b.quad(Vector3(l,in_y-.067,a),Vector3(l,in_y-.067,c),Vector3(r,out_y-.067,c),Vector3(r,out_y-.067,a),Vector3.DOWN,ink.darkened(.23),1)
	b.bar(Vector3(l,in_y-.044,f),Vector3(r,out_y-.044,f),.167,.106,_wood,Vector3.BACK,1)
	b.bar(Vector3(r,out_y-.043,z0),Vector3(r,out_y-.043,f),.132,.099,_wood,Vector3.RIGHT,1)

func _chimney(b: Batch, roof: Roof) -> void:
	var side := -1.0 if roof.along_x else (1.0 if int(plan.stack) == 3 else -1.0)
	var along := (.46 if int(plan.stack) == 3 else -.59) if roof.along_x else -.34
	var p := roof.on_roof(side,.62,along)
	var tall := 1.33 if archetype == Rules.TOWN else 1.00
	var y := p.y - .47
	var h := tall + .47
	var brick := _stone.lerp(_roof,.58)
	b.box(Vector3(p.x,y+h*.5,p.z),Vector3(.487,h,.494),brick.darkened(.15))
	for row in 6:
		var row_y := y+(row+.5)*h/6.0
		var f := Vector3(p.x,row_y,p.z+.251)
		var r := Vector3(p.x+.257,row_y,p.z)
		for j: float in [-1.0,1.0]:
			var offset := (j*.112)+(.013 if row%2==1 else -.015)
			var ink := Batch.tone(brick,_rng.randf_range(-.15,.16))
			b.box(f+Vector3(offset,0,0),Vector3(.208,h/6.0-.019,.034),ink)
			b.box(r+Vector3(0,0,offset),Vector3(.034,h/6.0-.019,.208),ink.darkened(.06))
	b.box(Vector3(p.x,y+h-.064,p.z),Vector3(.62,.13,.61),_stone)
	b.box(Vector3(p.x,y+h+.056,p.z),Vector3(.55,.14,.57),brick.lightened(.148))
	b.box(Vector3(p.x,y+h+.131,p.z),Vector3(.32,.019,.34),Color("3b3437"))
