extends RefCounted
## Two original volumetric characters, sharing an articulated hierarchy and
## planted-leg solver. Animation libraries are reused within each species.
const Kit := preload("res://art/monster_trial/source/rig.gd")
const Brush := preload("res://art/monster_trial/source/brush.gd")
const Props := preload("res://art/monster_variants/fantasy_props.gd")
static var _libraries: Dictionary = {}

static func build(orc: bool, look: int, weapon: int) -> Node3D:
	var kit := Kit.new("Model")
	var b: Brush = kit.b
	var skin: String = (["78834f","929553","79875e"] if orc else ["96977b","b3a78a","839088"])[look]
	var shade := Color(skin).darkened(.23).to_html(false)
	var high := Color(skin).lightened(.15).to_html(false)
	var cloth: String = (["6d4839","934e38","393b47"] if orc else ["6e6754","b49e79","4c6267"])[look]
	var boot := "503831" if orc else "484647"
	var w := 1.0 if orc else .65
	var height := .86 if orc else .70
	var hip := b.joint(kit.rig,"Hips",Vector3(0,height,-.026))
	var chest := b.joint(hip,"Torso",Vector3.ZERO,Vector3(11 if orc else 25,0,-6 if orc else -11))
	var neck := b.joint(chest,"Neck",Vector3(0,.655 if orc else .59,.081 if orc else .033),Vector3(-10 if orc else 16,0,9 if not orc else 1))
	var posture := b.joint(neck,"Profile",Vector3.ZERO,Vector3(0,0,[0,8,-8][look]))
	var shape := Vector3([1.0,1.08,.97][look],1,[1.0,1.08,.91][look])
	var armor := b.joint(chest,"Clothes",Vector3.ZERO)
	armor.scale = shape
	b.loft(armor,"CoatVolume",[[-.15,Vector2(0,-.021),Vector2(.32*w,.245*w),"56392e" if orc else "5d514c"],[.045,Vector2.ZERO,Vector2(.294*w,.234*w),cloth],[.20,Vector2(0,.022),Vector2(.32*w,.269*w),cloth],[.43,Vector2(0,.006),Vector2(.455*w,.288*w),cloth],[.55,Vector2(0,-.020),Vector2(.423*w,.245*w),skin if orc else cloth],[.63,Vector2(0,.015),Vector2(.184*w,.155*w),shade]],12,1,.055)
	b.link(chest,"NeckSkin",Vector3(0,.52,.034),Vector3(0,.703,.099),.183*w,.142*w,skin,8)
	b.loft(armor,"Belt",[[-.06,Vector2.ZERO,Vector2(.324*w,.25*w),"443533"],[.066,Vector2.ZERO,Vector2(.32*w,.245*w),"71533f"]],10)
	b.box(armor,"Clasp",Vector3(.04,.003,.251*w),Vector3(.119,.095,.044),"ad875c",Vector3(0,2,-9))
	b.fold(armor,"LoinFlap",Vector3(-.263*w,.015,.248*w),Vector3(.255*w,-.037,.246*w),Vector3(.025,-.34,.174*w),Vector3(0,-.105,.298*w),Vector3(0,-.110,.156*w),cloth,"544147")
	_face(b,posture,orc,skin,shade,high,look)
	var legs: Array[Kit.Leg] = []
	var arms: Array[Node3D] = []
	var elbows: Array[Node3D] = []
	var sockets: Array[Marker3D] = []
	var shoulders: Array[Node3D] = []
	for i in 2:
		var s := float(i*2-1)
		var suffix := "L" if i == 0 else "R"
		var arm := b.joint(chest,"Shoulder"+suffix,Vector3(s*(.381 if orc else .222),.469,.01),Vector3(-23 if orc else (-68 if i==0 else -35),0,s*(19 if orc else 12)))
		var mantle := b.joint(arm,"Mantle",Vector3(0,-.022,0))
		shoulders.append(mantle)
		b.oval(arm,"UpperArm",Vector3(0,-.135,0),Vector3(.306,.379,.32) if orc else Vector3(.163,.342,.166),skin,Vector3(0,0,4*s))
		b.link(arm,"RagSleeve",Vector3(0,.035,0),Vector3(0,-.15 if orc else -.19,0),.174 if orc else .101,.138 if orc else .087,cloth,8)
		var elbow := b.joint(arm,"Elbow",Vector3(0,-.33,0),Vector3(-52 if orc and i==0 else (-39 if orc else -23),0,s*7))
		b.loft(elbow,"Forearm",[[-.295,Vector2(0,.026),Vector2(.079*w,.085*w),shade],[-.16,Vector2.ZERO,Vector2(.121*w,.122*w),skin],[-.032,Vector2.ZERO,Vector2(.143*w,.142*w),high],[.05,Vector2.ZERO,Vector2(.099*w,.101*w),skin]],8,1,.037)
		if orc or i == 1:
			b.link(elbow,"Wristwrap",Vector3(0,-.25,0),Vector3(0,-.16,0),.111*w,.122*w,"6b5144",7)
		var fist := Vector3(0,-.309,.031)
		b.oval(elbow,"Hand",fist,Vector3(.190*w,.203,.157*w),high,Vector3(0,0,6*s),8)
		for finger in 3:
			var at := fist + Vector3((finger-1)*.045*w,-.049,.030)
			b.link(elbow,"Knuckle%d"%finger,at,at+Vector3(.004,-.082,.031 if orc else .052),.027*w,.017*w,skin,5)
		var socket := b.marker(elbow,"Hand"+suffix+"Socket",fist)
		socket.rotation_degrees = Vector3(60,-8*s,21*s) if orc else Vector3(16,0,26*s)
		sockets.append(socket)
		arms.append(arm)
		elbows.append(elbow)
		var x := s*(.226 if orc else .145)
		var ankle := Vector3(x,.119 if orc else .079,-s*.039 if orc else (-.17 if i==1 else .043))
		var leg := Kit.Leg.new(b,kit.rig,"Leg"+suffix,Vector3(x,height-.058,0),ankle,Vector3(.413,.359,0) if orc else Vector3(.358,.325,0),1.)
		b.loft(leg.top,"Thigh",[[-leg.l1,Vector2.ZERO,Vector2(.10*w,.11*w),boot],[-.16,Vector2(0,.013),Vector2(.162*w,.163*w),cloth],[.015,Vector2.ZERO,Vector2(.177*w,.169*w),cloth]],8,1,.05)
		b.link(leg.shin,"Shank",Vector3(0,.045,0),Vector3(0,-leg.l2,0),.105*w,.077*w,boot if orc or i==0 else shade,7)
		if orc:
			b.oval(leg.shin,"KneePlate",Vector3(0,-.031,.083),Vector3(.208,.22,.102),"857063",Vector3.ZERO,7)
		else:
			b.fold(leg.top,"TornHem",Vector3(-.106,-.16,.045),Vector3(.095,-.20,.059),Vector3(s*.088,-.417,.028),Vector3(0,-.27,.138),Vector3(0,-.19,-.010),cloth,"64554c")
		b.oval(leg.paw,"Foot",Vector3(0,-.04,.070),Vector3(.251*w,.148 if orc else .079,.414 if orc else .308),boot if orc or i==0 else skin,Vector3(0,s*8,0),8)
		legs.append(leg)
	_dress(b,orc,look,chest,posture,shoulders)
	var default_weapon: int = ([Props.AXE,Props.CLEAVER,Props.CLUB] if orc else [Props.EMPTY,Props.SICKLE,Props.SABER])[look]
	if weapon == Props.AUTO:
		weapon = default_weapon
	Props.attach(sockets[0 if orc else 1],weapon,b)
	if _libraries.has(orc):
		kit.player.remove_animation_library(&"")
		kit.player.add_animation_library(&"",_libraries[orc])
	else:
		var parts: Array[Node3D] = [kit.rig,hip,chest,neck]
		parts.append_array(arms)
		parts.append_array(elbows)
		for leg in legs: parts.append_array(leg.joints())
		kit.bind(parts)
		kit.clip(&"idle",3.15 if orc else 3.8,true,func(p: float) -> void:
			var wv := sin(TAU*p)
			chest.rotation_degrees += Vector3(3*wv,3*wv,2*wv)
			neck.rotation_degrees += Vector3(5*wv,-7*wv,2*wv)
			arms[0].rotation_degrees.x -= 7*wv
			arms[1].rotation_degrees.z += 4*wv
		)
		kit.clip(&"move",1.02 if orc else 1.48,true,func(p: float) -> void:
			var wv := sin(TAU*p)
			var rise := (.027 if orc else .019) * (1.-cos(2.*TAU*p))
			hip.position.y += rise
			chest.rotation_degrees += Vector3(8 if orc else 15,8*wv,6*wv)
			neck.rotation_degrees.x -= 3*wv
			arms[0].rotation_degrees.x += (24 if orc else 15)*wv
			arms[1].rotation_degrees.x -= (29 if orc else 10)*wv
			for i in 2:
				var leg := legs[i]
				var stride := Kit.stride(p+i*.5,.34 if orc else (.34 if i==0 else .19),.115 if orc else (.071 if i==0 else .024),.61 if orc else .74)
				leg.solve(leg.rest_socket+Vector3(0,rise,.013),leg.rest_ankle+Vector3(0,stride.x,stride.y),-stride.x*2.)
		)
		kit.clip(&"signature",1.83 if orc else 2.26,false,func(p: float) -> void:
			var lift := smoothstep(.08,.38,p)*(1.-smoothstep(.59,.96,p))
			var swing := sin(p*TAU) * lift
			chest.rotation_degrees += Vector3(lift*(-18 if orc else 27),swing*(25 if orc else 13),7*lift)
			neck.rotation_degrees += Vector3(lift*(-18 if orc else 12),swing*13,13*lift)
			arms[0].rotation_degrees += Vector3(lift*(-53 if orc else -36),0,lift*(-23 if orc else -6))
			arms[1].rotation_degrees += Vector3(lift*(-41 if orc else -48),0,lift*23)
			elbows[0].rotation_degrees.x += lift*(-22 if orc else 26)
		)
		_libraries[orc] = kit.library
	return kit.root

