extends RefCounted
## Original solid colour masses built in character space (+Z forward, Y up).
## The short tapered rings are authored cross-sections, not imported sprite pixels.

const REED := &"reed"
const LINNET := &"linnet"
const POTTER := &"potter"
const TENDER := &"tender"
const BAKER := &"baker"
# hip, shoulder y and x, upper/lower leg, leg splay, head scale, resting lean
const SIZES := {
	REED: Vector4(.835, .455, .310, 1.06),
	LINNET: Vector4(.760, .420, .267, 1.01),
	POTTER: Vector4(.710, .406, .350, 1.01),
	TENDER: Vector4(.741, .416, .233, .97),
	BAKER: Vector4(.540, .332, .214, .87),
}
const LEGS := {
	REED: Vector4(.420, .405, .119, .014),
	LINNET: Vector4(.386, .371, .102, .006),
	POTTER: Vector4(.355, .344, .145, .055),
	TENDER: Vector4(.374, .357, .093, .230),
	BAKER: Vector4(.271, .260, .087, .016),
}
# coat, fold, sleeve, lining, breeches, boot, hair, crown, skin, blush, accent
const PIGMENTS := {
	REED: "366c73 6e9a98 c5b997 274a51 544e43 352e33 303240 53566b e9b279 bc7959 b75f3e",
	LINNET: "7d5065 b87a86 c08059 54364d 665968 3b303f 513b4a 85535a cb9068 9f5d53 92bbb4",
	POTTER: "945a48 c68359 d7b489 674343 575859 443c36 422d32 725052 ac704f 824c40 ddcbad",
	TENDER: "687b55 9a9e72 a3966f 485444 514943 393637 a49799 d2c3b9 c89572 a46852 d8bf97",
	BAKER: "4b656d 78979b b09576 42465d 706076 443344 84604e b98b61 e1aa7c bd765b c78c54",
}

var id: StringName
var sizing: Vector4
var leg: Vector4
var facing: Node3D
var waist: Node3D
var chest: Node3D
var head: Node3D
var eyes: Node3D
var trim: Node3D
var tool: Node3D
var staff: Node3D
var legs: Array[Node3D] = []
var shins: Array[Node3D] = []
var feet: Array[Node3D] = []
var arms: Array[Node3D] = []
var elbows: Array[Node3D] = []
var scale_limbs: float
var _paint := StandardMaterial3D.new()
var _colors: Array[Color] = []

func build(parent: Node3D, profile: StringName) -> void:
	id = profile
	_paint.vertex_color_use_as_albedo = true
	_paint.roughness = 1.0
	_paint.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_paint.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	sizing = SIZES[id]
	leg = LEGS[id]
	scale_limbs = .77 if id == BAKER else (.90 if id == LINNET or id == TENDER else 1.0)
	for ink in PIGMENTS[id].split(" "): _colors.append(Color(ink))
	facing = _pivot(parent, "Facing")
	waist = _pivot(facing, "Waist", Vector3.UP * sizing.x)
	chest = _pivot(waist, "Chest")
	var hero := id in [REED,LINNET]
	head = _pivot(chest, "Head", Vector3(0, sizing.y + (-.025 if hero else .023), .017))
	head.scale = (Vector3(1.17,1.24,1.08) if hero else Vector3.ONE) * sizing.w
	_make_clothes()
	_make_head()
	_make_limbs()
	_make_gear()

