extends RefCounted
## The public hall meets the street on a broad podium, carried by two piers.
## The podium, pillars and canopy are structure, not furniture or part of the net room.
const Shape := preload("res://source/building_structure.gd")
const Batch := preload("res://art/building_trial/mesh_batch.gd")
const Trim := preload("res://art/content_batch/buildings/roof_trim.gd")
const Join := preload("res://art/building_trial/joinery.gd")
const Mark := preload("res://world/interiors/structures/guild_heraldry.gd")

static func make(p: Shape, kit, shell: Node3D, body: StaticBody3D) -> void:
	var spec: Dictionary = p.data.portico
	var z := p.depth*.5
	var x: float = p.door.u
	var pier: float = spec.columns
	var half: float = spec.width*.5
	var y: float = spec.roof
	var edge: float = z+spec.project
	var wood := p.color("timber")
	var stone := p.color("stone")
	var masonry: Batch = kit.get_layer("masonry")
	var beams: Batch = kit.get_layer("timber")
	var iron: Batch = kit.get_layer("hardware")
	var tiles: Batch = kit.get_layer("roof_tile")
	_podium(p, masonry, shell, body, stone)
	var roof := [Vector3(x-half,y,edge+.07),Vector3(x+half,y,edge+.07),Vector3(x-half,y+.35,z-.08),Vector3(x+half,y+.35,z-.08)]
	Trim.slope(tiles,roof[0],roof[1],roof[2],roof[3],p.color("roof").lightened(.09),wood,4)
	_hull(body,"GuildCanopy",[roof[0],roof[1],roof[3],roof[2]],Vector3.DOWN*.095)
	var front := edge-.35
	beams.box(Vector3(x,y-.185,front),Vector3(2*half-.08,.36,.33),wood,1)
	beams.box(Vector3(x,y-.135,front+.190),Vector3(2*half-.035,.115,.08),wood.lightened(.21),1)
	beams.box(Vector3(x,y-.299,front+.185),Vector3(2*half-.15,.063,.071),wood.lightened(.08),1)
	_box(body,"GuildEntablature",Vector3(x,y-.17,front),Vector3(2*half-.08,.34,.33))
	for s: float in [-1,1]:
		var cx := x+s*pier
		var foot := Vector3(cx,0,front)
		# Ashlar base plus chamfer-read pilaster capital are wider than the shaft.
		for course in [[.08,.16,.66], [.25,.18,.568], [.455,.23,.544], [.642,.115,.637]]:
			masonry.box(foot+Vector3.UP*float(course[0]),Vector3(course[2],course[1],course[2]),Batch.tone(stone,.04+.18*sin(float(course[0])*6.74)))
		_box(body,"GuildColumnFoot",foot+Vector3.UP*.35,Vector3(.66,.70,.66))
		beams.box(foot+Vector3.UP*(.70+(y-.95)*.5),Vector3(.45,y-.95,.44),wood.lightened(.16),1)
		_box(body,"GuildColumn",foot+Vector3.UP*(.70+(y-.95)*.5),Vector3(.45,y-.95,.44))
		beams.box(foot+Vector3.UP*(y-.407),Vector3(.62,.17,.58),wood.lightened(.13),1)
		beams.bar(foot+Vector3.UP*(y-.86),foot+Vector3(-s*.48,y-.36,0),.158,.187,wood,Vector3.BACK,1)
		var lamp := foot+Vector3(0,1.51,.255)
		Join.lantern(iron,lamp)
		var glow := OmniLight3D.new()
		glow.position = lamp+Vector3(0,-.074,.211)
		glow.light_energy = .84
		glow.light_color = Color("ffd49a")
		glow.omni_range = 2.85
		glow.visible = false
		glow.add_to_group(&"night_omni",true)
		shell.add_child(glow)
		_banner(iron,Vector3(x+s*2.83,p.upper+.47,z+.235),wood)
		var pot := Vector3(x+s*3.18,-p.rise,z+.38)
		_trough(beams,kit.get_layer("garden"),pot,wood)
		_box(body,"GuildPlanter",pot+Vector3.UP*.19,Vector3(1.13,.38,.48))
	var gable: Dictionary = p.front_roof.filter(func(b: Dictionary) -> bool: return not b.has("window")).front()
	var badge := Vector3(gable.u,lerpf(gable.shoulder,gable.peak,.33),gable.z+.20)
	beams.box(badge-Vector3.BACK*.105,Vector3(.88,1.02,.21),wood,1)
	Mark.shield(iron,badge,1.52,1.43)
	_peg(shell,"Sign",badge)
	_buttresses(p,masonry,beams,stone,wood)

