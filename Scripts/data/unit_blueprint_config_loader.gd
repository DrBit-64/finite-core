extends RefCounted
class_name UnitBlueprintConfigLoader

const TacticalTemplateCompilerScript := preload("res://Scripts/ai/tactical_template_compiler.gd")
const UnitDesignConfigLoaderScript := preload("res://Scripts/data/unit_design_config_loader.gd")

static func load_unit_blueprint(path: String, unit_id: StringName, recipe_defs: Array[RecipeDef], fallback: UnitBlueprint = null) -> UnitBlueprint:
	var blueprints := load_unit_blueprints(path, recipe_defs)
	for blueprint in blueprints:
		if blueprint.id == unit_id:
			return blueprint
	if fallback:
		push_warning("Unit blueprint %s not found in %s. Using fallback." % [String(unit_id), path])
		return fallback
	push_error("Unit blueprint %s not found in %s." % [String(unit_id), path])
	return null

static func load_unit_blueprints(path: String, recipe_defs: Array[RecipeDef]) -> Array[UnitBlueprint]:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unit blueprint config not found: %s" % path)
		return []

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Unit blueprint config must be a JSON object: %s" % path)
		return []

	var blueprint_items: Array = parsed.get("unit_blueprints", [])
	var blueprints: Array[UnitBlueprint] = []
	for item in blueprint_items:
		if typeof(item) != TYPE_DICTIONARY:
			push_warning("Unit blueprint entry skipped because it is not an object in %s" % path)
			continue
		blueprints.append(_make_blueprint(item, recipe_defs))
	return blueprints

static func _make_blueprint(data: Dictionary, recipe_defs: Array[RecipeDef]) -> UnitBlueprint:
	var blueprint := UnitBlueprint.new()
	blueprint.id = StringName(str(data.get("id", "")))
	blueprint.display_name = str(data.get("display_name", blueprint.id))
	blueprint.version = int(data.get("version", 1))
	blueprint.icon_path = str(data.get("icon_path", ""))
	blueprint.unit_type_id = StringName(str(data.get("unit_type_id", data.get("id", blueprint.unit_type_id))))
	blueprint.unit_type_display_name = str(data.get("unit_type_display_name", blueprint.unit_type_display_name))
	blueprint.upgrade_ids = _string_name_array(data.get("upgrade_ids", []))
	blueprint.upgrade_display_names = _string_array(data.get("upgrade_display_names", []))
	blueprint.chassis_id = StringName(str(data.get("chassis_id", blueprint.chassis_id)))
	blueprint.chassis_display_name = str(data.get("chassis_display_name", blueprint.chassis_display_name))
	blueprint.chassis_icon_path = str(data.get("chassis_icon_path", ""))
	blueprint.module_ids = _string_name_array(data.get("module_ids", blueprint.module_ids))
	blueprint.module_display_names = _string_array(data.get("module_display_names", blueprint.module_display_names))
	blueprint.module_icon_paths = _string_array(data.get("module_icon_paths", []))
	blueprint.default_brain_enabled = bool(data.get("default_brain_enabled", true))
	blueprint.tactical_templates = TacticalTemplateCompilerScript.normalize_templates(data.get("tactical_templates", []))
	blueprint.embedded_rules = data.get("embedded_rules", []).duplicate(true)
	blueprint.state_flag_defaults = data.get("state_flag_defaults", {}).duplicate(true)
	if not blueprint.tactical_templates.is_empty():
		var compiled: Dictionary = TacticalTemplateCompilerScript.compile_templates(blueprint.tactical_templates)
		blueprint.embedded_rules = compiled.get("rules", []).duplicate(true)
		blueprint.state_flag_defaults = compiled.get("state_flag_defaults", {}).duplicate(true)
	blueprint.stats = _make_stats(data.get("stats", {}))

	var recipe_id := StringName(str(data.get("production_recipe_id", "")))
	var recipe := _find_recipe(recipe_defs, recipe_id, blueprint.id)
	if recipe:
		blueprint.production_recipe_id = recipe.id
		blueprint.production_cost = recipe.inputs.duplicate(true)
		blueprint.production_time_seconds = recipe.duration_seconds
	UnitDesignConfigLoaderScript.apply_design_to_blueprint(blueprint, blueprint.unit_type_id, blueprint.upgrade_ids, recipe_defs)
	return blueprint

static func _make_stats(data: Variant) -> UnitStats:
	var stats := UnitStats.new()
	if typeof(data) != TYPE_DICTIONARY:
		return stats
	stats.max_hp = int(data.get("max_hp", stats.max_hp))
	stats.speed = float(data.get("speed", stats.speed))
	stats.lifespan_seconds = float(data.get("lifespan_seconds", stats.lifespan_seconds))
	stats.target_lock_seconds = float(data.get("target_lock_seconds", stats.target_lock_seconds))
	stats.fire_range = float(data.get("fire_range", stats.fire_range))
	stats.damage = int(data.get("damage", stats.damage))
	stats.fire_cooldown_seconds = float(data.get("fire_cooldown_seconds", stats.fire_cooldown_seconds))
	stats.damage_type = StringName(str(data.get("damage_type", stats.damage_type)))
	stats.armor_type = StringName(str(data.get("armor_type", stats.armor_type)))
	stats.heat_capacity = float(data.get("heat_capacity", stats.heat_capacity))
	stats.heat_per_shot = float(data.get("heat_per_shot", stats.heat_per_shot))
	stats.heat_cooling_per_second = float(data.get("heat_cooling_per_second", stats.heat_cooling_per_second))
	stats.overheat_threshold = float(data.get("overheat_threshold", stats.overheat_threshold))
	stats.overheated_resume_threshold = float(data.get("overheated_resume_threshold", stats.overheated_resume_threshold))
	stats.cargo_capacity = int(data.get("cargo_capacity", stats.cargo_capacity))
	stats.logic_capacity = int(data.get("logic_capacity", stats.logic_capacity))
	return stats

static func _find_recipe(recipe_defs: Array[RecipeDef], recipe_id: StringName, target_id: StringName) -> RecipeDef:
	for recipe in recipe_defs:
		if not String(recipe_id).is_empty() and recipe.id == recipe_id:
			return recipe
	for recipe in recipe_defs:
		if recipe.recipe_type == &"unit" and recipe.target_id == target_id:
			return recipe
	return null

static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		result.append(str(item))
	return result

static func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		result.append(StringName(str(item)))
	return result
