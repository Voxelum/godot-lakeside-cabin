extends Node3D
## The ledger owns departure, road delays and payment; these are only meshes.
const L := preload("res://scripts/foundation/village_ledger.gd")
var route: Path3D
var wheels: Array[Node3D] = []
var legs: Array[Node3D] = []
var loads: Array[Node3D] = []
var materials := {}

func part(p: Node3D, mesh: PrimitiveMesh, at: Vector3, c: String) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	if not materials.has(c):
		var m := StandardMaterial3D.new(); m.albedo_color = Color(c); materials[c] = m
	mesh.material = materials[c]; n.mesh = mesh; p.add_child(n); n.position = at
	return n

func box(p: Node3D, at: Vector3, size: Vector3, c: String) -> MeshInstance3D:
	var m := BoxMesh.new(); m.size = size; return part(p,m,at,c)

func oval(p: Node3D, at: Vector3, size: Vector3, c: String) -> MeshInstance3D:
	var m := SphereMesh.new(); m.radius=.5; m.height=1; m.radial_segments=8; m.rings=4
	var n := part(p,m,at,c); n.scale=size; return n

func _ready() -> void:
	name="MarketCaravan"; add_to_group("market_caravan"); hide()
	var team:=Node3D.new(); add_child(team); team.position.z=-2.47
	for side: float in [-.46,.46]:
		var coat := "975936" if side<0 else "bc8c58"
		oval(team, Vector3(side,.99,0),Vector3(.59,.73,1.46),coat)
		oval(team,Vector3(side,1.38,-.55),Vector3(.37,.93,.50),coat).rotation.x=-.43
		oval(team,Vector3(side,1.68,-.85),Vector3(.35,.39,.62),coat)
		oval(team,Vector3(side,1.58,-1.06),Vector3(.29,.23,.31),"674337")
		for x: float in [-.10,.10]: oval(team,Vector3(side+x,1.93,-.70),Vector3(.10,.29,.14),coat)
		oval(team,Vector3(side,1.53,-.46),Vector3(.18,.69,.24),"493628").rotation.x=-.43
		oval(team,Vector3(side,.79,.73),Vector3(.18,.78,.22),"493628").rotation.x=.26
		for z: float in [-.46,.45]:
			for x: float in [-.17,.17]:
				var joint:=Node3D.new(); team.add_child(joint); joint.position=Vector3(side+x,.80,z); legs.append(joint)
				box(joint,Vector3(0,-.34,0),Vector3(.13,.68,.16),coat)
				box(joint,Vector3(0,-.70,-.02),Vector3(.16,.15,.20),"44372d")
		oval(team,Vector3(side,1.04,-.27),Vector3(.62,.72,.17),"4e3626")
	box(self,Vector3(0,.67,0),Vector3(1.42,.18,1.95),"754831")
	for side: float in [-.68,.68]:
		box(self,Vector3(side,.88,0),Vector3(.10,.35,1.98),"ba874d")
		box(self,Vector3(side*.7,.76,-1.76),Vector3(.09,.10,2.35),"7d583c")
		for z: float in [-.65,.67]:
			var wheel:=Node3D.new(); add_child(wheel); wheel.position=Vector3(side*1.22,.46,z); wheels.append(wheel)
			var rim:=TorusMesh.new(); rim.inner_radius=.35; rim.outer_radius=.46; rim.rings=12; rim.ring_segments=5
			part(wheel,rim,Vector3.ZERO,"493c33").rotation.z=PI/2
			for i in 4: box(wheel,Vector3.ZERO,Vector3(.085,.79,.07),"c39257").rotation.x=i*PI/4
			oval(wheel,Vector3.ZERO,Vector3(.22,.20,.20),"cfaa62")
	for i in 3:
		var parcel:=Node3D.new(); add_child(parcel); loads.append(parcel)
		if i==0:
			box(parcel,Vector3.ZERO,Vector3(1.05,.60,.64),"b67c43")
			for x:float in [-.34,.34]: box(parcel,Vector3(x,0,0),Vector3(.07,.62,.66),"4d4946")
		else:
			oval(parcel,Vector3.ZERO,Vector3(.63,.72,.77),"d6b97d" if i==1 else "ceb08a")
			oval(parcel,Vector3(0,.31,0),Vector3(.22,.18,.20),"8e6946")

func update_view(d: Dictionary) -> void:
	if not is_instance_valid(route): route=get_tree().get_first_node_in_group(&"village_caravan_route") as Path3D
	visible = d.visit >= 0 and route != null and route.curve != null
	if not visible: return
	var age:=float(d.visit); var length:=route.curve.get_baked_length()
	var f:=age/L.DOCK if age<L.DOCK else 1.0 if age<L.LEAVE else 1.0-(age-L.LEAVE)/(L.HOME-L.LEAVE)
	var meters:=clampf(f,0,1)*length
	var pos:=route.to_global(route.curve.sample_baked(meters))
	var tangent:=route.to_global(route.curve.sample_baked(minf(length,meters+.25)))-route.to_global(route.curve.sample_baked(maxf(0,meters-.25)))
	tangent.y=0
	if tangent.length_squared()<.00001: return
	var turn:=smoothstep(L.LEAVE-.8,L.LEAVE,age)*PI
	global_rotation.y=atan2(-tangent.x,-tangent.z)+turn; global_position=pos
	for wheel in wheels: wheel.rotation.x=-meters/.46
	for i in legs.size(): legs[i].rotation.x=sin(meters*4+PI*float(i in [0,3,5,6]))*.38 if age<L.DOCK or age>L.LEAVE else 0.0
	var imported:=0; var exported:=0
	for job in d.cargo:
		if job["import"]: imported+=job.qty
		else: exported+=job.qty
	var stock:=0
	for count in d.wagon.values(): stock+=int(count)
	for i in loads.size():
		var p:=Vector3(0,1.06,-.42) if i==0 else Vector3(-.32 if i==1 else .32,1.06,.38)
		var unloading:=i==0 and imported>0
		var loading:=i==2 and exported>0
		loads[i].visible = (stock>i or imported+exported>i) and not (unloading and age>=L.DOCK+2.0)
		if loading and age<L.DOCK+2.0: loads[i].hide()
		var t:=smoothstep(L.DOCK,L.DOCK+2.0,age) if unloading else 1.0-smoothstep(L.DOCK+2.0,L.LEAVE-.8,age) if loading else 0.0
		loads[i].position=p+Vector3(1.45*t,sin(PI*t)*.62-.70*t,0)