func _make_clothes() -> void:
	var s := sizing
	var width := s.z * .95
	var breadth := width * (1.05 if id == POTTER else .88)
	var depth := .224 if id == POTTER else (.132 if id == BAKER else .169)
	var z_shift := .023 if id == POTTER else 0.0
	_ring(chest, "Coat", [Vector4(-.116, breadth * .96, depth * .92, z_shift),
		Vector4(-.065, breadth, depth, z_shift), Vector4(.14, width * .81, depth, z_shift),
		Vector4(s.y - .068, width, depth, 0), Vector4(s.y + .010, width * .81, depth * .83, 0),
		Vector4(s.y + .054, .112, depth * .70, 0)], _colors[0], [_colors[3],_colors[3],_colors[0],_colors[0],_colors[1],_colors[1],_colors[0],_colors[0]])
	_ring(chest, "Collar", [Vector4(s.y-.03,.123,.119,.022), Vector4(s.y+.050,.125,.121,.015), Vector4(s.y+.067,.102,.103,.015)], _colors[2])
	var z := depth + .016
	match id:
		REED:
			_panel(chest,"FoldedPlacket",[Vector3(-.171,s.y-.038,z-.020),Vector3(-.033,s.y-.036,z),Vector3(.128,.105,z),Vector3(.001,.12,z+.007)],_colors[1])
			_panel(chest,"CrossbodyStrap",[Vector3(-.181,s.y-.009,z),Vector3(-.120,s.y-.018,z+.009),Vector3(.204,.018,z+.017),Vector3(.145,.006,z+.016)],_colors[3])
			_box(chest,"BrassFastener",Vector3(-.018,.223,z+.017),Vector3(.076,.060,.036),Color("d7ac69"))
			for k: float in [-1, 1]:
				_ring(waist, "SplitJacket", [Vector4(-.245,.108,.130,0),Vector4(-.18,.128,.145,.007),Vector4(-.030,.135,.155,0)], _colors[0]).position.x = k * .154
			var map_case := _pivot(chest,"MapCase",Vector3(.264,-.037,.063))
			map_case.rotation.z = .13
			_box(map_case,"Leather",Vector3.ZERO,Vector3(.204,.272,.211),_colors[10])
			_box(map_case,"Lid",Vector3(.011,.096,.018),Vector3(.207,.091,.213),Color("d38960"))
		LINNET:
			# Not a cylinder on top of socks: two moving skirts leave a view of the legs.
			for k: float in [-1, 1]:
				var skirt := _ring(waist,"SplitOverskirt",[Vector4(-.286 if k < 0 else -.214,.142,.170,.006),Vector4(-.196,.173,.176,.007),Vector4(.030,.104,.152,0)],_colors[0],[_colors[1],_colors[0],_colors[3],_colors[3],_colors[3],_colors[0],_colors[0],_colors[1]])
				skirt.position.x = k * .145
				skirt.rotation.z = k * .078
			_panel(chest,"WrappedBodice",[Vector3(-.155,s.y-.046,z),Vector3(-.055,s.y-.053,z+.009),Vector3(.135,.130,z+.009),Vector3(-.044,.045,z+.009)],_colors[1])
			_box(chest,"FieldSatchel",Vector3(-.285,-.011,.033),Vector3(.206,.258,.225),_colors[10]).rotation.z = -.16
			_box(chest,"SatchelFlap",Vector3(-.298,.062,.157),Vector3(.167,.074,.036),Color("c7d4be"))
		POTTER:
			_ring(waist,"ApronHem",[Vector4(-.257,.278,.070,.171),Vector4(-.206,.321,.093,.162),Vector4(.113,.255,.079,.173)],_colors[10])
			_panel(chest,"ApronBib",[Vector3(-.189,.331,z-.005),Vector3(.180,.319,z-.005),Vector3(.223,.050,z+.011),Vector3(-.220,.064,z+.009)],_colors[10])
			_box(chest,"ClothPatch",Vector3(-.078,.147,z+.022),Vector3(.161,.133,.029),Color("b0ad85")).rotation.z = .08
		TENDER:
			_ring(chest,"ShoulderShawl",[Vector4(.224,width*1.04,depth+.025,0),Vector4(s.y-.048,width*1.12,depth+.039,0),Vector4(s.y+.017,width*.75,depth+.008,0)],_colors[2])
			_panel(chest,"LongFold",[Vector3(-.133,s.y-.022,z+.027),Vector3(.012,s.y-.047,z+.045),Vector3(.096,.056,z+.015),Vector3(-.096,.147,z+.016)],_colors[10])
			_ring(waist,"CoatTails",[Vector4(-.224,width*1.10,depth+.025,-.009),Vector4(-.171,width*1.15,depth+.035,0),Vector4(.043,width,depth+.017,0)],_colors[3])
		BAKER:
			_panel(chest,"WorkApron",[Vector3(-.103,.246,z),Vector3(.128,.246,z),Vector3(.155,-.138,z+.009),Vector3(-.166,-.138,z+.009)],Color("b8b195"))
			_box(chest,"BerryPin",Vector3(-.101,.252,z+.015),Vector3(.063,.056,.031),Color("9b5b54"))

