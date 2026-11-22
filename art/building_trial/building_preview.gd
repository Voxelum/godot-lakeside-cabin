extends Control
## Sandbox: only presentation, the stock Courier and local collisions. No WorldState.
const Site = preload("res://art/building_trial/trial_site.gd")
const VILLAGE = preload("res://art/building_trial/VillageLane.tscn")
const TOWN = preload("res://art/building_trial/TownCorner.tscn")
const WALKER = preload("res://world/Walker.tscn")

@onready var pixels: SubViewport = $Pixels
@onready var screen: TextureRect = $Screen
var site: Site
var actor: CharacterBody3D
var current_site := 0
var zoom_step := 4
var follow := false
var clay := false
var dusk := false
var aim := Vector3.ZERO

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	resized.connect(_fit)
	screen.texture = pixels.get_texture()
	set_pixel_size(320 if "--320" in args else 480)
	dusk = "--dusk" in args
	clay = "--clay" in args
	show_site(1 if "--town" in args else 0)

func show_site(index: int) -> void:
	current_site = clampi(index,0,1)
	if is_instance_valid(site):
		pixels.remove_child(site)
		site.queue_free()
	site = (VILLAGE if current_site == 0 else TOWN).instantiate() as Site
	pixels.add_child(site)
	actor = WALKER.instantiate() as CharacterBody3D
	site.add_child(actor)
	reset_position()
	apply_look()

func reset_position() -> void:
	actor.global_position = site.spawn.global_position
	actor.call(&"settle_input")
	aim = _target()
	_place_camera()

func _fit() -> void:
	var base := Vector2(pixels.size)
	var scale_value := maxi(1, floori(minf(size.x/base.x,size.y/base.y)))
	screen.size = base*scale_value
	screen.position = ((size-screen.size)*.5).floor()

func set_pixel_size(width: int) -> void:
	pixels.size = Vector2i(320,180) if width == 320 else Vector2i(480,270)
	get_window().min_size = pixels.size
	_fit()
	if is_instance_valid(site):
		_place_camera()
		_update_title()

func apply_look() -> void:
	site.lighting(dusk, clay)
	_update_title()

func _update_title() -> void:
	var label := "Village Lane" if current_site == 0 else "Town Corner"
	get_window().title = "%s  |  %d×%d  |  %s  |  1/2 Sites · V Pixels · C Clay · L Light · F Follow · R Reset" % [label,pixels.size.x,pixels.size.y,"Clay" if clay else ("Dusk" if dusk else "Day")]

func _target() -> Vector3:
	if follow or zoom_step < 4:
		return actor.global_position + Vector3.UP*lerpf(1.05,1.82,float(zoom_step)/5)
	return site.wide_focus

func _place_camera() -> void:
	site.view_at(aim,zoom_step,pixels.size.y)

func _process(dt: float) -> void:
	if not is_instance_valid(site):
		return
	if follow or zoom_step < 4:
		aim = aim.lerp(_target(),1.0-exp(-10.5*dt))
	_place_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and screen.get_rect().has_point(event.position):
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_step = clampi(zoom_step + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1),0,Site.ZOOM.size()-1)
			aim = _target()
			_place_camera()
			get_viewport().set_input_as_handled()
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1,KEY_KP_1: show_site(0)
		KEY_2,KEY_KP_2: show_site(1)
		KEY_V: set_pixel_size(320 if pixels.size.x == 480 else 480)
		KEY_C:
			clay = not clay
			apply_look()
		KEY_L:
			dusk = not dusk
			apply_look()
		KEY_F:
			follow = not follow
			aim = _target()
			_place_camera()
		KEY_R: reset_position()
		_: return
	get_viewport().set_input_as_handled()
