extends RefCounted
## Offline sculpt in metres, +Z forward. Every visible form is a capped solid;
## including the locks, cloth ends, eye insets and straps. No sampled image,
## UVs, camera-facing axis, alpha cutouts, or alternate-angle meshes.
const H := .627
const A := .296
const B := .285
# Albedos are calibrated for the map's actual sunlight, not a white studio.
# Reserve butter highlights for a few creases; do not clip the whole crown.
const GOLD := Color("a46e32")
const HONEY := Color("c99749")
const BUTTER := Color("efc875")
const OCHRE := Color("82552d")
const ROOT := Color("624625")
const SKIN := Color("e5b6a0")
const WARM := Color("be8a76")
const AZURE := Color("6691c7")
const BLUE := Color("495985")
const NAVY := Color("383653")
const STEEL := Color("b0aec7")
const FROST := Color("c8ccda")
const SCARLET := Color("ba573d")
const SAFFRON := Color("de9450")
const HIDE := Color("674e34")
const BUFF := Color("9c7147")
const TOE := Color("c69254")
var rig := Skeleton3D.new()
var root := Node3D.new()
var paint := StandardMaterial3D.new()
var bindings := {}
var st: SurfaceTool

func build() -> Node3D:
	root.name = "IsaacModel"
	rig.name = "Rig"; root.add_child(rig)
	paint.resource_name = "Pigmented facets · no texture"
	paint.vertex_color_use_as_albedo = true
	paint.vertex_color_is_srgb = true
	paint.roughness = 1.0
	paint.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	paint.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	bone("Hip","",Vector3.UP*H)
	bone("Trunk","Hip",Vector3(0,.045,0))
	bone("Head","Trunk",Vector3(0,.291,.006))
	bone("Eyes","Head",Vector3(0,.215,.219))
	bone("Muffler","Trunk",Vector3(.102,.299,-.153))
	for side in [-1,1]:
		var s := "L" if side < 0 else "R"
		bone("Arm"+s,"Trunk",Vector3(.257*side,.285,0))
		bone("Elbow"+s,"Arm"+s,Vector3(0,-.181,0))
		bone("Hip"+s,"Hip",Vector3(.109*side,0,0))
		bone("Knee"+s,"Hip"+s,Vector3(0,-A,0))
		bone("Foot"+s,"Knee"+s,Vector3(0,-B,0))
	rig.reset_bone_poses()
	_face(); _hair(); _coat()
	for side in [-1,1]: _limbs(side)
	return root

func bone(label: String, parent: String, pos: Vector3) -> void:
	var id := rig.add_bone(label)
	if not parent.is_empty(): rig.set_bone_parent(id, rig.find_bone(parent))
	var size := Vector3(1.09,1.075,1.12) if label == "Head" else Vector3.ONE
	rig.set_bone_rest(id,Transform3D(Basis.from_scale(size),pos))
	var attach := BoneAttachment3D.new()
	attach.name = label; rig.add_child(attach); attach.bone_name = label; attach.bone_idx = id
	bindings[label] = attach

func _open() -> void:
	st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)

func _finish(at: String, label: String) -> void:
	st.index()
	var part := MeshInstance3D.new(); part.name = label; part.mesh = st.commit()
	part.mesh.surface_set_material(0,paint)
	bindings[at].add_child(part)

func _tri(a: Vector3,b: Vector3,c: Vector3,outward: Vector3, tint: Color) -> void:
	var n := (c-a).cross(b-a)
	if n.length_squared() < .0000000000001: return
	if n.dot(outward) < 0.0:
		var tmp := b; b = c; c = tmp; n = -n
	n = n.normalized()
	for v: Vector3 in [a,b,c]:
		st.set_color(tint); st.set_normal(n); st.add_vertex(v)

func _face4(a: Vector3,b: Vector3,c: Vector3,d: Vector3,n: Vector3, col: Color) -> void:
	_tri(a,b,c,n,col); _tri(a,c,d,n,col)

