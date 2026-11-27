extends RefCounted
## Geometry and paint helpers only. The original instances and their Resources
## are never edited; colors are shallow per-instance material overrides.
const Brush := preload("res://art/monster_trial/source/brush.gd")
const Props := preload("res://art/monster_variants/fantasy_props.gd")

static func slime(model: Node3D, look: int, b: Brush) -> void:
	if look == 0: return
	var rig: Node3D = model.get_node("Rig")
	var jelly: MeshInstance3D = rig.get_node("ScallopedJelly")
	(rig.get_node("LongGlaze") as Node3D).hide()
	(rig.get_node("ShortGlaze") as Node3D).hide()
	if look == 1:
		model.scale = Vector3(1.12,.83,1.08)
		_paint(jelly,"dc916d")
		b.loft(rig,"OchreCanopy",[[.534,Vector2(-.063,-.098),Vector2(.44,.362),"77474a"],[.584,Vector2(-.10,-.134),Vector2(.522,.425),"ba6a48"],[.663,Vector2(-.132,-.144),Vector2(.461,.386),"d48853"],[.781,Vector2(-.199,-.190),Vector2(.243,.250),"e2aa6d"],[.856,Vector2(-.231,-.217),Vector2(.085,.083),"c39966"]],13,1,.072)
		for i in 5:
			var a := float(i)*TAU/5. + .17
			b.oval(rig,"PalePore%d"%i,Vector3(-.14+.292*cos(a),.73+.036*sin(a),-.13+.267*sin(a)),Vector3(.138,.067,.135),"f1c891",Vector3(10,0,-13),8)
	else:
		model.scale = Vector3(.82,1.18,.92)
		_paint(jelly,"9a90e8")
		for i in 4:
			var at: Vector3 = [Vector3(-.125,.55,-.01),Vector3(.147,.51,-.128),Vector3(-.283,.47,-.20),Vector3(.021,.491,-.297)][i]
			var angle: Vector3 = [Vector3(-13,15,12),Vector3(14,-17,-24),Vector3(4,-11,28),Vector3(-22,20,-7)][i]
			var spike := b.joint(rig,"Crystal%d"%i,at,angle)
			var h: float = [.64,.43,.45,.54][i]
			b.loft(spike,"Facets",[[0,Vector2.ZERO,Vector2(.11,.119),"456e92"],[h*.69,Vector2(0,-.02),Vector2(.107,.081),"88a6bf"],[h,Vector2(.033,-.006),Vector2(.008,.010),"c4dad0"]],5,1,.032)

static func goblin(model: Node3D, look: int, weapon: int, b: Brush) -> Marker3D:
	var rig: Node3D = model.get_node("Rig/Hips/Spine")
	var old: Node3D = rig.get_node("ClubShoulder/Elbow/PropSocket/RootwoodClub")
	var grip := b.marker(old.get_parent(),"HandLSocket",Vector3.ZERO)
	var free := b.marker(rig.get_node("FreeShoulder/Elbow"),"HandRSocket",Vector3(0,-.304,.016))
	free.rotation_degrees = Vector3(42,0,-24)
	var head: Node3D = rig.get_node("Head")
	if look == 1:
		_paint(rig.get_node("CanvasJerkin"),"9db3a4")
		b.loft(head,"CrescentCopperCap",[[.223,Vector2(0,-.031),Vector2(.257,.235),"74614d"],[.272,Vector2(-.013,-.024),Vector2(.238,.213),"b68b53"],[.345,Vector2(-.025,-.054),Vector2(.164,.159),"a67e48"],[.391,Vector2(-.032,-.061),Vector2(.063,.086),"9d724d"]],10,1,.047)
		b.fold(head,"BoarCrest",Vector3(-.01,.324,.15),Vector3(-.038,.33,-.18),Vector3(-.027,.60,-.062),Vector3(.072,.406,-.043),Vector3(-.105,.413,-.01),"c69a69","8f5e45")
	else:
		if look == 2:
			_paint(rig.get_node("CanvasJerkin"),"a6a87c")
			b.loft(head,"RaisedBriarHood",[[.076,Vector2(0,-.146),Vector2(.235,.116),"645346"],[.215,Vector2(0,-.135),Vector2(.25,.215),"6f7558"],[.399,Vector2(.052,-.180),Vector2(.202,.152),"88906b"],[.53,Vector2(.105,-.30),Vector2(.023,.026),"63694a"]],9,1,.072)
			var tablet := b.joint(free,"ShieldAnchor",Vector3(.028,.039,.063),Vector3(-26,-13,-22))
			Props.shield(tablet,b,.226,"838965")
	if look != 0 or weapon != Props.AUTO:
		old.hide()
		Props.attach(grip,weapon if weapon != Props.AUTO else ([Props.CLUB,Props.SPEAR,Props.SABER] as Array)[look],b)
	return grip

