extends SceneTree
const Brush = preload("brush_mesh.gd")
const DIR:="res://art/woods/"
var rng:=RandomNumberGenerator.new()
var land:=StaticBody3D.new()
var ink:=ShaderMaterial.new()
var outline:=PackedVector2Array()
func put(n:Node) -> void:
	# Ground art is seen by the main camera, never by the upwards mirror camera.
	if n is GeometryInstance3D: n.layers = 2
	land.add_child(n); n.owner = land

func planted_bank(p:Vector2) -> bool:
	var rd:=Vector2(.8660254*p.x-.5*(p.y-.6), .5*p.x+.8660254*(p.y-.6))
	var bank:=PackedVector2Array([Vector2(-1.55,6.55),Vector2(-.85,5.62),Vector2(.5,5.22),Vector2(1.55,4.99),Vector2(3,4.95),Vector2(4.15,5.08),Vector2(5.1,5.30),Vector2(6.42,5.12),Vector2(7.35,4.56),Vector2(8.48,4.4),Vector2(9.4,4.82),Vector2(10.15,5.64),Vector2(10.3,6.48),Vector2(9.76,7.55),Vector2(8.6,8.35),Vector2(6.92,8.62),Vector2(5.65,9.15),Vector2(4.05,9.45),Vector2(2.14,9.24),Vector2(.69,8.65),Vector2(-.60,8.32),Vector2(-1.38,7.52)])
	if Geometry2D.is_point_in_polygon(rd,bank): return false
	for i in bank.size():
		if rd.distance_to(Geometry2D.get_closest_point_to_segment(rd,bank[i],bank[(i+1)%bank.size()]))<.42: return false
	return true
func _initialize() -> void:
	rng.seed=502143;land.name="StoneLane";ink.shader=load(DIR+"pigments.gdshader");ink.resource_name="Dry pigments | stone and wildflowers"
	var turf:=ShaderMaterial.new();turf.shader=load(DIR+"meadow.gdshader");turf.resource_name="Meadow | block-in"
	var g:=MeshInstance3D.new();g.name="Meadow";var plane:=PlaneMesh.new();plane.size=Vector2(80,80);plane.material=turf;g.mesh=plane;g.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;put(g)
	var cs:=CollisionShape3D.new();cs.name="Soil";var box:=BoxShape3D.new();box.size=Vector3(80,.4,80);cs.position.y=-.2;cs.shape=box;put(cs)
	road(); foliage_patches(); markers(); stone_herbs()
	var target:=Brush.unused_scene_path(DIR+"Bankside")
	var packed:=PackedScene.new();var err:=packed.pack(land);if err==OK:err=ResourceSaver.save(packed,target)
	print(target,": ",error_string(err));land.free();quit(0 if err==OK else 1)
func at(p:Vector2,h:float) -> Vector3:return Vector3(p.x,h,p.y)
func polygon(b,poly:PackedVector2Array,h:float,col:Color) -> void:
	var tris:=Geometry2D.triangulate_polygon(poly)
	for i in range(0,tris.size(),3):b.flat(at(poly[tris[i]],h),at(poly[tris[i+1]],h),at(poly[tris[i+2]],h),Vector3.UP,col)
func area(poly:PackedVector2Array) -> float:
	var a:=0.;for i in poly.size():a+=poly[i].cross(poly[(i+1)%poly.size()]);
	return absf(a)*.5
func bisect(poly:PackedVector2Array,p:Vector2,q:Vector2) -> PackedVector2Array:
	var result:=PackedVector2Array();var n:=q-p;var mid:=(q+p)*.5
	for i in poly.size():
		var a:=poly[i];var b:=poly[(i+1)%poly.size()];var da:=(a-mid).dot(n);var db:=(b-mid).dot(n)
		if da<=0:result.append(a)
		if (da<0 and db>0) or (da>0 and db<0):result.append(a.lerp(b,da/(da-db)))
	return result
