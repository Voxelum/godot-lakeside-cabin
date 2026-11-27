extends Node
## Single actor per ledger identity; room layouts may be freed, so actors live
## beside the room root, never in a disposable room. Offstage bodies are inert.
const Life := preload("res://scripts/foundation/resident_life.gd")
const Person := preload("res://art/field_cast/village_person.gd")
var session
var field_parents := {}

func _physics_process(dt:float) -> void:
	var host = session.host
	var d:Dictionary = session.state.village.d
	var clearing:Node3D = host.field.get_node("Clearing")
	for person:Person in get_tree().get_nodes_in_group(&"village_person"):
		if not host.is_ancestor_of(person): continue
		if not field_parents.has(person.person_id): field_parents[person.person_id] = person.get_parent()
		var p := Life.pose(d,person.person_id)
		person.activity = p.activity
		person.meal_pose(str(p.food),dt)
		var outside:bool = p.scene == "field"
		var active:bool = outside or (host.indoors and host.place_id()==p.scene)
		if not active:
			person.present(false); continue
		var parent:Node = field_parents[person.person_id] if outside else host.room
		var foot:Vector3 = (clearing if outside else host._room_layout).to_global(p.position)
		var walker:Node3D = host.field_actor if outside else host.room_actor
		# Withhold an arrival under a stationary Walker until the foot is clear.
		var transfer := person.get_parent()!=parent or not person.visible
		if foot.distance_to(walker.global_position)<.68 and (transfer or person.global_position.distance_to(foot)>.001): continue
		if person.get_parent()!=parent: person.reparent(parent,false)
		var previous := person.global_position
		person.global_position = foot; person.present(true)
		var rig:Node3D = person.get_node("Model")
		var bed:Node3D
		if p.activity=="sleep" and not outside:
			bed=host._room_layout.get_node_or_null("Furnishing/"+str(p.bed).split("/",true,1)[1])
		person.rest_on(bed)
		if bed!=null: continue
		if rig.has_method("pose_motion")==false and not Vector3(p.direction).is_zero_approx():
			rig.rotation.y=atan2(p.direction.x,p.direction.z)
		var stride := (foot-previous).slide(Vector3.UP)
		if rig.has_method("pose_motion"): rig.call("pose_motion",stride.normalized(),minf(stride.length(),dt*4.) if not transfer else 0.,dt,false)