static func wolf(model: Node3D, look: int, b: Brush) -> void:
	if look == 0: return
	var body: Node3D = model.get_node("Rig/Body")
	var head: Node3D = body.get_node("Head")
	var tail: Node3D = body.get_node("Tail")
	if look == 1:
		model.scale = Vector3(1.13,1.05,1.)
		_paint(body.get_node("SaddleAndRuff"),"e1dfd0")
		b.loft(body,"WinterCape",[[.05,Vector2(0,.15),Vector2(.220,.245),"a29c95"],[.26,Vector2(0,.119),Vector2(.375,.355),"c3bcab"],[.46,Vector2(0,.151),Vector2(.398,.36),"ded8b9"],[.62,Vector2(0,.173),Vector2(.329,.302),"dbd4c0"],[.79,Vector2(0,.242),Vector2(.264,.21),"aaa79f"]],11,2,.083)
		for i in 2:
			var s := float(i*2-1)
			for j in 3:
				b.fold(body,"WinterGuard%d%d"%[i,j],Vector3(s*.23,.32-.17*j,.62),Vector3(s*.30,.16-.17*j,.48),Vector3(s*(.55-.04*j),.18-.17*j,.23-.075*j),Vector3(s*.403,.23-.17*j,.462),Vector3(s*.275,.17-.17*j,.425),"e2d9bf","a59b8c")
	else:
		model.scale = Vector3(.87,.91,1.05)
		for path in ["SaddleAndRuff","Head/WedgeHead","Head/Jaw/Chin"]:
			_paint(body.get_node(path),"d7a17b")
		for side in ["L","R"]:
			(body.get_node("FurFan"+side) as Node3D).hide()
			(body.get_node("BreastLock"+side) as Node3D).hide()
			var ear: Node3D = head.get_node("Ear"+side)
			for part: MeshInstance3D in ear.find_children("*","MeshInstance3D",false,false): part.scale.y *= 1.33
		tail.get_node("BrushTail").hide()
		b.loft(tail,"BlackSickleTail",[[.038,Vector2.ZERO,Vector2(.084,.088),"57473e"],[-.27,Vector2(.037,.013),Vector2(.093,.084),"a37556"],[-.55,Vector2(.103,.070),Vector2(.092,.077),"8c644f"],[-.76,Vector2(.141,.206),Vector2(.057,.064),"5e4d44"],[-.86,Vector2(.136,.35),Vector2(.025,.027),"514640"],[-.83,Vector2(.129,.427),Vector2(.005,.007),"433942"]],9,2,.047)

static func rat(model: Node3D, look: int, b: Brush) -> void:
	if look == 0: return
	var body: Node3D = model.get_node("Rig/Body")
	var head: Node3D = body.get_node("Head")
	if look == 1:
		model.scale = Vector3(1.15,.88,1.05)
		_paint(body.get_node("RoundHaunch"),"a99580")
		_paint(head.get_node("RatWedge"),"bbba95")
		for i in 5:
			var at := Vector3((i%3-1)*.134,.222-.01*(i%2),-.36+float(i%2)*.185)
			var up := Vector3((i%3-1)*.82,1,.21).normalized()
			var cap := at+up*(.123+.045*(i%3))
			b.link(body,"Mycelia%d"%i,at,cap,.031,.045,"bfb899",6)
			b.oval(body,"FanCap%d"%i,cap,Vector3(.216+.034*(i%2),.077,.158),"dda372" if i%2==0 else "bc805f",Vector3(12,-10,28*(i%3-1)),8)
	else:
		model.scale = Vector3(.89,1.06,1.05)
		_paint(body.get_node("RoundHaunch"),"ccab99")
		_paint(head.get_node("RatWedge"),"d1a283")
		for i in 2:
			var s := float(i*2-1)
			var ear: Node3D = head.get_node("EarL" if i==0 else "EarR")
			b.oval(ear,"TallEar",Vector3(0,.073,-.015),Vector3(.234,.402,.138),"a97c79",Vector3(0,0,-17*s),9)
			b.oval(ear,"RoseInset",Vector3(.003,.084,.054),Vector3(.156,.302,.044),"c49790",Vector3(0,0,-17*s),8)
			b.fold(body,"SaddleRag%d"%i,Vector3(s*.081,.245,.238),Vector3(s*.091,.254,-.268),Vector3(s*.342,-.078,-.091),Vector3(s*.254,.151,-.053),Vector3(s*.22,.074,-.039),"657d79" if i==0 else "73928a","4d5e60")
		b.oval(body,"CastOffButton",Vector3(.243,.144,.146),Vector3(.084,.084,.084),"b89461")

