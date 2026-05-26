extends Resource
class_name UnitBlueprint

@export var id: StringName
@export var display_name: String = ""
@export var version: int = 1
@export var icon_path: String = ""
@export var chassis_icon_path: String = ""
@export var module_icon_paths: Array[String] = []
@export var stats: UnitStats
@export var production_recipe_id: StringName
@export var production_cost: Dictionary = {}
@export var production_time_seconds: float = 12.0
@export_file("*.json") var rules_path: String = ""
@export var default_brain_enabled: bool = true

func get_blueprint_key() -> String:
	return "%s_v%d" % [String(id), version]
