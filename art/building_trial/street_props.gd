@tool
extends RefCounted
## The same joinery, field stone and crate kit appears in both sites.
const Batch = preload("res://art/building_trial/mesh_batch.gd")
const Join = preload("res://art/building_trial/joinery.gd")
const OAK := Color("917052")
const DARK := Color("55453c")
const STONE := Color("9c8b7b")
const LEAF := Color("728252")

static func rail(b: Batch, a: Vector3, c: Vector3) -> void:
	var n := maxi(1, roundi(a.distance_to(c)/1.21))
	for i in range(n+1):
		var p := a.lerp(c,float(i)/n)
		b.box(p + Vector3.UP*.375, Vector3(.127,.75,.132), OAK, 1)
		b.lathe(p,Vector3.UP,PackedVector2Array([Vector2(.733,.095),Vector2(.865,0)]),4,OAK.lightened(.11),1)
		if i >= n:
			continue
		var q := a.lerp(c,float(i+1)/n)
		for h: float in [.276,.533]:
			var sag := (p+q)*.5+Vector3.UP*(h-.034)
			b.bar(p+Vector3.UP*h,sag,.098,.090,OAK.lightened(.12),Vector3.UP,1)
			b.bar(sag,q+Vector3.UP*h,.092,.084,OAK,Vector3.UP,1)

static func crate(b: Batch, p: Vector3, side := .55, twist := .0, bread := false) -> void:
	var axes := Basis(Vector3.UP,twist)
	var f := Transform3D(axes,p)
	var h := side*.83
	Join.panel(b,f,Vector3(0,h*.5,0),Vector3(side*.94,h,side*.84),OAK.darkened(.21),1)
	for s: float in [-1,1]:
		for j in 3:
			var y := (j+.5)*h/3.0
			var c := Batch.tone(OAK,.12*sin(float(j)*1.9))
			Join.panel(b,f,Vector3(0,y,s*side*.424),Vector3(side,h/3.0-.022,.049),c,1)
			Join.panel(b,f,Vector3(s*side*.483,y,0),Vector3(.044,h/3.0-.021,side*.87),c,1)
	for x: float in [-.40,.40]:
		for z: float in [-.432,.432]:
			Join.panel(b,f,Vector3(x*side,h*.5,z*side),Vector3(.083,h+.033,.077),OAK.lightened(.17),1)
	if bread:
		for i in 3:
			b.lathe(f*Vector3(0,h+.032,(i-1)*side*.24),axes.x,PackedVector2Array([Vector2(-side*.36,0),Vector2(-side*.28,side*.101),Vector2(side*.24,side*.113),Vector2(side*.34,0)]),7,Color("d5a469"))
	else:
		for i in 4:
			Join.panel(b,f,Vector3(0,h+.021,lerpf(-.347,.347,float(i)/3)*side),Vector3(side,.038,side*.201),OAK.lightened(.09),1)

static func cask(b: Batch, p: Vector3, k := 1.0) -> void:
	var a := PackedVector2Array([Vector2(0,0),Vector2(0,.219),Vector2(.125,.256),Vector2(.34,.269),Vector2(.55,.222),Vector2(.55,0)])
	for i in a.size():
		a[i] *= k
	b.lathe(p,Vector3.UP,a,10,OAK,1)
	for y: float in [.11,.43]:
		b.roller(p+Vector3.UP*y*k,Vector3.UP,.055*k,(.265 if y < .3 else .259)*k,10,Color("6e6660"))
	b.roller(p+Vector3.UP*.563*k,Vector3.UP,.026*k,.198*k,10,OAK.lightened(.145),1)

