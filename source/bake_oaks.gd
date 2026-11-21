extends SceneTree
const Brush = preload("brush_mesh.gd")
const DIR := "res://art/woods/"
var rng := RandomNumberGenerator.new()
var bark := ShaderMaterial.new()
var foliage := ShaderMaterial.new()
var n_errors := 0
func _initialize() -> void:
	bark.shader=load(DIR+"pigments.gdshader"); bark.resource_name="Bark | warm umber"
	for variant in 2:
		rng.seed=18813+variant*300
		foliage=ShaderMaterial.new(); foliage.shader=load(DIR+"canopy.gdshader"); foliage.resource_name="Canopy | five leaf inks"
		if variant==1:
			foliage.set_shader_parameter("recess",Color("203e38")); foliage.set_shader_parameter("pine",Color("2a5040")); foliage.set_shader_parameter("jade",Color("34694a")); foliage.set_shader_parameter("leaf",Color("4e8253")); foliage.set_shader_parameter("lime",Color("719856")); foliage.set_shader_parameter("gold",Color("95aa62"))
		tree(variant)
	quit(n_errors)
func attach(root: Node,n: Node) -> void:
	root.add_child(n); n.owner=root
func tree(v: int) -> void:
	var root:=StaticBody3D.new(); root.name="WaysideOak" if v==0 else "CoppiceMaple"
	var trunk = Brush.new(); var w:=Color("745142")
	branch(trunk,[Vector3(0,-.1,0),Vector3(-.04,.24,-.02),Vector3(.10,1.06,.03),Vector3(-.05,1.87,.08),Vector3(.19,2.71,-.13),Vector3(.31,3.49,-.19)],[.60,.42,.32,.29,.19,.095],9,w)
	branch(trunk,[Vector3(.02,1.22,.06),Vector3(-.45,1.94,.14),Vector3(-1.06,2.31,.18),Vector3(-1.31,3.05,.13)],[.235,.19,.13,.055],7,Color("825840"))
	branch(trunk,[Vector3(.11,1.77,.035),Vector3(.65,2.18,-.13),Vector3(.96,2.46,-.48),Vector3(1.28,3.05,-.56)],[.205,.15,.11,.055],7,w)
	branch(trunk,[Vector3(-.02,1.96,.04),Vector3(-.04,2.26,.52),Vector3(.35,2.56,.95),Vector3(.29,2.93,1.15)],[.14,.12,.088,.045],7,w)
	for k in 6:
		var a:=TAU*k/6+rng.randf_range(-.24,.24); var d:=Vector3(cos(a),0,sin(a)); var t:=Vector3(-d.z,0,d.x); var l:=rng.randf_range(.60,.89); var width:=rng.randf_range(.15,.25)
		var top:=d*.23+Vector3.UP*rng.randf_range(.38,.56); var mid:=d*.56+Vector3.UP*.12; var end:=d*l+Vector3.UP*.008; var s1:=d*.23+t*width; var s2:=d*.23-t*width
		trunk.flat(top,s1,mid,(t+Vector3.UP*.5).normalized(),Color("946647"));trunk.flat(top,mid,s2,(-t+Vector3.UP*.3).normalized(),w);trunk.flat(mid,s1,end,Vector3.UP,Color("846244"));trunk.flat(s2,mid,end,Vector3.UP,w)
	attach(root,trunk.bake("BentBole_ForksAndFoot",bark))
	var centers:Array[Vector3]=[Vector3(-.03,3.54,-.04),Vector3(-1.18,3.16,.08),Vector3(1.03,3.09,-.31),Vector3(-.40,3.42,-1.10),Vector3(.36,3.07,.91),Vector3(-.64,4.02,-.26),Vector3(.66,3.87,.37),Vector3(-.88,3.44,.84)]
	var sizes:Array[Vector3]=[Vector3(1.48,1.16,1.39),Vector3(1.13,.92,1.07),Vector3(1.17,1.0,1.03),Vector3(1.19,1.0,.99),Vector3(1.25,.84,1.11),Vector3(1.14,1.01,1.15),Vector3(1.06,.96,1.04),Vector3(.97,.76,.87)]
	if v==1:
		centers[5]+=Vector3(.08,.38,-.1);centers[4]+=Vector3(-.52,.21,-.14);centers[1]+=Vector3(-.13,.39,-.17);sizes[2]*=Vector3(.8,1.12,.89)
	for i in centers.size():
		var brush=Brush.new(); var phase:=rng.randf()*TAU
		build_lobe(brush,centers[i],sizes[i],phase)
		var crown: MeshInstance3D=brush.bake("Bough_%02d"%(i+1),foliage);attach(root,crown)
	var cs:=CollisionShape3D.new();cs.name="SolidTrunk";var shape:=CylinderShape3D.new();shape.height=3.0;shape.radius=.39;cs.position.y=1.5;cs.shape=shape;attach(root,cs)
	var packed:=PackedScene.new(); var err:=packed.pack(root)
	var target:=Brush.unused_scene_path(DIR+str(root.name))
	if err==OK: err=ResourceSaver.save(packed,target)
	print(target,": ",error_string(err));if err!=OK:n_errors+=1
	root.free()