func _make_head() -> void:
	_ring(head,"Face",[Vector4(.022,.098,.110,.039),Vector4(.061,.155,.143,.040),
		Vector4(.145,.208,.185,.021), Vector4(.261,.225,.198,.005),
		Vector4(.367,.207,.185,-.011),Vector4(.450,.145,.139,-.023),Vector4(.478,.073,.073,-.031)],_colors[8])
	# Hair silhouette deliberately breaks symmetry; near the front, the bevel frames
	# one warm face plane large enough to survive native 320 rendering.
	var angles := 8
	var bottom: Array[Vector3] = []
	var shoulder: Array[Vector3] = []
	var crown: Array[Vector3] = []
	var cut := [.283,.188,.104,.088,.078,.115,.227,.332]
	if id == LINNET: cut = [.275,.152,.113,.108,.106,.129,.230,.323]
	if id == TENDER: cut = [.341,.215,.132,.107,.116,.147,.220,.355]
	for k in angles:
		var a := TAU * (float(k) + .5) / angles
		var p := Vector3(sin(a),0,cos(a))
		bottom.append(Vector3(p.x*.244,cut[k],p.z*.216-.008))
		shoulder.append(Vector3(p.x*.260,.376 + .020*sin(a),p.z*.224-.023))
		crown.append(Vector3(p.x*.164 - .022,.464 + .020*sin(a),p.z*.164-.044))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in angles:
		var n := (k+1)%angles
		_quad(st,bottom[k],shoulder[k],shoulder[n],bottom[n],_colors[6])
		_quad(st,shoulder[k],crown[k],crown[n],shoulder[n],_colors[7] if k in [0,5,6,7] else _colors[6])
		_tri(st,Vector3(-.048,.487,-.043),crown[n],crown[k],_colors[7])
	_mesh(head,"HairPlanes",st)
	if id == REED:
		# A slanted, single swept crown, not a row of same-sized spikes.
		_ring(head,"SweptCrown",[Vector4(.333,.219,.164,-.020),Vector4(.445,.206,.173,-.023),Vector4(.492,.142,.145,-.057),Vector4(.532,.042,.080,-.073)],_colors[7]).rotation.z = -.17
	elif id == LINNET:
		trim = _pivot(head,"LowPlait",Vector3(.157,.301,-.137))
		trim.rotation.z = .255
		_ring(trim,"Plait",[Vector4(-.430,.053,.051,-.167),Vector4(-.338,.093,.084,-.127),Vector4(-.140,.113,.102,-.059),Vector4(.026,.081,.077,0)],_colors[6],[_colors[7],_colors[6],_colors[6],_colors[6],_colors[6],_colors[7],_colors[7],_colors[7]])
		_ring(trim,"PlaitClasp",[Vector4(-.351,.088,.079,-.131),Vector4(-.295,.100,.092,-.120)],_colors[10])
	elif id == POTTER:
		_ring(head,"ClayStainedWrap",[Vector4(.316,.264,.220,-.006),Vector4(.378,.279,.243,-.017),Vector4(.476,.210,.193,-.061),Vector4(.512,.091,.100,-.074)],Color("d5bea0"),[Color("efd3ac"),Color("c1a68d"),Color("b3957f"),Color("bb9e86"),Color("bb9e86"),Color("c6a98d"),Color("e1c49b"),Color("efd3ac")])
		_ring(head,"BackKnot",[Vector4(.165,.092,.063,-.218),Vector4(.271,.106,.094,-.232),Vector4(.341,.058,.055,-.201)],Color("b69b7f")).position.x = -.108
	elif id == TENDER:
		_ring(head,"SilverKnot",[Vector4(.188,.121,.117,-.201),Vector4(.320,.127,.121,-.226),Vector4(.391,.082,.086,-.191)],_colors[7]).position.x = .068
		_ring(head,"ChinSilver",[Vector4(.024,.081,.057,.157),Vector4(.108,.151,.078,.118),Vector4(.139,.134,.043,.144)],_colors[7])
	else:
		_ring(head,"BakeryCap",[Vector4(.316,.272,.239,.002),Vector4(.358,.294,.259,.004),Vector4(.484,.215,.206,-.033),Vector4(.509,.123,.147,-.052)],Color("d4c095"),[Color("e5d4ac"),Color("baa87e"),Color("a99070"),Color("b9a17b"),Color("b9a17b"),Color("c5ae85"),Color("dcc69b"),Color("e5d4ac")])
	for side: float in [-1,1]:
		_ring(head,"Ear",[Vector4(.126,.038,.043,.055),Vector4(.18,.044,.049,.043),Vector4(.237,.032,.039,.037)],_colors[9],[],6).position.x = side*.205
	# Eyes are a short, dark note in one mass, not two white circles.
	eyes = _pivot(head,"Eyes",Vector3(0,.202,.202))
	for side: float in [-1,1]:
		_box(eyes,"Eye",Vector3(side*.081,0,.001),Vector3(.043,.047,.018),Color("382c35"))
		if id == TENDER:
			_box(head,"Brow",Vector3(side*.092,.237,.199),Vector3(.064,.036,.023),_colors[7]).rotation.z = side*.16
	_ring(head,"Nose",[Vector4(.125,.041,.046,.183),Vector4(.165,.043,.048,.193),Vector4(.205,.023,.024,.193)],_colors[8].lightened(.10),[],6)

