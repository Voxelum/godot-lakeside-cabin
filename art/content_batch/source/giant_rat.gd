extends RefCounted
## Broad hocks, thin pink naked tail, cup ears and a small lifted snout.
## Output uses the same native meshes/animation rig convention as the F5 specimens.
const Kit := preload("res://art/monster_trial/source/rig.gd")
const Brush := preload("res://art/monster_trial/source/brush.gd")
const BODY_Y := .425
const TAIL_RUNS := [Vector3(.097,-.085,-.358),Vector3(.221,-.093,-.353),Vector3(.200,-.016,-.307),Vector3(-.059,.063,-.334)]
const TAIL_RADII := [.087,.077,.064,.048,.018]

func build() -> PackedScene:
	var kit := Kit.new("GiantRat")
	var b := kit.b
	var body := b.joint(kit.rig,"Body",Vector3(0,BODY_Y,0))
	b.loft(body,"RoundHaunch",[
		[-.60,Vector2(.032,.023),Vector2(.104,.132),"7d5851"],
		[-.51,Vector2(.010,.028),Vector2(.278,.245),"986c60"],
		[-.29,Vector2(0,.068),Vector2(.381,.304),"b08473"],
		[-.045,Vector2(.012,.065),Vector2(.347,.274),"a67a69"],
		[.185,Vector2(0,.028),Vector2(.284,.249),"a07767"],
		[.378,Vector2(0,.015),Vector2(.245,.211),"b68c76"],
		[.507,Vector2(0,.040),Vector2(.142,.146),"aa8171"],
	],14,Vector3.AXIS_Z,.029,false,.67)
	for s: float in [-1,1]:
		b.fold(body,"FlankFur",Vector3(s*.271,.100,-.25),Vector3(s*.255,-.137,-.13),Vector3(s*.261,-.077,.30),Vector3(s*.329,-.034,-.077),Vector3(s*.236,-.038,-.014),"ba9680","86645b")
	var head := b.joint(body,"Head",Vector3(0,.086,.406),Vector3(-3,-4,0))
	var ears := _face(b,head)
	var tail := _tail(b,body)
	var legs: Array[Kit.Leg] = []
	for i in 4:
		var s := -1. if i%2==0 else 1.
		var rear := i>=2
		var label := ("Hind" if rear else "Fore")+("L" if s<0. else "R")
		var socket := Vector3(s*(.226 if rear else .177),.38,-.351 if rear else .303)
		var ankle := Vector3(socket.x,.073,(-.398 if rear else .424)+s*.026)
		var leg := Kit.Leg.new(b,kit.rig,label,socket,ankle,Vector3(.188,.178,0.) if rear else Vector3(.195,.183,0.),1.0 if rear else -1.0)
		_paw(b,leg,rear)
		legs.append(leg)
	var moving: Array[Node3D] = [body,head]
	moving.append_array(ears)
	moving.append_array(tail)
	for leg in legs: moving.append_array(leg.joints())
	kit.bind(moving)
	kit.clip(&"idle",2.48,true,func(u: float) -> void:
		var pulse := sin(u*TAU)
		var nose := pow(sin(u*TAU*3.0),2.0) * sin(PI*u)
		body.position.y += .017*pulse
		body.scale.x = 1.+.037*pulse
		head.rotation_degrees += Vector3(-5.3*nose,8.0*pulse,-3.6*pulse)
		for i in 2:
			var blink := exp(-pow((u-(.44+.086*i))*26.,2.))
			ears[i].rotation_degrees += Vector3(blink*12.0,blink*(-12.+24.*i),pulse*3.)
		_bend_tail(tail,4.0,7.0*pulse,9.0*sin(TAU*u))
		for leg in legs: leg.solve(_socket(body,leg),leg.rest_ankle)
	)
	kit.clip(&"move",.54,true,func(u: float) -> void:
		var p := sin(TAU*u)
		body.position.y += .011+.025*cos(TAU*2.*u)
		body.rotation_degrees += Vector3(3.2*p,5.1*p,4.8*p)
		head.rotation_degrees += Vector3(-4.-6.*p,-3.0*p,p*2.7)
		for i in 2: ears[i].rotation_degrees.x += 8.+4.*p
		_bend_tail(tail,-7.0,17.0*p,12.0*sin(TAU*u-.45))
		_float_tail(body,tail)
		for i in 4:
			var leg := legs[i]
			var d := Kit.stride(u + (0.50 if i==1 or i==2 else 0.)-(.056 if i>=2 else 0.0),.33,.102 if i>=2 else .090,.57)
			leg.solve(_socket(body,leg),leg.rest_ankle+Vector3(0,d.x,d.y),-1.6*d.x)
	)
	kit.clip(&"rear_and_sniff",1.84,false,func(u: float) -> void:
		# Nose leads the lift. The two hind feet anchor it, forepaws scoop twice,
		# then the chest peels forward and both forefeet settle back on the mark.
		var v := Kit.curve([
			[0., 0.,0.,0.,0.,0.,0.,0.],
			[.15,-.037,-.08,14.,8.,0.,5.,0.],
			[.29,.072,-.075,-27.,-10.,.21,-8.,.06],
			[.43,.167,-.11,-48.,-9.,.44,-17.,.12],
			[.56,.189,-.11,-48.,8.,.49,8.,.10],
			[.69,.176,-.084,-46.,-7.,.45,13.,.11],
			[.80,.102,.016,-24.,-13.,.31,-7.,.10],
			[.92,-.021,.067,7.,-4.,.026,4.,.02],
			[1.,0.,0.,0.,0.,0.,0.,0.],
		],u)
		body.position += Vector3(0,v[0],v[1])
		body.rotation_degrees.x = v[2]
		head.rotation_degrees += Vector3(v[3],v[5],-v[5]*.3)
		for i in 2: ears[i].rotation_degrees += Vector3(-v[4]*19.,v[5]*.38,0.)
		_bend_tail(tail,-v[2]*.91+v[4]*10.,v[5]*1.6,-v[5])
		_float_tail(body,tail)
		for i in 4:
			var leg := legs[i]
			var raise := 0. if i>=2 else v[4]
			var flick := raise*.168*sin((u-.39)*TAU*4.+i*PI)
			var forward := v[6]*(1. if u>=.76 else -2.04)
			if i<2:
				leg.solve(_socket(body,leg),leg.rest_ankle+Vector3(0,raise+flick,forward+.66*flick),-.65*raise)
			else:
				leg.solve(_socket(body,leg),leg.rest_ankle)
	)
	var scene := kit.pack()
	kit.root.free()
	return scene

