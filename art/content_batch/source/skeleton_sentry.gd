extends RefCounted
## Uneven bone ridges, hollow rib silhouette and a battered red kite shield.
## The body and shield are rigid articulated geometry; the animation is visual.
const Kit := preload("res://art/monster_trial/source/rig.gd")
const Brush := preload("res://art/monster_trial/source/brush.gd")
const HIP_Y := .925
const BONE := "d5c5a5"
const SUN_BONE := "e2d3b3"
const SHADOW_BONE := "aa9b85"

func build() -> PackedScene:
	var kit := Kit.new("SkeletonSentry")
	var b := kit.b
	var pelvis := b.joint(kit.rig,"Pelvis",Vector3(0,HIP_Y,0))
	_pelvis(b,pelvis)
	var spine := b.joint(pelvis,"Spine",Vector3(0,.121,-.015),Vector3(6,0,-4))
	_ribs(b,spine)
	var head := b.joint(spine,"Skull",Vector3(.007,.639,-.005),Vector3(-10,-5,3))
	var mandible := _skull(b,head)
	var shoulder := b.joint(spine,"ShieldShoulder",Vector3(.284,.468,-.003),Vector3(-19,-8,18))
	var shield_elbow := _arm(b,shoulder)
	shield_elbow.rotation_degrees = Vector3(-37,5,-12)
	var grip := b.joint(shield_elbow,"ShieldSocket",Vector3(.028,-.227,.092),Vector3(55,-9,-14))
	_shield(b,grip)
	var hand := b.joint(spine,"FreeShoulder",Vector3(-.278,.459,.001),Vector3(12,2,-14))
	var free_elbow := _arm(b,hand)
	free_elbow.rotation_degrees.x = -20.
	var rag := b.joint(pelvis,"Sash",Vector3(-.155,.066,.148),Vector3(-6,0,4))
	b.fold(rag,"FrayedWool",Vector3(-.097,-.015,0),Vector3(.077,-.012,.025),Vector3(-.125,-.284,.026),Vector3(-.092,-.102,.092),Vector3(-.053,-.071,-.056),"617c75","415d5b")
	b.fold(rag,"SashNotch",Vector3(-.035,-.086,.034),Vector3(.077,-.012,.025),Vector3(.018,-.203,.082),Vector3(.02,-.096,.072),Vector3(-.009,-.092,.027),"7a9080","50696a")
	var legs: Array[Kit.Leg] = []
	for i in 2:
		var s := 2.*i-1.
		var socket := Vector3(s*.159,HIP_Y-.04,.012)
		var step := Vector3(socket.x,.081,.013+s*.061)
		var leg := Kit.Leg.new(b,kit.rig,"LegL" if i==0 else "LegR",socket,step,Vector3(.423,.425,0),1.0)
		_foot(b,leg,s)
		legs.append(leg)
	var moving: Array[Node3D] = [pelvis,spine,head,mandible,shoulder,shield_elbow,grip,hand,free_elbow,rag]
	for leg in legs: moving.append_array(leg.joints())
	kit.bind(moving)
	kit.clip(&"idle",2.94,true,func(u: float) -> void:
		var w := sin(TAU*u)
		pelvis.position.y -= .009 * sin(PI*u)
		spine.rotation_degrees += Vector3(2.2*w,4.2*w,3.8*w)
		head.rotation_degrees += Vector3(-1.6*w,8.0*w,2.4*w)
		mandible.rotation_degrees.x += 8.*exp(-pow((u-.71)*37.,2.))
		shoulder.rotation_degrees.x -= 3.8*w
		free_elbow.rotation_degrees.x -= 5.2*w
		rag.rotation_degrees.z -= 6.1*w
		for leg in legs: leg.solve(_socket(pelvis,leg),leg.rest_ankle)
	)
	kit.clip(&"move",1.06,true,func(u: float) -> void:
		var w := sin(TAU*u)
		var bob := -.023*cos(2.*TAU*u) + .008*w
		pelvis.position.y += bob
		spine.rotation_degrees += Vector3(4.+3.1*w,-11.6*w,7.8*w)
		head.rotation_degrees += Vector3(-1.0+4.0*sin(TAU*2.*u),-5.*w,-6.*w)
		mandible.rotation_degrees.x += 12.0*pow(absf(sin(TAU*u+.58)),8.)
		shoulder.rotation_degrees.x -= 12.0*w
		shield_elbow.rotation_degrees.x -= 8.*w
		grip.rotation_degrees.z += 11.*w
		hand.rotation_degrees.x += 28.0*w
		free_elbow.rotation_degrees.x -= 10.0*w
		rag.rotation_degrees += Vector3(8.+12.*w,6.*w,-11.*w)
		for i in 2:
			var leg := legs[i]
			var step := Kit.stride(u + i*.54,.47,.142 if i==0 else .089,.57 if i==0 else .66)
			leg.solve(_socket(pelvis,leg),leg.rest_ankle + Vector3(0,step.x,step.y),-1.6*step.x)
	)
	kit.clip(&"rattle_guard",1.93,false,func(u: float) -> void:
		# Stops, looks, sets one foot, props the shield high on the outside and
		# clacks its jaw twice. No swing, projectile, root translation or hit.
		var v := Kit.curve([
			[0.,0.,0.,0.,0.,0.,0.,0.],
			[.11,-.019,-.041,-5.,-12.,4.,.027,.023],
			[.23,-.065,.017,9.,17.,24.,.132,.222],
			[.34,-.065,.078,13.,11.,54.,.038,.386],
			[.46,-.080,.081,15.,7.,50.,.0,.395],
			[.60,-.076,.077,12.,-7.,49.,.0,.395],
			[.70,-.064,.057,8.,-10.,33.,.036,.342],
			[.85,-.019,.008,2.,5.,8.,.106,.108],
			[1.,0.,0.,0.,0.,0.,0.,0.],
		],u)
		var clack_a := exp(-pow((u-.495)*36.,2.))
		var clack_b := exp(-pow((u-.612)*40.,2.))
		var rattle := (clack_a-clack_b)
		pelvis.position += Vector3(0,v[0],v[1])
		spine.rotation_degrees += Vector3(v[2],.70*v[3],-.156*v[4])
		head.rotation_degrees += Vector3(-.56*v[2]+rattle*7.2,-1.34*v[3]+rattle*9.3,.048*v[4])
		mandible.rotation_degrees.x += 33.*clack_a + 29.*clack_b
		shoulder.rotation_degrees += Vector3(-v[4],-.34*v[4],.35*v[4])
		shield_elbow.rotation_degrees += Vector3(-.36*v[4],.40*v[4],-.18*v[4])
		grip.rotation_degrees += Vector3(.94*v[4],-.25*v[4],-.27*v[4]+8.*rattle)
		hand.rotation_degrees += Vector3(.50*v[4],-.58*v[3],-.31*v[4])
		free_elbow.rotation_degrees.x -= .54*v[4]
		rag.rotation_degrees += Vector3(-.27*v[4],.32*v[3],.28*v[4])
		for i in 2:
			var leg := legs[i]
			var ankle := leg.rest_ankle + (Vector3(0,v[5],v[6]) if i==1 else Vector3.ZERO)
			leg.solve(_socket(pelvis,leg),ankle,-v[5]*1.3)
	)
	var scene := kit.pack()
	kit.root.free()
	return scene