func road() -> void:
	var border:=PackedVector2Array([Vector2(-2.36,1.13),Vector2(-.53,1.13),Vector2(-.49,2.07),Vector2(.4,2.10),Vector2(1.92,1.76),Vector2(3.55,1.60),Vector2(4.57,1.65),Vector2(5.02,1.36),Vector2(5.13,.63),Vector2(5.15,-1.46),Vector2(4.96,-2.55),Vector2(4.45,-3.37),Vector2(3.55,-4.48),Vector2(2.80,-5.93),Vector2(3.66,-6.14),Vector2(4.95,-5.06),Vector2(6.18,-3.68),Vector2(6.72,-2.68),Vector2(6.88,-1.65),Vector2(6.91,.70),Vector2(6.56,1.93),Vector2(5.75,2.77),Vector2(4.68,3.11),Vector2(3.37,3.28),Vector2(2.17,3.54),Vector2(.78,3.85),Vector2(-.12,4.41),Vector2(-.1,5.64),Vector2(.32,7.33),Vector2(1.06,9.06),Vector2(1.50,10.98),Vector2(1.77,12.82),Vector2(3.29,16.32),Vector2(.58,16.7),Vector2(-.75,13.02),Vector2(-1.08,11.03),Vector2(-1.63,9.04),Vector2(-2.29,7.05),Vector2(-2.58,5.44),Vector2(-2.51,3.46)])
	for i in border.size():
		var a:=border[i];var b:=border[(i+1)%border.size()];var n:=(b-a).orthogonal().normalized();var steps:=maxi(1,roundi(a.distance_to(b)/.51))
		for j in steps:outline.append(a.lerp(b,float(j)/steps)+n*(0. if j==0 else rng.randf_range(-.11,.11)))
	var bed=Brush.new();var beds:=Geometry2D.offset_polygon(outline,-.16,Geometry2D.JOIN_ROUND);for inner in beds:polygon(bed,inner,.019,Color("a99d78"))
	var earth:MeshInstance3D=bed.bake("Sandy_Grout",ink);earth.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;put(earth)
	var seeds:=PackedVector2Array();var z:=-7.5;var row:=0
	while z<18.4:
		var x:=-5.0+fmod(row*.56,1.12)
		while x<8.65:
			seeds.append(Vector2(x+rng.randf_range(-.21,.21),z+rng.randf_range(-.205,.205)));x+=rng.randf_range(.9,1.48)
		z+=rng.randf_range(.72,.99);row+=1
	flagstones(seeds)

# Shared cut stone brush. Keep the original lane defaults and the original draw
# order; another bake can keep a sparser section or use shallower dressed stone.
func flagstones(seeds: PackedVector2Array, min_high := .067, max_high := .101, foot := .021, bevel := .033, keep := Callable(), colors: Array[Color] = []) -> void:
	var tile_count:=0
	var palette:Array[Color] = [Color("d9c9a7"),Color("cdbea0"),Color("ded0b2"),Color("d7c5a3"),Color("cabc9e"),Color("d8c8ab")]
	if not colors.is_empty(): palette = colors
	var tiles=Brush.new()
	for s in seeds:
		var cell:=PackedVector2Array([s+Vector2(-2,-2),s+Vector2(2,-2),s+Vector2(2,2),s+Vector2(-2,2)])
		for q in seeds:
			if s!=q and s.distance_squared_to(q)<12.5:cell=bisect(cell,s,q)
		var parts:=Geometry2D.intersect_polygons(cell,outline)
		for part in parts:
			if part.size()<3 or area(part)<.082:continue
			var center:=Vector2.ZERO;for p:Vector2 in part:center+=p
			center/=part.size()
			if keep.is_valid() and not keep.call(center): continue
			var contraction:=rng.randf_range(.060,.146);var inset:=PackedVector2Array()
			for i in part.size():
				var a:Vector2=part[i].lerp(center,contraction);var prev:Vector2=part[(i-1+part.size())%part.size()].lerp(center,contraction);var next:Vector2=part[(i+1)%part.size()].lerp(center,contraction);var cut:=rng.randf_range(.035,.135)
				inset.append(a.move_toward(prev,minf(cut,a.distance_to(prev)*.23)));inset.append(a.move_toward(next,minf(cut*.82,a.distance_to(next)*.23)))
			var h:=rng.randf_range(min_high,max_high);var col:Color=palette[rng.randi()%palette.size()];var lip:=PackedVector2Array()
			for point in inset:lip.append(point.move_toward(center,minf(.049,point.distance_to(center)*.12)))
			polygon(tiles,lip,h,col)
			for j in inset.size():
				var j2: int=(j+1)%inset.size();var a:=inset[j];var b:=inset[j2];var outside:Vector2=((a+b)*.5-center).normalized();var bevel_color:=col.lightened(.095) if outside.dot(Vector2(-.65,.76))>.28 else col.darkened(.06)
				tiles.quad(at(a,foot),at(b,foot),at(b,h-bevel),at(a,h-bevel),at(outside,0),col.darkened(.17));tiles.quad(at(a,h-bevel),at(b,h-bevel),at(lip[j2],h),at(lip[j],h),at(outside,.9).normalized(),bevel_color)
			tile_count+=1
	put(tiles.bake("Handcut_Flagstones_%03d"%tile_count,ink))
