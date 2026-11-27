extends "res://art/farm_creatures/source/painter.gd"
const Kit := preload("res://art/monster_trial/source/rig.gd")

func build(k: Kit) -> void:
	var hip:=b.joint(k.rig,"Haunches",Vector3(0,.44,0))
	var chest:=b.joint(hip,"Mantle",Vector3(0,.045,.02))
	var head:=b.joint(chest,"Mask",Vector3(0,.56,.091))
	var tail:=b.joint(hip,"Tail",Vector3(0,.065,-.119))
	var wings:Array[Node3D]=[]; var arms:Array[Node3D]=[]; var legs:Array[Node3D]=[]
	for j in 2:
		var s:=float(2*j-1)
		wings.append(b.joint(chest,"Wing%d"%j,Vector3(s*.16,.364,-.073)))
		arms.append(b.joint(chest,"Palm%d"%j,Vector3(s*.222,.337,.055)))
		legs.append(b.joint(hip,"Hoof%d"%j,Vector3(s*.115,-.018,.0)))
	var ember:=b.joint(arms[1],"Coal",Vector3(.115,-.269,.161))
	for look in 3:
		index=look
		var skin:String=["af5749","69759b","ac7545"][look]
		var dark:String=["67414a","49445f","63454b"][look]
		var warm:String=["d7805d","9e98b1","da9860"][look]
		var wing:String=["975459","75728d","a66d4c"][look]
		var tip:String=["e4bc8f","e7d4b1","dca46b"][look]
		var eyes:String=["ffd675","bee7d4","ffcb69"][look]
		var cloth:String=["545055","65535c","635d54"][look]
		shell(chest,Vector3.ZERO,false,[[-.08,-.011,.131,.106,dark],[.04,-.012,.167,.147,skin],[.19,.014,.14,.149,skin],[.313,.029,.236,.166,skin],[.384,.028,.182,.127,warm],[.442,.043,.113,.098,dark]],10)
		shell(hip,Vector3.ZERO,false,[[-.10,-.018,.145,.13,cloth],[-.029,0,.18,.144,cloth],[.055,0,.154,.152,"8a684e"]],10)
		# Short angular muzzle, heavy high cheekbones and large forward eye masks.
		shell(head,Vector3.ZERO,false,[[-.19,.06,.094,.095,dark],[-.11,.029,.195,.168,skin],[.016,.014,.238,.207,skin],[.129,-.012,.221,.183,warm],[.183,-.018,.133,.138,skin]],10)
		egg(head,Vector3(0,-.106,.166),Vector3(.127,.034,.05),"483642",8)
		plate(head,[Vector3(-.058,-.024,.181),Vector3(0,.037,.218),Vector3(.063,-.019,.18),Vector3(.022,-.058,.226)],Vector3(.003,-.023,.281),Vector3(0,-.019,.16),warm,dark)
		for j in 2:
			var s:=float(2*j-1)
			var ep:=Vector3(s*.113,.032,.162)
			egg(head,ep,Vector3(.092,.06,.061),dark,8)
			egg(head,ep+Vector3(0,.004,.031),Vector3(.064,.038,.043),eyes,8)
			horn(head,[Vector3(s*.027,.069,.211),Vector3(s*.114,.109,.197),Vector3(s*.211,.103,.092)],[.032,.046,.017],[skin,warm],5)
			horn(head,[Vector3(s*.082,-.095,.198),Vector3(s*.085,-.143,.207)],[.026,.002],[tip],5)
			plate(head,[Vector3(s*.16,-.033,-.018),Vector3(s*.172,.085,-.007),Vector3(s*.365,.16,-.119),Vector3(s*.263,-.015,-.077)],Vector3(s*.227,.038,.016),Vector3(s*.234,.032,-.094),warm,dark)
			var base:=Vector3(s*.147,.116,-.022)
			match look:
				0: horn(head,[base,base+Vector3(s*.085,.10,-.032),base+Vector3(s*.116,.203,-.106),base+Vector3(s*.113,.303,-.143)],[.083,.069,.043,.003],[dark,"ac866d",tip],7)
				1: horn(head,[base,base+Vector3(s*.095,.066,-.043),base+Vector3(s*.148,.142,-.10),base+Vector3(s*.097,.242,-.146),base+Vector3(s*.039,.268,-.113)],[.088,.079,.061,.032,.003],[dark,"9c908a",tip,tip],7)
				2: horn(head,[base,base+Vector3(s*.036,.13,-.043),base+Vector3(s*.021,.215,-.012),base+Vector3(-s*.01,.307,.038)],[.089,.073,.044,.004],[dark,"b08467",tip],7)
			var wp:Node3D=wings[j]
			var wrist:=Vector3(s*.285,.287,-.139)
			var outer:=Vector3(s*.675,.127 if look!=2 else .22,-.197)
			var middle:=Vector3(s*.461,-.105,-.301)
			var lower:=Vector3(s*.258,-.193,-.277)
			var heel:=Vector3(s*.068,-.132,-.143)
			for pair in [[outer,middle],[middle,lower],[lower,heel]]:
				var a:Vector3=pair[0]; var z:Vector3=pair[1]
				var bite:=a.lerp(z,.55).lerp(wrist,.28)
				var ctr:=wrist.lerp(bite,.49)
				plate(wp,[wrist,a,bite,z],ctr+Vector3(.0,.027,.041),ctr-Vector3(.0,.031,.041),wing,dark)
			horn(wp,[Vector3.ZERO,wrist,outer],[.060,.054,.008],[dark,skin],6)
			for end in [middle,lower,heel]: horn(wp,[wrist,end],[.033,.009],[dark],5)
			horn(wp,[wrist,wrist+Vector3(s*.026,.088,.013)],[.032,.002],[tip],5)
			var elbow:=Vector3(s*.092,-.169,-.032); var fist:=Vector3(s*.117,-.293,.087)
			horn(arms[j],[Vector3.ZERO,elbow,fist],[.076,.057,.067],[skin,warm],7)
			egg(arms[j],fist,Vector3(.073,.063,.071),dark,7)
			for digit in 2:
				var p:=fist+Vector3((digit-.5)*.069,-.014,.027)
				horn(arms[j],[p,p+Vector3(.004,-.039,.055),p+Vector3(0,-.023,.09)],[.026,.02,.003],[warm,tip],5)
			var knee:=Vector3(s*.031,-.187,.066); var hock:=Vector3(s*.048,-.306,-.055)
			horn(legs[j],[Vector3.ZERO,knee,hock,Vector3(s*.037,-.368,.012)],[.095,.077,.048,.049],[skin,dark,warm],7)
			for toe in 2:
				var p:=Vector3(s*.039+(toe-.5)*.06,-.38,.032)
				egg(legs[j],p,Vector3(.051,.041,.099),"4d3c41",7)
		var bend:=Vector3(-.096,.069,-.36); var curl:=Vector3(-.268,.246,-.474); var end:=curl+Vector3(.049,.104,-.006)
		horn(tail,[Vector3.ZERO,bend,curl,end],[.065,.046,.027,.024],[skin,warm,dark],7)
		plate(tail,[end+Vector3(-.089,-.028,0),end+Vector3(-.026,.154,-.022),end+Vector3(.091,-.036,.002),end-Vector3.UP*.014],end+Vector3(0,.041,.04),end+Vector3(0,.037,-.049),wing,dark)
		if look==1:
			plate(chest,[Vector3(-.185,.345,.088),Vector3(.19,.278,.142),Vector3(.118,.192,.191),Vector3(-.154,.267,.148)],Vector3(.029,.28,.205),Vector3(0,.274,.11),"cab497","76665e")
		elif look==2:
			# The charcoal carrier wears a split green hood and a bulbous coal satchel.
			shell(chest,Vector3.ZERO,false,[[.229,.006,.201,.18,"3b5354"],[.282,.016,.271,.196,"597571"],[.351,.018,.257,.169,"648378"],[.378,.046,.134,.116,"8c916d"]],9)
			plate(chest,[Vector3(-.14,.31,-.115),Vector3(.052,.29,-.145),Vector3(-.268,.09,-.312),Vector3(-.242,.166,-.28)],Vector3(-.143,.232,-.245),Vector3(-.106,.232,-.194),"74948a","4c6364")
			egg(hip,Vector3(-.174,-.022,-.018),Vector3(.121,.152,.123),"685343",8)
			egg(hip,Vector3(-.194,.039,.062),Vector3(.083,.051,.047),"ba995f",7)
			for j in 3:
				var p:=Vector3((j-1)*.105,-.034,.109)
				plate(hip,[p+Vector3(-.074,.02,0),p+Vector3(.077,0,0),p+Vector3(.022,-.157-.036*(j%2),.027)],p+Vector3(0,-.054,.04),p+Vector3(0,-.057,-.036),cloth,"453b40")
		# Hand-bound fire: three solid flame tongues, never an independent projectile.
		var flame:String=["ed924f","81c8bb","ed9854"][look]
		egg(ember,Vector3(0,.035,0),Vector3(.107,.112,.101),flame,7)
		horn(ember,[Vector3(-.016,.057,0),Vector3(.021,.139,-.019),Vector3(-.022,.231,-.031)],[.077,.053,.002],[eyes,flame],6)
		horn(ember,[Vector3(.044,.052,.006),Vector3(.085,.116,.006),Vector3(.088,.163,-.018)],[.042,.033,.003],[eyes,flame],5)
		finish_look()
	ember.scale=Vector3.ONE*.37
	var parts:Array[Node3D]=[k.rig,hip,chest,head,tail,ember]
	parts.append_array(wings); parts.append_array(arms); parts.append_array(legs)
	k.bind(parts)
	k.clip(&"idle",1.8,true,func(t:float)->void:
		var v:=sin(TAU*t)
		chest.rotation_degrees.x=3.*v; head.rotation_degrees.y=7.*v
		tail.rotation_degrees.y=15.*v
		for j in 2: wings[j].rotation_degrees.y=(2*j-1)*(13.+11.*v)
		ember.scale=Vector3.ONE*(.37+.09*v)
	)
	k.clip(&"move",.68,true,func(t:float)->void:
		var v:=sin(TAU*t); hip.position.y+=.066*absf(v)
		chest.rotation_degrees=Vector3(8.,8.*v,3.*v); tail.rotation_degrees.y=19.*v
		for j in 2:
			var s:=float(2*j-1)
			legs[j].rotation_degrees.x=s*31.*v
			arms[j].rotation_degrees.x=-s*22.*v
			wings[j].rotation_degrees.z=s*(4.+11.*cos(TAU*t*2.))
	)
	k.clip(&"attack",1.14,false,func(t:float)->void:
		var p:=Kit.curve([[0,0,0],[.29,1,0],[.46,1,0],[.545,0,1],[.655,0,1],[.86,.09,.17],[1,0,0]],t)
		var wind:=p[0]; var hit:=p[1]
		k.rig.position=Vector3(0,.07*wind+.045*hit,-.15*wind+.21*hit)
		chest.rotation_degrees=Vector3(-15.*wind+13.*hit,-31.*wind+27.*hit,7.*wind-8.*hit)
		head.rotation_degrees.y=18.*wind-18.*hit
		arms[1].rotation_degrees=Vector3(-109.*wind-95.*hit,34.*wind-11.*hit,61.*wind+7.*hit)
		arms[0].rotation_degrees=Vector3(-33.*wind+35.*hit,0,-25.*wind)
		ember.rotation_degrees=Vector3(110.*wind+145.*hit,9.*hit,-27.*wind)
		ember.scale=Vector3.ONE*(.37+1.34*wind+.81*hit)
		for j in 2: wings[j].rotation_degrees=Vector3(0,(2*j-1)*(-18.*wind+38.*hit),(2*j-1)*(18.*wind-7.*hit))
		tail.rotation_degrees.x=26.*wind-11.*hit
	)