func _socket(pelvis: Node3D, leg: Kit.Leg) -> Vector3:
	return pelvis.transform * (leg.rest_socket-Vector3.UP*HIP_Y)

func _pelvis(b: Brush, pelvis: Node3D) -> void:
	b.oval(pelvis,"Sacrum",Vector3(0,.009,-.084),Vector3(.204,.216,.145),SHADOW_BONE,Vector3(14,0,0),9)
	for s: float in [-1,1]:
		var a := Vector3(s*.04,.008,-.099)
		var c := Vector3(s*.177,.064,-.037)
		var d := Vector3(s*.205,.034,.057)
		var e := Vector3(s*.132,-.066,.093)
		b.fold(pelvis,"PelvicFlare",a,c,e,d,Vector3(s*.13,-.018,-.103),SUN_BONE,SHADOW_BONE)
		b.link(pelvis,"PelvicRing",e,Vector3(s*.042,-.081,.098),.054,.031,BONE,8)
		b.oval(pelvis,"BallJoint",Vector3(s*.158,-.049,.011),Vector3(.140,.137,.129),BONE,Vector3.ZERO,8)
	var belt := b.joint(pelvis,"CopperBuckle",Vector3(-.164,.052,.109),Vector3(0,-29,-14))
	b.box(belt,"OldLeather",Vector3(0,0,-.013),Vector3(.233,.108,.073),"76554a")
	b.box(belt,"Buckle",Vector3(0,0,.033),Vector3(.111,.084,.032),"af9063")
	b.box(belt,"Hollow",Vector3(0,0,.052),Vector3(.066,.049,.015),"705243")