func _lathe(dx: float, sections: Array, hues: Array, n := 10) -> void:
	# Sections = (height, transverse radius, depth radius, centre Z).
	var ring0: Array[Vector3] = []
	for j in sections.size():
		var sec: Vector4 = sections[j]; var middle := Vector3(dx,sec.x,sec.w)
		var ring: Array[Vector3] = []
		for k in n:
			var angle := TAU*(float(k)+.5)/n
			ring.append(middle+Vector3(sin(angle)*sec.y,0,cos(angle)*sec.z))
		for k in n:
			var q := (k+1)%n
			var normal := (ring[k]+ring[q])*.5-middle
			if j == 0: _tri(middle,ring[k],ring[q],Vector3.DOWN,hues[0])
			else: _face4(ring0[k],ring[k],ring[q],ring0[q],normal,hues[mini(j-1,hues.size()-1)])
			if j == sections.size()-1: _tri(middle,ring[k],ring[q],Vector3.UP,hues[-1])
		ring0=ring

func _bead(p: Vector3, span: Vector3, hue: Color, sides := 8) -> void:
	_lathe(p.x,[Vector4(p.y-span.y*.5,span.x*.27,span.z*.31,p.z),Vector4(p.y-span.y*.27,span.x*.5,span.z*.49,p.z),Vector4(p.y+span.y*.29,span.x*.50,span.z*.50,p.z),Vector4(p.y+span.y*.5,span.x*.32,span.z*.34,p.z)],[hue,hue,hue.lightened(.034)],sides)

func _lock(a: Vector3, swell: Vector3, tip: Vector3, width: float, depth: float, ridge: Vector3, shadow: Color, light: Color, end: Color) -> void:
	# Creased solid sweep. Four unequal planes per cross-section and a real
	# point: this does not disappear edge-on. The central rib catches daylight.
	var u := (tip-a).normalized()
	var across := u.cross(ridge).normalized()
	var outward := across.cross(u).normalized()
	var before: Array[Vector3]=[]
	var centers := [a,swell,swell.lerp(tip,.52)]
	var widths := [.62,1.0,.51]
	for i in 3:
		var center: Vector3 = centers[i]; var w: float = width*widths[i]; var t: float = depth*widths[i]
		var ring: Array[Vector3] = [center+across*w,center+outward*t,center-across*w,center-outward*t*.72]
		for j in 4:
			var k := (j+1)%4; var n := (ring[j]+ring[k])*.5-center
			var color := (light if j == 0 else end) if j < 2 else shadow
			# The brightest crease is mid-lock, not a yellow cap covering the whole head.
			if i == 1: color = color.lerp(shadow,.53)
			if i == 0: _tri(a,ring[k],ring[j],-u,shadow)
			else: _face4(before[j],ring[j],ring[k],before[k],n,color)
			if i == 2: _tri(ring[j],tip,ring[k],n,color)
		before=ring

func _face() -> void:
	_open()
	_lathe(0,[Vector4(.015,.102,.101,.050),Vector4(.061,.172,.154,.044),Vector4(.136,.224,.194,.030),Vector4(.220,.245,.211,.021),Vector4(.330,.235,.215,.006),Vector4(.429,.194,.168,-.010),Vector4(.465,.087,.092,-.017)],[WARM,SKIN,SKIN,SKIN,SKIN,WARM],12)
	for side in [-1,1]:
		_bead(Vector3(side*.235,.177,.017),Vector3(.106,.153,.123),WARM)
		_bead(Vector3(side*.264,.182,.040),Vector3(.046,.073,.060),SKIN)
	_bead(Vector3(0,.165,.222),Vector3(.069,.076,.074),Color("f1bc94"),6)
	_finish("Head","CheeksEarsAndNose")
	_open()
	for side in [-1,1]:
		_bead(Vector3(side*.102,0,.005),Vector3(.094,.088,.048),Color("f6e3c3"))
		_bead(Vector3(side*.095,-.005,.031),Vector3(.050,.080,.027),Color("353350"))
		_bead(Vector3(side*.095,-.029,.041),Vector3(.043,.023,.015),Color("4d6d99"),6)
	_finish("Eyes","InsetEyes")

