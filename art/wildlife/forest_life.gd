extends Node3D
## Local wildlife clock, independent of orbit. Lengths are in scene meters.
const Terrain = preload("res://art/terrace/terrain_profile.gd")
@export var west_route := PackedVector3Array([Vector3(-10,5.52,6.2),Vector3(-5.65,5.77,5.8),Vector3(1,5.67,4.7),Vector3(10,6.8,2.1)])
@export var north_route := PackedVector3Array([Vector3(10,7.8,-6),Vector3(4,8.4,-7.0),Vector3(-3,7.6,-7.2),Vector3(-11,7.9,-4)])
@export var hare_stops := PackedVector2Array([Vector2(-3.55,6.35),Vector2(-4.05,7.22),Vector2(-4.60,6.75),Vector2(-4.15,5.85)])
var clock := 0.0
var birds: Array[Node3D] = []
var flies: Array[MeshInstance3D] = []
var glow_mats: Array[ShaderMaterial] = []
@onready var hare: Node3D = $Hare
@onready var almanac := get_node_or_null("../Almanac")

func _ready() -> void:
	for bird in [$SwiftWest, $SwiftNorth]:
		birds.append(bird)
		build_swift(bird)
	build_hare()
	for patch in [$WestOakFireflies, $BackMapleFireflies]:
		for i in range(3 if patch == $WestOakFireflies else 2):
			build_fly(patch, i)
	_process(0.0)

