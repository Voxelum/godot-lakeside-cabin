extends "res://art/building_trial/trial_site.gd"
## Same lots, road kit and dressing as the standalone trial, without its test
## plane, four blocking edges or viewport ownership. The host owns the ground.

func _ready() -> void:
	# The inherited @onready bindings have resolved, but no frame has drawn yet.
	for preview_node in [air, sun, camera]:
		remove_child(preview_node)
		preview_node.queue_free()
	_rebuild()

func _rebuild() -> void:
	if is_instance_valid(_generated):
		remove_child(_generated)
		_generated.queue_free()
	_generated = Node3D.new()
	_generated.name = "StreetDressing"
	add_child(_generated)
	_solid = StaticBody3D.new()
	_solid.name = "StreetPropsCollision"
	_solid.collision_mask = 0
	_generated.add_child(_solid)
	_rng.seed = 3259 + setting * 1987
	pigment.shader = PIGMENT
	var paving := Batch.new()
	var props := Batch.new()
	if setting == 0:
		_village(paving, props)
	else:
		_town(paving, props)
	for lot in lots():
		var link := road_link(lot)
		var approach := lot.marker("Approach")
		var door := lot.marker("DoorAnchor")
		if link == null or approach == null or door == null or not _faces_link(door, link):
			continue
		var start := _xz(to_local(approach.global_position - approach.global_basis.z * .17))
		var finish := _xz(to_local(link.global_position))
		if start.distance_to(finish) > .13:
			var village := setting == 0
			_ribbon(paving, [start, start.lerp(finish, .53), finish], lot.door_width + (.19 if village else .30), .026 if village else .015, Color("ad9471") if village else Color("abad9f"), village)
	paving.add_to(_generated, "RoadAndApproaches", pigment, false)
	props.add_to(_generated, "StreetProps", pigment)