func _ribs(b: Brush, spine: Node3D) -> void:
	for i in 7:
		var y := (i+.11)*.085
		var z := -.052-.042*sin(i*.78)
		var width := .106 + .024*sin(i*.74)
		b.oval(spine,"Vertebra",Vector3(0,y,z),Vector3(width,.085,.139),SHADOW_BONE,Vector3(6,0,0),9)
		b.oval(spine,"SpinousProcess",Vector3(0,y+.016,z-.055),Vector3(.052,.073,.109),BONE,Vector3(18,0,0),7)
	for s: float in [-1,1]:
		var arm := Vector3(s*.265,.472,-.016)
		b.oval(spine,"Shoulder",arm,Vector3(.142,.147,.147),BONE,Vector3.ZERO,10)
		b.link(spine,"Clavicle",Vector3(s*.036,.477,.086),Vector3(s*.139,.492,.062),.033,.048,SUN_BONE,8)
		b.link(spine,"OuterClavicle",Vector3(s*.139,.492,.062),arm,.043,.041,BONE,8)
		b.fold(spine,"Scapula",Vector3(s*.09,.431,-.085),Vector3(s*.243,.445,-.071),Vector3(s*.13,.258,-.126),Vector3(s*.14,.349,-.127),Vector3(s*.12,.391,-.051),BONE,SHADOW_BONE)
		for i in 4:
			var y := .151+i*.083
			var x := .157+.022*i
			var path := [Vector3(s*.022,y,-.089),Vector3(s*x*.67,y+.009,-.109),Vector3(s*x,y-.031,-.052),Vector3(s*x*.94,y-.052,.048),Vector3(s*x*.59,y-.066,.128),Vector3(s*(.087 if i==0 else .026),y-.049,.136)]
			for j in range(path.size()-1):
				var thick := .0295+.0024*i-.0019*j
				b.link(spine,"Rib",path[j],path[j+1],thick,thick*.91,SUN_BONE if j>1 else BONE,7)
				if j>0: b.oval(spine,"RibCurve",path[j],Vector3.ONE*(thick*1.95),BONE,Vector3.ZERO,7)
	b.loft(spine,"Sternum",[[.138,Vector2(0,.128),Vector2(.016,.017),SHADOW_BONE],[.211,Vector2(0,.141),Vector2(.038,.024),BONE],[.383,Vector2(0,.131),Vector2(.042,.026),SUN_BONE],[.437,Vector2(0,.101),Vector2(.037,.022),BONE]],9)
	b.link(spine,"NeckAtlas",Vector3(0,.493,-.041),Vector3(0,.657,-.006),.063,.073,BONE,8)

