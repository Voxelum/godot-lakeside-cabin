extends Node3D
## Guild-only furnishings measured in metres; the room shell stays unscaled.
const Batch := preload("res://art/building_trial/mesh_batch.gd")
const Mark := preload("res://world/interiors/structures/guild_heraldry.gd")
const WOOD := Color("795239")
const TRIM := Color("b58557")
const PAPER := Color("e9cf9d")
@export_enum("Reception", "Archive", "Entry Rug", "Council Rug", "Wall Shield", "Council Table", "Waiting Settle", "Registry Files") var role := 0

func _ready() -> void:
	var b := Batch.new()
	match role:
		0: _counter(b)
		1: _archive(b)
		2: _rug(b,Vector2(1.68,2.83),true)
		3: _rug(b,Vector2(3.59,3.04),false)
		4: Mark.shield(b,Vector3.ZERO,1.00,1.07)
		5: _council(b)
		6: _settle(b)
		7: _registry_files(b)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = .92
	b.add_to(self,"PaintedFurniture",material,role not in [2,3])

func _counter(b: Batch) -> void:
	const SIZE := Vector3(3.24,1.04,.84)
	b.box(Vector3(0,.945,0),Vector3(3.19,.13,.81),WOOD.darkened(.13),1)
	for i in 3:
		b.box(Vector3(0,1.012,(i-1)*.277),Vector3(SIZE.x,.056,.274),TRIM.darkened(.13+i*.04),1)
	b.box(Vector3(0,.442,0),Vector3(3.02,.884,.66),WOOD,1)
	b.box(Vector3(0,.072,0),Vector3(3.13,.144,.737),WOOD.darkened(.26),1)
	for i in 4:
		var x := (i-1.5)*.753
		b.box(Vector3(x,.48,.344),Vector3(.677,.635,.066),WOOD.darkened(.27),1)
		b.box(Vector3(x,.48,.377),Vector3(.54,.492,.043),TRIM.darkened(.27),1)
	for i in 5:
		b.box(Vector3((i-2)*.752,.49,.366),Vector3(.097,.82,.078),TRIM.darkened(.12),1)
	b.box(Vector3(0,.835,.365),Vector3(3.12,.105,.087),TRIM.darkened(.16),1)
	b.box(Vector3(0,.183,.367),Vector3(3.12,.088,.081),TRIM.darkened(.18),1)
	Mark.shield(b,Vector3(0,.49,.419),.37,.43)
	# Register lies open at the clerk's main station; spare forms sit to its right.
	var at := Vector3(-.59,1.04,.025)
	var axes := Basis(Vector3.UP,.13)
	b.box(at+Vector3.UP*.021,Vector3(.67,.043,.39),Color("643a2b"),1,axes)
	for side: float in [-1,1]:
		var leaf := at+axes*Vector3(side*.153,.056,0)
		b.box(leaf,Vector3(.296,.043,.349),PAPER,1,axes*Basis(Vector3.BACK,side*.09))
		for i in 4:
			b.box(leaf+axes*Vector3(0,.025,(i-1.5)*.061),Vector3(.188,.006,.015),Color("947052"),0,axes)
	b.box(at+Vector3.UP*.080,Vector3(.019,.011,.348),Color("9b744e"),0,axes)
	_page(b,Vector3(.73,1.036,.016),Vector2(.33,.25),-.32)
	_page(b,Vector3(.98,1.041,.095),Vector2(.29,.21),.09)
	b.roller(Vector3(.11,1.083,-.134),Vector3.UP,.088,.077,8,Color("342c33"))
	b.roller(Vector3(.11,1.136,-.134),Vector3.UP,.036,.050,8,Color("59443c"))
	b.bar(Vector3(.11,1.154,-.134),Vector3(.23,1.34,-.14),.026,.018,Color("c3a47a"))
	b.bar(Vector3(.185,1.265,-.138),Vector3(.262,1.38,-.144),.064,.017,Mark.IVORY)
	_block(SIZE)

