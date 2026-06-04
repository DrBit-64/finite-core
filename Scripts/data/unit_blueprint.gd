extends Resource
class_name UnitBlueprint

@export var id: StringName
@export var display_name: String = ""
@export var version: int = 1
@export var icon_path: String = ""
@export var chassis_id: StringName = &"light_chassis"
@export var chassis_display_name: String = "轻型底盘"
@export var chassis_icon_path: String = ""
@export var module_ids: Array[StringName] = [&"rifle_module"]
@export var module_display_names: Array[String] = ["步枪模块"]
@export var module_icon_paths: Array[String] = []
@export var stats: UnitStats
@export var production_recipe_id: StringName
@export var production_cost: Dictionary = {}
@export var production_time_seconds: float = 12.0
@export_file("*.json") var rules_path: String = ""
@export var tactical_templates: Array = []
@export var embedded_rules: Array = []
@export var state_flag_defaults: Dictionary = {}
@export var default_brain_enabled: bool = true
@export var snapshot_id: StringName = &""
@export var source_blueprint_id: StringName = &""
@export var is_snapshot: bool = false

func get_blueprint_key() -> String:
	return "%s_v%d" % [String(id), version]

func get_snapshot_key() -> String:
	if not String(snapshot_id).is_empty():
		return String(snapshot_id)
	return get_blueprint_key()

func make_snapshot(next_snapshot_id: StringName = &"") -> UnitBlueprint:
	var snapshot := UnitBlueprint.new()
	snapshot.id = id
	snapshot.display_name = display_name
	snapshot.version = version
	snapshot.icon_path = icon_path
	snapshot.chassis_id = chassis_id
	snapshot.chassis_display_name = chassis_display_name
	snapshot.chassis_icon_path = chassis_icon_path
	snapshot.module_ids = module_ids.duplicate()
	snapshot.module_display_names = module_display_names.duplicate()
	snapshot.module_icon_paths = module_icon_paths.duplicate()
	snapshot.stats = stats.duplicate(true) if stats else UnitStats.new()
	snapshot.production_recipe_id = production_recipe_id
	snapshot.production_cost = production_cost.duplicate(true)
	snapshot.production_time_seconds = production_time_seconds
	snapshot.rules_path = rules_path
	snapshot.tactical_templates = tactical_templates.duplicate(true)
	snapshot.embedded_rules = embedded_rules.duplicate(true)
	snapshot.state_flag_defaults = state_flag_defaults.duplicate(true)
	snapshot.default_brain_enabled = default_brain_enabled
	snapshot.snapshot_id = next_snapshot_id if not String(next_snapshot_id).is_empty() else StringName("%s_snapshot_v%d" % [String(id), version])
	snapshot.source_blueprint_id = id
	snapshot.is_snapshot = true
	return snapshot