# Terrace overrides this for the actual pool; the legacy scene is unchanged.
func allows_shore_plant(_p: Vector2, _radius: float) -> bool:
	return true

func tuft(b,p:Vector3,sz:float,col:Color,keep := true) -> void:
	var bearing:=rng.randf()*TAU
	for i in rng.randi_range(4,7):
		var a:=bearing+i*1.5+rng.randf_range(-.36,.36);var d:=Vector3(cos(a),0,sin(a));var t:=Vector3(-d.z,0,d.x);var base:=p+d*rng.randf_range(.0,.09)*sz;var len:=rng.randf_range(.16,.34)*sz;var width:=rng.randf_range(.037,.092)*sz
		var tip:=base+d*len*rng.randf_range(.45,.89)+Vector3.UP*len;var mid:=base+d*len*.3+Vector3.UP*len*.5;var n:Vector3=(d*.49+Vector3.UP).normalized();var c:=col.lightened(.12) if i%4==0 else col
		if keep:
			b.flat(base-t*width*.48,base+t*width*.48,mid+t*width,n,c);b.flat(base-t*width*.48,mid+t*width,mid-t*width*.5,n,c);b.flat(mid-t*width*.5,mid+t*width,tip,n,c)
func flower(b,p:Vector3,col:Color,sz:float,keep := true) -> void:
	var d:=Vector3(rng.randf_range(-.09,.09),0,rng.randf_range(-.09,.09));var head:=p+d+Vector3.UP*rng.randf_range(.26,.48)*sz;var n:Vector3=(Vector3.UP+Vector3(.1,0,.46)).normalized()
	var turn:=rng.randf()*TAU
	if not keep: return
	b.quad(p-Vector3.RIGHT*.019,p+Vector3.RIGHT*.019,head+Vector3.RIGHT*.021,head-Vector3.RIGHT*.021,Vector3(.16,.13,.98),Color("527744"))
	for i in 5:
		var a:=turn+float(i)*TAU/5.;var v:=Vector3(cos(a),0,sin(a));var t:=Vector3(-v.z,0,v.x);var l:=.105*sz;var tip:=head+v*l+Vector3(0,.03*sz-v.z*.025*sz,0);var c:=col if i%3!=0 else col.darkened(.06)
		b.quad(head,head+v*l*.58+t*l*.48,tip,head+v*l*.6-t*l*.48,n,c)
	b.flat(head+Vector3(-.042,.017,0)*sz,head+Vector3(.021,.021,.048)*sz,head+Vector3(.032,.018,-.04)*sz,n,Color("ffc263"))