func _skull(b: Brush, skull: Node3D) -> Node3D:
	b.loft(skull,"Cranium",[
		[-.029,Vector2(0,.047),Vector2(.125,.108),SHADOW_BONE],
		[.054,Vector2(0,.004),Vector2(.204,.168),BONE],
		[.181,Vector2(0,-.029),Vector2(.239,.204),SUN_BONE],
		[.282,Vector2(0,-.037),Vector2(.221,.187),"e5d7b8"],
		[.365,Vector2(0,-.042),Vector2(.142,.142),"e1d1b3"],
		[.392,Vector2(0,-.035),Vector2(.050,.065),BONE],
	],14,Vector3.AXIS_Y,.028)
	b.oval(skull,"Maxilla",Vector3(0,.013,.112),Vector3(.292,.149,.209),BONE,Vector3(6,0,0),11)
	b.oval(skull,"MouthShadow",Vector3(0,-.049,.132),Vector3(.236,.060,.162),"634c43",Vector3(-7,0,0),11)
	for i in 4:
		var x := (i-1.5)*.045
		b.box(skull,"UpperTooth",Vector3(x,-.036,.204-absf(x)*.20),Vector3(.035,.045,.042),SUN_BONE,Vector3(-5,x*52,0))
	var jaw := b.joint(skull,"Mandible",Vector3(0,.023,.005),Vector3(5,0,0))
	var nose := Vector3(0,.078,.199)
	b.fold(skull,"NasalCavity",nose+Vector3(-.044,-.040,-.009),nose+Vector3(.045,-.040,-.009),nose+Vector3(.006,.061,-.018),nose+Vector3(0,-.006,.019),nose+Vector3(0,.008,-.024),"55484a","816a59")
	for s: float in [-1,1]:
		var eye := b.joint(skull,"Orbit",Vector3(s*.108,.161,.140),Vector3(-5.,s*23.,s*7.))
		b.oval(eye,"OrbitalRim",Vector3.ZERO,Vector3(.190,.162,.109),"c8b99a",Vector3.ZERO,10)
		b.oval(eye,"HollowSocket",Vector3(0,.002,.048),Vector3(.142,.118,.053),"4e4248",Vector3(3,0,-s*13),11)
		b.oval(eye,"BrowBone",Vector3(0,.068,.044),Vector3(.209,.069,.059),SUN_BONE,Vector3(-4,0,s*7),10)
		b.fold(skull,"CheekBone",Vector3(s*.051,.082,.177),Vector3(s*.171,.076,.133),Vector3(s*.202,.101,.038),Vector3(s*.158,.056,.177),Vector3(s*.104,.027,.086),SUN_BONE,SHADOW_BONE)
		b.link(jaw,"JawHinge",Vector3(s*.153,.009,.007),Vector3(s*.139,-.086,.051),.037,.035,BONE,8)
		b.link(jaw,"JawBranch",Vector3(s*.144,-.084,.044),Vector3(s*.100,-.105,.161),.038,.040,SUN_BONE,8)
		b.link(jaw,"Chin",Vector3(s*.102,-.105,.161),Vector3(0,-.108,.198),.038,.038,BONE,8)
		for i in 2:
			b.box(jaw,"LowerTooth",Vector3(s*(.029+i*.046),-.078,.194-.012*i),Vector3(.035,.035,.034),SUN_BONE,Vector3(7,0,s*5.))
	b.marker(skull,"Look",Vector3(0,.164,.241))
	b.marker(jaw,"ChinTip",Vector3(0,-.115,.217))
	return jaw

func _arm(b: Brush, parent: Node3D) -> Node3D:
	b.link(parent,"Humerus",Vector3(0,-.013,0),Vector3(0,-.340,0),.049,.042,BONE,9)
	b.oval(parent,"UpperBoneHead",Vector3(0,-.044,.001),Vector3(.135,.137,.132),SUN_BONE,Vector3.ZERO,9)
	var elbow := b.joint(parent,"Elbow",Vector3(0,-.365,.012))
	b.oval(elbow,"ElbowJoint",Vector3(0,.013,0),Vector3(.129,.126,.118),SHADOW_BONE,Vector3.ZERO,9)
	for s: float in [-1,1]:
		b.link(elbow,"ForearmBone",Vector3(s*.033,-.023,-.010),Vector3(s*.025,-.300,.025+s*.013),.028,.024,SUN_BONE if s<0. else BONE,8)
	b.oval(elbow,"Wrist",Vector3(0,-.304,.028),Vector3(.094,.088,.082),BONE,Vector3.ZERO,9)
	b.oval(elbow,"Palm",Vector3(.002,-.356,.041),Vector3(.105,.114,.066),BONE,Vector3(-13,0,0),9)
	for i in 4:
		var x := (i-1.5)*.026
		var a := Vector3(x,-.379,.039)
		var c := Vector3(x*1.23,-.419-(1.-absf(i-1.5)/1.5)*.027,.056)
		var d := c+Vector3(x*.12,-.033,.026)
		b.link(elbow,"Finger",a,c,.0145,.012,SUN_BONE,6)
		b.link(elbow,"Phalanx",c,d,.013,.009,SHADOW_BONE,6)
	b.link(elbow,"Thumb",Vector3(-.036,-.338,.036),Vector3(-.084,-.379,.071),.020,.016,BONE,7)
	return elbow

