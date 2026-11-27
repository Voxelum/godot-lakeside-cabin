extends RefCounted
## Temporary rigid mesh props; grip is at the origin and +Y is the blade/point.
var _hand: Node3D
var _stowed: Node3D
var _weapon: StringName

func bind(hand: Node3D, hip: Node3D, grip: Vector3) -> void:
	_hand = Node3D.new()
	_stowed = Node3D.new()
	hand.add_child(_hand)
	hip.add_child(_stowed)
	_hand.position = grip
	_stowed.position = Vector3(-.25, .02, -.14)
	_stowed.rotation.z = -.37

func show_weapon(weapon: StringName, drawn: bool) -> void:
	if _weapon != weapon:
		_weapon = weapon
		for prop in [_hand, _stowed]:
			for child in prop.get_children():
				prop.remove_child(child)
				child.queue_free()
			if not weapon.is_empty():
				_build(prop, weapon == &"spear", prop == _stowed)
		_hand.rotation.x = PI * (.48 if weapon == &"spear" else .18)
	_hand.visible = not weapon.is_empty() and drawn
	_stowed.visible = not weapon.is_empty() and not drawn

func _build(at: Node3D, spear: bool, stowed: bool) -> void:
	var steel := Color("c4d2d2")
	var wood := Color("8b6944")
	if spear:
		_box(at, Vector3(0, .34, 0), Vector3(.048, 1.39, .048), wood)
		var point := CylinderMesh.new()
		point.top_radius = 0
		point.bottom_radius = .068
		point.height = .24
		point.radial_segments = 4
		_mesh(at, point, Vector3(0, 1.10, 0), steel)
	else:
		var blade := Color("735946") if stowed else steel
		_box(at, Vector3(0, .43, 0), Vector3(.088, .66, .035), blade)
		_box(at, Vector3(0, .09, 0), Vector3(.22, .051, .059), Color("b39658"))
		_box(at, Vector3(0, -.025, 0), Vector3(.059, .18, .056), wood)

func _box(at: Node3D, offset: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh(at, mesh, offset, color)

func _mesh(at: Node3D, mesh: Mesh, offset: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	instance.material_override = paint
	instance.mesh = mesh
	instance.position = offset
	at.add_child(instance)