func bracken(b,p:Vector3,sz:float,keep := true) -> void:
	var start:=rng.randf()*TAU
	for i in 6:
		var a:=start+i*1.047+rng.randf_range(-.16,.16);var d:=Vector3(cos(a),0,sin(a));var t:=Vector3(-d.z,0,d.x);var len:=rng.randf_range(.34,.59)*sz;var color:=Color("699557") if i%2==0 else Color("508757");var tip:=p+d*len+Vector3.UP*.26*sz
		if not keep: continue
		b.flat(p-t*.035,p+t*.035,tip,Vector3.UP,color)
		for j in range(1,5):
			var u:=float(j)/5.4;var base:=p.lerp(tip,u);base.y+=sin(u*PI)*.09*sz;var width:=len*.28*(1.-.55*u)
			for side in [-1,1]:
				var end:Vector3=base+d*(.10*sz)+t*width*float(side);b.flat(base-d*.065*sz,base+d*.08*sz,end+Vector3.UP*.035,Vector3.UP,color)
func foliage_patches() -> void:
	# Composed borders around an intentionally quiet lane, never a uniform scatter.
	var centers:Array[Vector2]=[Vector2(-4.2,7.5),Vector2(-7.8,6.75),Vector2(-4.15,3.27),Vector2(-7.2,.6),Vector2(-5.5,-3.6),Vector2(-6.65,-5.6),Vector2(.7,-6.4),Vector2(7.03,-3.65),Vector2(8.22,.24),Vector2(2.22,4.1),Vector2(.79,6.62),Vector2(1.72,10.4),Vector2(10.45,6.64),Vector2(11.39,-.69),Vector2(-.6,-9.3),Vector2(-10.4,3.9),Vector2(-2.6,10.6),Vector2(7.8,-8.1),Vector2(13.1,1.0),Vector2(-10.3,-3.95)]
	var bloom:Array[Color]=[Color("fff1bd"),Color("a7aedb"),Color("f3bf68"),Color("c4c8ea")]
	for j in centers.size():
		var b=Brush.new();var c:=centers[j];var size:=rng.randf_range(.8,1.22);var count:=rng.randi_range(9,17)
		for k in count:
			var a:=rng.randf()*TAU;var rr:=sqrt(rng.randf());var off:=Vector2(cos(a)*rng.randf_range(.7,1.45),sin(a)*.72)*rr;var pos:=c+off
			if Geometry2D.is_point_in_polygon(pos,outline) or not planted_bank(pos):continue
			var here := at(off,.012)
			# Reject whole plants, but consume the same RNG as before so unrelated art stays put.
			var grass_size := size*rng.randf_range(.65,1.13)
			tuft(b,here,grass_size,[Color("719949"),Color("7b9d49"),Color("8da955"),Color("71974f")][(k+j)%4],
				allows_shore_plant(pos,.40*grass_size))
			if (k+j)%4==0 and j%5!=1:
				var bloom_size := size*rng.randf_range(.85,1.22)
				flower(b,here,bloom[j%4],bloom_size,allows_shore_plant(pos,.13+.11*bloom_size))
		if j%3==0 or j==1:
			var fern_size := size*1.39
			bracken(b,Vector3(-.19,.013,.23),fern_size,allows_shore_plant(c+Vector2(-.19,.23),.63*fern_size))
		var inst:MeshInstance3D=b.bake("Wild_Border_%02d"%(j+1),ink);inst.position=at(c,0);put(inst)