func _hair() -> void:
	_open()
	var rims: Array = []
	for j in 4:
		var loop: Array[Vector3] = []
		for k in 12:
			var a := TAU*k/12.0; var x := sin(a); var z := cos(a)
			var y: float = [.114+.199*smoothstep(-.22,.97,z)+.024*x,.347+.026*sin(a*2),.472+.024*x,.548+.016*x][j]
			loop.append(Vector3(x*[.259,.293,.259,.120][j]-.018*j/3.0,y,z*[.216,.261,.224,.107][j]-.023))
		rims.append(loop)
	for k in 12:
		var q := (k+1)%12
		var n: Vector3 = (rims[1][k]+rims[1][q])*.5; n.y=0.0
		_tri(Vector3(0,.185,-.017),rims[0][k],rims[0][q],Vector3.DOWN,ROOT)
		for j in 3: _face4(rims[j][k],rims[j+1][k],rims[j+1][q],rims[j][q],n,[ROOT,GOLD,OCHRE][j])
		_tri(Vector3(-.027,.573,-.031),rims[3][k],rims[3][q],Vector3.UP,OCHRE)
	# Crown part, high crooked cowlick and the split behind it. Shorter radial
	# locks change level around both temples; the nape drops behind the scarf.
	_lock(Vector3(.03,.46,-.04),Vector3(-.035,.610,-.048),Vector3(-.120,.755,-.041),.059,.041,Vector3.UP,OCHRE,HONEY,BUTTER)
	_lock(Vector3(.02,.448,-.032),Vector3(.104,.540,-.102),Vector3(.245,.597,-.132),.071,.051,Vector3.UP,OCHRE,GOLD,HONEY)
	_lock(Vector3(-.06,.434,-.018),Vector3(-.176,.504,-.047),Vector3(-.286,.551,-.106),.071,.046,Vector3.UP,OCHRE,HONEY,GOLD)
	# Broad, stepped fringe; frame the eyes rather than covering the whole face.
	_lock(Vector3(-.071,.504,.096),Vector3(-.195,.403,.211),Vector3(-.301,.270,.198),.094,.053,Vector3.BACK,OCHRE,HONEY,GOLD)
	_lock(Vector3(-.014,.510,.113),Vector3(-.090,.390,.234),Vector3(-.100,.232,.258),.093,.047,Vector3.BACK,ROOT,BUTTER,HONEY)
	_lock(Vector3(.088,.508,.109),Vector3(.043,.381,.236),Vector3(.013,.269,.273),.083,.047,Vector3.BACK,OCHRE,HONEY,BUTTER)
	_lock(Vector3(.141,.477,.091),Vector3(.163,.360,.217),Vector3(.112,.254,.255),.074,.052,Vector3.BACK,ROOT,GOLD,HONEY)
	for k in 9:
		var a: float = [1.04,1.56,2.07,2.62,3.13,3.71,4.22,4.78,5.24][k]
		var out := Vector3(sin(a),0,cos(a)); var sweep := Vector3(cos(a),0,-sin(a))
		var root_p := out*.174 + Vector3(-.015,.450,-.023)
		var at := out*(.254+.011*sin(a*3.0))+Vector3(0,.343,-.023)
		var tip := out*([.325,.382,.312,.327,.335,.313,.333,.374,.314][k] as float)+sweep*.036+Vector3(0,[.128,.297,.149,.112,.206,.126,.166,.237,.097][k],-.018)
		_lock(root_p,at,tip,.087,.052,(out+Vector3.UP*.48).normalized(),OCHRE,HONEY if k%3!=1 else GOLD,GOLD if k%3!=1 else BUTTER)
	_finish("Head","SweptCrownAndLocks")

