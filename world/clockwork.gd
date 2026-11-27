extends Node
## One continuous 24 h clock drives the actual light rig shared by BOTH cameras.
## Sun, moon, local-lamp dimmers and lit windows are sampled from the same time.
@export_range(24.0, 1200.0, 1.0) var seconds_per_day := 120.0
@export_range(0.0, 24.0, .05) var starting_hour := 14.0
var hour := 14.0
var daylight := 1.0
var sundown := 0.0
var halted := false
var ledger: RefCounted

func bind_time(source: RefCounted) -> void:
	ledger = source
	sync_time()

func sync_time() -> void:
	elapsed_days = int(ledger.d.hour) / 24
	hour = float(int(ledger.d.hour) % 24) + float(ledger.d.seconds) / 5.0
	_advance_sky()
var allow_fast_key := true
var points_on := true
var spots_on := true
var show_dial := true
var elapsed_days := 0
var _moon: DirectionalLight3D
var _sun: DirectionalLight3D
var _air: Environment
var _water: Node
var _locals: Dictionary = {}
var _lenses: Dictionary = {}
var _glazing: Array[ShaderMaterial] = []
var _casements: Array[StandardMaterial3D] = []

func _ready() -> void:
	var clearing := get_parent()
	_sun=clearing.get_node("Sun"); _moon=clearing.get_node("Moon")
	_air=(clearing.get_node("Air") as WorldEnvironment).environment
	_water=clearing.get_node("Pool")
	for group in [&"night_omni", &"night_spot"]:
		for item in get_tree().get_nodes_in_group(group):
			var lamp:=item as Light3D
			if lamp: _locals[lamp]=lamp.light_energy
	for node in get_tree().get_nodes_in_group(&"night_glow"):
		var glass:=node as MeshInstance3D
		if not glass: continue
		var mat:=glass.material_override as StandardMaterial3D
		if mat and not _lenses.has(mat):
			_lenses[mat]=Vector2(maxf(.85,mat.emission_energy_multiplier),float(clearing.get_node("PorchLight").is_ancestor_of(glass)))
	for node in get_tree().get_nodes_in_group(&"clock_glass"):
		var pane:=node as MeshInstance3D
		if pane and pane.material_override is ShaderMaterial and not _glazing.has(pane.material_override): _glazing.append(pane.material_override)
	# Only the old cottage's opaque little casements glow. The conservatory uses
	# separate transmissive panes; we do not replace its transparency or contents.
	var copies:Dictionary={}
	for node in clearing.get_node("Cottage").find_children("Wavy_Glass_*","MeshInstance3D",true,false):
		var mesh:=node as MeshInstance3D;var old:=mesh.get_active_material(0) as StandardMaterial3D
		if old==null: continue
		if not copies.has(old):
			var mat:=old.duplicate() as StandardMaterial3D
			mat.emission_enabled=true;mat.emission=Color("ffc078");mat.emission_energy_multiplier=0.0
			copies[old]=mat; _casements.append(mat)
		mesh.material_override=copies[old]
	hour=fposmod(starting_hour,24.0)
	_advance_sky()

func _process(delta: float) -> void:
	if halted:
		# A manual economy step still changes the shared time when paused.
		if ledger and (elapsed_days != int(ledger.d.hour) / 24 or floori(hour) != int(ledger.d.hour) % 24): sync_time()
		return
	var rate:=16.0 if allow_fast_key and Input.is_physical_key_pressed(KEY_T) else 1.0
	if ledger:
		ledger.elapsed(delta * rate)
		sync_time()
		return
	var next:=hour + 24.*delta*rate/seconds_per_day
	elapsed_days+=floori(next/24.)
	hour=fposmod(next,24.0)
	_advance_sky()

func handle_key(key:Key) -> bool:
	var previous := hour
	match key:
		KEY_1,KEY_KP_1: hour=14.0; halted=true
		KEY_2,KEY_KP_2: hour=16.75; halted=true
		KEY_3,KEY_KP_3: hour=18.66667; halted=true
		KEY_4,KEY_KP_4: hour=6.15
		KEY_P: halted=not halted
		KEY_H: show_dial=not show_dial
		KEY_O: points_on=not points_on
		KEY_I: spots_on=not spots_on
		_: return false
	if ledger and key in [KEY_1,KEY_KP_1,KEY_2,KEY_KP_2,KEY_3,KEY_KP_3,KEY_4,KEY_KP_4]:
		# Seek forward to the next occurrence; an identical preset is a no-op.
		var forward := 0.0 if is_equal_approx(previous,hour) else fposmod(hour-previous,24.0)
		ledger.elapsed(forward * 5.0)
		sync_time()
	else:
		_advance_sky()
	return true

func _advance_sky() -> void:
	var height:=sin((hour-6.0)*TAU/24.0)
	var high:=clampf(height,0.,1.)
	daylight=smoothstep(-.205,.275,height)
	sundown=1.0-smoothstep(-.13,.21,height)
	var honey:=1.0-smoothstep(.02,.55,high)
	var eastern:=hour<12.
	# Cool open shade holds foliage and stone together; warm accents come from
	# directional sunlight and actual windows, never a rose wash in every shadow.
	var clear_sky:=Color("87bdbe").lerp(Color("d3c5ab") if eastern else Color("bc9d91"),honey*.74)
	_air.background_color=Color("102335").lerp(clear_sky,daylight)
	var low_fill:=Color("a1bac2") if eastern else Color("99a7b7")
	_air.ambient_light_color=Color("819fbf").lerp(Color("b4cbc6").lerp(low_fill,honey*.80),daylight)
	_air.ambient_light_energy=lerpf(.28,.62,daylight)
	# Keep very low angle shadows from fighting their source polygons at dawn.
	_sun.rotation_degrees=Vector3(-lerpf(18.0,59.0,high),80.0-(hour-6.0)*14.9,0.)
	_sun.shadow_bias=lerpf(.39,.12,smoothstep(.06,.52,high))
	_sun.shadow_normal_bias=lerpf(1.95,1.3,smoothstep(.06,.52,high))
	RenderingServer.global_shader_parameter_set(&"moon_ink",1.-smoothstep(-.25,.04,height))
	_sun.light_color=(Color("f0d6b1") if eastern else Color("f2af87")).lerp(Color("fff4d9"),smoothstep(.01,.50,high))
	_sun.light_energy=smoothstep(-.12,.11,height)*lerpf(.71,1.03,smoothstep(0.,.64,high))
	_sun.visible = _sun.light_energy>.003
	var moon_up:=clampf(-height,0.,1.)
	_moon.rotation_degrees=Vector3(-lerpf(17.,51.,moon_up),-78.+43.*sin((hour-19.)*TAU/24.),0.)
	_moon.light_color=Color("8daef0")
	_moon.light_energy=(1.-smoothstep(-.27,.16,height))*.205
	_moon.visible = _moon.light_energy>.002
	for item in _locals:
		var lamp:=item as Light3D;var enabled:=spots_on if lamp is SpotLight3D else points_on
		lamp.light_energy=float(_locals[item])*sundown*float(enabled)
		lamp.visible=lamp.light_energy>.004
	for item in _lenses:
		var mat:=item as StandardMaterial3D
		var setting:Vector2=_lenses[item]
		mat.emission_energy_multiplier=sundown*setting.x*float(spots_on if setting.y>.5 else points_on)
	for mat in _casements: mat.emission_energy_multiplier=.88*pow(sundown,1.4)
	for mat in _glazing: mat.set_shader_parameter(&"night_mix",1.0-daylight)
	if _water.has_method(&"set_time_of_day"): _water.call(&"set_time_of_day",daylight,hour)
