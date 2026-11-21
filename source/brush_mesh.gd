extends RefCounted
## Offline GDScript brush: triangles carry a deliberate pigment and normal.
## Godot's clockwise front face is enforced also for bent/double-sided leaves.
var st := SurfaceTool.new()
var rng := RandomNumberGenerator.new()
var count := 0
func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
func vert(p: Vector3, n: Vector3, c: Color) -> void:
	st.set_normal(n.normalized()); st.set_color(c); st.add_vertex(p)
func tri(a: Vector3,b: Vector3,c: Vector3, na: Vector3,nb: Vector3,nc: Vector3,ca: Color,cb: Color,cc: Color) -> void:
	var cr := (b-a).cross(c-a)
	if cr.length_squared() < 0.00000000001: return
	vert(a,na,ca)
	if cr.dot(na+nb+nc)>0:
		vert(c,nc,cc); vert(b,nb,cb)
	else:
		vert(b,nb,cb); vert(c,nc,cc)
	count+=1
func flat(a: Vector3,b: Vector3,c: Vector3, n: Vector3,col: Color) -> void:
	tri(a,b,c,n,n,n,col,col,col)
func quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,n: Vector3,col: Color) -> void:
	flat(a,b,c,n,col); flat(a,c,d,n,col)
func bake(label: String, mat: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new(); inst.name=label
	if count:
		st.index(); st.set_material(mat); inst.mesh=st.commit(); inst.mesh.resource_name=label
	return inst

## Manual rebuilds go beside the shipped art, never over an existing scene.
static func unused_scene_path(stem: String) -> String:
	var i := 1
	var path := "%s_Rebuild_%02d.tscn" % [stem, i]
	while FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		i += 1
		path = "%s_Rebuild_%02d.tscn" % [stem, i]
	return path
