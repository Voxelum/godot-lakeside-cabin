extends RefCounted
## Baking utilities only. Instances of the exported scenes have no scripts.

const Brush := preload("res://art/monster_trial/source/brush.gd")
var b := Brush.new()
var root: Node3D
var rig: Node3D
var player := AnimationPlayer.new()
var library := AnimationLibrary.new()
var _rest: Dictionary = {}

func _init(label: String) -> void:
	root = Node3D.new()
	root.name = label
	rig = b.joint(root, "Rig", Vector3.ZERO)
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.add_animation_library(&"", library)

func bind(parts: Array[Node3D]) -> void:
	for part in parts:
		_rest[part] = part.transform
	clip(&"RESET", 0.0167, false, func(_u: float) -> void: pass)

func clip(id: StringName, seconds: float, looping: bool, pose: Callable) -> void:
	var anim := Animation.new()
	anim.resource_name = String(id)
	anim.length = seconds
	anim.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	anim.step = 1.0 / 24.0
	var samples := 0 if id == &"RESET" else maxi(2, roundi(seconds * 24.0))
	var frames: Dictionary = {}
	for n: Node3D in _rest:
		frames[n] = []
	for i in range(samples + 1):
		_restore()
		pose.call(float(i) / maxi(1, samples))
		for n: Node3D in _rest:
			frames[n].append([n.position, n.quaternion, n.scale])
	_restore()
	for n: Node3D in _rest:
		var values: Array = frames[n]
		for channel in 3:
			var type: Animation.TrackType = [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D][channel]
			var track := anim.add_track(type)
			anim.track_set_path(track, root.get_path_to(n))
			var constant := true
			for value: Array in values:
				if not value[channel].is_equal_approx(values[0][channel]):
					constant = false
					break
			for i in (1 if constant else values.size()):
				var t := seconds * float(i) / maxi(1, samples)
				match type:
					Animation.TYPE_POSITION_3D: anim.position_track_insert_key(track, t, values[i][0])
					Animation.TYPE_ROTATION_3D: anim.rotation_track_insert_key(track, t, values[i][1])
					Animation.TYPE_SCALE_3D: anim.scale_track_insert_key(track, t, values[i][2])
	library.add_animation(id, anim)

func _restore() -> void:
	for n: Node3D in _rest:
		n.transform = _rest[n]

func pack() -> PackedScene:
	player.autoplay = &"idle"
	_own(root)
	var scene := PackedScene.new()
	if scene.pack(root) != OK:
		push_error("Could not pack " + String(root.name))
		return null
	return scene

func _own(at: Node) -> void:
	for child in at.get_children():
		child.owner = root
		_own(child)

static func curve(keys: Array, u: float) -> PackedFloat32Array:
	var v := PackedFloat32Array()
	for i in range(1, keys.size()):
		if u <= float(keys[i][0]) or i == keys.size() - 1:
			var w := smoothstep(float(keys[i-1][0]), float(keys[i][0]), u)
			for k in range(1, keys[i].size()):
				v.append(lerpf(float(keys[i-1][k]), float(keys[i][k]), w))
			return v
	return v

static func stride(phase: float, span: float, lift: float, duty: float) -> Vector2:
	var p := fposmod(phase, 1.0)
	if p < duty:
		return Vector2(0.0, span * (0.5 - p / duty))
	var swing := (p - duty) / (1.0 - duty)
	return Vector2(lift * pow(sin(swing * PI), 1.3), span * (smoothstep(0.0, 1.0, swing) - 0.5))

## Sagittal two-link solve at bake time. The wolf's rear leg adds a short hock.
## Only the baked parent-relative keys ship on the actor.
class Leg:
	var top: Node3D
	var shin: Node3D
	var hock: Node3D
	var paw: Node3D
	var l1: float
	var l2: float
	var hock_length: float
	var knee_forward: float
	var rest_socket: Vector3
	var rest_ankle: Vector3

	func _init(brush: RefCounted, parent: Node3D, label: String, socket: Vector3, ankle: Vector3, lengths: Vector3, bend: float) -> void:
		l1 = lengths.x
		l2 = lengths.y
		hock_length = lengths.z
		knee_forward = bend
		rest_socket = socket
		rest_ankle = ankle
		top = brush.joint(parent, label, socket)
		shin = brush.joint(top, "Shin", Vector3(0, -l1, 0))
		if hock_length > 0.0:
			hock = brush.joint(shin, "Hock", Vector3(0, -l2, 0))
			paw = brush.joint(hock, "Paw", Vector3(0, -hock_length, 0))
		else:
			paw = brush.joint(shin, "Paw", Vector3(0, -l2, 0))
		solve(socket, ankle)

	func joints() -> Array[Node3D]:
		var out: Array[Node3D] = [top, shin, paw]
		if hock != null:
			out.append(hock)
		return out

	func solve(socket: Vector3, ankle: Vector3, pitch := 0.0, hock_angle := -0.59) -> void:
		var ray := Vector2(ankle.y - socket.y, ankle.z - socket.z)
		if hock != null:
			ray += Vector2(cos(hock_angle), sin(hock_angle)) * hock_length
		var distance := clampf(ray.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
		var aim := ray.normalized()
		if aim.is_zero_approx():
			aim = Vector2(-1, 0)
		var offset := (l1*l1 - l2*l2 + distance*distance) / (2.0 * distance)
		var altitude := sqrt(maxf(0.0, l1*l1 - offset*offset))
		var knee := aim * offset + Vector2(aim.y, -aim.x) * altitude * knee_forward
		var lower := aim * distance - knee
		var angle_a := atan2(-knee.y, -knee.x)
		var angle_b := atan2(-lower.y, -lower.x)
		top.position = socket
		top.rotation.x = angle_a
		shin.rotation.x = wrapf(angle_b - angle_a, -PI, PI)
		if hock != null:
			hock.rotation.x = wrapf(hock_angle - angle_b, -PI, PI)
		paw.rotation.x = wrapf(pitch - (hock_angle if hock != null else angle_b), -PI, PI)
