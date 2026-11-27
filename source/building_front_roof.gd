extends RefCounted
## Cross-gables interrupt the main roof rather than sitting on top of it.
## Everything, including the volume open to the second storey, is solved in
## shell metres. No ceiling plane, false third floor, or rendered-only sash.
const Shape := preload("res://source/building_structure.gd")
const Batch := preload("res://art/building_trial/mesh_batch.gd")

static func make(p: Shape, kit, hit: StaticBody3D, outside: bool) -> void:
	var tiles: Batch = kit.get_layer("roof_tile")
	var b: Batch = kit.get_layer("timber")
	var wall: Batch = kit.get_layer("facade" if outside else "lining")
	var slate := p.color("roof")
	var trim := p.color("fascia", p.color("timber"))
	var plaster := p.color("facade" if outside else "lining")
	var x := p.roof.half_ridge
	var z := p.roof.half_cross
	var bays := p.front_roof.duplicate()
	bays.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return a.u < c.u)
	var bands: Array[float] = []
	for j in 11: bands.append(z*j/10.0)
	for bay: Dictionary in bays:
		bands.append_array([minf(bay.z,z), _back(p,bay.shoulder), _back(p,bay.peak)])
		_cross(p,bay,tiles,b,wall,hit,outside,slate,trim,plaster)
	bands.sort()
	for i in bands.size()-1:
		var a := bands[i]; var c := bands[i+1]
		if c-a < .0001: continue
		var left := Vector2(-x,-x)
		for bay: Dictionary in bays:
			var mid := (a+c)*.5
			if mid > bay.z or mid < _back(p,bay.peak): continue
			var widths := Vector2(_cut(p,bay,a),_cut(p,bay,c))
			var center := Vector2.ONE*float(bay.u)
			_band(p,tiles,hit,outside,slate,a,c,left,center-widths,i)
			left = center+widths
		_band(p,tiles,hit,outside,slate,a,c,left,Vector2(x,x),i)
	# The rear pitch has no interruptions. Give it the same slate courses.
	for j in 10: _band(p,tiles,hit,outside,slate,-z*j/10.0,-z*(j+1)/10.0,Vector2(-x,-x),Vector2(x,x),j)
	if not outside: return
	for side: float in [-1,1]:
		b.bar(Vector3(side*x,p.eave, -z),Vector3(side*x,p.roof_y(0),0),.14,.15,trim,Vector3.RIGHT,1)
		b.bar(Vector3(side*x,p.eave, z),Vector3(side*x,p.roof_y(0),0),.14,.15,trim,Vector3.RIGHT,1)
	b.bar(Vector3(-x,p.eave-.05,-z),Vector3(x,p.eave-.05,-z),.15,.17,trim,Vector3.UP,1)
	var start := -x
	for bay: Dictionary in bays:
		if bay.z < z: continue
		var end: float = bay.u-_cut(p,bay,z)
		b.bar(Vector3(start,p.eave-.05,z),Vector3(end,p.eave-.05,z),.15,.17,trim,Vector3.UP,1)
		start = bay.u+_cut(p,bay,z)
	b.bar(Vector3(start,p.eave-.05,z),Vector3(x,p.eave-.05,z),.15,.17,trim,Vector3.UP,1)
	# Segmented ridge caps read as stoneware rather than a single long beam.
	for j in 21:
		tiles.roller(Vector3(lerpf(-x,x,(j+.5)/21.),p.roof_y(0)+.039,0),Vector3.RIGHT,2.*x/21.+.015,.104,7,Batch.tone(slate,.12+.065*sin(j*6.8)))

static func _back(p: Shape, y: float) -> float:
	return p.roof.half_cross*(1.0-(y-p.eave)/p.roof_rise)

static func _cut(p: Shape, bay: Dictionary, z: float) -> float:
	return bay.width*.5*clampf((bay.peak-p.roof_y(z))/(bay.peak-bay.shoulder),0.0,1.0)

static func _band(p: Shape, tiles: Batch, hit: StaticBody3D, outside: bool, ink: Color, za: float, zb: float, left: Vector2, right: Vector2, row: int) -> void:
	var a := Vector3(left.x,p.roof_y(absf(za)),za)
	var c := Vector3(right.x,a.y,za)
	var d := Vector3(left.y,p.roof_y(absf(zb)),zb)
	var e := Vector3(right.y,d.y,zb)
	_sheet(hit,"RoofHallPitch",[a,c,e,d])
	if outside: _slates(tiles,a,c,d,e,ink,row)

