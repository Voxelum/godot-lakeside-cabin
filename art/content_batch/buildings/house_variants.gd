@tool
extends "res://world/outskirts/outskirts_lot.gd"
## Two authored recipes in the original lot system. Door/landing, identity,
## wall collision, wall lantern and F5 pigment continue to come from that system.
const Trim := preload("res://art/content_batch/buildings/roof_trim.gd")
const Props := preload("res://art/building_trial/street_props.gd")

func _farm(b: Batch, dx: float) -> void:
	super._farm(b,dx)
	# The asymmetric rain porch shelters the door-facing two thirds of the wall.
	# Its posts flank the original landing; they do not move the door approach.
	var side := signf(dx)
	var a := side*(_w*.5+.09)
	var c := -side*_w*.18
	var left := minf(a,c)
	var right := maxf(a,c)
	var wall_z := _d*.5
	var eave := _h-.38
	var foot_z := wall_z+1.01
	var sill := .116
	Trim.slope(b,Vector3(left,eave,wall_z+1.32),Vector3(right,eave,wall_z+1.32),
		Vector3(left,_h-.045,wall_z-.19),Vector3(right,_h-.045,wall_z-.19),_roof.darkened(.075),_wood,5)
	b.box(Vector3((left+right)*.5,eave-.126,foot_z),Vector3(right-left,.17,.19),_wood,1)
	for x: float in [left+.16,right-.16]:
		b.box(Vector3(x,sill*.5,foot_z),Vector3(.32,sill,.32),_stone.lightened(.085))
		b.box(Vector3(x,(eave-.19+sill)*.5,foot_z),Vector3(.164,eave-.19-sill,.174),_wood,1)
		b.bar(Vector3(x,eave-.54,foot_z),Vector3(x+signf((left+right)*.5-x)*.39,eave-.11,foot_z),.112,.123,_wood.lightened(.06),Vector3.BACK,1)
		b.bar(Vector3(x,eave-.52,foot_z),Vector3(x,eave-.067,wall_z+.60),.099,.123,_wood,Vector3.RIGHT,1)
		_box_shape("PorchPost",Vector3(x,(eave-.15)*.5,foot_z),Vector3(.25,eave-.15,.25))
	_anchor("PorchEave",Vector3((left+right)*.5,eave+.05,wall_z+1.33))
	# A low sill at the outside window, never in the door line.
	var planter := Vector3(-side*_w*.376,0,wall_z+.39)
	Props.pot(b,planter,.79)
	_box_shape("PorchPot",planter+Vector3.UP*.126,Vector3(.34,.26,.34))

func _town(b: Batch, dx: float) -> void:
	super._town(b,dx)
	var z0 := _d*.5-.014
	var z1 := _d*.5+.82
	var x0 := _w*.375
	var x1 := _w*.255
	var base := _rise + 2.32
	var h := 1.58
	var a := Vector3(-x0,base,z0)
	var c := Vector3(-x1,base,z1)
	var d := Vector3(x1,base,z1)
	var e := Vector3(x0,base,z0)
	var high := Vector3.UP*h
	var top := Vector3.UP*.10
	var rim: Array[Vector3] = [a,c,d,e]
	var cornice := _wood.darkened(.10)
	b.quad(a,e,d,c,Vector3.DOWN,cornice,1)
	for i in 3:
		var u := rim[i]
		var v := rim[i+1]
		var front := (v-u).cross(Vector3.UP).normalized()
		b.quad(u,v,v+high,u+high,front,_wall.darkened(.08))
		b.bar(u+top,v+top,.175,.157,cornice,front,1)
		b.bar(u+high,v+high,.142,.135,cornice,front,1)
		var frame := Transform3D(Basis((v-u).normalized(),Vector3.UP,front),(u+v)*.5+Vector3.UP*.38)
		Join.window(b,frame,u.distance_to(v)-(.23 if i==1 else .27),.97,_wood,_accent,_stone,false,3 if i==1 else 2)
	for p in rim:
		b.bar(p+top,p+high,.123,.143,_wood,Vector3.BACK,1)
		if absf(p.x) < x0-.1:
			b.bar(Vector3(p.x,base-.455,z0),p+Vector3.DOWN*.039,.109,.115,_wood,Vector3.RIGHT,1)
	# Low polygonal cap, pitched back into the wall. The wider front throws the
	# oriel shape into silhouette before the glazing is visible.
	var cap := high+Vector3.UP*.085
	var p0 := a+cap+Vector3(-.11,0,0)
	var p1 := c+cap+Vector3(-.077,0,.13)
	var p2 := d+cap+Vector3(.077,0,.13)
	var p3 := e+cap+Vector3(.11,0,0)
	var crown_l := a+Vector3(.27,h+.36,0)
	var crown_r := e+Vector3(-.27,h+.36,0)
	Trim.slope(b,p1,p2,crown_l,crown_r,_roof,_wood,4)
	b.tri(p0,p1,crown_l,Vector3.UP,_roof.darkened(.13))
	b.tri(p2,p3,crown_r,Vector3.UP,_roof.darkened(.05))
	b.bar(p0,p1,.103,.096,cornice,Vector3.UP,1)
	b.bar(p2,p3,.103,.096,cornice,Vector3.UP,1)
	_anchor("Oriel",Vector3(0,base+1.0,z1+.18))
	_side_dormer(b)

func _side_dormer(b: Batch) -> void:
	# Below the clipped ends and inside the width of the right-hand roof slope.
	# The main roof rises through the back; no floating box behind the dormer.
	var f := Transform3D(Basis(Vector3.UP,PI*.5),Vector3(_w*.5+.06,_h,-_d*.115))
	var eave := .794
	var ridge := 1.14
	var width := .605
	Join.panel(b,f,Vector3(0,(eave+.08)*.5,-.025),Vector3(width*2,eave-.08,.093),_wall)
	for s: float in [-1,1]:
		var edge := s*width
		b.quad(f*Vector3(edge,.11,.015),f*Vector3(edge,eave,.015),f*Vector3(edge,eave,-.91),f*Vector3(edge,.11,-.91),f.basis.x*s,_wall.darkened(.16))
		b.bar(f*Vector3(edge,.18,.04),f*Vector3(edge,eave,.04),.101,.106,_wood,f.basis.z,1)
		Trim.slope(b,f*Vector3(s*(width+.108),eave,.119),f*Vector3(s*(width+.108),eave,-1.03),
			f*Vector3(0,ridge,.119),f*Vector3(0,ridge,-1.03),_roof.lightened(.075),_wood,4)
	b.tri(f*Vector3(-width,eave,.044),f*Vector3(width,eave,.044),f*Vector3(0,ridge,.044),f.basis.z,_wall)
	b.roller(f*Vector3(0,ridge+.042,-.438),f.basis.z,1.15,.059,7,_roof.lightened(.13))
	Join.window(b,f.translated_local(Vector3(0,.29,.03)),.63,.40,_wood,_accent,_stone,false)
