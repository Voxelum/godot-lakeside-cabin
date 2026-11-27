extends Node3D
## View layer only. +Z is forward; a stopped Walker provides zero XZ travel.
## Grounded leg targets come from distance, while the coat/head use six pose beats.
const Geometry := preload("res://art/character_trial/cast_geometry.gd")
const WALK_BEAT := [0.0, -.040, .028, 0.0, -.040, .028]
const RUN_BEAT := [-.024, -.046, .044, -.024, -.046, .044]
const REST_PERIOD := 8.6
const GESTURE_START := 4.1

var profile: StringName = Geometry.REED
var idle_offset := 0.0
var mode: StringName = &"idle"
var phase := 0.0
var _look: Geometry
var _yaw := 0.0
var _time := 0.0
var _rest := 0.0
var _gait := 0.0
var _rush := 0.0

func _ready() -> void:
	_look = Geometry.new()
	_look.build(self, profile)
	reset_pose(Vector3.BACK)

func reset_pose(direction: Vector3) -> void:
	_set_heading(direction)
	_look.facing.rotation.y = _yaw
	phase = 0.0
	_time = 0.0
	_rest = 0.0
	_gait = 0.0
	_rush = 0.0
	mode = &"idle"
	_apply(0.0)

func pose_motion(direction: Vector3, distance: float, dt: float, sprinting: bool) -> void:
	_time += dt
	var moving := distance > .00021
	# Facing follows intent when moving or braced at a wall, but the soles do not.
	_set_heading(direction)
	_look.facing.rotation.y = lerp_angle(_look.facing.rotation.y,_yaw,1.0-exp(-26.0*dt))
	if moving:
		_rest = 0.0
		mode = &"run" if sprinting else &"walk"
		_rush = move_toward(_rush,float(sprinting),dt*8.6)
		_gait = move_toward(_gait,1.0,distance/.16)
		phase = fposmod(phase + distance/_stride(),1.0)
	else:
		_rest = _rest + dt if direction.is_zero_approx() else 0.0
		_gait = move_toward(_gait,0.0,dt*6.9)
		if _gait <= 0.0:
			phase = 0.0
			_rush = 0.0
		mode = &"idle"
	var gesture := _gesture_weight() if not moving and direction.is_zero_approx() else 0.0
	if gesture > .75: mode = &"gesture"
	_apply(gesture)

func _set_heading(direction: Vector3) -> void:
	if Vector2(direction.x,direction.z).length_squared() > .0001:
		# Global direction expressed in this presentation node's local axes.
		var here := global_basis.inverse() * direction
		_yaw = atan2(here.x,here.z)

func _stride() -> float:
	var scale_stride := .73 if profile == Geometry.BAKER else (0.96 if profile == Geometry.LINNET else 1.0)
	return lerpf(1.47,2.14,_rush)*scale_stride

func _gesture_weight() -> float:
	# Long listening hold -> clear anticipation -> readable hold -> release.
	var t := fposmod(_rest + idle_offset,REST_PERIOD) - GESTURE_START
	return smoothstep(0.0,.29,t)*(1.0-smoothstep(.83,1.22,t))

func _beat(curve: Array) -> float:
	var f := phase * 6.0
	var lo := int(f) % 6
	return lerpf(curve[lo],curve[(lo+1)%6],smoothstep(0.0,1.0,f-floorf(f)))

func _sole_track(p: float) -> Vector3:
	# Stance travels backwards at exactly the actor's travel rate when fully
	# blended. With a shorter stance, the run has a distinct suspension beat.
	var planted := lerpf(.62,.45,_rush)
	var reach := _stride() * planted
	if p < planted:
		var t := p / planted
		var heel := -.17*(1.0-smoothstep(0.0,.19,t))
		var tip := lerpf(.37,.64,_rush)*smoothstep(.66,1.0,t)
		return Vector3(reach*(.5-t),0,heel+tip)
	var w := (p-planted)/(1.0-planted)
	var center := reach*(smoothstep(0.0,1.0,w)-.5) - _stride()*(1.0-planted)*w*(1.0-w)*(1.0-2.0*w)
	var lift := pow(sin(PI*w),1.72)*lerpf(.135,.300,_rush)
	return Vector3(center,lift,lerpf(lerpf(.37,.64,_rush),-.17,smoothstep(0.0,1.0,w)))