func branch(b,points:Array,radii:Array,sides:int,base:Color) -> void:
	var ax:Vector3=(points.back()-points.front()).normalized();var u:Vector3=(Vector3.RIGHT-ax*ax.x).normalized();var v:=ax.cross(u).normalized();var phase:=rng.randf()*.58
	var rings:Array=[];var normals:Array=[];var shades:Array=[]
	for i in sides:
		var angle:=TAU*i/sides+phase;normals.append((u*cos(angle)+v*sin(angle)).normalized());shades.append(base.lerp(Color("ae805c"),rng.randf_range(0,.29)) if i%3!=1 else base.darkened(.13))
	for k in points.size():
		var ring:Array=[]
		for i in sides:ring.append(points[k]+normals[i]*float(radii[k])*(1.0+.055*sin(float(i)*3.76)))
		rings.append(ring)
	for k in range(rings.size()-1):
		for i in sides:
			var j: int=(i+1)%sides;var n:Vector3=(normals[i]+normals[j]+ax*.1).normalized(); b.quad(rings[k][i],rings[k][j],rings[k+1][j],rings[k+1][i],n,shades[i])
func unit_at(az:float,lat:float) -> Vector3:return Vector3(cos(az)*cos(lat),sin(lat),sin(az)*cos(lat))
func point_at(n:Vector3,o:Vector3,r:Vector3,phase:float) -> Vector3:
	var swell:=1.0+.075*sin(n.x*6.8+n.z*4.6+phase)*cos(n.y*5.24-n.z*2.1)+.042*cos(n.z*10.1-n.y*7.33+phase)+.026*sin(n.x*12.0+n.y*5.0)
	return o+n*r*swell
func bent(p:Vector3,d:Vector3,r:Vector3) -> Vector3:
	var local:Vector3=(d/r).normalized();var whole:=((p-Vector3(0,3.10,0))*Vector3(.85,1.2,.9)).normalized()
	return local.lerp(whole,.32).normalized()
func dye(p:Vector3, dab:float)->Color:return Color(dab,clampf((p.y-2.02)/3.05,0,1),0,1)
func build_lobe(b,o:Vector3,r:Vector3,phase:float) -> void:
	var steps:=20;var bands:=11
	for k in bands:
		for i in steps:
			var normals:Array[Vector3]=[];var ps:Array[Vector3]=[];var cols:Array[Color]=[]
			for uv:Vector2i in [Vector2i(i,k),Vector2i(i+1,k),Vector2i(i+1,k+1),Vector2i(i,k+1)]:
				var d:=unit_at(TAU*uv.x/steps, -PI/2+PI*uv.y/bands);var p:=point_at(d,o,r,phase);ps.append(p);normals.append(bent(p,d,r));cols.append(dye(p,.25))
			b.tri(ps[0],ps[1],ps[2],normals[0],normals[1],normals[2],cols[0],cols[1],cols[2]);b.tri(ps[0],ps[2],ps[3],normals[0],normals[2],normals[3],cols[0],cols[2],cols[3])
	# Serrate the big bough with sparse, overlapping three-leaf sprigs. These are
	# solid silhouettes from both the camera and the sun, not a 2D outline filter.
	for j in 41:
		var d:=unit_at(rng.randf()*TAU, asin(rng.randf_range(-.91,.96)));var p:=point_at(d,o,r,phase);var n:=bent(p,d,r);var t:=Vector3.UP.cross(d).normalized();var v:=d.cross(t).normalized();var turn:=rng.randf()*TAU
		for k in rng.randi_range(2,3):
			var a:=turn+k*.86;var tangent:Vector3=(t*cos(a)+v*sin(a)).normalized(); var along:Vector3=(tangent*.91+d*.48).normalized();var width:=d.cross(tangent).normalized()*rng.randf_range(.069,.122);var l:=rng.randf_range(.16,.34)
			var base:=p-d*.058;var tip:=base+along*l+d*.043;var left:=base+along*(l*.52)+width;var right:=base+along*(l*.42)-width*.80;var peak:=base+along*l*.54+d*.053
			var col:=dye(tip,rng.randf_range(.34,1.0));b.tri(base,left,peak,n,n,n,col,col,col);b.tri(left,tip,peak,n,n,n,col,col,col);b.tri(tip,right,peak,n,n,n,col,col,col);b.tri(right,base,peak,n,n,n,col,col,col)
