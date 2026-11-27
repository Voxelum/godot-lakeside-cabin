extends RefCounted
## Component palette. One type per wall system / opening, not one type per view.
## Physical apertures are cut independently from these finish and joinery parts.
const Join := preload("res://art/building_trial/joinery.gd")
const Batch := preload("res://art/building_trial/mesh_batch.gd")

const WALLS := {
	"plaster_posts": {"boards": false, "plinth": false, "framed": false},
	"framed_plaster": {"boards": false, "plinth": false, "framed": true},
	"board_batten": {"boards": true, "plinth": false, "framed": false},
	"masonry_plinth": {"boards": false, "plinth": true, "framed": false},
}
const WINDOWS := {
	"casement": {"panes": 2, "cross": true, "shutters": false},
	"shuttered_casement": {"panes": 2, "cross": true, "shutters": true},
	"triplet": {"panes": 3, "cross": true, "shutters": false},
	"shuttered_triplet": {"panes": 3, "cross": true, "shutters": true},
	"shop_display": {"panes": 3, "cross": false, "shutters": false},
	"louver": {"panes": 0, "cross": false, "shutters": false},
}

static func wall_type(recipe: Dictionary) -> String:
	if recipe.has("wall_panel"): return recipe.wall_panel
	return {"barn": "board_batten", "smith": "masonry_plinth", "town": "framed_plaster"}.get(recipe.get("kind", "town"), "plaster_posts")

static func opening_type(op: Dictionary) -> String:
	if op.kind == "vent": return op.get("component", "louver")
	if op.has("component"): return op.component
	return ("shuttered_" if op.get("shutters", false) else "") + ("triplet" if int(op.get("panes", 2)) == 3 else "casement")

static func panel(art: Batch, f: Transform3D, u: float, span: float, low: float, high: float, thick: float, ink: Color, grain := 0.0) -> void:
	if high > low + .0001:
		Join.panel(art, f, Vector3(u, (low+high)*.5, 0), Vector3(span, high-low, thick), ink, grain)

static func battens(art: Batch, f: Transform3D, a: float, b: float, low: float, high: float, z: float, ink: Color) -> void:
	if high-low < .03: return
	for i in range(floori(a/.265), ceili(b/.265)):
		var l := maxf(a, i*.265)+.007
		var r := minf(b, (i+1)*.265)-.007
		if r-l < .018: continue
		Join.panel(art,f,Vector3((l+r)*.5,(low+high)*.5,z),Vector3(r-l,high-low-.011,.044),Batch.tone(ink,.15*sin(i*3.2)),1)

static func sash(trim: Batch, glass: Batch, sill: Batch, frame: Transform3D, aperture: Vector2, wall: float, parts: Dictionary, sash_ink: Color, pane_ink: Color, sill_ink: Color, outside: bool) -> void:
	var w := aperture.x
	var h := aperture.y
	var z := -wall*.5
	var thick := wall+.103
	for s: float in [-1,1]:
		Join.panel(trim,frame,Vector3(s*(w*.5-.008),h*.5,z),Vector3(.058,h+.047,thick),sash_ink,1)
		Join.panel(trim,frame,Vector3(0,h*.5+s*(h*.5-.007),z),Vector3(w+.11,.057,thick),sash_ink,1)
	var panes: int = parts.panes
	if panes == 0:
		for i in 4:
			var slat := frame.rotated_local(Vector3.RIGHT, -.23)
			slat.origin = frame*Vector3(0,(i+1)*h/5.0,z)
			Join.panel(trim,slat,Vector3.ZERO,Vector3(w,.068,.102),sash_ink.darkened(.18),1)
		return
	Join.panel(glass,frame,Vector3(0,h*.5,z),Vector3(w-.041,h-.041,.042),pane_ink,3)
	for i in range(1,panes):
		var x := lerpf(-w*.5,w*.5,float(i)/panes)
		Join.panel(trim,frame,Vector3(x,h*.5,z),Vector3(.043,h,.082),sash_ink,1)
	if parts.cross:
		Join.panel(trim,frame,Vector3(0,h*.52,z),Vector3(w,.041,.086),sash_ink,1)
	var face := frame if outside else Transform3D(frame.basis.rotated(Vector3.UP,PI),frame.origin-frame.basis.z*wall)
	Join.panel(trim,face,Vector3(0,h+.035,.016),Vector3(w+.165,.081,.146),sash_ink.lightened(.12),1)
	Join.panel(sill,face,Vector3(0,-.031,.066),Vector3(w+.18,.084,.173),sill_ink,1 if sill == trim else 0)
	for i in panes:
		var x := lerpf(-w*.5,w*.5,(i+.57)/panes)
		var offset := minf(.102,w/panes*.37)
		var zz := -wall*.5+.022
		glass.quad(face*Vector3(x-offset*.8,h*.63,zz),face*Vector3(x+offset*.22,h*.90,zz),face*Vector3(x+offset*.84,h*.90,zz),face*Vector3(x-offset*.16,h*.63,zz),face.basis.z,pane_ink.lightened(.42),3)

static func shutters(trim: Batch, frame: Transform3D, size: Vector2, ink: Color) -> void:
	for s: float in [-1,1]:
		var x := s*(size.x*.5+.147)
		Join.panel(trim,frame,Vector3(x,size.y*.5,.038),Vector3(.218,size.y+.030,.087),ink,1)
		for i in 5: Join.panel(trim,frame,Vector3(x,(i+.5)*size.y/5.0,.091),Vector3(.186,.030,.023),ink.lightened(.21),1)
