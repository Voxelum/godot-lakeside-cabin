extends Node
## Trial dressing for Main, not a second map or player controller.
const Geometry := preload("res://art/character_trial/cast_geometry.gd")
const Rig := preload("res://art/character_trial/cast_rig.gd")
const Isaac := preload("res://art/character_trial/isaac/isaac_look.gd")
const Survey := preload("res://world/outskirts/outskirts_profile.gd")
const FieldBody := preload("res://art/field_cast/field_body.gd")
# Radius / full capsule height. Props and gesturing hands are not solid.
const BODIES := {
	Geometry.REED: Vector2(.31, 1.77), Geometry.LINNET: Vector2(.27, 1.62),
	Geometry.TENDER: Vector2(.25, 1.48), Geometry.POTTER: Vector2(.34, 1.64),
	Geometry.BAKER: Vector2(.215, 1.27),
}
const COMPANION_XZ := Vector2(1.09,7.36)
const TENDER_XZ := Vector2(8.43,23.38)
# Keep clear of the normal follow camera's sightlines behind the smithy and maple.
const POTTER_XZ := Vector2(16.74,26.86)
const BAKER_A := Vector2(31.08,75.62)
const BAKER_B := Vector2(33.22,75.59)
const BAKER_ROUND := 13.5

@export var enabled := true
# Preserve existing Inspector indices 0/1. The default is the internal 3D study.
@export_enum("Reed · Surveyor", "Linnet · Seed keeper", "Isaac · 3D study") var player_look := 2
var companion: Rig
var tender: Rig
var potter: Rig
var baker: Rig
var outdoor: Node3D
var _clearing: Node3D
var _elapsed := 0.0
var _grounded := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not enabled or "--legacy-cast" in args:
		set_physics_process(false)
		return
	_clearing = $"../Pixels/Clearing"
	outdoor = Node3D.new()
	outdoor.name = "TrialTownsfolk"
	_clearing.add_child(outdoor)
	var look: StringName = [Geometry.REED, Geometry.LINNET, Isaac.PROFILE][player_look]
	for arg in args:
		if arg in ["--hero=reed", "--hero=linnet", "--hero=isaac"]:
			look = StringName(arg.trim_prefix("--hero="))
	select_hero(look)
	tender = _local("HazelTender",Geometry.TENDER,TENDER_XZ,-.25,1.2)
	potter = _local("WellPotter",Geometry.POTTER,POTTER_XZ,.20,2.4)
	baker = _local("BakeryRunner",Geometry.BAKER,BAKER_A,.23,.55)

func select_hero(profile: StringName) -> void:
	if outdoor == null or profile not in [Isaac.PROFILE,Geometry.REED,Geometry.LINNET]: return
	var field_actor = _clearing.get_node("Traveler")
	var room_actor = get_node("../RoomPixels/Guest")
	if (field_actor.artwork is Rig or field_actor.artwork is Isaac) and field_actor.artwork.profile == profile: return
	_mount(field_actor,profile,Vector3.BACK)
	_mount(room_actor,profile,Vector3.FORWARD)
	if companion != null:
		var former := companion.get_parent()
		former.get_parent().remove_child(former)
		former.queue_free()
	companion = _local("LakesideCompanion",Geometry.REED if profile == Geometry.LINNET else Geometry.LINNET,COMPANION_XZ,-.21,2.75)
	_grounded = false

func _mount(actor: CharacterBody3D, profile: StringName, facing: Vector3) -> void:
	var previous: Node3D = actor.get("artwork")
	previous.hide()
	if previous is Rig or previous is Isaac: previous.queue_free()
	var model: Node3D
	if profile == Isaac.PROFILE:
		var ink := Isaac.new()
		ink.follow_sky = actor.get_viewport() == _clearing.get_viewport()
		model = ink
	else:
		var rig := Rig.new()
		rig.profile = profile
		model = rig
	model.name = "TrialAppearance"
	actor.add_child(model,true)
	actor.set("artwork",model)
	model.call(&"reset_pose", facing)

func _local(label: String, profile: StringName, xz: Vector2, yaw: float, shift: float) -> Rig:
	var body := preload("res://art/field_cast/village_person.gd").new()
	body.name = label
	body.position = Survey.point(xz,.009)
	var dimensions: Vector2 = BODIES[profile]
	body.use_capsule(dimensions.x,dimensions.y)
	var model := Rig.new()
	model.name = "Model"
	model.profile = profile
	model.idle_offset = shift
	body.add_child(model)
	outdoor.add_child(body)
	model.reset_pose(Vector3(sin(yaw),0,cos(yaw)))
	return model

# ResidentPresenter owns locomotion for the whole cast.