static func woodpile(b: Batch, p: Vector3) -> void:
	for row in 3:
		var n := 5-row
		for i in n:
			var pr := p+Vector3((i-(n-1)*.5)*.198,.113+row*.173,.022*sin(float(i*2+row)))
			var len := .61 + .084*cos(float(i*11+row))
			var ink := Batch.tone(Color("79624a"),.16*sin(float(i+row)))
			b.roller(pr,Vector3.BACK,len,.109,7,ink,1)
			b.roller(pr+Vector3.BACK*(len*.5+.011),Vector3.BACK,.018,.089,7,Color("c3a470"))
			b.roller(pr+Vector3.BACK*(len*.5+.022),Vector3.BACK,.012,.046,7,Color("a58258"))
	for s: float in [-1,1]:
		b.box(p+Vector3(s*.53,.27,.11),Vector3(.103,.54,.111),DARK,1)

static func straw(b: Batch, p: Vector3, tw := .0) -> void:
	var axes := Basis(Vector3.UP,tw)
	b.box(p+Vector3.UP*.21,Vector3(.78,.394,.57),Color("bca05e"),1,axes)
	for x: float in [-.20,.20]:
		b.box(p+Vector3.UP*.216+axes.x*x,Vector3(.038,.414,.59),Color("887146"),0,axes)
	for i in 11:
		var q := p+axes*Vector3(.317*sin(float(i)*4.37),.055+i*.029,.292)
		b.bar(q,q+axes*Vector3(.12*cos(float(i)*2.71),.029,.025),.018,.024,Color("d1b672"),axes.z)

static func well(b: Batch, p: Vector3) -> void:
	b.roller(p+Vector3.UP*.017,Vector3.UP,.033,.83,10,STONE.darkened(.05))
	b.roller(p+Vector3.UP*.14,Vector3.UP,.25,.60,10,Color("4d5b54"))
	for row in 3:
		for i in 9:
			var angle := TAU*(i+float(row%2)*.5)/9.0
			var axes := Basis(Vector3.UP,angle)
			var stone := Batch.tone(STONE,.11*sin(float(i*4+row)))
			b.box(p+axes.z*.524+Vector3.UP*(.16+row*.182),Vector3(.365,.167,.174),stone,0,axes)
	for i in 9:
		var axes := Basis(Vector3.UP,TAU*i/9.0)
		b.box(p+axes.z*.527+Vector3.UP*.676,Vector3(.405,.13,.228),STONE.lightened(.16),0,axes)
	for x: float in [-.598,.598]:
		b.box(p+Vector3(x,1.144,0),Vector3(.123,1.74,.139),DARK,1)
		b.bar(p+Vector3(x,1.67,0),p+Vector3(x*.53,1.92,0),.096,.088,OAK,Vector3.BACK,1)
	b.roller(p+Vector3.UP*1.35,Vector3.RIGHT,1.32,.074,8,OAK,1)
	b.roller(p+Vector3.UP*1.35,Vector3.RIGHT,.29,.12,8,Color("bc9d67"))
	b.bar(p+Vector3(0,.43,.115),p+Vector3(0,1.37,.115),.026,.028,Color("b7a688"))
	var ridge := p+Vector3.UP*2.26
	var roof := Color("8e6752")
	for s: float in [-1,1]:
		for i in 6:
			var x := -.782+float(i)*.263
			var a := ridge+Vector3(x,0,0)
			var f := a+Vector3(0,-.39,s*.54)
			b.quad(a,a+Vector3.RIGHT*.260,f+Vector3.RIGHT*.260,f,Vector3.UP,Batch.tone(roof,.14*sin(float(i)*3.1)),1)
		b.bar(ridge+Vector3(-.80,-.39,s*.545),ridge+Vector3(.82,-.39,s*.545),.085,.10,DARK,Vector3.UP,1)
	b.roller(ridge,Vector3.RIGHT,1.67,.062,6,roof.lightened(.13))

