extends Node
## One continuous 24 h clock drives the actual light rig shared by BOTH cameras.
## Sun, moon, local-lamp dimmers and lit windows are sampled from the same time.
@export_range(24.0, 1200.0, 1.0) var seconds_per_day := 120.0
@export_range(0.0, 24.0, .05) var starting_hour := 14.0
var hour := 14.0
var daylight := 1.0
var sundown := 0.0
var halted := false
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
	if halted: return
	var rate:=16.0 if Input.is_physical_key_pressed(KEY_T) else 1.0
	var next:=hour + 24.*delta*rate/seconds_per_day
	elapsed_days+=floori(next/24.)
	hour=fposmod(next,24.0)
	_advance_sky()

func handle_key(key:Key) -> bool:
	match key:
		KEY_1,KEY_KP_1: hour=14.0
		KEY_2,KEY_KP_2: hour=17.85
		KEY_3,KEY_KP_3: hour=22.0
		KEY_4,KEY_KP_4: hour=6.15
		KEY_P: halted=not halted
		KEY_H: show_dial=not show_dial
		KEY_O: points_on=not points_on
		KEY_I: spots_on=not spots_on
		_: return false
	_advance_sky()
	return true

func _advance_sky() -> void:
	var height:=sin((hour-6.0)*TAU/24.0)
	var high:=clampf(height,0.,1.)
	daylight=smoothstep(-.205,.275,height)
	sundown=1.0-smoothstep(-.13,.21,height)
	var honey:=1.0-smoothstep(.02,.55,high)
	var eastern:=hour<12.
	var clear_sky:=Color("94c7cf").lerp(Color("f4b294") if eastern else Color("eb9d87"),honey*.87)
	_air.background_color=Color("141e37").lerp(clear_sky,daylight)
	_air.ambient_light_color=Color("92a6d8").lerp(Color("c4d2dd").lerp(Color("c1a4bb"),honey*.68),daylight)
	_air.ambient_light_energy=lerpf(.285,.69,daylight)
	# Keep very low angle shadows from fighting their source polygons at dawn.
	_sun.rotation_degrees=Vector3(-lerpf(18.0,59.0,high),80.0-(hour-6.0)*14.9,0.)
	_sun.shadow_bias=lerpf(.39,.12,smoothstep(.06,.52,high))
	_sun.shadow_normal_bias=lerpf(1.95,1.3,smoothstep(.06,.52,high))
	RenderingServer.global_shader_parameter_set(&"moon_ink",1.-smoothstep(-.25,.04,height))
	_sun.light_color=(Color("ffb07a") if eastern else Color("ff9168")).lerp(Color("fff4d9"),smoothstep(.01,.50,high))
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