static func _podium(p: Shape, stonework: Batch, shell: Node3D, body: StaticBody3D, stone: Color) -> void:
	var x: float = p.door.u
	var half: float = p.data.portico.steps_width*.5
	var a := p.depth*.5-.032
	var b := p.depth*.5+float(p.data.stoop_landing)
	var c := b+float(p.data.stoop_run)
	var bottom := -p.rise-.08
	# Full tread/riser solids in the mesh. The swept capsule uses a fitted
	# continuous walk surface (also used on the hall's main interior stair).
	for row in 4:
		var front := b if row == 0 else lerpf(b,c,row/3.)
		var back := a if row == 0 else lerpf(b,c,(row-1)/3.)
		var crest := -row*p.rise/3.
		for i in 7:
			var l := x+lerpf(-half,half,i/7.)+.007
			var r := x+lerpf(-half,half,(i+1)/7.)-.007
			stonework.box(Vector3((l+r)*.5,(bottom+crest)*.5,(back+front)*.5),Vector3(r-l,crest-bottom,front-back+.018),Batch.tone(stone,.18+.10*sin(row*2.45+i*6.02)))
		if row < 3:
			stonework.box(Vector3(x,crest-.027,front+.012),Vector3(half*2+.032,.054,.072),stone.lightened(.30))
	_hull(body,"GuildSteps",[Vector3(x-half,0,a),Vector3(x+half,0,a),Vector3(x+half,0,b),Vector3(x+half,-p.rise,c),Vector3(x-half,-p.rise,c),Vector3(x-half,0,b)],Vector3.DOWN*.135)
	_peg(shell,"DoorAnchor",Vector3(x,0,p.depth*.5+.103))
	_peg(shell,"Landing",Vector3(x,0,b-.10))
	_peg(shell,"Approach",Vector3(x,-p.rise,c+.18))

static func _buttresses(p: Shape, masonry: Batch, beams: Batch, stone: Color, wood: Color) -> void:
	for side in 4:
		var f := p.frame(side)
		var half := p.wall_span(side)*.5
		for s: float in [-1,1]:
			var u := s*(half-.24)
			for i in 7:
				Join.panel(masonry,f,Vector3(u,.035+i*.151,.037),Vector3(.34 if i%2 else .49,.137,.117),Batch.tone(stone,.14*sin(i*7.9+side*2.1)))
			var h := p.upper-1.11
			Join.panel(beams,f,Vector3(s*(half-.141),1.02+h*.5,.087),Vector3(.177,h,.147),wood,1)
			Join.panel(beams,f,Vector3(s*(half-.141),(p.eave+p.upper)*.5,.087),Vector3(.177,p.eave-p.upper,.147),wood,1)
		for i in range(-10,11):
			var u := i*(half-.36)/11.
			Join.panel(beams,f,Vector3(u,p.eave-.095,.103),Vector3(.077,.16,.126),wood.lightened(.15),1)

static func _banner(b: Batch, at: Vector3, wood: Color) -> void:
	b.roller(at+Vector3.UP*.46,Vector3.RIGHT,.63,.040,8,wood.lightened(.23),1)
	for s: float in [-1,1]:
		b.roller(at+Vector3(s*.31,.46,0),Vector3.RIGHT,.043,.053,8,Mark.EDGE)
	for layer in [[.25,0.,Mark.EDGE],[.215,.013,Mark.BLUE.lightened(.17)]]:
		var w: float = layer[0]
		var z: float = layer[1]
		b.fan(PackedVector3Array([at+Vector3(-w,.43,z),at+Vector3(w,.43,z),at+Vector3(w,-.26,z),at+Vector3(0,-.44+z*2.8,z),at+Vector3(-w,-.26,z)]),Vector3.BACK,layer[2])
	Mark.swords(b,at+Vector3(0,.048,.028),.34)

static func _trough(b: Batch, leaves: Batch, at: Vector3, wood: Color) -> void:
	b.box(at+Vector3.UP*.17,Vector3(1.08,.34,.42),wood,1)
	b.box(at+Vector3.UP*.329,Vector3(1.13,.096,.48),wood.lightened(.18),1)
	for i in 10:
		var stem := at+Vector3(-.48+i*.107,.41,.105*cos(i*2.66))
		leaves.roller(stem,Vector3.UP,.186,.12,6,Batch.tone(Color("617a42"),.14*cos(4.21*i)))
		if i%3 != 1: leaves.roller(stem+Vector3.UP*.096,Vector3.UP,.042,.063,7,Color("eed794") if i%2 == 0 else Color("c78865"))

static func _peg(shell: Node3D, label: String, at: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = label
	marker.position = at
	shell.add_child(marker)

static func _box(body: StaticBody3D, label: String, at: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	_add(body,label,at,shape)

static func _hull(body: StaticBody3D, label: String, corners: Array, thickness: Vector3) -> void:
	var hull := PackedVector3Array()
	for pt: Vector3 in corners:
		hull.append(pt)
		hull.append(pt+thickness)
	var p := ConvexPolygonShape3D.new()
	p.points = hull
	_add(body,label,Vector3.ZERO,p)

static func _add(body: StaticBody3D, label: String, at: Vector3, shape: Shape3D) -> void:
	var piece := CollisionShape3D.new()
	piece.name = label
	piece.position = at
	piece.shape = shape
	body.add_child(piece,true)
