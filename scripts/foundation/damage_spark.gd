extends Sprite3D
## A contact mark owned by the victim. Never drives pose, physics or input.
const LIFE := .25
const MONSTER := ["   x    ","   xx  x"," x xxx x","xxxxxxxx"," x xxx x","   xx  x","   x    "]
const HERO := ["   xx    ","    xx xx","     xx x","xxxxxxxxx","     xx x","    xx xx","   xx    "]
static var stamps := {}
var remaining := 0.0

func _ready() -> void:
	name = "DamageSpark"
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	pixel_size = .095
	clear()

func play_hit(toward_source: Vector3, height: float, hero: bool) -> void:
	var body := get_parent() as Node3D
	var camera := get_viewport().get_camera_3d()
	if not camera: return
	var away := -toward_source.slide(Vector3.UP).normalized()
	if away.length_squared() < .01: away = body.global_basis.z.normalized()
	global_position = body.global_position + Vector3.UP * height + away * .28
	var projected := camera.unproject_position(global_position + away) - camera.unproject_position(global_position)
	var sector := posmod(roundi(projected.angle() / (PI / 4)), 8)
	var key := sector + (8 if hero else 0)
	if not stamps.has(key): stamps[key] = _stamp(sector, hero)
	texture = stamps[key]
	remaining = LIFE
	show()
	set_physics_process(true)

static func _stamp(sector: int, hero: bool) -> Texture2D:
	var image := Image.create_empty(17,17,false,Image.FORMAT_RGBA8)
	var rows: Array = HERO if hero else MONSTER
	var dark := Color("572d38") if hero else Color("344635")
	var tint := Color("ff7958") if hero else Color("ffc45d")
	var angle := sector * PI / 4
	for pass_index in 2:
		for y in 17:
			for x in 17:
				var uv := Vector2i((Vector2(x-8,y-8).rotated(-angle) + Vector2(4,3)).round())
				if uv.y < 0 or uv.y >= rows.size() or uv.x < 0 or uv.x >= rows[uv.y].length() or rows[uv.y][uv.x] != "x": continue
				if pass_index == 0: image.fill_rect(Rect2i(x-1,y-1,3,3),dark)
				else: image.set_pixel(x,y,Color("fff2c9") if uv.y == 3 else tint)
	return ImageTexture.create_from_image(image)

func clear() -> void:
	remaining = 0
	hide()
	set_physics_process(false)

func _physics_process(dt: float) -> void:
	remaining -= dt
	if remaining <= 0: clear()
