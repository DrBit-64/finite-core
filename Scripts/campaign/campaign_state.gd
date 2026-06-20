extends RefCounted
class_name CampaignState

signal unlocks_changed
signal stage_advanced(stage: int)
signal key_item_added(key_item_id: StringName)
signal technology_unlocked(technology_id: StringName)
signal recipe_upgrade_changed(resource_id: StringName, level: int)

var current_stage: int = 0
var defeated_nests: Array[StringName] = []
var key_items: Array[StringName] = []
var unlocked_technologies: Array[StringName] = []
var unlocked_resources: Array[StringName] = []
var unlocked_buildings: Array[StringName] = []
var unlocked_unit_types: Array[StringName] = []
var unlocked_chassis: Array[StringName] = []
var unlocked_weapons: Array[StringName] = []
var unlocked_modules: Array[StringName] = []
var unlocked_templates: Array[StringName] = []
var unlocked_conditions: Array[StringName] = []
var unlocked_actions: Array[StringName] = []
var unlocked_upgrades: Array[StringName] = []
var recipe_upgrade_levels: Dictionary = {}

func seed_defaults() -> void:
	unlocked_buildings = [&"main_base", &"miner", &"processor", &"robot_forge", &"research_terminal"]
	unlocked_unit_types = [&"basic_rifle_robot", &"battlefield_hauler"]
	unlocked_chassis = [&"light_chassis"]
	unlocked_weapons = [&"rifle_module"]
	unlocked_modules = [&"rifle_module"]
	unlocked_templates = [&"default_attack", &"move_to_rally", &"rally_then_attack"]
	unlocked_conditions = [&"has_rally_point", &"nearby_friend_count"]
	unlocked_actions = [&"move_to_rally", &"wait", &"set_state_flag", &"default_combat"]
	unlocked_resources = [&"iron_ore", &"copper_ore", &"iron_plate", &"copper_wire", &"construction_mass"]

func mark_nest_defeated(nest_id: StringName) -> void:
	if not defeated_nests.has(nest_id):
		defeated_nests.append(nest_id)

func add_key_item(key_item_id: StringName) -> void:
	if String(key_item_id).is_empty() or key_items.has(key_item_id):
		return
	key_items.append(key_item_id)
	key_item_added.emit(key_item_id)
	unlocks_changed.emit()

func can_research(technology: Variant) -> bool:
	if technology == null or unlocked_technologies.has(technology.id):
		return false
	return technology.can_meet_key_items(key_items) and technology.can_meet_prerequisites(unlocked_technologies)

func unlock_technology(technology: Variant) -> void:
	if technology == null or unlocked_technologies.has(technology.id):
		return
	unlocked_technologies.append(technology.id)
	_apply_unlocks(technology.unlocks)
	if technology.stage > current_stage:
		current_stage = technology.stage
		stage_advanced.emit(current_stage)
	technology_unlocked.emit(technology.id)
	unlocks_changed.emit()

func debug_unlock_all_technologies(technologies: Array) -> int:
	var unlocked_count := 0
	for technology in technologies:
		if technology == null or unlocked_technologies.has(technology.id):
			continue
		unlocked_technologies.append(technology.id)
		_apply_unlocks(technology.unlocks)
		current_stage = maxi(current_stage, int(technology.stage))
		unlocked_count += 1
	if unlocked_count > 0:
		unlocks_changed.emit()
	return unlocked_count

func is_building_unlocked(building_id: StringName) -> bool:
	return unlocked_buildings.has(building_id)

func is_template_unlocked(template_id: StringName) -> bool:
	return unlocked_templates.has(template_id)

func to_save_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"current_stage": current_stage,
		"defeated_nests": _string_array(defeated_nests),
		"key_items": _string_array(key_items),
		"unlocked_technologies": _string_array(unlocked_technologies),
		"unlocked_resources": _string_array(unlocked_resources),
		"unlocked_buildings": _string_array(unlocked_buildings),
		"unlocked_unit_types": _string_array(unlocked_unit_types),
		"unlocked_chassis": _string_array(unlocked_chassis),
		"unlocked_weapons": _string_array(unlocked_weapons),
		"unlocked_modules": _string_array(unlocked_modules),
		"unlocked_templates": _string_array(unlocked_templates),
		"unlocked_conditions": _string_array(unlocked_conditions),
		"unlocked_actions": _string_array(unlocked_actions),
		"unlocked_upgrades": _string_array(unlocked_upgrades),
		"recipe_upgrade_levels": _string_key_int_dictionary(recipe_upgrade_levels),
	}

func get_recipe_upgrade_level(resource_id: StringName) -> int:
	return clampi(int(recipe_upgrade_levels.get(resource_id, recipe_upgrade_levels.get(String(resource_id), 0))), 0, 5)

func set_recipe_upgrade_level(resource_id: StringName, level: int) -> void:
	var next_level := clampi(level, 0, 5)
	if get_recipe_upgrade_level(resource_id) == next_level:
		return
	recipe_upgrade_levels[resource_id] = next_level
	recipe_upgrade_changed.emit(resource_id, next_level)
	unlocks_changed.emit()

func _apply_unlocks(unlocks: Dictionary) -> void:
	_append_unique(unlocked_resources, unlocks.get("resources", []))
	_append_unique(unlocked_buildings, unlocks.get("buildings", []))
	_append_unique(unlocked_unit_types, unlocks.get("unit_types", []))
	_append_unique(unlocked_chassis, unlocks.get("chassis", []))
	_append_unique(unlocked_weapons, unlocks.get("weapons", []))
	_append_unique(unlocked_modules, unlocks.get("modules", []))
	_append_unique(unlocked_templates, unlocks.get("templates", []))
	_append_unique(unlocked_conditions, unlocks.get("conditions", []))
	_append_unique(unlocked_actions, unlocks.get("actions", []))
	_append_unique(unlocked_upgrades, unlocks.get("upgrades", []))

func _append_unique(target: Array[StringName], values: Variant) -> void:
	if typeof(values) != TYPE_ARRAY:
		return
	for value in values:
		var id := StringName(str(value))
		if not target.has(id):
			target.append(id)

func _string_array(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result

func _string_key_int_dictionary(values: Dictionary) -> Dictionary:
	var result := {}
	for key in values.keys():
		result[String(key)] = int(values[key])
	return result