func _socket(body: Node3D, leg: Kit.Leg) -> Vector3:
	return body.transform * (leg.rest_socket-Vector3.UP*BODY_Y)

func _paw(b: Brush, leg: Kit.Leg, rear: bool) -> void:
	b.oval(leg.top,"ThickHaunch" if rear else "ForeCoat",Vector3(0,-.031,.014),Vector3(.293,.369,.393) if rear else Vector3(.18,.292,.219),"a27968" if rear else "ba9580",Vector3(8,0,0),10)
	b.link(leg.shin,"Taper",Vector3(0,.038,0),Vector3(0,-leg.l2,0),.080 if rear else .054,.037,"95756a",8)
	b.oval(leg.paw,"PinkPad",Vector3(0,-.022,.051),Vector3(.165,.102,.229) if rear else Vector3(.131,.102,.187),"ab7c73",Vector3.ZERO,10)
	for i in 3:
		var x := (i-1)*(.039 if rear else .035)
		var z := (.148 if rear else .133)-absf(i-1)*.025
		b.oval(leg.paw,"Toes",Vector3(x,-.041,z),Vector3(.040,.045,.089),"c09583",Vector3(0,(i-1)*12.,0),7)
		b.link(leg.paw,"Claw",Vector3(x,-.036,z+.033),Vector3(x*1.14,-.043,z+.072),.012,.003,"d8ba9e",5)
	b.marker(leg.paw,"Sole",Vector3(0,-.073,.089))

