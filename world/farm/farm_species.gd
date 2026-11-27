extends Resource
## One immutable bestiary entry. Each placed animal gets its own ActorStats and clock.
@export var id: StringName
@export var title := ""
@export var coats := PackedStringArray()
@export var body_names := PackedStringArray()
@export_enum("First:1", "Second:2") var tier := 1
@export var model_scene: PackedScene
@export var health := 20
@export var power := 5
@export var armor := 0
@export var speed := 2.0
@export var reach := 1.20
@export var notice := 4.0
@export var windup := .55
@export var recovery := 1.00
## Portion of the visual attack clip played up to the single contact check.
@export_range(0.1, 0.9) var contact_pose := .50
@export var follow_through := .32
@export var soil := Color("aca176")
## Plain art-only scenes need a solid. Existing specimen scenes keep their authored body.
@export var verge_inset := .72 # keep visible limbs inside open gates too
@export var solid_radius := .30
@export var solid_height := 1.10
@export var body_lift := .02
@export var cue_height := 1.5
