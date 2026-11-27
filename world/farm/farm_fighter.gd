extends Node
## One real body, one HP pool. The farm selects at most one attacker; only this
## component may advance its enemy state and the single attack contact check.
const Species := preload("farm_species.gd")
const Layout := preload("farm_layout.gd")
const Body := preload("res://art/field_cast/field_body.gd")
const Specimen := preload("res://art/monster_variants/specimen.gd")
const Combat := preload("res://scripts/foundation/field_combat.gd")
const Stats := preload("res://scripts/foundation/actor_stats.gd")
enum Phase { WATCH, ALERT, CLOSE, TELL, SWING, RECOVER, HOME, DOWN }
const WORDS := ["观察", "警戒", "接敌", "蓄势！", "出手", "收招", "归位", "已倒下"]
var definition: Species
var coat: int
var display_name: String
var actor: Body
var model: Node3D
var animator: AnimationPlayer
var stats: Stats
var farm: Node
var box: Rect2
var home: Vector3
var home_yaw: float
var phase := Phase.WATCH
var elapsed := 0.0
var clock := 0.0
var hit_flash := 0.0
var damage_spark := preload("res://scripts/foundation/damage_spark.gd").new()
var committed := Vector3.BACK
var model_rest := Transform3D.IDENTITY
var motion_sample := 0.0
var edge_clearance := .55
var pass_side := 1.0
var cue: Label3D

func install(site: Node, body: Body, look: Node3D, entry: Species, index: int, bounds: Rect2) -> void:
	farm = site
	actor = body
	model = look
	definition = entry
	coat = index
	display_name = entry.coats[index]
	box = bounds
	home = body.global_position
	home_yaw = body.global_rotation.y
	model_rest = model.transform
	var shape := body.solid.shape
	if shape is CylinderShape3D: edge_clearance = shape.radius
	elif shape is CapsuleShape3D:
		edge_clearance = shape.height*.5 if absf(body.body_rotation_degrees.x) > 45 else shape.radius
	edge_clearance = maxf(entry.verge_inset,edge_clearance + Vector2(body.body_center.x,body.body_center.z).length()+.095)
	pass_side = -1.0 if index==1 else 1.0
	stats = Stats.new(0, entry.health, entry.armor)
	clock = float(index)*.83 + absf(home.x*.31)
	actor.set_physics_process(false) # the old presentation timetable must not move the authoritative body
	if not actor is Specimen:
		animator = model.get_node("AnimationPlayer")
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	name = "Encounter"
	actor.add_child(self)
	add_to_group(&"prototype_combat_target")
	cue = Label3D.new()
	cue.name = "WindupMark"
	cue.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cue.font_size = 48
	cue.outline_size = 10
	cue.outline_modulate = Color("473226")
	cue.pixel_size = .011
	cue.position.y = definition.cue_height
	cue.modulate = Color("ffda72")
	cue.text = "!"
	cue.hide()
	actor.add_child(cue)
	actor.add_child(damage_spark)

func can_be_hit_by(source: CharacterBody3D) -> bool:
	return stats.hp() > 0 and source == farm.player and farm.playable() and box.has_point(Layout.xz(source.global_position))

func receive_damage(power: int, _from_direction: Vector3) -> int:
	if not can_be_hit_by(farm.player): return 0
	var lost := stats.take_physical_damage(power)
	if lost <= 0: return 0
	damage_spark.play_hit(_from_direction, definition.cue_height * .83, false)
	hit_flash = .22
	if stats.hp() == 0:
		change(Phase.DOWN)
		actor.solid.set_deferred("disabled", true)
	elif phase == Phase.WATCH:
		farm.challenge(self)
	return lost

func change(next: Phase) -> void:
	if phase == next: return
	phase = next
	elapsed = 0.0
	cue.visible = phase == Phase.TELL

func _face(direction: Vector3) -> void:
	if direction.length_squared() > .0001:
		actor.try_yaw(atan2(direction.x, direction.z))

func _step(toward: Vector3, rate: float, dt: float) -> void:
	if rate <= 0: return
	# Never step or rotate the solid through another actor or a fence. At a
	# gate the same body-sized inset still applies even though there is no rail.
	var safe := box.grow(-edge_clearance)
	var goal := Layout.xz(toward).clamp(safe.position, safe.end)
	var here := Layout.xz(actor.global_position)
	var dir := (goal-here).normalized()
	var step := minf(rate*dt, here.distance_to(goal))
	if step < .0001: return
	_face(Layout.foot(dir,0))
	# A parked sibling can lie on the straight return path. Try short swept
	# alternatives on a consistent side; never warp through the blocker.
	for angle: float in [0.0, .70*pass_side, 1.34*pass_side, -.70*pass_side, -1.34*pass_side]:
		var dest := (here + dir.rotated(angle)*step).clamp(safe.position,safe.end)
		var motion := Layout.foot(dest,home.y) - actor.global_position
		if motion.length_squared() < step*step*.12 or actor.test_move(actor.global_transform,motion): continue
		actor.move_to_mark(Layout.foot(dest,home.y),step)
		return

func disengage() -> void:
	if phase not in [Phase.WATCH, Phase.DOWN, Phase.HOME] or (phase == Phase.WATCH and stats.hp() != stats.max_hp()): change(Phase.HOME)

func _replenish() -> void:
	damage_spark.clear()
	stats.change_hp(stats.max_hp())
	hit_flash = 0
	actor.solid.set_deferred("disabled", false)
	actor.global_rotation.y = home_yaw
	change(Phase.WATCH)
	_pose()

