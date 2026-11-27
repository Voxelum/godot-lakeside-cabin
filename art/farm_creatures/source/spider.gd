extends "res://art/farm_creatures/source/painter.gd"
const Kit := preload("res://art/monster_trial/source/rig.gd")

func build(k: Kit) -> void:
	var trunk := b.joint(k.rig,"Cephalothorax",Vector3(0,.39,.08))
	var belly := b.joint(trunk,"Abdomen",Vector3(0,.12,-.21))
	var legs: Array[Node3D] = []
	var jaws: Array[Node3D] = []
	for i in 8:
		var s := -1 if i < 4 else 1
		var row := i%4
		legs.append(b.joint(trunk,"Leg%d"%i,Vector3(s*.15,-.02,.24-.116*row)))
	for s: int in [-1,1]: jaws.append(b.joint(trunk,"FangL" if s<0 else "FangR",Vector3(s*.125,-.03,.38)))
	for look in 3:
		index=look
		var dark: String=["352c33","333249","44332f"][look]
		var coat: String=["795643","655c80","7d5140"][look]
		var band: String=["bf925e","c8c3b1","d38348"][look]
		var eye: String=["efa947","a8e5d8","ffbd50"][look]
		# Heart-shaped prosoma overlaps a much larger pear-shaped abdomen.
		shell(trunk,Vector3.ZERO,true,[[-.25,.0,.105,.10,dark],[-.11,.025,.237,.16,dark],[.11,.035,.293,.19,coat],[.28,.025,.257,.155,coat],[.386,-.005,.158,.09,dark]],10)
		var w: float=[1.,.94,1.1][look]
		shell(belly,Vector3.ZERO,true,[[-.65,.01,.037,.045,dark],[-.55,.05,.226*w,.20,coat],[-.38,.07,.347*w,.248,coat],[-.12,.08,.33*w,.24,coat],[.055,.035,.23,.16,dark],[.12,.01,.11,.08,dark]],12)
		for side in 2:
			var s := float(side*2-1)
			# A recurved pair of dark mandibles, with pale pointed inner teeth.
			horn(jaws[side],[Vector3.ZERO,Vector3(s*.054,-.008,.085),Vector3(s*.054,-.092,.16),Vector3(-s*.024,-.14,.212)],[.091,.082,.041,.004],[coat,dark,"e5c193"],7)
			for j in 2:
				var p := Vector3(s*(.106+j*.087),.078+j*.038,.34-j*.06)
				var r := .065-j*.018
				egg(trunk,p,Vector3(r*1.32,r*1.04,r),dark,7)
				egg(trunk,p+Vector3(s*.008,.016,.023),Vector3(r*.87,r*.78,r),eye,7)
			# Broad broken dorsal chevrons, cut on the actual shell surface.
			for j in (2 if look!=1 else 1):
				var z := -.19-.195*j
				plate(belly,[Vector3(s*.014,.326,z+.071),Vector3(s*.166,.288,z-.008),Vector3(s*.249,.238,z-.10),Vector3(s*.077,.313,z-.049)],Vector3(s*.106,.329,z-.012),Vector3(s*.12,.256,z-.012),band,coat)
			if look==1:
				for j in 3:
					var z := -.15-.125*j
					plate(belly,[Vector3(s*.235,.19,z+.12),Vector3(s*.31,.05,z-.06),Vector3(s*(.42-j*.017),.13,z-.17)],Vector3(s*.32,.17,z-.025),Vector3(s*.31,.085,z-.035),band,"695e75")
			elif look==2:
				for j in 3:
					var p:=Vector3(s*(.22+.04*sin(j*1.4)),.22,-.13-j*.15)
					horn(belly,[p,p+Vector3(s*.111,.085,-.05),p+Vector3(s*.139,.16-j*.016,-.098)],[.075,.045,.003],[dark,band],5)
		for i in 8:
			var s := -1. if i<4 else 1.
			var row := i%4
			var z: float=[.42,.17,-.16,-.48][row]
			var spread: float=[.69,.86,.89,.75][row]
			var elbow:=Vector3(s*spread*.63,.18-.019*row,z*.52)
			var ankle:=Vector3(s*spread*.92,-.269,z*.95)
			var foot:=Vector3(s*spread,-.359,z+.027)
			horn(legs[i],[Vector3.ZERO,elbow*.77,elbow,elbow.lerp(ankle,.21),ankle,foot],[.064,.056,.078,.053,.033,.009],[coat,dark,band,coat,dark],6)
		finish_look()
	var parts: Array[Node3D]=[k.rig,trunk,belly]
	parts.append_array(legs); parts.append_array(jaws)
	k.bind(parts)
	k.clip(&"idle",2.4,true,func(t:float)->void:
		var v:=sin(TAU*t)
		belly.position.y+=.032*v
		belly.scale=Vector3(1.+.045*v,1.+.066*v,1.)
		for j in 2: jaws[j].rotation_degrees.y=(2*j-1)*8.*v
	)
	k.clip(&"move",.72,true,func(t:float)->void:
		trunk.position.y+=.019*absf(sin(TAU*t))
		belly.rotation_degrees.y=6.*sin(TAU*t)
		for i in 8:
			var s := -1. if i<4 else 1.
			var a:=TAU*(t+(i%4)*.47+(.5 if i>=4 else 0.))
			legs[i].rotation_degrees=Vector3(0,s*15.5*sin(a),s*14.*maxf(0.,cos(a)))
	)
	k.clip(&"attack",1.02,false,func(t:float)->void:
		var p:=Kit.curve([[0,0,0],[.25,1,0],[.43,1,0],[.52,0,1],[.62,0,.94],[1,0,0]],t)
		var wind:=p[0]; var bite:=p[1]
		k.rig.position=Vector3(0,.065*wind+.045*bite,-.19*wind+.37*bite)
		trunk.rotation_degrees.x=-10.*wind+3.*bite
		belly.rotation_degrees.x=14.*wind-7.*bite
		for i in 8:
			var s := -1. if i<4 else 1.
			if i%4<2:
				legs[i].rotation_degrees=Vector3(-23.*wind,-s*(7.*wind+16.*bite),s*wind*(38.-12.*(i%4)))
		for j in 2: jaws[j].rotation_degrees.y=(2*j-1)*(38.*wind-17.*bite)
	)