func joint(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = label
	parent.add_child(n)
	n.position = at
	return n

func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	return m

func oval(parent: Node3D, label: String, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 10
	mesh.rings = 5
	n.name = label
	n.mesh = mesh
	n.material_override = material(color)
	parent.add_child(n)
	n.position = at
	n.scale = size
	return n

# Explicit triangles define swept, pointed wings and two distinct tail forks.
func feather(parent: Node3D, label: String, points: PackedVector3Array, color: Color) -> void:
	var mesh := ImmediateMesh.new()
	var m := material(color)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, m)
	for p in points:
		mesh.surface_set_normal(Vector3.UP)
		mesh.surface_add_vertex(p)
	mesh.surface_end()
	var n := MeshInstance3D.new()
	n.name = label
	n.mesh = mesh
	parent.add_child(n)

func build_swift(bird: Node3D) -> void:
	var dark := Color("352c32")
	var slate := Color("51454a")
	oval(bird, "Body", Vector3.ZERO, Vector3(.20,.17,.48), dark)
	oval(bird, "Head", Vector3(0,.026,-.197), Vector3(.167,.157,.18), dark)
	oval(bird, "Throat", Vector3(0,-.045,-.197), Vector3(.105,.072,.16), Color("a59485"))
	for side in [-1.0, 1.0]:
		var wing := joint(bird, "LeftWing" if side < 0 else "RightWing", Vector3(.062*side,.02,-.04))
		var a := Vector3(0,0,-.115)
		var b := Vector3(.31*side,.025,-.18)
		var c := Vector3(.67*side,-.037,.156)
		var d := Vector3(.24*side,-.02,.08)
		var e := Vector3(0,0,.196)
		feather(wing,"SweptPrimaries",[a,b,d,b,c,d,a,d,e],slate)
		feather(bird,"TailForkL" if side < 0 else "TailForkR",[Vector3(0,0,.14),Vector3(.095*side,0,.20),Vector3(.148*side,-.015,.48),Vector3(0,0,.14),Vector3(.148*side,-.015,.48),Vector3(.012*side,0,.30)],dark)

func build_hare() -> void:
	var fur := Color("976248")
	var warm := Color("b67f5d")
	var cream := Color("d0a782")
	var rig := joint(hare,"Pose",Vector3.ZERO)
	oval(rig,"Back",Vector3(0,.25,.055),Vector3(.32,.43,.58),fur)
	oval(rig,"Chest",Vector3(0,.29,-.16),Vector3(.255,.32,.28),cream)
	oval(rig,"PowderPuff",Vector3(0,.24,.355),Vector3(.16,.16,.17),cream)
	var head := joint(rig,"Head",Vector3(0,.425,-.217))
	oval(head,"Face",Vector3.ZERO,Vector3(.256,.255,.275),warm)
	oval(head,"Muzzle",Vector3(0,-.057,-.095),Vector3(.164,.126,.159),cream)
	oval(head,"Nose",Vector3(0,-.031,-.165),Vector3(.059,.045,.045),Color("51343a"))
	for side in [-1.0,1.0]:
		var suffix := "L" if side < 0 else "R"
		oval(head,"Eye"+suffix,Vector3(.111*side,.017,-.064),Vector3(.049,.057,.055),Color("221a19"))
		oval(head,"EyeGlint"+suffix,Vector3(.129*side,.031,-.075),Vector3(.016,.017,.016),Color("f9e3bc"))
		var ear := joint(head,"Ear"+suffix,Vector3(.072*side,.091,.012))
		ear.rotation.z = -.26*side
		oval(ear,"Outer",Vector3(0,.137,0),Vector3(.092,.315,.064),fur)
		oval(ear,"Inner",Vector3(0,.151,-.025),Vector3(.055,.242,.029),Color("c28b82"))
		oval(rig,"Haunch"+suffix,Vector3(.122*side,.164,.158),Vector3(.197,.264,.307),warm)
		var rear := joint(rig,"HindFoot"+suffix,Vector3(.118*side,.071,.12))
		oval(rear,"Paw",Vector3(0,-.017,-.053),Vector3(.104,.102,.235),fur)
		var front := joint(rig,"ForeFoot"+suffix,Vector3(.079*side,.162,-.188))
		oval(front,"Paw",Vector3(0,-.06,-.019),Vector3(.08,.191,.116),warm)

func build_fly(patch: Node3D, i: int) -> void:
	var n := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(.32,.32)
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float strength = 0.0;
void vertex() {
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
 float r = length(UV - vec2(0.5)) * 2.0;
 ALBEDO = mix(vec3(0.62, 0.76, 0.15), vec3(1.0, 0.83, 0.42), 1.0-smoothstep(0.09,0.38,r));
 ALPHA = strength * (0.22 * (1.0-smoothstep(0.13,0.96,r)) + 0.83*(1.0-smoothstep(0.08,0.36,r)));
}
"""
	var m := ShaderMaterial.new()
	m.shader = shader
	n.name = "Mote%d" % (i+1)
	n.mesh = quad
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patch.add_child(n)
	flies.append(n)
	glow_mats.append(m)

func track(route: PackedVector3Array, u: float) -> Vector3:
	var travel := clampf(u,0.0,1.0) * (route.size()-1)
	var i := mini(int(travel), route.size()-2)
	return route[i].cubic_interpolate(route[i+1],route[maxi(i-1,0)],route[mini(i+2,route.size()-1)],travel-i)

func swift(bird: Node3D, route: PackedVector3Array, t: float, length: float, phase: float) -> void:
	bird.visible = t >= 0.0 and t <= length and route.size() >= 2
	if not bird.visible:
		return
	var u := t / length
	var p := track(route,u)
	bird.position = p + Vector3.UP * .12 * sin(u*TAU*1.7)
	var heading := track(route,u+.005) - track(route,u-.005)
	bird.look_at(bird.global_position + global_transform.basis * heading,Vector3.UP)
	bird.rotate_object_local(Vector3.FORWARD,.35*sin(u*TAU+phase))
	var power := smoothstep(-.42,.25,sin(t*2.7+phase))
	var beat := lerpf(.08,.63,power)*sin(t*TAU*4.4+phase)
	bird.get_node("LeftWing").rotation.z = -beat
	bird.get_node("RightWing").rotation.z = beat

func animate_hare() -> void:
	if hare_stops.size() < 2:
		return
	var first_rest := 5.2
	var trip := 1.86
	var slot := 9.35
	var cycle := maxf(clock-first_rest,0.0)
	var i := int(cycle/slot) % hare_stops.size()
	var offset := fmod(cycle,slot)
	var a := hare_stops[i]
	var b := hare_stops[(i+1)%hare_stops.size()]
	var travelling := clock >= first_rest and offset < trip
	var landing := 0.0
	var bound := 0.0
	var phase := 0.0
	var ground := a if clock < first_rest else b
	if travelling:
		var h := offset/trip*3.0
		phase = fmod(h,1.0)
		ground = a.lerp(b,(floorf(h)+smoothstep(.10,.82,phase))/3.0)
		bound = sin(PI*smoothstep(.06,.89,phase))
		landing = exp(-pow((phase-.91)*13.0,2.0))
	hare.position = Vector3(ground.x,Terrain.soil(ground.x,ground.y),ground.y)
	var direction := (b-a).normalized()
	var heading := atan2(-direction.x,-direction.y)
	var prev := (a-hare_stops[posmod(i-1,hare_stops.size())]).normalized()
	if clock < first_rest:
		hare.rotation.y = 2.55 + .15*sin(clock*.95)
	else:
		var start_heading := 2.55+.15*sin(first_rest*.95) if cycle < slot else atan2(-prev.x,-prev.y)
		hare.rotation.y = lerp_angle(start_heading,heading,smoothstep(0.0,.38,offset))
	var pose: Node3D = hare.get_node("Pose")
	pose.position.y = .19*bound
	pose.scale = Vector3(1.0+.13*landing,1.0+.08*bound-.19*landing+.018*sin(clock*4.2),1.0+.12*bound+.08*landing)
	pose.rotation.x = .18*bound*cos(phase*PI)
	var head: Node3D = pose.get_node("Head")
	head.rotation.y = .24*sin(clock*1.45)*(1.0-bound)
	head.rotation.x = -.08 + .15*sin(clock*2.3)*(1.0-bound)
	for suffix in ["L","R"]:
		var skew := 1.0 if suffix == "L" else -1.0
		head.get_node("Ear"+suffix).rotation.x = .46*bound + .12*sin(clock*4.0+skew)*pow(maxf(0.0,sin(clock*.9+skew)),6.0)
		pose.get_node("ForeFoot"+suffix).rotation.x = -.72*bound + .16*landing
		pose.get_node("HindFoot"+suffix).rotation.x = .76*bound - .20*landing

func _process(delta: float) -> void:
	clock += delta
	swift(birds[0],west_route,fmod(clock,41.0)-1.0,4.0,.42)
	swift(birds[1],north_route,fmod(clock,53.0)-13.5,5.8,2.27)
	animate_hare()
	var hour := float(almanac.get("hour")) if almanac != null else 14.0
	var fade := smoothstep(17.92,18.75,hour) * (1.0-smoothstep(20.1,20.75,hour))
	for i in range(flies.size()):
		var t := clock * (.68 + .11*i) + i*2.44
		flies[i].visible = fade > 0.001
		if flies[i].visible:
			if i < 3:
				# Three staggered stations along the near edge of the oak shade.
				var stations := [Vector3(-.22,.19,-.20),Vector3(-.01,-.22,.17),Vector3(.22,.03,.01)]
				flies[i].position = stations[i] + Vector3(.078*sin(t),.127*sin(1.13*t+i),.107*cos(.86*t))
			else:
				flies[i].position = Vector3(.40*sin(t)+.11*sin(1.91*t),.30*sin(1.13*t+i),.38*cos(.86*t)-.14*cos(1.8*t))
			# Fixed stagger keeps at least one western mote past mid-pulse.
			var pulse := .5+.5*sin(clock*2.05+i*TAU/3.0)
			glow_mats[i].set_shader_parameter("strength",fade*(.54+.46*pulse*pulse))
