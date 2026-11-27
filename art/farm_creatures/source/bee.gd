extends "res://art/farm_creatures/source/painter.gd"
const Kit := preload("res://art/monster_trial/source/rig.gd")

func build(k: Kit) -> void:
	var chest:=b.joint(k.rig,"Thorax",Vector3(0,.99,.035))
	var abdomen:=b.joint(chest,"Petiole",Vector3(0,.02,-.16))
	var wings: Array[Node3D]=[]
	for j in 2: wings.append(b.joint(chest,"WingL" if j==0 else "WingR",Vector3((j*2-1)*.134,.126,-.035)))
	for look in 3:
		index=look
		var ink:String=["473338","4b3430","433b48"][look]
		var honey:String=["ddaa48","e8b86b","bc7050"][look]
		var rim:String=["f5c965","ffdb83","edac64"][look]
		var film:String=["c4ddd3","d7e2bc","a7cec7"][look]
		var vein:String=["85a9a5","99b4a1","779a9d"][look]
		# Separate head, fur collar, thorax, petiole and a continuous striped abdomen.
		egg(chest,Vector3.ZERO,Vector3(.233,.225,.266),ink,10)
		egg(chest,Vector3(0,.057,.075),Vector3(.247,.219,.19),honey,10)
		egg(chest,Vector3(0,.005,.287),Vector3(.226,.197,.176),ink,10)
		var f:float=[1.,1.11,.87][look]
		shell(abdomen,Vector3.ZERO,true,[[-.54,-.12,.047,.045,ink],[-.44,-.08,.137*f,.129,ink],[-.36,-.056,.18*f,.176,honey],[-.28,-.028,.211*f,.201,ink],[-.175,.002,.224*f,.202,honey],[-.097,.006,.205*f,.188,ink],[.013,.003,.16*f,.153,honey],[.099,-.018,.063,.077,ink]],12)
		horn(abdomen,[Vector3(0,-.12,-.5),Vector3(0,-.16,-.61),Vector3(0,-.171,-(.81 if look==2 else .73))],[.073,.059,.003],[ink,"dbbe88"],6)
		for j in 2:
			var s:=float(2*j-1)
			# Dark broad compound eyes, each with one opal facet rather than pupils.
			egg(chest,Vector3(s*.144,.046,.373),Vector3(.094,.142,.096),"39323c",8)
			egg(chest,Vector3(s*.172,.113,.416),Vector3(.045,.048,.035),"a6bab1",6)
			horn(chest,[Vector3(s*.073,.137,.37),Vector3(s*.126,.296,.43),Vector3(s*(.25 if look==2 else .193),.315,.494)],[.026,.023,.034],[ink,rim],6)
			# Two independently contoured foils per side. Opaque pearl underside,
			# a bent leading spar and ivory leading edge stay legible against grass.
			var a:=Vector3.ZERO; var tip:=Vector3(s*(.75 if look==2 else .66),.148,(-.24 if look==2 else -.09))
			var elbow:=Vector3(s*.38,.132,.077); var rear:=Vector3(s*.40,.079,-.216)
			var apex:=Vector3(s*.32,.164,-.051)
			plate(wings[j],[a,elbow,tip,tip+Vector3(-s*.058,-.052,-.104),rear],apex,apex-Vector3.UP*.074,film,vein)
			horn(wings[j],[a,elbow,tip],[.032,.019,.007],["d8d9b3",rim],5)
			horn(wings[j],[apex,tip+Vector3(-s*.058,-.05,-.103)],[.012,.009],[vein],5)
			plate(wings[j],[a,Vector3(s*.31,.065,-.117),Vector3(s*.455,.022,-.315),Vector3(s*.366,.008,-.34),Vector3(s*.086,.016,-.17)],Vector3(s*.23,.074,-.188),Vector3(s*.24,.004,-.189),film,vein)
			for h in 3:
				var rootp:=Vector3(s*.128,-.104,.158-.128*h)
				var joint:=rootp+Vector3(s*.101,-.114,-.033)
				var toe:=joint+Vector3(s*.101,-.146,-.077-.042*h)
				horn(chest,[rootp,joint,toe,toe+Vector3(s*.023,-.043,-.043)],[.03,.036,.021,.008],[honey,ink,ink],5)
				if h==2 and look==1:
					egg(chest,joint.lerp(toe,.72)+Vector3(s*.045,0,0),Vector3(.142,.148,.143),"d79343",8)
					egg(chest,toe+Vector3(s*.039,.084,.044),Vector3(.106,.096,.106),"f9c866",7)
			if look==1:
				# Buff-haired mantle comes to uneven points around the thorax.
				for h in 3:
					var p:=Vector3(s*(.086+.051*h),.23-.054*h,.09)
					horn(chest,[p,p+Vector3(s*.036,.024,-.082),p+Vector3(s*.054,.013,-.165)],[.068,.059,.004],[rim,honey],5)
			elif look==2:
				horn(chest,[Vector3(s*.15,.14,.22),Vector3(s*.178,.19,.095),Vector3(s*.194,.218,-.055)],[.045,.052,.006],[rim,ink],5)
		finish_look()
	var parts:Array[Node3D]=[k.rig,chest,abdomen,wings[0],wings[1]]
	k.bind(parts)
	k.clip(&"idle",.8,true,func(t:float)->void:
		chest.position.y+=.065*sin(TAU*t)
		chest.rotation_degrees.x=4.*sin(TAU*t)
		abdomen.rotation_degrees.x=-7.+5.*sin(TAU*t)
		for j in 2: wings[j].rotation_degrees.z=(2*j-1)*(12.+26.*sin(TAU*t*4.))
	)
	k.clip(&"move",.48,true,func(t:float)->void:
		chest.position.y+=.044*sin(TAU*t)
		chest.rotation_degrees.x=17.+4.*sin(TAU*t)
		abdomen.rotation_degrees.x=-16.+6.*sin(TAU*t)
		for j in 2: wings[j].rotation_degrees.z=(2*j-1)*(8.+36.*sin(TAU*t*3.))
	)
	k.clip(&"attack",.84,false,func(t:float)->void:
		var p:=Kit.curve([[0,0,0],[.24,1,0],[.40,1,0],[.51,0,1],[.63,0,.98],[.83,.1,.18],[1,0,0]],t)
		var wind:=p[0]; var hit:=p[1]
		k.rig.position=Vector3(0,.19*wind+.035*hit,-.25*wind+.46*hit)
		chest.rotation_degrees.x=-19.*wind-15.*hit
		abdomen.rotation_degrees.x=-50.*wind-133.*hit
		for j in 2:
			wings[j].rotation_degrees=Vector3(0,(2*j-1)*36.*hit,(2*j-1)*(48.*wind-12.*hit+15.*sin(TAU*t*4.)*(1.-hit)))
	)