func _coat() -> void:
	_open()
	_lathe(0,[Vector4(-.152,.222,.155,-.004),Vector4(-.119,.248,.172,-.003),Vector4(-.071,.236,.164,0),Vector4(.071,.189,.139,.005),Vector4(.214,.219,.153,0),Vector4(.269,.238,.153,-.003),Vector4(.305,.170,.120,-.005)],[NAVY,AZURE,BLUE,BLUE,NAVY,BLUE])
	_lathe(0,[Vector4(.029,.195,.145,.005),Vector4(.078,.193,.150,.003)],[Color("443e50")])
	_bead(Vector3(-.028,.055,.151),Vector3(.093,.057,.029),BUFF)
	_finish("Trunk","IndigoTunicHemAndBelt")
	_open()
	_lathe(0,[Vector4(.184,.136,.153,.019),Vector4(.228,.200,.171,.009),Vector4(.288,.220,.176,0),Vector4(.324,.144,.147,0)],[Color("778cae"),STEEL,FROST],10)
	_lathe(0,[Vector4(.290,.139,.134,.005),Vector4(.334,.154,.135,-.002),Vector4(.357,.119,.120,0)],[SCARLET,SAFFRON])
	_lock(Vector3(-.117,.294,.121),Vector3(-.049,.232,.173),Vector3(.053,.164,.174),.075,.021,Vector3.BACK,SCARLET,SAFFRON,Color("ed9148"))
	_finish("Trunk","SteelGorgetAndFoldedScarf")
	_open()
	_lock(Vector3(0,0,0),Vector3(-.076,-.117,-.050),Vector3(-.184,-.295,-.083),.086,.033,Vector3.FORWARD,Color("a75135"),SCARLET,SAFFRON)
	_lock(Vector3(.013,-.013,0),Vector3(.079,-.071,-.048),Vector3(.151,-.137,-.095),.049,.028,Vector3.FORWARD,HIDE,SAFFRON,SCARLET)
	_finish("Muffler","SplitScarfEnds")

func _limbs(side: int) -> void:
	var s := "L" if side<0 else "R"
	_open()
	_lathe(0,[Vector4(-A-.010,.072,.080,.003),Vector4(-.149,.091,.102,0),Vector4(.020,.113,.124,-.003)],[NAVY,Color("414973")],8)
	_finish("Hip"+s,"Breeches")
	_open()
	_lathe(0,[Vector4(-B+.009,.074,.084,0),Vector4(-.173,.084,.095,0),Vector4(-.071,.088,.094,.003),Vector4(-.037,.098,.102,0),Vector4(-.015,.093,.093,-.002),Vector4(.017,.071,.075,0)],[HIDE,BUFF,Color("ae7743"),TOE,NAVY],8)
	_finish("Knee"+s,"RolledBootTopAndCalf")
	_open()
	_lathe(0,[Vector4(-.076,.086,.142,.065),Vector4(-.052,.099,.151,.065),Vector4(.002,.098,.149,.061),Vector4(.049,.083,.122,.035),Vector4(.086,.074,.082,.002)],[HIDE,BUFF,TOE,HIDE],8)
	_finish("Foot"+s,"LeatherToeAndSole")
	_open()
	_lathe(0,[Vector4(-.204,.070,.080,.004),Vector4(-.146,.086,.091,0),Vector4(-.035,.100,.103,0),Vector4(.019,.090,.089,0)],[NAVY,NAVY,BLUE],8)
	_lathe(0,[Vector4(-.072,.103,.099,0),Vector4(-.043,.119,.111,-.006),Vector4(.011,.116,.108,-.008),Vector4(.048,.073,.078,0)],[Color("778ba9"),AZURE,STEEL],8)
	_finish("Arm"+s,"BlueSleeveAndPauldron")
	_open()
	_lathe(0,[Vector4(-.159,.068,.065,.021),Vector4(-.105,.079,.079,.013),Vector4(-.045,.082,.081,.007),Vector4(.012,.068,.079,0)],[HIDE,BUFF,NAVY],8)
	_bead(Vector3(0,-.183,.027),Vector3(.143,.116,.135),TOE)
	_finish("Elbow"+s,"BracerAndGlove")