func _face(b: Brush, head: Node3D) -> Array[Node3D]:
	b.loft(head,"RatWedge",[
		[-.177,Vector2(0,.008),Vector2(.156,.159),"957167"],
		[-.070,Vector2(.004,.035),Vector2(.247,.212),"b78b77"],
		[.077,Vector2(0,.018),Vector2(.213,.179),"ae7e69"],
		[.215,Vector2(0,-.023),Vector2(.166,.130),"ba937a"],
		[.356,Vector2(0,-.058),Vector2(.093,.080),"bb9684"],
		[.451,Vector2(0,-.054),Vector2(.056,.050),"af8b83"],
	],13,Vector3.AXIS_Z,.023,false,.64)
	b.oval(head,"Nose",Vector3(0,-.041,.447),Vector3(.146,.087,.114),"694c52",Vector3(16,0,0),10)
	b.oval(head,"NoseGlint",Vector3(-.018,-.015,.487),Vector3(.041,.025,.030),"a77d7c",Vector3.ZERO,8)
	b.oval(head,"Mouth",Vector3(0,-.108,.340),Vector3(.147,.045,.186),"594249",Vector3(-5,0,0),10)
	var ears: Array[Node3D] = []
	for i in 2:
		var s := 2.*i-1.
		var suffix := "L" if i==0 else "R"
		b.box(head,"Incisor"+suffix,Vector3(s*.029,-.124,.417),Vector3(.045,.054,.037),"d8b274",Vector3(10,s*4.,-s*4.))
		b.oval(head,"WhiskerPad"+suffix,Vector3(s*.089,-.070,.312),Vector3(.165,.116,.172),"c7a48e",Vector3(-7,s*23,0),9)
		for j in 3:
			var a := Vector3(s*(.107+.013*j),-.065-.028*j,.366-.028*j)
			var mid := a+Vector3(s*(.102+.016*j),.014-.018*j,.020+.017*j)
			var tip := mid+Vector3(s*(.107-.012*j),.04-.029*j,-.027-.026*j)
			b.link(head,"Whisker",a,mid,.011,.0074,"d3b39e",5)
			b.link(head,"WhiskerEnd",mid,tip,.008,.0038,"c7aca0",5)
		var eye := b.joint(head,"Eye"+suffix,Vector3(s*.173,.078,.152),Vector3(-12,s*49.,s*8.))
		b.oval(eye,"Lid",Vector3.ZERO,Vector3(.169,.117,.079),"7b5953",Vector3(0,0,-s*5.),10)
		b.oval(eye,"SmallDarkEye",Vector3(0,.004,.029),Vector3(.125,.090,.079),"3b343e",Vector3.ZERO,10)
		b.oval(eye,"Glint",Vector3(-.019,.025,.064),Vector3(.037,.028,.017),"d9b29b",Vector3.ZERO,8)
		var ear := b.joint(head,"Ear"+suffix,Vector3(s*.169,.172,-.075),Vector3(-12,s*31.,-s*21.))
		b.loft(ear,"FoldedRim",[
			[-.03,Vector2(0,0),Vector2(.058,.034),"a87870"],
			[.067,Vector2(s*.012,0),Vector2(.127,.049),"b8847a"],
			[.165,Vector2(s*.023,-.010),Vector2(.156,.045),"c18e82"],
			[.265-i*.015,Vector2(s*.021,-.015),Vector2(.116,.032),"be897d"],
			[.310-i*.015,Vector2(s*.011,-.014),Vector2(.029,.012),"ba8478"],
		],12,Vector3.AXIS_Y,.05)
		b.oval(ear,"EarBowl",Vector3(s*.016,.168,.026),Vector3(.233,.218,.048),"895b62",Vector3(-7,0,-s*12),11)
		b.oval(ear,"Tragus",Vector3(-s*.013,.059,.046),Vector3(.102,.090,.061),"b88780",Vector3(0,0,-s*24.),8)
		ears.append(ear)
	b.marker(head,"Look",Vector3(0,.09,.303))
	b.marker(head,"NoseTip",Vector3(0,-.032,.503))
	return ears

func _tail(b: Brush, body: Node3D) -> Array[Node3D]:
	var joints: Array[Node3D] = []
	var parent := body
	var p := Vector3(.053,.008,-.524)
	for i in 4:
		var j := b.joint(parent,"Tail%02d"%(i+1),p)
		var end: Vector3 = TAIL_RUNS[i]
		var wide: float = TAIL_RADII[i]
		var thin: float = TAIL_RADII[i+1]
		var rows := []
		for q in 7:
			var f := (float(q)-.36)/5.64
			var u := end*f
			var r := lerpf(wide,thin,clampf(f,0.,1.))*(1. if q%2==0 else .927)
			rows.append([u.z,Vector2(u.x,u.y),Vector2(r,r*.85),"be8d82" if q%2==0 else "a67672"])
		b.loft(j,"BareTailRings",rows,9,Vector3.AXIS_Z,.015)
		b.oval(j,"TailKnuckle",Vector3.ZERO,Vector3.ONE*Vector3(2.*wide,1.64*wide,2.*wide),"b8897e",Vector3.ZERO,8)
		joints.append(j)
		parent = j
		p = end
	b.marker(joints.back(),"TailTip",p)
	return joints

func _bend_tail(parts: Array[Node3D], pitch: float, base: float, tip: float) -> void:
	parts[0].rotation_degrees += Vector3(pitch,base,0)
	parts[1].rotation_degrees += Vector3(-pitch*.28,-base*.41,0)
	parts[2].rotation_degrees += Vector3(pitch*.11,tip*.60,0)
	parts[3].rotation_degrees += Vector3(pitch*.27,-tip,0)

func _float_tail(body: Node3D, parts: Array[Node3D]) -> void:
	# Bake the relaxed lever against the same flat datum as the feet. Nudge
	# any low segment up without shortening it or dragging the instance root.
	var frame := body.transform
	for i in parts.size():
		var part := parts[i]
		var current := frame * part.transform
		var tip: Vector3 = current * TAIL_RUNS[i]
		var clearance: float = TAIL_RADII[i+1]+.017
		if tip.y<clearance+.028:
			var lift := (clearance+.028-tip.y)*(1.-smoothstep(clearance,clearance+.028,tip.y))
			var d := tip-current.origin
			var reach := d.length()
			var height := clampf(d.y+lift,-reach*.97,reach*.97)
			var planar := d.slide(Vector3.UP).normalized()
			if planar.is_zero_approx(): planar = Vector3.FORWARD
			var fixed := planar*sqrt(reach*reach-height*height)+Vector3.UP*height
			var turn := Basis(Quaternion(d.normalized(),fixed.normalized()))
			part.basis = (frame.basis.inverse()*turn*current.basis).orthonormalized()
		frame = frame * part.transform
