extends Node3D
## Original faceted silhouettes. Local +Z forward; the foot origin is fixed.
const Batch := preload("res://art/building_trial/mesh_batch.gd")
@export_enum("Net Mender", "Lamplighter", "Root Maw") var look := 0
var _paint := StandardMaterial3D.new()
var _pivot: Node3D
var _gear: Node3D
var _jaw: Node3D
var _elapsed := 0.0
const CombatMotion := preload("res://scripts/foundation/combat_motion.gd")
var _arms: Array[Node3D] = []
var _action: StringName = &"idle"

func _ready() -> void:
	_paint.vertex_color_use_as_albedo = true
	_paint.roughness = .98
	_paint.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_paint.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	if look == 2:
		_flower()
	else:
		_person(look == 0)

func _physics_process(dt: float) -> void:
	if _action != &"idle": return
	_elapsed += dt
	if look == 2:
		# The stem and lower maw stay rooted. Only the hinged upper petals
		# breathe/open; this idle isn't an attack, hit volume or lunging clip.
		var pulse := fposmod(_elapsed + 1.8, 6.4)
		_jaw.rotation.x = -.13 - .43 * smoothstep(2.2, 2.85, pulse) * (1.-smoothstep(3.2, 4.12, pulse))
	else:
		var sway := sin(_elapsed * 1.4 + float(look) * 2.22)
		_pivot.rotation.y = .16 * sway
		_gear.rotation.z = .038 * sway
		for arm in _arms: arm.rotation = Vector3.ZERO

func _person(net: bool) -> void:
	var height := 1.0 if net else 1.17
	var coat := Color("4d837c") if net else Color("55445e")
	var edge := Color("87b39b") if net else Color("9b664a")
	var dark := Color("354c48") if net else Color("393540")
	var skin := Color("c29070") if net else Color("b88563")
	var batch := Batch.new()
	for sign_x: float in [-1, 1]:
		var x := sign_x * (.135 if net else .117)
		batch.box(Vector3(x,.10,sign_x * .055 + .04),Vector3(.191,.20,.316),dark)
		batch.bar(Vector3(x,.17,sign_x*.044),Vector3(x,.56 * height,0),.166,.177,dark.lightened(.18))
	var edge_bottom := .29 if net else .24
	var width := .298 if net else .252
	var top := .262 if net else .237
	batch.lathe(Vector3.ZERO,Vector3.UP,PackedVector2Array([
		Vector2(edge_bottom,0),Vector2(edge_bottom,width),Vector2(.51*height,width*.83),
		Vector2(.76*height,top*.89),Vector2(1.10*height,top), Vector2(1.19*height,.109), Vector2(1.19*height,0)]),8,coat)
	batch.roller(Vector3(0,.66*height,0),Vector3.UP,.085,width*.80,8,dark)
	batch.roller(Vector3(0,1.15*height,0),Vector3.UP,.093,.149,8,edge)
	for sign_x: float in [-1, 1]:
		var shoulder := Vector3(sign_x * top,.995*height,0)
		var elbow := Vector3(sign_x * (top+.105),.735*height,.07)
		var hand := Vector3(sign_x * (.34 if net else .42),.82*height,.245)
		var arm := Node3D.new()
		arm.position = shoulder
		add_child(arm)
		_arms.append(arm)
		var sleeve := Batch.new()
		sleeve.bar(Vector3.ZERO,elbow-shoulder,.177,.155,coat.lightened(.154))
		sleeve.bar(elbow-shoulder,hand-shoulder,.131,.129,edge)
		sleeve.box(hand-shoulder,Vector3(.134,.138,.145),skin)
		sleeve.add_to(arm,"Sleeve",_paint)
	batch.add_to(self,"CoatAndBoots",_paint)

	_pivot = Node3D.new()
	_pivot.name = "Head"
	_pivot.position = Vector3(0,1.22*height,.014)
	add_child(_pivot)
	batch = Batch.new()
	batch.lathe(Vector3.ZERO,Vector3.UP,PackedVector2Array([
		Vector2(-.055,0),Vector2(-.055,.128),Vector2(.026,.204),Vector2(.235,.216),
		Vector2(.314,.143),Vector2(.345,0)]),8,skin)
	batch.box(Vector3(0,.094,.213),Vector3(.082,.074,.071),skin.lightened(.095))
	for side: float in [-1,1]:
		batch.box(Vector3(side * .081,.159,.196),Vector3(.041,.062,.032),Color("48343c"))
	if net:
		batch.roller(Vector3(0,.234,0),Vector3.UP,.075,.233,9,Color("59443e"))
		batch.lathe(Vector3.ZERO,Vector3.UP,PackedVector2Array([Vector2(.264,0),
			Vector2(.265,.365),Vector2(.32,.391),Vector2(.364,.238),Vector2(.484,.161),Vector2(.493,0)]),10,Color("cfab65"))
		batch.roller(Vector3(0,.369,0),Vector3.UP,.045,.235,10,Color("805d4f"))
	else:
		# Pointed cowl pulled back at the forehead. Cloth folds descend at the shoulders.
		batch.lathe(Vector3(0,.16,-.075),Vector3(0,1,-.38),PackedVector2Array([
			Vector2(-.138,.19),Vector2(.051,.229),Vector2(.165,.228),Vector2(.385,.141),Vector2(.478,0)]),7,dark)
		for side: float in [-1,1]:
			batch.bar(Vector3(side * .176,.22,.11),Vector3(side*.247,-.14,.043),.13,.14,coat)
	batch.add_to(_pivot,"FaceAndHeadwear",_paint)

	_gear = Node3D.new()
	_gear.name = "Net" if net else "LanternStaff"
	_gear.position = Vector3(-.34,.82,.245) if net else Vector3(.42,.82*height,.245)
	var holding := _arms[0 if net else 1]
	_gear.position -= holding.position
	holding.add_child(_gear)
	batch = Batch.new()
	if net:
		var hoop := PackedVector3Array()
		for i in 9:
			var a := TAU*float(i)/8.
			hoop.append(Vector3(-.19 + .217*cos(a), .09 + .274*sin(a),.02 + .09*cos(a)))
		for i in 8:
			batch.bar(hoop[i],hoop[i+1],.040,.038,Color("96734f"))
			batch.bar(hoop[i],Vector3(-.154,-.254,-.101),.025,.025,Color("b8aa78"))
		batch.bar(Vector3(-.19,-.18,.02),Vector3(.02,.036,0),.058,.061,Color("96734f"))
	else:
		var brass := Color("926f4b")
		batch.bar(Vector3(.015,-.92,.025),Vector3(.028,.80,.01),.070,.071,Color("502f2b"))
		batch.bar(Vector3(.028,.80,.01),Vector3(.309,.745,.01),.081,.077,brass)
		batch.bar(Vector3(.309,.745,.01),Vector3(.313,.643,.009),.065,.069,brass)
		var lamp := Vector3(.313,.470,.009)
		batch.roller(lamp,Vector3.UP,.219,.103,6,Color("efb451"))
		batch.lathe(lamp,Vector3.UP,PackedVector2Array([Vector2(.10,.146),Vector2(.144,.149),Vector2(.205,0)]),6,brass)
		batch.roller(lamp-Vector3.UP*.113,Vector3.UP,.065,.139,6,brass)
		for i in 6:
			var a := TAU*float(i)/6.
			batch.roller(lamp+Vector3(cos(a)*.128,0,sin(a)*.128),Vector3.UP,.226,.018,4,brass)
	batch.add_to(_gear,"HandmadeProp",_paint)

