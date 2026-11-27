extends RefCounted
## Decorative socket-local +Y points up the haft, +Z faces the viewer.
const Brush := preload("res://art/monster_trial/source/brush.gd")
const AUTO := 0
const EMPTY := 1
const CLUB := 2
const SPEAR := 3
const CLEAVER := 4
const AXE := 5
const MACE := 6
const SABER := 7
const SICKLE := 8

static func attach(socket: Node3D, kind: int, b: Brush) -> Node3D:
	if kind <= EMPTY:
		return null
	var p := b.joint(socket, "DisplayProp", Vector3.ZERO)
	var wood := "604233"
	var iron := "7d8584"
	var edge := "c5c6aa"
	var rivet := "c5965e"
	match kind:
		CLUB:
			b.loft(p,"Knotwood",[[-.20,Vector2.ZERO,Vector2(.046,.044),"443333"],[.28,Vector2.ZERO,Vector2(.053,.060),wood],[.49,Vector2(.02,0),Vector2(.127,.105),"946544"],[.81,Vector2(-.04,.018),Vector2(.122,.108),"b68c59"],[.89,Vector2(-.045,.011),Vector2(.079,.067),"805641"]],8,1,.08)
			b.link(p,"ForgedBand",Vector3(0,.52,0),Vector3(-.012,.62,.009),.130,.134,iron,8)
			b.oval(p,"Pin",Vector3(0,.57,.126),Vector3(.080,.080,.042),rivet)
		SPEAR:
			b.link(p,"LongHaft",Vector3(0,-.52,0),Vector3(0,.77,0),.032,.036,wood)
			b.link(p,"Socket",Vector3(0,.67,0),Vector3(0,.83,0),.051,.045,rivet,7)
			_blade(b,p,"LeafIron",[Vector2(0,.75),Vector2(.115,.87),Vector2(.074,1.02),Vector2(0,1.12),Vector2(-.087,.96),Vector2(-.115,.86)],.039,edge,iron)
			b.fold(p,"Pennon",Vector3(0,.67,.011),Vector3(0,.50,.02),Vector3(.29,.50,.014),Vector3(.11,.61,.077),Vector3(.11,.61,-.025),"be6645","744339")
		CLEAVER, SABER, SICKLE:
			b.link(p,"Tang",Vector3(0,-.17,0),Vector3(0,.18,0),.035,.037,wood)
			b.link(p,"CrossGuard",Vector3(-.12,.14,0),Vector3(.14,.14,.02),.044,.036,rivet,6)
			if kind == CLEAVER:
				_blade(b,p,"SplitIron",[Vector2(-.06,.17),Vector2(.095,.18),Vector2(.185,.72),Vector2(.13,.83),Vector2(.04,.77),Vector2(-.08,.87)],.042,"acb3a5","687a76")
			elif kind == SABER:
				_blade(b,p,"BowBlade",[Vector2(-.034,.17),Vector2(.055,.17),Vector2(.112,.48),Vector2(.045,.76),Vector2(-.086,.86),Vector2(-.043,.58),Vector2(-.019,.41)],.027,"dfc99e","8e8176")
			else:
				var outer := [Vector2(-.02,.16),Vector2(.035,.38),Vector2(.15,.55),Vector2(.36,.57),Vector2(.48,.47),Vector2(.48,.33)]
				var inner := [Vector2(.05,.17),Vector2(.13,.37),Vector2(.24,.45),Vector2(.37,.45),Vector2(.43,.40),Vector2(.48,.33)]
				for i in outer.size()-1:
					_blade(b,p,"Crescent%d"%i,[outer[i],outer[i+1],inner[i+1],inner[i]],.023,"b1a394","726759")
		AXE:
			b.link(p,"TwoToneHaft",Vector3(0,-.29,0),Vector3(0,.79,0),.040,.041,wood)
			b.link(p,"LuggedEye",Vector3(0,.53,0),Vector3(0,.79,0),.077,.070,iron)
			_blade(b,p,"CrescentAxe",[Vector2(-.055,.56),Vector2(.11,.57),Vector2(.30,.39),Vector2(.45,.52),Vector2(.43,.77),Vector2(.29,.91),Vector2(.12,.75),Vector2(-.055,.75)],.057,edge,"708182")
			_blade(b,p,"Poll",[Vector2(-.04,.56),Vector2(-.22,.55),Vector2(-.20,.78),Vector2(-.04,.75)],.060,"99987e",iron)
		MACE:
			b.link(p,"WornHaft",Vector3(0,-.16,0),Vector3(0,.57,0),.031,.040,wood)
			b.oval(p,"BronzeCore",Vector3(0,.61,0),Vector3(.235,.285,.235),"8c764e",Vector3.ZERO,7)
			for i in 5:
				var d := Vector3(sin(TAU*i/5.),0,cos(TAU*i/5.))
				b.link(p,"CrownFlange%d"%i,Vector3.UP*.61+d*.075,Vector3.UP*.64+d*.196,.064,.023,rivet,4)
	b.link(p,"GripWrap",Vector3(0,-.080,0),Vector3(0,.095,0),.042,.042,"503d39",6)
	return p

static func shield(anchor: Node3D, b: Brush, radius: float, color: String) -> void:
	b.link(anchor,"ShieldRim",Vector3(0,0,-.036),Vector3(0,0,.03),radius,radius,"64544e",10)
	b.link(anchor,"ShieldFace",Vector3(0,0,.027),Vector3(0,0,.055),radius*.91,radius*.86,color,10)
	b.oval(anchor,"ShieldBoss",Vector3(0,0,.061),Vector3.ONE*radius*.75,"b99366")
	for i in 5:
		var a := TAU*i/5.
		b.oval(anchor,"RimPin%d"%i,Vector3(cos(a),sin(a),0)*radius*.76+Vector3.BACK*.057,Vector3.ONE*.047,"b9a477",Vector3.ZERO,6)

static func _blade(b: Brush, p: Node3D, label: String, outline: Array, thickness: float, bright: String, dark: String) -> void:
	var st := b.surface()
	var flat := PackedVector2Array(outline)
	var indices := Geometry2D.triangulate_polygon(flat)
	for i in range(0, indices.size(), 3):
		for side: float in [-1,1]:
			var z := thickness * side
			var a := flat[indices[i]]
			var c := flat[indices[i+1]]
			var d := flat[indices[i+2]]
			b.flat(st,Vector3(a.x,a.y,z),Vector3(c.x,c.y,z),Vector3(d.x,d.y,z),Vector3.BACK*side,Color(dark).lerp(Color(bright),.12+.18*float(i%2)))
	for i in flat.size():
		var a := flat[i]
		var c := flat[(i+1)%flat.size()]
		var t := (c-a).orthogonal()
		var n := Vector3(t.x,t.y,0) * (-1.0 if Geometry2D.is_polygon_clockwise(flat) else 1.0)
		var ridge := Vector3((a.x+c.x)*.5,(a.y+c.y)*.5,0) + n.normalized()*.014
		for side: float in [-1,1]:
			b.flat(st,Vector3(a.x,a.y,thickness*side),Vector3(c.x,c.y,thickness*side),ridge,n,Color(bright).darkened(.10 if side<0 else 0.0))
	b.finish(p,label,st)