static func _face(b: Brush, head: Node3D, orc: bool, skin: String, shade: String, high: String, look: int) -> void:
	var w := 1.0 if orc else .73
	b.loft(head,"Cranium",[[-.113,Vector2(0,.055),Vector2(.151*w,.138*w),shade],[-.032,Vector2(0,.063),Vector2(.228*w,.184*w),skin],[.114,Vector2(0,.011),Vector2(.239*w,.204*w),skin],[.233,Vector2(0,-.005),Vector2(.204*w,.178*w),high],[.304,Vector2(0,-.025),Vector2(.131*w,.109*w),shade]],10,1,.041)
	b.oval(head,"SnubNose",Vector3(0,.059,.220*w),Vector3((.183 if orc else .089),.103,.122*w),high,Vector3(-12,0,0),8)
	b.oval(head,"Mouth",Vector3(0,-.046,.214*w),Vector3(.247*w,.051,.035),"443833",Vector3(0,0,8 if not orc else -4),8)
	b.oval(head,"HeavyJaw",Vector3(0,-.101,.145*w),Vector3(.392*w,.116,.199*w),shade)
	for i in 2:
		var s := float(i*2-1)
		var x := s*.117*w
		var y := .137+(.017*i if not orc else .0)
		b.oval(head,"EyeHollow%d"%i,Vector3(x,y,.173*w),Vector3(.153*w,.075,.075),"4c493b" if orc else "424049",Vector3(0,s*22,s*-10))
		b.oval(head,"Eye%d"%i,Vector3(x,y,.216*w+.017),Vector3(.071*w,.031,.023),"e2b568" if orc else ("dbcc92" if i==0 else "746f63"))
		b.oval(head,"Brow%d"%i,Vector3(x,y+.045,.183*w),Vector3(.184*w,.070,.105),shade,Vector3(0,s*20,s*18))
		if orc:
			b.fold(head,"PrickedEar%d"%i,Vector3(s*.175,.041,-.015),Vector3(s*.214,.153,-.026),Vector3(s*.388,.214,-.089),Vector3(s*.246,.101,.046),Vector3(s*.243,.102,-.052),high,shade)
			var tip := Vector3(s*(.155+.019*i),.027+.034*i,.256)
			b.link(head,"Tusk%d"%i,Vector3(s*.104,-.098,.214),tip,.041,.013,"d6bd90",6)
			b.link(head,"TuskTip%d"%i,tip,tip+Vector3(s*.013,.065,.008),.014,.003,"e5cea6",6)
		else:
			b.oval(head,"Ear%d"%i,Vector3(s*.166,.067,-.02),Vector3(.071,.117,.090),shade,Vector3(0,0,s*-17))
	if orc or look == 0:
		b.loft(head,"ScalpAndHair",[[.15,Vector2(0,-.054),Vector2(.196*w,.127*w),"433433"],[.24,Vector2(.02,-.067),Vector2(.199*w,.145*w),"514039"],[.322,Vector2(-.024,-.081),Vector2(.116*w,.092*w),"57402e"]],9,1,.10)

