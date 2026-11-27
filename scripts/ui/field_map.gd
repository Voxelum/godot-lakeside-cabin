extends Panel
## North-up field survey. The loaded outdoor scene owns geometry, names and roads.
const INK := Color("463523")
const COLORS := {"building":Color("b77150"),"field":Color("bb983d"),"pasture":Color("88a567"),"shelter":Color("859b9d"),"market":Color("b87889"),"gate":Color("6e819e")}
const PLOT := Rect2(16,34,249,158)
var session
var enabled := false
var landmarks := {}
var roads: Array[PackedVector2Array] = []
var road_records:Dictionary={}
var bounds := Rect2()
var refresh_in := 0.0
var labels:Array[Dictionary]=[]

func install(s) -> void:
	session=s; theme=preload("res://scripts/ui/parchment_theme.tres"); mouse_filter=Control.MOUSE_FILTER_IGNORE; hide(); s.host.add_child(self)
	var layout=s.host.get_node("UILayout")
	var fit:=func(): layout.place(self,Rect2(12,48,282,222))
	layout.changed.connect(fit); fit.call()

func _process(dt:float) -> void:
	visible=enabled and not session.host.indoors and not session.host.crossing and not session.is_modal()
	if not visible:
		refresh_in=0; return
	refresh_in-=dt
	if refresh_in<=0:
		survey(); refresh_in=0.75
	queue_redraw()

func xz(p:Vector3) -> Vector2: return Vector2(p.x,p.z)

const Space := preload("res://world/outskirts/settlement_space.gd")

func survey() -> void:
	landmarks.clear(); roads.clear()
	var actor:Vector2=xz(session.host.field_actor.global_position)
	bounds=Rect2(actor-Vector2.ONE,Vector2.ONE*2)
	var space:=Space.snapshot(session.host.field)
	landmarks=space.parcels
	for parcel:Dictionary in landmarks.values():
		var extent:=Rect2(parcel.shape[0],Vector2.ZERO)
		for p in parcel.shape: extent=extent.expand(p)
		bounds=bounds.merge(extent); parcel.center=extent.get_center()
	road_records=space.roads
	for road:Dictionary in road_records.values():
		roads.append(road.points)
		for p in road.points: bounds=bounds.expand(p)
	place_labels()

func project(p:Vector2) -> Vector2:
	var zoom:=minf(PLOT.size.x/bounds.size.x,PLOT.size.y/bounds.size.y)
	return PLOT.get_center()+(p-bounds.get_center())*zoom

func projected(points:PackedVector2Array) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for p in points: result.append(project(p))
	return result

func text(p:Vector2,s:String,sz:int=11) -> void:
	draw_string(get_theme_default_font(),p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,sz,INK)

func _draw() -> void:
	if not session or bounds.size.x<=0: return
	text(Vector2(15,24),"乡野舆图",16); text(Vector2(186,23),"北 ↑   M 收起")
	var zoom:=minf(PLOT.size.x/bounds.size.x,PLOT.size.y/bounds.size.y)
	for r:Dictionary in road_records.values():
		var points:=projected(r.points)
		for i in points.size()-1:
			var width:=maxf(1.0,.5*zoom*(float(r.widths[i])+float(r.widths[i+1])))
			draw_line(points[i],points[i+1],INK,width+1,true)
			draw_line(points[i],points[i+1],Color("edce99"),width,true)
	var places:=landmarks.values()
	places.sort_custom(func(a,b): return int(a.kind=="building")<int(b.kind=="building"))
	var actor=session.host.field_actor; var pos:=project(xz(actor.global_position))
	for place in places:
		var shape:=projected(place.shape); var center:=project(place.center); var color:Color=COLORS.get(place.kind,Color("a68461"))
		if shape.size()>=3 and not Geometry2D.triangulate_polygon(shape).is_empty():
			draw_colored_polygon(shape,color); shape.append(shape[0]); draw_polyline(shape,INK,.8,true)
		else: draw_circle(center,1.8,color)
	for tag in labels:
		var rect:Rect2=tag.box; var anchor:Vector2=tag.anchor
		draw_line(anchor,anchor.clamp(rect.position,rect.end),INK,.7,true); draw_rect(rect,Color("ead6ae")); text(rect.position+Vector2(1,get_theme_default_font().get_ascent(11)),tag.text)
	var d:=xz(actor.combat.forward).normalized(); var t:=d.orthogonal()
	draw_circle(pos,4.5,Color("fff5d5")); draw_colored_polygon(PackedVector2Array([pos+d*6,pos-d*3+t*3,pos-d*3-t*3]),Color("a53122"))
	text(Vector2(16,208),"红箭：你")
	var x:=80.0
	for pair in [["building","屋"],["field","田"],["pasture","牧"],["shelter","舍"],["market","市"]]:
		draw_rect(Rect2(x,200,6,7),COLORS[pair[0]]); text(Vector2(x+8,208),pair[1]); x+=37

func label_priority(place:Dictionary) -> int:
	if place.id=="clearing.lakeside.cottage" or place.kind=="gate": return 0
	return 2 if place.kind=="building" else 1

func place_labels() -> void:
	labels.clear()
	var places:=landmarks.values()
	places.sort_custom(func(a,b): return label_priority(a)<label_priority(b))
	var occupied:Array[Rect2]=[]
	var pos:=project(xz(session.host.field_actor.global_position)); occupied.append(Rect2(pos-Vector2(5,5),Vector2(10,10)))
	for place in places:
		var center:=project(place.center); occupied.append(Rect2(center-Vector2.ONE,Vector2.ONE*2))
	var font:=get_theme_default_font()
	for place in places:
		var label:String=place.label
		if label.is_empty(): continue
		var sz:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,11)+Vector2(3,0); var anchor:=project(place.center)
		var placed:=false
		for radius in [4,14,25,37,50]:
			for dir in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,-1),Vector2(-1,1),Vector2(-1,-1),Vector2(1,1)]:
				var rect:=Rect2((anchor+dir*radius+(dir.sign()-Vector2.ONE)*sz*.5).round(),sz)
				if not PLOT.grow(3).encloses(rect) or occupied.any(func(other):return rect.grow(1).intersects(other)): continue
				labels.append({"anchor":anchor,"box":rect,"text":label}); occupied.append(rect); placed=true; break
			if placed: break
