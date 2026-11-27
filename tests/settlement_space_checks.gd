extends SceneTree
const Space:=preload("res://world/outskirts/settlement_space.gd")
var failures:=0
func check(ok:bool, reason:String) -> void:
	if not ok: failures+=1; push_error(reason)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main:=preload("res://Main.tscn").instantiate(); root.add_child(main); await process_frame
	var s:=Space.snapshot(main.field); var errors:=Space.validate(s)
	check(errors.is_empty(),str(errors)); check(s.links.size()==12 and s.roads.has("FarmLane"),"missing real lots or field track")
	var id:String="clearing.stone_street.sill_house"; var lot:Node3D=s.parcels[id].node
	var before:=lot.global_transform; lot.global_position=Vector3(26.31,0,72.62); lot.rotate_y(.6)
	var moved:=Space.snapshot(main.field); var bad:=Space.validate(moved)
	check(bad.has("overlap:TownAlley:"+id) and bad.has("broken-door-link:"+id),str(bad)); lot.global_transform=before
	var wide:Dictionary=s.duplicate(true); wide.roads.FarmLane.widths.fill(16)
	check(Space.validate(wide).has("overlap:FarmLane:rotation_field"),"wide field lane did not overlap planted parcel")
	var reversed:Dictionary=s.duplicate(true); reversed.links[id].normal=-reversed.links[id].normal
	check(Space.validate(reversed).has("illegal-door-side:"+id),"a backwards doorway passed")
	var isolated:Dictionary=s.duplicate(true); isolated.roads.MarketStreet.joins=[]
	check(Space.validate(isolated).has("unreachable:MarketStreet"),"detached court accepted")
	print("Settlement space: ",s.links.size()," doors, ",s.roads.size()," roads; failures ",failures); quit(int(failures!=0))