static func _dress(b: Brush, orc: bool, look: int, chest: Node3D, head: Node3D, shoulder: Array[Node3D]) -> void:
	if orc:
		b.link(chest,"ChestBaldric",Vector3(-.301,.11,.235),Vector3(.321,.499,.235),.065,.077,"584238",6)
		if look == 0:
			b.oval(shoulder[1],"RawhidePauldron",Vector3(.041,.0,-.007),Vector3(.398,.249,.393),"aa7d50",Vector3(0,15,12),9)
			for i in 3: b.oval(shoulder[1],"Pin%d"%i,Vector3(.131-i*.071,.05,.179),Vector3.ONE*.065,"e0ad5b")
		elif look == 1:
			for i in 2:
				for j in 3:
					b.box(shoulder[i],"LappedIron%d"%j,Vector3((i*2-1)*(.055+.031*j),.097-.065*j,0),Vector3(.367,.090,.437),"75817c" if j==0 else "685f54",Vector3(11-j*11,5,14*(i*2-1)))
			b.loft(head,"CopperVisor",[[.21,Vector2.ZERO,Vector2(.246,.219),"ab7044"],[.295,Vector2(0,-.024),Vector2(.224,.199),"b68b53"],[.376,Vector2(0,-.042),Vector2(.119,.098),"5e4637"]],10,1,.05)
			b.box(head,"NoseBar",Vector3(0,.151,.239),Vector3(.047,.16,.049),"a77a57")
		else:
			for i in 2:
				var s := float(i*2-1)
				b.oval(shoulder[i],"PeltRoll",Vector3(s*.069,.051,0),Vector3(.485,.270,.38),"76635b",Vector3(0,0,s*24),8)
				var a := Vector3(s*.169,.253,-.048)
				var mid := Vector3(s*.373,.353,-.077)
				b.link(head,"KeratinBase%d"%i,a,mid,.096,.062,"b29a73",7)
				b.link(head,"KeratinTip%d"%i,mid,Vector3(s*.442,.522,-.071),.063,.008,"dcc49b",7)
			b.fold(chest,"FurMantle",Vector3(-.46,.50,-.19),Vector3(.42,.50,-.17),Vector3(-.14,-.27,-.32),Vector3(.04,.25,-.345),Vector3(.05,.24,-.19),"6a6257","4a4850")
	else:
		if look == 0:
			b.fold(chest,"HangingVest",Vector3(-.285,.52,.093),Vector3(.04,.51,.184),Vector3(-.205,-.31,.154),Vector3(-.15,.22,.237),Vector3(-.145,.22,.118),"958069","665849")
			b.box(chest,"OpenCollar",Vector3(.106,.375,.182),Vector3(.063,.353,.03),"afa88a",Vector3(-10,0,-29))
		elif look == 1:
			b.loft(head,"ShroudHood",[[.081,Vector2(0,-.067),Vector2(.177,.133),"8c765f"],[.23,Vector2(0,-.053),Vector2(.206,.159),"b7a481"],[.37,Vector2(.029,-.094),Vector2(.141,.092),"d0bb92"],[.439,Vector2(.080,-.12),Vector2(.027,.043),"ac9775"]],9,1,.067)
			for i in 3:
				var x := -.21+.14*i
				b.fold(chest,"ShroudFlap%d"%i,Vector3(x-.11,.47,-.125),Vector3(x+.12,.43,.075),Vector3(x-.18,-.36+.07*i,-.058),Vector3(x-.08,.12,.17),Vector3(x,.075,-.18),"c8b992","867964")
		else:
			b.loft(head,"PeatBlackKettle",[[.174,Vector2(0,.005),Vector2(.265,.247),"555b59"],[.205,Vector2(0,.002),Vector2(.261,.239),"89846e"],[.237,Vector2(0,-.032),Vector2(.179,.174),"625d56"],[.322,Vector2(0,-.030),Vector2(.143,.132),"555a60"]],10,1,.055)
			b.fold(chest,"WaterloggedApron",Vector3(-.20,.43,.167),Vector3(.175,.40,.150),Vector3(.16,-.48,.20),Vector3(-.068,.15,.245),Vector3(0,.126,.159),"738689","454e58")
			b.link(shoulder[0],"BrokenPauldron",Vector3(0,.069,0),Vector3(0,-.082,0),.111,.131,"7b6c59",7)
