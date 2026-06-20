extends Resource
class_name TechnologyDef

@export var id: StringName
@export var display_name: String = ""
@export var description: String = ""
@export var stage: int = 0
@export var duration_seconds: float = 1.0
@export var icon_path: String = ""
@export var tree_column: int = -1
@export var tree_row: int = -1
@export var key_item_requirements: Array[StringName] = []
@export var prerequisites: Array[StringName] = []
@export var costs: Dictionary = {}
@export var unlocks: Dictionary = {}

func can_meet_key_items(key_items: Array[StringName]) -> bool:
	for item in key_item_requirements:
		if not key_items.has(item):
			return false
	return true

func can_meet_prerequisites(unlocked_technologies: Array[StringName]) -> bool:
	for tech_id in prerequisites:
		if not unlocked_technologies.has(tech_id):
			return false
	return true