func _make_limbs() -> void:
	var s := scale_limbs
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		var thigh := _pivot(facing,"Thigh",Vector3(side*leg.z,sizing.x,0))
		var shin := _pivot(thigh,"Shin",Vector3.DOWN*leg.x)
		var foot := _pivot(shin,"Foot",Vector3.DOWN*leg.y)
		legs.append(thigh); shins.append(shin); feet.append(foot)
		_ring(thigh,"Breeches", [Vector4(-leg.x-.045,.077*s,.087*s,.007),Vector4(-leg.x+.039,.094*s,.106*s,0),Vector4(.026,.112*s,.128*s,0)],_colors[4])
		_ring(shin,"BootCuff",[Vector4(-leg.y,.087*s,.090*s,0),Vector4(-leg.y+.137*s,.099*s,.093*s,0),Vector4(-leg.y+.171*s,.095*s,.086*s,0)],_colors[5])
		_ring(shin,"LowerTrouser",[Vector4(-leg.y+.141*s,.078*s,.080*s,0),Vector4(-.006,.082*s,.094*s,.006)],_colors[4])
		_ring(foot,"BootToe",[Vector4(-.073*s,.095*s,.138*s,.049*s),Vector4(-.042*s,.103*s,.140*s,.051*s),Vector4(.017*s,.094*s,.127*s,.046*s),Vector4(.086*s,.081*s,.088*s,.005*s)],_colors[5],[_colors[5].lightened(.18),_colors[5],_colors[5],_colors[5],_colors[5],_colors[5],_colors[5],_colors[5].lightened(.18)])
		var arm := _pivot(chest,"Shoulder",Vector3(side*sizing.z,sizing.y-.045,.003))
		var elbow := _pivot(arm,"Elbow",Vector3.DOWN*.222*s)
		arms.append(arm); elbows.append(elbow)
		var wide := s*(1.17 if id == POTTER else 1.0)
		_ring(arm,"Sleeve",[Vector4(-.251*s,.077*wide,.081*wide,0),Vector4(-.180*s,.096*wide,.100*wide,0),Vector4(-.034*s,.118*wide,.112*wide,0),Vector4(.050*s,.086*wide,.084*wide,0)],_colors[2])
		_ring(elbow,"CuffAndForearm",[Vector4(-.169*s,.059*wide,.064*wide,.006),Vector4(-.048*s,.073*wide,.076*wide,.006),Vector4(.029*s,.076*wide,.079*wide,0)],_colors[2].darkened(.10))
		_ring(elbow,"Hand",[Vector4(-.266*s,.050*wide,.047*wide,.019),Vector4(-.234*s,.064*wide,.057*wide,.019),Vector4(-.154*s,.061*wide,.061*wide,.011)],_colors[8])

