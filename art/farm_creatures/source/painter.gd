extends RefCounted
## Offline vertex paint. Each poseable rigid part takes a single opaque surface.
## Rows describe sculpted cross-sections, not a primitive stretched at runtime.
const Brush := preload("res://art/monster_trial/source/brush.gd")
var b := Brush.new()
var pots: Dictionary = {}
var index := 0

func at(part: Node3D) -> SurfaceTool:
	if not pots.has(part): pots[part] = b.surface()
	return pots[part]

func finish_look() -> void:
	for part: Node3D in pots:
		var st: SurfaceTool = pots[part]
		st.index()
		st.set_material(b.vertex_pigment())
		var mesh := st.commit()
		mesh.resource_name = "%s • %d" % [part.name,index]
		var skin := part.get_node_or_null("Skin") as MeshInstance3D
		if not skin:
			skin = MeshInstance3D.new()
			skin.name = "Skin"
			part.add_child(skin)
			skin.set_meta(&"looks", [null,null,null])
		var looks: Array = skin.get_meta(&"looks")
		looks[index] = mesh
		skin.set_meta(&"looks", looks)
		if index == 0: skin.mesh = mesh
	pots.clear()

# X + Y sections along Z (insects), or X + Z along Y. Dimensions in metres.
# Row: [axis coordinate, transverse center, rx, other radius, paint].
func shell(part: Node3D, center: Vector3, along_z: bool, rows: Array, n := 10, phase := 0.0) -> void:
	var st := at(part)
	var prev: Array[Vector3] = []
	var old_center := center
	for j in rows.size():
		var r: Array = rows[j]
		var mid := center + (Vector3(0,r[1],r[0]) if along_z else Vector3(0,r[0],r[1]))
		var ring: Array[Vector3] = []
		for k in n:
			var a := TAU*k/n+phase
			var x := float(r[2])*cos(a)
			var y := float(r[3])*sin(a)
			ring.append(mid+(Vector3(x,y,0) if along_z else Vector3(x,0,y)))
		for k in n:
			var q := (k+1)%n
			var col := Color(r[4]).darkened(.025*float(k%3))
			if j == 0 or j == rows.size()-1:
				var norm := (Vector3.BACK if along_z else Vector3.UP) * (-1 if j==0 else 1)
				b.flat(st,mid,ring[k],ring[q],norm,col)
			if j > 0:
				var norm := (ring[k]+ring[q]+prev[k]+prev[q])*.25-(mid+old_center)*.5
				b.flat(st,prev[k],prev[q],ring[k],norm,col)
				b.flat(st,ring[k],prev[q],ring[q],norm,col)
		prev=ring
		old_center=mid

# Midsection facets are broad enough to resolve at 320x180.
func egg(part: Node3D, center: Vector3, radii: Vector3, color: String, n := 9) -> void:
	var rows := []
	for d: float in [-.99,-.65,-.12,.46,.84,.99]:
		var width := sqrt(1.-d*d)
		rows.append([d*radii.y,0,radii.x*width,radii.z*width,color])
	shell(part,center,false,rows,n)

# Hand bent tubes maintain their ring orientation through every angle.
func horn(part: Node3D, path: Array, radii: Array, colors: Array, sides := 6) -> void:
	var st := at(part)
	var prev: Array[Vector3] = []
	var old_mid: Vector3 = path[0]
	var first := (Vector3(path[1])-old_mid).normalized()
	var guide := Vector3.FORWARD if absf(first.dot(Vector3.FORWARD))<.8 else Vector3.UP
	var u := first.cross(guide).normalized()
	for j in path.size():
		var mid: Vector3 = path[j]
		var tangent := (Vector3(path[mini(j+1,path.size()-1)])-Vector3(path[maxi(j-1,0)])).normalized()
		u = (u-tangent*tangent.dot(u)).normalized()
		var v := tangent.cross(u)
		var ring: Array[Vector3] = []
		var col := Color(colors[mini(maxi(j-1,0),colors.size()-1)])
		for k in sides:
			var angle := TAU*k/sides
			ring.append(mid+(u*cos(angle)+v*sin(angle))*float(radii[j]))
		for k in sides:
			var q := (k+1)%sides
			if j == 0 or j == path.size()-1: b.flat(st,mid,ring[k],ring[q],tangent*(-1 if j==0 else 1),col)
			if j > 0:
				var norm := (ring[k]+ring[q]+prev[k]+prev[q])*.25-(mid+old_mid)*.5
				b.flat(st,prev[k],prev[q],ring[k],norm,col)
				b.flat(st,ring[k],prev[q],ring[q],norm,col)
		prev=ring
		old_mid=mid

# Plate with a hand-set crest and reverse ridge, including back faces.
func plate(part: Node3D, edge: Array, crest: Vector3, reverse: Vector3, tint: String, shade: String) -> void:
	var st := at(part)
	var center := crest.lerp(reverse,.5)
	for i in edge.size():
		var p: Vector3 = edge[i]
		var q: Vector3 = edge[(i+1)%edge.size()]
		b.flat(st,p,q,crest,(p+q+crest)/3.-center,Color(tint).lerp(Color(shade),.055*(i%4)))
		b.flat(st,p,q,reverse,(p+q+reverse)/3.-center,Color(shade))