func _registry_files(b: Batch) -> void:
	const SIZE := Vector3(1.34,1.75,.48)
	b.box(Vector3(0,.86,-.20),Vector3(1.28,1.72,.078),WOOD.darkened(.32),1)
	for x: float in [-.602,.602]:
		b.box(Vector3(x,.86,0),Vector3(.115,1.72,.45),WOOD,1)
	b.box(Vector3(0,1.701,0),Vector3(1.34,.098,.48),TRIM.darkened(.19),1)
	for row in 3:
		var y := .125+row*.494
		b.box(Vector3(0,y,.001),Vector3(1.27,.086,.46),TRIM.darkened(.22),1)
		for i in 5:
			var x := -.443+i*.202
			var h := .22 + .075*absf(sin(i+row*2.9))
			var color := [Color("76564b"),Color("746b51"),Color("596978")][(i+row)%3] as Color
			if (i+row)%4 == 2:
				b.box(Vector3(x,y+.094,.061),Vector3(.17,.088,.277),PAPER.darkened(.18),1)
				b.box(Vector3(x+.011,y+.143,.073),Vector3(.145,.022,.241),color,1)
			else:
				b.box(Vector3(x,y+.043+h*.5,.063),Vector3(.152,h,.275),color,1)
				b.box(Vector3(x,y+.125,.204),Vector3(.101,.044,.014),PAPER.darkened(.13))
	_block(SIZE)

func _archive(b: Batch) -> void:
	const SIZE := Vector3(1.58,1.61,.50)
	b.box(Vector3(0,.755,-.199),Vector3(1.51,1.51,.10),WOOD.darkened(.23),1)
	for x: float in [-.727,.727]:
		b.box(Vector3(x,.79,0),Vector3(.126,1.58,.48),WOOD,1)
	b.box(Vector3(0,1.562,0),Vector3(1.58,.096,.50),TRIM,1)
	var covers := [Color("625d44"),Color("814e3e"),Color("52677b"),Color("8c6b3f"),Color("a37d52")]
	for row in 3:
		var y := .112+row*.457
		b.box(Vector3(0,y,.001),Vector3(1.50,.075,.49),WOOD.lightened(.08),1)
		var x := -.606
		for i in 10:
			var w := .068+.066*absf(sin(i*1.63+row*2.7))
			if i == 3 and row != 1: x += .087
			var h := .19+.137*absf(cos(i*2.35+row))
			var ink: Color = covers[(i+2*row)%covers.size()]
			b.box(Vector3(x+w*.5,y+.038+h*.5,.078),Vector3(w,h,.286),ink)
			b.box(Vector3(x+w*.5,y+.104,.226),Vector3(w*.82,.023,.012),TRIM.lightened(.26))
			x += w+.017
	_block(SIZE)

func _rug(b: Batch, size: Vector2, bearing: bool) -> void:
	b.box(Vector3(0,.011,0),Vector3(size.x,.022,size.y),Mark.BLUE.darkened(.28))
	b.box(Vector3(0,.025,0),Vector3(size.x-.088,.006,size.y-.088),Mark.EDGE)
	b.box(Vector3(0,.030,0),Vector3(size.x-.162,.006,size.y-.162),Mark.BLUE.lightened(.09))
	for x: float in [-1,1]:
		for z: float in [-1,1]:
			var at := Vector3(x*(size.x*.5-.154),.038,z*(size.y*.5-.15))
			b.box(at,Vector3(.09,.007,.09),Mark.EDGE,0,Basis(Vector3.UP,PI*.25))
			for i in 9:
				b.box(Vector3(x*(.058+i*.092)*size.x*.5,.012,z*(size.y*.5+.022)),Vector3(.027,.013,.047),Mark.EDGE.darkened(.10))
	if bearing:
		Mark.swords(b,Vector3(0,.043,0),.97,Basis(Vector3.RIGHT,-PI*.5))