func _apply(gesture: float) -> void:
	var part := _look
	var weight := smoothstep(0.0,1.0,_gait)
	var p := wave_phase()
	var breath := sin((_time+idle_offset)*2.65)
	var hip_z := lerpf(.009,.058,_rush)*weight + .019*gesture
	var hip_x := sin(p)*.018*weight
	var hip_y := part.sizing.x + lerpf(_beat(WALK_BEAT),_beat(RUN_BEAT),_rush)*weight + .007*breath - .024*gesture
	var propped_ankles: Array[Vector3] = []
	var step_pitch: Array[float] = []
	var s := part.scale_limbs
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		var sample := _sole_track(fposmod(phase+.5*k+.045,1.0))*weight
		sample.x += .048*side*(1.0-weight)
		var point := (.175 if sample.z >= 0.0 else -.080)*s
		var sole_offset := Vector3(0,-.073*s,point).rotated(Vector3.RIGHT,sample.z)
		var ankle := Vector3(0,sample.y,sample.x+point)-sole_offset
		propped_ankles.append(ankle)
		step_pitch.append(sample.z)
		var z_gap := ankle.z-hip_z
		var reach := part.leg.x+part.leg.y-.004
		hip_y = minf(hip_y,ankle.y+sqrt(maxf(.02,reach*reach-z_gap*z_gap)))
	part.waist.position = Vector3(hip_x,hip_y,hip_z)
	part.waist.rotation.z = .028*sin(p)*weight
	var lean := part.leg.w + lerpf(.055,.239,_rush)*weight
	part.chest.rotation = Vector3(lean+.034*breath+.055*gesture, .118*sin(p)*weight + .15*gesture,.014*breath-.027*cos(p)*weight-.066*gesture)
	var inspect := -.235 if profile == Geometry.LINNET else (.242 if profile == Geometry.REED else .112)
	part.head.rotation = Vector3(-.57*lean+.021*breath+inspect*gesture,-.052*sin(p)*weight+.22*gesture,.031*breath+.05*gesture)
	var blink := absf(fposmod(_time+idle_offset+1.31,5.2)-.123)
	part.eyes.scale.y = lerpf(.12,1.0,smoothstep(.014,.079,blink))
	if part.trim != null:
		part.trim.rotation = Vector3(-(.10+.22*_rush+.14*sin(p-.58))*weight,0,.255+.12*weight*cos(p-.47)+.067*gesture)
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		part.legs[k].position = Vector3(hip_x+side*part.leg.z,hip_y,hip_z)
		_plant_leg(k,propped_ankles[k]-Vector3(0,hip_y,hip_z),step_pitch[k])
		var pump := cos(p+.5*TAU*k-.24)
		var swing := pump*lerpf(.43,.88,_rush)*weight
		var reach_pose := 0.0
		if profile == Geometry.REED: reach_pose = .80 if k == 0 else 1.06
		elif profile == Geometry.LINNET and k == 1: reach_pose = 1.27
		elif profile == Geometry.POTTER and k == 1: reach_pose = .61
		elif profile == Geometry.TENDER: reach_pose = .19 if k == 1 else .27
		elif profile == Geometry.BAKER and k == 1: reach_pose = .45
		var item_arm := k == 1 and profile in [Geometry.POTTER,Geometry.TENDER,Geometry.BAKER]
		var rest_x := -.34 if item_arm else (-.085 if k == 0 else -.16)
		var wrist_x := -.68 if item_arm else -.15
		var show_flask := k == 1 and profile == Geometry.LINNET
		var spread := (.71 if show_flask else (.28 if k == 1 else .10))*gesture
		var out_turn := .23*gesture if show_flask else 0.0
		part.arms[k].rotation = Vector3(rest_x+(swing*.28 if item_arm else swing)-reach_pose*gesture+.036*breath,.034*side+out_turn,side*(.14+.040*weight)+spread)
		part.elbows[k].rotation.x = wrist_x - maxf(0.0,-pump)*lerpf(.22,.80,_rush)*weight - (.83 if show_flask else (.72 if reach_pose > .3 else .20))*gesture
	var hero := profile in [Geometry.REED,Geometry.LINNET]
	part.tool.visible = not hero or gesture > .32
	var desired := Vector3(-.39,.17,.13) if profile == Geometry.REED else Vector3(-.06,.08,-.13)
	# Pitched tools follow the hand but do not spin end-for-end with the forearm.
	part.tool.basis = (part.chest.basis*part.arms[1].basis*part.elbows[1].basis).inverse()*Basis.from_euler(desired)
	if part.staff != null:
		part.staff.rotation.z = -.045*breath-.112*gesture

func wave_phase() -> float:
	return phase * TAU

func _plant_leg(k: int, aim: Vector3, pitch: float) -> void:
	var a := _look.leg.x; var b := _look.leg.y
	var r := clampf(Vector2(aim.y,aim.z).length(),.01,a+b-.001)
	var upper := -(atan2(aim.z,-aim.y)+acos(clampf((a*a+r*r-b*b)/(2.0*a*r),-1.0,1.0)))
	var bend := PI-acos(clampf((a*a+b*b-r*r)/(2.0*a*b),-1.0,1.0))
	_look.legs[k].rotation.x = upper
	_look.shins[k].rotation.x = bend
	_look.feet[k].rotation.x = pitch-upper-bend

const CombatMotion := preload("res://scripts/foundation/combat_motion.gd")
const CombatProps := preload("res://scripts/foundation/combat_props.gd")
var _combat_props: CombatProps

func drive_combat(action: StringName, progress: float, direction: Vector3, weapon: StringName, drawn: bool) -> void:
	if _combat_props == null:
		_combat_props = CombatProps.new()
		_combat_props.bind(_look.elbows[1], _look.waist, Vector3(.025, -.23, .10))
	_combat_props.show_weapon(weapon, drawn)
	reset_pose(direction)
	_look.waist.rotation.x = 0.0
	if action == &"idle": return
	var pose := CombatMotion.sample(action, progress)
	var whole_body := action in [&"roll", &"down"]
	if whole_body:
		_look.waist.rotation.x = pose.x
		_look.waist.position.y -= .35 * (sin(PI * progress) if action == &"roll" else progress)
	_look.chest.rotation = Vector3(0.0 if whole_body else pose.x, pose.y, 0)
	_look.arms[1].rotation.x = pose.z
	_look.arms[0].rotation.x = pose.w
	_look.elbows[0].rotation.x = -.72 if action == &"guard" else -.23
	_look.elbows[1].rotation.x = -.55 if action == &"guard" else -.24