func _flower() -> void:
	var batch := Batch.new()
	var green := Color("47745c")
	var lime := Color("809659")
	var lip := Color("b7444a")
	var flesh := Color("713445")
	var teeth := Color("ebc58b")
	batch.lathe(Vector3.ZERO,Vector3.UP,PackedVector2Array([Vector2(0,0),Vector2(.026,.214),
		Vector2(.19,.178),Vector2(.48,.111),Vector2(.70,.134),Vector2(.74,0)]),8,green)
	for i in 5:
		var d := Vector3(sin(TAU*i/5.),0,cos(TAU*i/5.))
		var side := d.cross(Vector3.UP)
		var low := .04 + float(i % 2)*.08
		var root := Vector3.UP*(.24+.041*i)
		var ridge := d*.42+Vector3.UP*(low+.11)
		var tip := d*(.75-float(i%3)*.07)+Vector3.UP*(low+.08)
		var l := d*.40+Vector3.UP*low+side*.162
		var r := d*.46+Vector3.UP*low-side*.176
		batch.tri(root,l,ridge,Vector3.UP,green)
		batch.tri(l,tip,ridge,Vector3.UP,green)
		batch.tri(root,ridge,r,Vector3.UP,lime)
		batch.tri(ridge,tip,r,Vector3.UP,lime)
		batch.tri(root,tip,r,Vector3.DOWN,green.darkened(.15))
	batch.lathe(Vector3(0,.63,.03),Vector3(0,-.17,1),PackedVector2Array([Vector2(-.36,0),
		Vector2(-.27,.218),Vector2(-.096,.339),Vector2(.28,.306),Vector2(.394,.199),Vector2(.42,0)]),9,lip)
	batch.box(Vector3(0,.743,.26),Vector3(.493,.065,.299),flesh)
	for x: float in [-.185,0,.185]:
		var p := Vector3(x,.79,.359 - absf(x)*.32)
		batch.lathe(p,Vector3.UP,PackedVector2Array([Vector2(-.025,.045),Vector2(.068,0)]),4,teeth)
	batch.add_to(self,"RootAndLowerPetals",_paint)
	_jaw = Node3D.new()
	_jaw.name = "UpperPetals"
	_jaw.position = Vector3(0,.82,-.196)
	add_child(_jaw)
	batch = Batch.new()
	batch.lathe(Vector3(0,.08,.19),Vector3.BACK,PackedVector2Array([Vector2(-.21,0),
		Vector2(-.154,.248),Vector2(.095,.305),Vector2(.281,.218),Vector2(.375,.126),Vector2(.39,0)]),9,lip.lightened(.12))
	for x: float in [-.206,-.070,.070,.206]:
		var z := .485 - absf(x)*.46
		batch.lathe(Vector3(x,-.067,z),Vector3.DOWN,PackedVector2Array([Vector2(-.022,.046),Vector2(.079,0)]),4,teeth)
		batch.box(Vector3(x,.166,.385 - absf(x)*.32),Vector3(.056,.05,.083),lip.lightened(.33))
	batch.add_to(_jaw,"OuterPetalAndTeeth",_paint)

func drive_combat(action: StringName, progress: float, _forward: Vector3, _weapon: StringName, _drawn: bool) -> void:
	_action = action
	if look == 2:
		# Rooted plant has a hinged jaw, not humanoid shoulders.
		var pulse := sin(PI * progress)
		_jaw.rotation.x = (-.11 + 1.1 * progress) if action == &"down" else (-.11 - .84 * pulse)
		position.y = -.26 * progress if action == &"down" else 0.0
		return
	var pose := CombatMotion.sample(action, progress)
	rotation = Vector3(pose.x * .72, pose.y * .72, 0)
	_arms[1].rotation.x = pose.z
	_arms[0].rotation.x = pose.w
	position.y = -.29 * progress if action == &"down" else 0.0