static func skeleton(model: Node3D, look: int, weapon: int, b: Brush) -> Marker3D:
	var spine: Node3D = model.get_node("Rig/Pelvis/Spine")
	var head: Node3D = spine.get_node("Skull")
	var defense: Node3D = spine.get_node("ShieldShoulder/Elbow/ShieldSocket")
	b.marker(defense,"ShieldSocketMarker",Vector3.ZERO)
	var elbow: Node3D = spine.get_node("FreeShoulder/Elbow")
	var socket := b.marker(elbow,"HandLSocket",Vector3(0,-.389,.056))
	socket.rotation_degrees = Vector3(59,-5,-18)
	if look != 0:
		defense.get_node("KiteShield").hide()
		if look == 1:
			Props.shield(defense,b,.316,"759084")
			b.loft(head,"VerdiHelmet",[[.144,Vector2.ZERO,Vector2(.215,.169),"8a9b8a"],[.203,Vector2(0,-.027),Vector2(.189,.165),"6a8178"],[.280,Vector2(0,-.031),Vector2(.142,.133),"8d9c81"],[.328,Vector2(0,-.048),Vector2(.067,.080),"807554"]],10,1,.052)
			b.box(head,"BeakGuard",Vector3(.008,.124,.167),Vector3(.056,.20,.052),"aa986a")
		else:
			for i in 7:
				var a := TAU*float(i)/7.
				var d := Vector3(cos(a),0,sin(a))
				b.link(head,"ReliquaryTooth%d"%i,d*.152+Vector3.UP*.203,d*.193+Vector3.UP*(.33+.073*(i%2)),.039,.014,"bd9b65",5)
			b.link(head,"Circlet",Vector3.UP*.186,Vector3.UP*.23,.185,.179,"907349",9)
			b.fold(spine,"FuneralBanner",Vector3(-.29,.49,-.108),Vector3(.255,.50,-.126),Vector3(.162,-.30,-.24),Vector3(.032,.11,-.276),Vector3(.031,.11,-.144),"9c645a","6c4655")
	Props.attach(socket,weapon if weapon != Props.AUTO else ([Props.EMPTY,Props.MACE,Props.SPEAR] as Array)[look],b)
	return socket

static func maw(model: Node3D, look: int, b: Brush) -> void:
	if look == 0: return
	var jaw: Node3D = model.get_node("UpperPetals")
	if look == 1:
		model.scale = Vector3(1.10,1.10,1.)
		for i in 7:
			var a := i*TAU/7.
			var d := Vector3(sin(a),0,cos(a))
			var cross := d.cross(Vector3.UP)
			var start := d*.224+Vector3.UP*.101
			b.fold(model,"ThornBlade%d"%i,start+cross*.058,start-cross*.069,d*(.63+.10*(i%2))+Vector3.UP*(.68+.12*(i%3)),d*.474+Vector3.UP*.428,d*.36+Vector3.UP*.242,"ae9b66","696d49")
		for i in 5:
			var x := -.27+.135*i
			b.link(jaw,"CalyxHook%d"%i,Vector3(x,.142,.29),Vector3(x*1.25,.36+.029*(i%2),.104),.046,.009,"d7b17b",5)
	else:
		model.scale = Vector3(.98,.89,1.08)
		for i in 6:
			var a := i*TAU/6.+.23
			var d := Vector3(sin(a),0,cos(a))
			var cross := d.cross(Vector3.UP)
			var at := d*.32+Vector3.UP*.57
			b.fold(model,"SplitOrchidSepal%d"%i,at+cross*.178,at-cross*.16,d*.84+Vector3.UP*(.59+.14*(i%2)),d*.63+Vector3.UP*.75,d*.55+Vector3.UP*.45,"c49cbb","7d5a89")
		for i in 3:
			var x := -.19+i*.19
			b.oval(jaw,"PollenLobe%d"%i,Vector3(x,.266,.29-absf(x)*.25),Vector3(.131,.102,.262),"d7b082",Vector3(-11,0,13*(i-1)),8)

static func _paint(mesh: MeshInstance3D, tint: String) -> void:
	var paint := mesh.get_active_material(0).duplicate() as StandardMaterial3D
	paint.albedo_color = Color(tint)
	mesh.material_override = paint
