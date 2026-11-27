extends Resource

@export var definition_id: String
@export var title: String
@export_multiline var description: String
@export var rarity: int
@export var icon: Texture2D
@export_range(0.0, 100.0, 0.01) var unit_weight_kg := 0.1 # S10 prototype
@export var equipment_slot := ""
@export var combat_weapon: StringName
