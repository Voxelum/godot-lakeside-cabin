@tool
extends RefCounted
## Shared trim, lantern, glazing and door pieces. Front is local +Z;
## right-wall and rear variants use the same frame rotated around Y.
const Batch = preload("res://art/building_trial/mesh_batch.gd")
const MORTAR := Color("8d7e76")
const SHADOW := Color("403236")
const BRASS := Color("bd945f")
const GLASS := Color("81a6a6")

static func panel(b: Batch, frame: Transform3D, p: Vector3, size: Vector3, ink: Color, grain := 0.0) -> void:
	b.box(frame * p, size, ink, grain, frame.basis)

static func timber(b: Batch, frame: Transform3D, a: Vector3, c: Vector3, size: Vector2, ink: Color, finish := 1.0) -> void:
	b.bar(frame*a, frame*c, size.x, size.y, ink, frame.basis.z, finish)

static func window(b: Batch, f: Transform3D, w: float, h: float, beam: Color, accent: Color, stone: Color, shutters := false, panes := 2, display := false) -> void:
	panel(b, f, Vector3(0, h*.5, .012), Vector3(w+.20, h+.16, .10), SHADOW)
	panel(b, f, Vector3(0, h*.5, .070), Vector3(w+.08, h+.06, .066), beam, 1)
	var tint := Color("ba965c") if display else GLASS
	panel(b, f, Vector3(0, h*.5, .107), Vector3(w-.064, h-.064, .032), tint, 3)
	for i in panes:
		var x := lerpf(-w*.5, w*.5, (i + .67) / panes)
		if display:
			b.roller(f * Vector3(x-.08, h*.20, .138), f.basis.z, .034, .118, 7, Color("edd096"), 3)
		else:
			b.quad(f*Vector3(x-.115,h*.65,.128), f*Vector3(x+.025,h*.97,.128), f*Vector3(x+.145,h*.97,.128), f*Vector3(x-.008,h*.57,.128), f.basis.z, GLASS.lightened(.40), 3)
	for i in range(1, panes):
		panel(b, f, Vector3(lerpf(-w*.5, w*.5, float(i)/panes), h*.5, .138), Vector3(.052,h,.05), beam, 1)
	panel(b, f, Vector3(0, h * (.76 if display else .52), .139), Vector3(w,.05,.05), beam, 1)
	panel(b, f, Vector3(0, h+.064, .143), Vector3(w+.22,.093,.26), beam.lightened(.12), 1)
	panel(b, f, Vector3(0, -.024, .142), Vector3(w+.29,.095,.31), stone.lightened(.23))
	if shutters:
		for side: float in [-1.0,1.0]:
			var x := side*(w*.5+.194)
			panel(b, f, Vector3(x,h*.5,.066), Vector3(.26,h+.052,.123), accent, 1)
			for k in range(1,5):
				panel(b, f, Vector3(x,h*k*.2,.136), Vector3(.237,.032,.028), accent.lightened(.19), 1)
			panel(b, f, Vector3(x-side*.103,h*.5,.144), Vector3(.029,h*.96,.026), beam, 1)

static func entry(b: Batch, f: Transform3D, w: float, h: float, beam: Color, accent: Color, stone: Color, arched: bool, double: bool) -> void:
	if arched:
		_door_face(b, f, w+.25, h+.125, .045, stone.lightened(.17), true)
	_door_face(b, f, w+.10, h+.048, .070, SHADOW, arched)
	_door_face(b, f, w, h, .096, accent.darkened(.17), arched)
	var count := ceili(w / .175)
	var spring := h - w*.37
	for i in count:
		var a := w * (float(i)/count-.5) + .025
		var c := w * (float(i+1)/count-.5) - .014
		var y_a := spring + w*.37 * sqrt(maxf(0, 1.0 - pow(a*2.0/w,2))) if arched else h-.035
		var y_c := spring + w*.37 * sqrt(maxf(0, 1.0 - pow(c*2.0/w,2))) if arched else h-.035
		b.quad(f*Vector3(a,.018,.104), f*Vector3(c,.018,.104), f*Vector3(c,y_c,.104), f*Vector3(a,y_a,.104), f.basis.z, Batch.tone(accent, .085 * sin(float(i)*2.1)), 1)
	if not arched:
		panel(b,f,Vector3(0,h+.075,.136),Vector3(w+.33,.185,.27),beam.lightened(.095),1)
		for side: float in [-1.0, 1.0]:
			panel(b,f,Vector3(side*(w*.5+.082),h*.5,.113),Vector3(.158,h+.08,.225),beam,1)
	var pull := .31 * w
	if double:
		panel(b,f,Vector3(0,h*.5,.115),Vector3(.045,h,.064),SHADOW)
		for side: float in [-1.0, 1.0]:
			var center := side*w*.25
			for y in [h*.17,h*.83]:
				panel(b,f,Vector3(center,y,.16),Vector3(w*.45,.09,.08),beam.lightened(.16),1)
			timber(b,f,Vector3(center-side*w*.21,h*.17,.163),Vector3(center+side*w*.21,h*.83,.163),Vector2(.115,.073),beam.lightened(.21))
		pull = w*.066
	else:
		panel(b,f,Vector3(0,h*.23,.148),Vector3(w*.89,.088,.068),accent.darkened(.28),1)
		panel(b,f,Vector3(0,h*.73,.148),Vector3(w*.89,.076,.068),accent.darkened(.25),1)
	panel(b,f,Vector3(pull,h*.46,.163),Vector3(.13,.21,.083),SHADOW)
	b.roller(f*Vector3(pull,h*.46,.227), f.basis.z, .085, .053, 8, BRASS)
	if double:
		b.roller(f*Vector3(-pull,h*.46,.207), f.basis.z, .065, .053, 8, BRASS)

static func _door_face(b: Batch, f: Transform3D, w: float, h: float, z: float, ink: Color, arched: bool) -> void:
	var spring := h-w*.37 if arched else h
	b.quad(f*Vector3(-w*.5,0,z),f*Vector3(w*.5,0,z),f*Vector3(w*.5,spring,z),f*Vector3(-w*.5,spring,z),f.basis.z,ink,1)
	if arched:
		for i in 12:
			var a := PI*i/12.0
			var c := PI*(i+1)/12.0
			b.tri(f*Vector3(0,spring,z), f*Vector3(w*.5*cos(a),spring+w*.37*sin(a),z), f*Vector3(w*.5*cos(c),spring+w*.37*sin(c),z), f.basis.z, ink, 1)

static func lantern(b: Batch, p: Vector3, scale_value := 1.0) -> void:
	var iron := Color("443d38")
	b.bar(p + Vector3(0,.27,-.23)*scale_value, p + Vector3(0,.27,0)*scale_value, .062*scale_value, .062*scale_value, iron)
	b.box(p + Vector3(0,-.139,0)*scale_value, Vector3(.22,.058,.22)*scale_value, iron)
	b.box(p, Vector3(.17,.21,.17)*scale_value, Color("ebb171"), 3)
	for x: float in [-.092, .092]:
		for z: float in [-.092, .092]:
			b.box(p+Vector3(x,0,z)*scale_value,Vector3(.037,.24,.037)*scale_value,iron)
	b.lathe(p, Vector3.UP, PackedVector2Array([Vector2(.102,.167)*scale_value,Vector2(.225,.053)*scale_value,Vector2(.248,0)*scale_value]), 4, iron.lightened(.12))