func _foot(b: Brush, leg: Kit.Leg,s: float) -> void:
	b.link(leg.top,"Femur",Vector3(0,-.023,0),Vector3(0,-leg.l1,0),.060,.047,BONE,8)
	b.oval(leg.top,"FemoralKnot",Vector3(0,-.069,.004),Vector3(.125,.159,.119),SUN_BONE,Vector3(7,s*11.,0),9)
	b.oval(leg.shin,"Kneecap",Vector3(0,-.013,.018),Vector3(.148,.151,.133),SUN_BONE,Vector3.ZERO,9)
	b.link(leg.shin,"Shin",Vector3(-s*.024,-.027,.024),Vector3(-s*.014,-leg.l2,.005),.040,.033,BONE,8)
	b.link(leg.shin,"SecondBone",Vector3(s*.035,-.051,-.017),Vector3(s*.026,-leg.l2,.017),.029,.025,SHADOW_BONE,8)
	b.oval(leg.paw,"Ankle",Vector3(0,-.015,.009),Vector3(.137,.101,.122),SHADOW_BONE,Vector3.ZERO,9)
	b.oval(leg.paw,"Tarsal",Vector3(0,-.041,.055),Vector3(.132,.076,.159),BONE,Vector3(9,0,0),9)
	for i in 4:
		var x := (i-1.5)*.032
		b.link(leg.paw,"Toe",Vector3(x*.78,-.043,.084),Vector3(x*1.13,-.058,.173+(.02 if i==1 else -.012*i)),.022,.017,SUN_BONE,7)
	b.marker(leg.paw,"Sole",Vector3(0,-.081,.10))

func _shield(b: Brush, grip: Node3D) -> void:
	var shield := b.joint(grip,"KiteShield",Vector3(.018,-.078,.014),Vector3(0,4,-3))
	var outline := [Vector2(-.343,.256),Vector2(-.262,.366),Vector2(-.002,.398),Vector2(.262,.363),Vector2(.357,.254),Vector2(.299,-.023),Vector2(.217,-.244),Vector2(.035,-.476),Vector2(-.041,-.435),Vector2(-.225,-.241),Vector2(-.299,-.026)]
	var surf := b.surface()
	var red := Color("9a5c4d")
	var rim := Color("9a9282")
	for i in outline.size():
		var p: Vector2 = outline[i]
		var q: Vector2 = outline[(i+1)%outline.size()]
		var a := Vector3(p.x,p.y,.015)
		var c := Vector3(q.x,q.y,.015)
		var d := Vector3(q.x*.861,q.y*.895,.045)
		var e := Vector3(p.x*.861,p.y*.895,.045)
		var pigment := red.lightened(.10) if p.x+q.x<0.0 else red.darkened(.055)
		var edge := rim.lightened(.11*sin(i*2.7))
		b.flat(surf,a,c,d,Vector3.BACK,edge)
		b.flat(surf,a,d,e,Vector3.BACK,edge)
		b.flat(surf,e,d,Vector3(-.013,.024,.143),Vector3.BACK,pigment)
		b.flat(surf,a,a+Vector3.FORWARD*.061,c+Vector3.FORWARD*.061,(a+c).slide(Vector3.BACK),Color("5b514e"))
		b.flat(surf,a,c+Vector3.FORWARD*.061,c,(a+c).slide(Vector3.BACK),Color("5b514e"))
		b.flat(surf,a+Vector3.FORWARD*.061,c+Vector3.FORWARD*.061,Vector3(0,0,.039),Vector3.FORWARD,Color("75594a"))
		if i in [1,3,5,8,10]:
			b.oval(shield,"CopperRivet",a.lerp(e,.52)+Vector3.BACK*.025,Vector3(.048,.048,.036),"ceb389",Vector3.ZERO,8)
	b.finish(shield,"BatteredKite",surf)
	b.oval(shield,"Boss",Vector3(-.026,.111,.142),Vector3(.166,.157,.081),"baaf98",Vector3.ZERO,10)
	# The faded reed device has three broad fronds; it is paint on the wood,
	# not a separate prop. Lower fronds taper with the curvature of the face.
	var design := b.surface()
	var faded := Color("d0a978")
	var base := Vector3(-.044,-.295,.091)
	var stalk := Vector3(-.017,-.052,.137)
	b.flat(design,base,stalk+Vector3.RIGHT*.02,stalk+Vector3.LEFT*.013,Vector3.BACK,faded)
	for s: float in [-1,1]:
		b.flat(design,stalk+Vector3.DOWN*.056,stalk+Vector3(s*.064,-.021,-.012),stalk+Vector3(s*.122,.037,-.023),Vector3.BACK,faded)
		b.flat(design,stalk+Vector3.DOWN*.056,stalk+Vector3(s*.122,.037,-.023),stalk+Vector3(s*.106,-.020,-.022),Vector3.BACK,faded)
	b.finish(shield,"FadedDevice",design)
	b.box(shield,"GripLeather",Vector3(-.027,.064,-.09),Vector3(.264,.068,.104),"5d4b42",Vector3(0,0,-11))
	b.marker(shield,"RimTip",Vector3(0,.398,.019))