func _make_gear() -> void:
	tool = _pivot(elbows[1], "HandProp", Vector3(.009,-.224*scale_limbs,.062))
	match id:
		REED:
			_box(tool,"FoldedSurvey",Vector3(.046,-.036,.061),Vector3(.329,.204,.039),Color("dfc59a"))
			_box(tool,"InnerLeaf",Vector3(-.018,-.029,.089),Vector3(.162,.185,.019),Color("f0dab2")).rotation.y = .14
			_box(tool,"Watermark",Vector3(.070,-.035,.090),Vector3(.136,.028,.010),Color("84918a")).rotation.z = -.28
		LINNET:
			_ring(tool,"SeedFlask",[Vector4(-.145,.090,.079,0),Vector4(-.102,.107,.094,0),Vector4(.010,.102,.086,0),Vector4(.064,.048,.048,0),Vector4(.130,.041,.043,0)],_colors[10])
			_ring(tool,"Cork",[Vector4(.106,.051,.049,0),Vector4(.156,.046,.046,0)],Color("efd8a2"))
			_box(tool,"GlassLight",Vector3(-.031,-.055,.084),Vector3(.054,.109,.024),Color("c0d8bc"))
		POTTER:
			_ring(tool,"JugBody",[Vector4(-.267,.101,.101,.069),Vector4(-.195,.151,.142,.064),Vector4(-.076,.164,.148,.060),Vector4(.052,.105,.092,.043),Vector4(.131,.072,.062,.028)],Color("b87d59"))
			_ring(tool,"JugRim",[Vector4(.107,.103,.084,.026),Vector4(.152,.091,.090,.022)],Color("e0ad79"))
			_ring(tool,"GlazedMouth",[Vector4(.150,.068,.066,.023),Vector4(.154,.065,.060,.023)],Color("59443f"))
			_rod(tool,"Handle",Vector3(.098,-.06,.049),Vector3(.192,.010,.039),.037,Color("a76c51"))
			_rod(tool,"HandleReturn",Vector3(.192,.010,.039),Vector3(.079,.103,.027),.037,Color("c88a5f"))
		TENDER:
			staff = _pivot(facing,"HazelStick",Vector3(.322,.004,.254))
			_rod(staff,"Stock",Vector3.ZERO,Vector3(-.004,.923,-.06),.039,Color("896952"))
			_rod(staff,"BentGrip",Vector3(-.004,.923,-.06),Vector3(-.098,1.008,-.099),.047,Color("b19364"))
		BAKER:
			_box(tool,"DeliveryCloth",Vector3(-.034,-.042,.078),Vector3(.258,.183,.193),Color("aa8a6f"))
			_ring(tool,"Loaf",[Vector4(-.052,.080,.072,.091),Vector4(.021,.120,.092,.101),Vector4(.109,.126,.089,.111),Vector4(.147,.098,.062,.117)],_colors[10]).rotation.z = -.32
			_box(tool,"CrustCut",Vector3(.034,.076,.187),Vector3(.114,.035,.028),Color("e6b781")).rotation.z = -.38

func _pivot(parent: Node3D, label: String, p := Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name = label; node.position = p
	parent.add_child(node,true)
	return node

func _box(parent: Node3D, label: String, p: Vector3, v: Vector3, ink: Color) -> MeshInstance3D:
	var mesh := _ring(parent,label,[Vector4(-v.y*.5,v.x*.47,v.z*.46,0),Vector4(-v.y*.38,v.x*.55,v.z*.54,0),Vector4(v.y*.38,v.x*.55,v.z*.54,0),Vector4(v.y*.5,v.x*.47,v.z*.46,0)],ink)
	mesh.position = p
	return mesh

func _rod(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, ink: Color) -> void:
	var mesh := _ring(parent,label,[Vector4(0,radius,radius,0),Vector4(a.distance_to(b),radius*.91,radius*.91,0)],ink,[],5)
	mesh.position = a
	mesh.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func _panel(parent: Node3D, label: String, p: Array[Vector3], ink: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st,p[0],p[1],p[2],p[3],ink)
	_mesh(parent,label,st,false)

func _ring(parent: Node3D, label: String, rings: Array[Vector4], ink: Color, sides: Array[Color] = [], n := 8) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in rings.size()-1:
		for k in n:
			var a := TAU*(float(k)+.5)/n
			var b := TAU*(float(k)+1.5)/n
			var tint := ink if sides.is_empty() else sides[k]
			_quad(st,_ring_point(rings[j],a),_ring_point(rings[j+1],a),_ring_point(rings[j+1],b),_ring_point(rings[j],b),tint)
	for k in n:
		var a := TAU*(float(k)+.5)/n
		var b := TAU*(float(k)+1.5)/n
		var low := rings[0]; var high := rings[-1]
		_tri(st,Vector3(0,low.x,low.w),_ring_point(low,a),_ring_point(low,b),ink.darkened(.13))
		_tri(st,Vector3(0,high.x,high.w),_ring_point(high,b),_ring_point(high,a),ink.lightened(.11))
	return _mesh(parent,label,st)

func _ring_point(r: Vector4, a: float) -> Vector3:
	return Vector3(sin(a)*r.y,r.x,cos(a)*r.z+r.w)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ink: Color) -> void:
	_tri(st,a,b,c,ink); _tri(st,a,c,d,ink)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ink: Color) -> void:
	var normal := (c-a).cross(b-a).normalized()
	for v in [a,b,c]:
		st.set_normal(normal); st.set_color(ink); st.add_vertex(v)

func _mesh(parent: Node3D, label: String, st: SurfaceTool, shadow := true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = st.commit()
	mesh.material_override = _paint
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh,true)
	return mesh