func _settle(b: Batch) -> void:
	const SIZE := Vector3(1.42,.90,.49)
	for x: float in [-.60,.60]:
		for z: float in [-.177,.172]:
			b.box(Vector3(x,.23,z),Vector3(.104,.46,.107),WOOD.darkened(.19),1)
		b.box(Vector3(x,.645,-.188),Vector3(.112,.52,.094),TRIM,1)
		b.box(Vector3(x,.62,.018),Vector3(.106,.092,.435),TRIM,1)
	b.box(Vector3(0,.465,0),Vector3(1.42,.105,.49),TRIM,1)
	b.box(Vector3(0,.53,.036),Vector3(1.16,.065,.336),Mark.BLUE.lightened(.11))
	b.box(Vector3(0,.735,-.195),Vector3(1.42,.23,.085),WOOD,1)
	b.box(Vector3(0,.861,-.195),Vector3(1.45,.065,.10),TRIM,1)
	_block(SIZE)

func _council(b: Batch) -> void:
	const SIZE := Vector3(2.69,.874,1.19)
	for s: float in [-1,1]:
		b.box(Vector3(s*1.03,.410,0),Vector3(.18,.82,.87),WOOD.darkened(.09),1)
		b.box(Vector3(s*1.03,.099,0),Vector3(.34,.198,1.03),WOOD,1)
	b.box(Vector3(0,.34,0),Vector3(2.24,.146,.204),WOOD,1)
	b.box(Vector3(0,.779,0),Vector3(2.56,.16,1.09),WOOD,1)
	for i in 4:
		b.box(Vector3(0,.825,(i-1.5)*.298),Vector3(SIZE.x,.098,.29),Batch.tone(TRIM,.17*cos(i*2.9)),1)
	var papers := Batch.new()
	_papers(papers)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	var surface := Node3D.new()
	surface.name = "CouncilBusiness"
	surface.position.y = SIZE.y
	add_child(surface)
	papers.add_to(surface,"MapsAndMinutes",material,false)
	_block(SIZE)

func _papers(b: Batch) -> void:
	_page(b,Vector3(-.21,.002,-.10),Vector2(.53,.32),-.22,true)
	_page(b,Vector3(.36,.003,-.17),Vector2(.31,.25),.15)
	_page(b,Vector3(-.46,.003,.29),Vector2(.218,.23),-.30)
	_page(b,Vector3(.28,.002,.25),Vector2(.25,.33),.40)
	b.roller(Vector3(-.64,.030,-.25),Vector3.RIGHT,.215,.032,8,PAPER)
	b.roller(Vector3(.65,.059,.13),Vector3.UP,.116,.078,8,Color("785845"))
	b.roller(Vector3(.65,.119,.13),Vector3.UP,.012,.054,8,Color("554130"))

func _page(b: Batch, at: Vector3, size: Vector2, angle: float, folio := false) -> void:
	var axes := Basis(Vector3.UP,angle)
	if folio:
		b.box(at,Vector3(size.x+.028,.010,size.y+.028),Color("705247"),0,axes)
	b.box(at+Vector3.UP*.016,Vector3(size.x,.023,size.y),PAPER,0,axes)
	for i in 4:
		var line := at+axes*Vector3(0,.028,(i-1.5)*size.y*.15)
		b.box(line,Vector3(size.x*(.72 if i<3 else .53),.003,.009),Color("9a7655"),0,axes)
	if folio:
		b.box(at+Vector3.UP*.032,Vector3(.013,.005,size.y),Color("ad8d65"),0,axes)
	else:
		b.roller(at+axes*Vector3(size.x*.31,.030,size.y*.28),Vector3.UP,.012,.028,8,Color("a14f3b"))

func _block(size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_mask = 0
	add_child(body)
	var piece := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	piece.shape = shape
	piece.position.y = size.y*.5
	body.add_child(piece)