static func pot(b: Batch, p: Vector3, k := 1.0, blossom := true) -> void:
	var shape := PackedVector2Array([Vector2(0,0),Vector2(0,.135),Vector2(.268,.201),Vector2(.299,.213),Vector2(.325,.213),Vector2(.325,.0)])
	for i in shape.size():
		shape[i] *= k
	b.lathe(p,Vector3.UP,shape,8,Color("a96850"))
	b.roller(p+Vector3.UP*.328*k,Vector3.UP,.026*k,.164*k,8,Color("685243"))
	for i in 7:
		var a := i*2.4
		var v := Vector3(cos(a)*.20,.17+.14*absf(sin(a)),sin(a)*.19)
		var q := p+Vector3.UP*.325*k
		var c := q + v*k
		b.bar(q,c,.034*k,.029*k,LEAF)
		b.tri(q+v*k*.48,c+Vector3(cos(a+.78),.2,sin(a+.78))*.074*k,c,Vector3.UP,Color("8c9c5e"))
		if blossom and i%2==0:
			b.roller(c,Vector3.UP,.048*k,.074*k,5, Color("ddb683") if i==4 else Color("c59b8c"))

static func garden(b: Batch, p: Vector3) -> void:
	for row in 4:
		var z := -.82+.55*row
		for i in 8:
			var x := -.27+(.376*(i-3.5))
			var q := p+Vector3(x,.024,z)
			b.box(q,Vector3(.405,.058,.367),Batch.tone(Color("8e6e52"),.10*sin(float(i*4+row))))
			if row < 2:
				var c := q+Vector3.UP*.037
				for j in 5:
					var a := 2.4*j
					b.tri(c,c+Vector3(cos(a)*.116,.11,sin(a)*.13),c+Vector3(cos(a+.70)*.144,.071,sin(a+.70)*.113),Vector3.UP,Batch.tone(Color("809653"),.20*cos(float(j+i))))
			elif (i+row)%3 != 0:
				var k := .081+.028*absf(sin(float(i)))
				b.lathe(q+Vector3.UP*.036,Vector3.UP,PackedVector2Array([Vector2(0,0),Vector2(.038,k),Vector2(.099,k*.94),Vector2(.133,0)]),7,Color("bb8752"))
	var stake := p+Vector3(-1.81,0,.68)
	b.box(stake+Vector3.UP*.294,Vector3(.079,.58,.087),OAK,1)
	b.box(stake+Vector3.UP*.53,Vector3(.314,.126,.06),OAK.lightened(.22),1)

static func orchard_tree(b: Batch, p: Vector3, k: float, phase: float) -> void:
	b.lathe(p,Vector3.UP,PackedVector2Array([Vector2(0,.235),Vector2(.32*k,.14),Vector2(1.45*k,.092),Vector2(2.6*k,.047)]),7,Color("75604a"),1)
	for i in 7:
		var a := i*2.39 + phase
		var q := p+Vector3(cos(a)*(.65+.16*sin(a))*k,(2.25+.83*absf(cos(a)))*k,sin(a)*(.73+.08*cos(a))*k)
		b.bar(p+Vector3.UP*(1.16+.11*i)*k,q,.12*k,.132*k,Color("746048"),Vector3.BACK,1)
		var r := (.79+.22*absf(sin(a)))*k
		var c := Batch.tone(Color("839452"),.17*sin(a*1.7))
		b.lathe(q,Vector3.UP,PackedVector2Array([Vector2(-r*.64,0),Vector2(-r*.37,r*.76),Vector2(r*.01,r),Vector2(r*.51,r*.80),Vector2(r*.83,r*.44),Vector2(r*.93,0)]),7,c)
		for j in 2:
			var berry := q+Vector3(cos(a+j)*r*.83,-r*.10,sin(a+j)*r*.83)
			b.roller(berry,Vector3.UP,.106*k,.075*k,6,Color("bf8657"))

static func street_lamp(b: Batch, p: Vector3) -> void:
	b.roller(p+Vector3.UP*.055,Vector3.UP,.11,.21,8,STONE)
	b.lathe(p,Vector3.UP,PackedVector2Array([Vector2(.095,.12),Vector2(.28,.11),Vector2(.43,.066),Vector2(2.08,.056),Vector2(2.32,.093)]),7,Color("5b5148"))
	Join.lantern(b,p+Vector3(0,2.12,.245),1.17)