static func _slates(tiles: Batch, a: Vector3, c: Vector3, d: Vector3, e: Vector3, ink: Color, row: int) -> void:
	var normal := (d-a).cross(c-a).normalized()
	if normal.y < 0.: normal = -normal
	tiles.quad(a,c,e,d,normal,ink.darkened(.24))
	# Stagger while preserving the clipped sheet boundary down each valley.
	var count := maxi(1,ceili(maxf(a.distance_to(c),d.distance_to(e))/.40))
	for col in range(-1,count):
		var shift := .50*(row%2)
		var u := clampf((col+shift+.020)/count,0.,1.)
		var v := clampf((col+shift+.980)/count,0.,1.)
		if v-u < .002: continue
		var p := a.lerp(c,u)+Vector3.UP*.044
		var q := a.lerp(c,v)+Vector3.UP*.044
		var r := d.lerp(e,v)+Vector3.UP*.020
		var s := d.lerp(e,u)+Vector3.UP*.020
		var tint := Batch.tone(ink,.142*sin(row*6.32+col*4.38+q.x))
		tiles.quad(p,q,r,s,normal,tint)
		tiles.quad(p-Vector3.UP*.035,q-Vector3.UP*.035,q,p,(a+c-d-e).normalized(),tint.darkened(.28))

static func _cross(p: Shape, bay: Dictionary, tiles: Batch, b: Batch, wall: Batch, hit: StaticBody3D, outside: bool, slate: Color, trim: Color, plaster: Color) -> void:
	var x: float = bay.u
	var z: float = bay.z
	var hw: float = bay.width*.5
	var s: float = bay.shoulder
	var top: float = bay.peak
	var low := p.roof_y(z)-.037
	var knee := _back(p,s)
	var tip := _back(p,top)
	var peak := Vector3(x,top,z)
	var ridge := Vector3(x,top,tip)
	for sign_x: float in [-1,1]:
		var foot := Vector3(x+sign_x*hw,s,z)
		var heel := Vector3(foot.x,s,knee)
		_sheet(hit,"RoofHallCross",[foot,heel,ridge,peak])
		var cheek := [Vector3(foot.x,low,z),heel,foot]
		_panel(hit,"Wall_RoofCheek",cheek,Vector3.RIGHT*(-sign_x*p.wall))
		if outside:
			wall.tri(cheek[0],cheek[1],cheek[2],Vector3.RIGHT*sign_x,plaster.darkened(.12))
			for row in 6:
				_slates(tiles,foot.lerp(peak,row/6.),heel.lerp(ridge,row/6.),foot.lerp(peak,(row+1)/6.),heel.lerp(ridge,(row+1)/6.),slate.lightened(.045),row)
			b.bar(foot+Vector3.BACK*.045,peak+Vector3.BACK*.045,.134,.141,trim.lightened(.10),Vector3.BACK,1)
	var outline := [Vector3(x-hw,s,z),Vector3(x+hw,s,z),peak]
	_face(hit,wall,outline,p.wall,plaster)
	if bay.has("opening"):
		var o: Dictionary = bay.opening
		_box_face(hit,wall,x-hw,x+hw,low,o.y,z,p.wall,plaster)
		_box_face(hit,wall,x-hw,x+hw,o.y+o.height,s,z,p.wall,plaster)
		_box_face(hit,wall,x-hw,x-o.width*.5,o.y,o.y+o.height,z,p.wall,plaster)
		_box_face(hit,wall,x+o.width*.5,x+hw,o.y,o.y+o.height,z,p.wall,plaster)
	else:
		_box_face(hit,wall,x-hw,x+hw,low,s,z,p.wall,plaster)
	if outside:
		b.bar(peak+Vector3.UP*.056,ridge+Vector3.UP*.056,.135,.119,slate.lightened(.12),Vector3.RIGHT)
		b.box(Vector3(x,s,z+.044),Vector3(2*hw,.106,.133),trim,1)
		for sign_x: float in [-1,1]:
			var edge := x+sign_x*(hw-.052)
			b.box(Vector3(edge,(low+s)*.5,z+.02),Vector3(.09,s-low,.10),trim,1)

static func _box_face(hit: StaticBody3D, b: Batch, a: float, c: float, low: float, high: float, z: float, thick: float, ink: Color) -> void:
	if high-low < .003: return
	_face(hit,b,[Vector3(a,low,z),Vector3(c,low,z),Vector3(c,high,z),Vector3(a,high,z)],thick,ink)

static func _face(hit: StaticBody3D, b: Batch, points: Array, thick: float, ink: Color) -> void:
	_panel(hit,"Wall_RoofFront",points,Vector3.FORWARD*thick)
	var inside := PackedVector3Array()
	for pt: Vector3 in points: inside.append(pt+Vector3.FORWARD*thick)
	b.fan(PackedVector3Array(points),Vector3.BACK,ink)
	b.fan(inside,Vector3.FORWARD,ink.darkened(.11))

static func _sheet(hit: StaticBody3D, name_: String, corners: Array) -> void:
	_panel(hit,name_,corners,Vector3.DOWN*.095)

static func _panel(hit: StaticBody3D, name_: String, corners: Array, thickness: Vector3) -> void:
	var hull := PackedVector3Array()
	for pt: Vector3 in corners:
		hull.append(pt)
		hull.append(pt+thickness)
	var shape := ConvexPolygonShape3D.new()
	shape.points = hull
	var piece := CollisionShape3D.new()
	piece.name = name_
	piece.shape = shape
	hit.add_child(piece,true)
