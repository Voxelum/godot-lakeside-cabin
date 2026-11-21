extends Control
## The composed world is rendered into a small buffer (water has a separate
## low-resolution reflection pass). Only whole texels
## are displayed, even when a resize leaves an odd number of spare pixels.
@export_enum("320 × 180", "480 × 270") var resolution_preset: int = 1

func _ready() -> void:
	if "--320" in OS.get_cmdline_user_args():
		resolution_preset = 0
	var base := Vector2i(480, 270) if resolution_preset == 1 else Vector2i(320, 180)
	$Pixels.size = base
	get_window().min_size = base
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	var base := Vector2($Pixels.size)
	var k := maxi(1, floori(minf(size.x / base.x, size.y / base.y)))
	$Screen.size = base * k
	$Screen.position = ((size - $Screen.size) * 0.5).floor()

func _unhandled_key_input(event: InputEvent) -> void:
	var key:=event as InputEventKey
	if key and key.pressed and not key.echo:
		if $Pixels/Clearing/Almanac.handle_key(key.keycode):
			get_viewport().set_input_as_handled()