func markers() -> void:
	var loc:Array[Vector2]=[Vector2(-4.15,7.96),Vector2(7.52,-3.87),Vector2(8.08,1.07),Vector2(-5.6,-3.02),Vector2(-9.82,4.57),Vector2(2.05,10.92)]
	for k in loc.size():
		var b=Brush.new()
		for h in (2 if k%2==0 else 1):
			var o:=Vector3(h*.54,0,h*.19);var scale_rock:=rng.randf_range(.70,1.08)*(.55 if h else 1.0);var rim:Array[Vector3]=[];var top:Array[Vector3]=[];var n:=7;var phase:=rng.randf()*TAU
			for i in n:
				var a:=phase+TAU*i/n;var offset:=Vector3(cos(a)*rng.randf_range(.35,.48),0,sin(a)*rng.randf_range(.21,.32))*scale_rock;rim.append(o+offset-Vector3.UP*.012);top.append(o+offset*rng.randf_range(.43,.82)+Vector3.UP*rng.randf_range(.16,.25)*scale_rock)
			var center:=o+Vector3(-.06,.27,.02)*scale_rock
			for i in n:
				var j:=(i+1)%n;var d:Vector3=((rim[i]+rim[j])*.5-o+Vector3.UP*.14).normalized();b.quad(rim[i],rim[j],top[j],top[i],d,Color("9c9d88") if i%3!=1 else Color("a8a78b"));b.flat(top[i],top[j],center,Vector3.UP,Color("b7b698") if i<4 else Color("99a477"))
		var inst:MeshInstance3D=b.bake("Meadowsill_%02d"%(k+1),ink);inst.position=at(loc[k],0);put(inst)

func stone_herbs() -> void:
	# A few tall bells give the garden a readable scale. Only two drifts by the
	# cottage and two in the meadow; the open areas remain large quiet shapes.
	var groups:Array[Vector3]=[Vector3(1.00,0,1.29),Vector3(-3.55,0,1.28),Vector3(5.96,0,.53),Vector3(-3.42,0,7.56)]
	for k in groups.size():
		var b=Brush.new();var sun:=Color("f39a85") if k<2 else Color("b1a7df");var shadow:=Color("b55d69") if k<2 else Color("7c76ad")
		for i in (4 if k==0 or k==3 else 3):
			var o:=Vector3((i-1)*.19+rng.randf_range(-.06,.06),.013,rng.randf_range(-.11,.15));var h:=rng.randf_range(.46,.82);var head:=o+Vector3(rng.randf_range(-.12,.1),h,-.06);var n:=Vector3(.1,.55,.82).normalized()
			b.quad(o-Vector3.RIGHT*.025,o+Vector3.RIGHT*.025,head+Vector3.RIGHT*.024,head-Vector3.RIGHT*.024,n,Color("5d824d"));tuft(b,o,1.20,Color("6c994e"))
			for j in 3:
				var p:=o.lerp(head,.48+j*.23);var side:=1. if (j+i)%2==0 else -1.;var end:=p+Vector3(side*.065,.018,.025);var w:=.085 if j<2 else .069;var left:=end+Vector3(-w,-.07,.015);var right:=end+Vector3(w,-.07,.015);var tip:=end+Vector3(.02,-.124,.036)
				b.flat(end+Vector3(0,.036,0),left,right,n,sun);b.flat(left,tip,right,n,shadow);b.flat(left,left+Vector3(.035,-.059,.027),tip,n,sun.lightened(.1))
		var inst:MeshInstance3D=b.bake("Bellflowers_%02d"%(k+1),ink);inst.position=groups[k];put(inst)
	var tips=Brush.new();var positions:Array[Vector2]=[Vector2(-2.49,6.28),Vector2(-.14,4.81),Vector2(2.17,3.57),Vector2(5.08,.44),Vector2(6.91,-.52),Vector2(6.20,-3.64),Vector2(-1.30,9.93),Vector2(.86,8.68),Vector2(-2.32,2.26),Vector2(-2.24,7.23)]
	for p in positions:
		for j in 3:
			var pos := p+Vector2(rng.randf_range(-.17,.17),rng.randf_range(-.20,.20))
			var size := rng.randf_range(.60,.92)
			tuft(tips,at(pos,.074),size,Color("869d53"),allows_shore_plant(pos,.40*size))
	put(tips.bake("Thyme_In_The_Joints",ink))