func home_overlaps_walker(foot: Vector3, walker_shape: CollisionShape3D) -> bool:
	# Evaluate both authored rest shapes directly: right after load the physics
	# broadphase can still contain last frame's defeated/moved monsters.
	var walker := walker_shape.shape as CapsuleShape3D
	var w := foot + walker_shape.position
	var dy := maxf(0, walker.height*.5 - walker.radius)
	var rest_shape := Transform3D(Basis(Vector3.UP,home_yaw),home) * actor.solid.transform
	var obstacle := actor.solid.shape
	if obstacle is CapsuleShape3D:
		var axis := rest_shape.basis.y * maxf(0,obstacle.height*.5 - obstacle.radius)
		var nearest := Geometry3D.get_closest_points_between_segments(w-Vector3.UP*dy,w+Vector3.UP*dy,rest_shape.origin-axis,rest_shape.origin+axis)
		return nearest[0].distance_to(nearest[1]) < walker.radius + obstacle.radius + .012
	if obstacle is CylinderShape3D:
		var dx := maxf(0,Layout.xz(w-rest_shape.origin).length()-obstacle.radius)
		var y := maxf(0,absf(w.y-rest_shape.origin.y)-dy-obstacle.height*.5)
		return Vector2(dx,y).length() < walker.radius+.012
	return false

func reset_to_home() -> void:
	# For a fresh/load/rest encounter only, with the player placed safely.
	actor.global_position = home
	actor.reset_physics_interpolation()
	_replenish()

func tick(dt: float, chosen: bool, inside: bool, near_camera: bool) -> void:
	elapsed += dt
	clock += dt
	hit_flash = maxf(0, hit_flash - dt)
	if phase == Phase.DOWN:
		if not inside and elapsed >= 1.15: reset_to_home()
	elif not chosen:
		if not inside or phase not in [Phase.WATCH, Phase.HOME]: disengage()
		if phase == Phase.HOME:
			if actor.global_position.distance_to(home) < .04: _replenish()
			else: _step(home, maxf(1.7, definition.speed), dt)
	else:
		var delta: Vector3 = farm.player.global_position - actor.global_position
		var gap := delta.slide(Vector3.UP).length()
		match phase:
			Phase.WATCH, Phase.HOME: change(Phase.ALERT)
			Phase.ALERT:
				_face(delta)
				if elapsed >= .25: change(Phase.CLOSE)
			Phase.CLOSE:
				_face(delta)
				var facing := actor.global_basis.z.normalized()
				if gap <= definition.reach - .065 and Combat.clear_melee(actor, farm.player, facing, definition.reach, .44):
					committed = facing
					change(Phase.TELL)
				else:
					_step(farm.player.global_position, definition.speed, dt)
			Phase.TELL:
				if elapsed >= definition.windup:
					change(Phase.SWING) # leave this state before applying damage: exactly one opportunity, including a miss
					if farm.playable() and Combat.clear_melee(actor, farm.player, committed, definition.reach, .48):
						var lost: int = farm.player.combat.receive_damage(definition.power, -delta.slide(Vector3.UP))
						farm.report_contact(self, lost)
			Phase.SWING:
				if elapsed >= definition.follow_through: change(Phase.RECOVER)
			Phase.RECOVER:
				if elapsed >= definition.recovery: change(Phase.CLOSE)
	if near_camera:
		# Distant idles cost nothing, nearby idle art samples at 12 Hz; active
		# silhouettes, windups, hits and falls follow the physics clock.
		motion_sample -= dt
		if phase != Phase.WATCH or hit_flash > 0 or motion_sample <= 0:
			_pose()
			motion_sample = 1.0/12.0

func _pose() -> void:
	var clip: StringName = &"idle"
	var p := 0.0
	match phase:
		Phase.TELL:
			clip = &"attack"
			p = definition.contact_pose * clampf(elapsed / definition.windup, 0, 1)
		Phase.SWING:
			clip = &"attack"
			p = lerpf(definition.contact_pose, 1.0, clampf(elapsed / definition.follow_through, 0, 1))
		Phase.CLOSE, Phase.HOME:
			if definition.speed > 0: clip = &"move"
	if actor is Specimen:
		var unit := actor as Specimen
		if clip == &"attack": clip = unit.signature()
		else: p = fposmod(clock / maxf(.1, unit.duration(clip)), 1.0)
		unit.set_display_pose(clip,p)
	else:
		var length := animator.get_animation(clip).length
		if clip != &"attack": p = fposmod(clock / length, 1.0)
		if animator.current_animation != clip: animator.play(clip)
		animator.seek(p * length, true)
	model.transform = model_rest
	if phase == Phase.DOWN:
		var fall := smoothstep(0, .39, elapsed)
		model.rotation.z += fall * 1.22
		model.scale.y *= 1.0 - .32 * fall
	elif hit_flash > 0:
		model.rotation.z -= sin(PI * hit_flash / .22) * .27
	elif clip != &"idle" and actor is Specimen and phase in [Phase.TELL, Phase.SWING]:
		# Old signatures (e.g. rat sniff / sentry guard) keep their articulated
		# silhouette; a short body check makes their actual close contact readable.
		var press := smoothstep(.60,1.0,elapsed/definition.windup) if phase == Phase.TELL else 1.0-smoothstep(0,1,elapsed/definition.follow_through)
		if definition.speed > 0: model.position.z += press * .17
		model.rotation.x += press * .18
