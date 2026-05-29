extends RefCounted
class_name UnitBlueprintConfigLoader

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
	blueprint.chassis_id = StringName(str(data.get("chassis_id", blueprint.chassis_id)))
	blueprint.chassis_display_name = str(data.get("chassis_display_name", blueprint.chassis_display_name))
	blueprint.chassis_icon_path = str(data.get("chassis_icon_path", ""))
	blueprint.module_ids = _string_name_array(data.get("module_ids", blueprint.module_ids))
	blueprint.module_display_names = _string_array(data.get("module_display_names", blueprint.module_display_names))
	blueprint.module_icon_paths = _string_array(data.get("module_icon_paths", []))
	blueprint.default_brain_enabled = bool(data.get("default_brain_enabled", true))
	blueprint.embedded_rules = data.get("embedded_rules", []).duplicate(true)
	blueprint.state_flag_defaults = data.get("state_flag_defaults", {}).duplicate(true)
	blueprint.stats = _make_stats(data.get("stats", {}))

	var recipe_id := StringName(str(data.get("production_recipe_id", "")))
	var recipe := _find_recipe(recipe_defs, recipe_id, blueprint.id)
	if recipe:
		blueprint.production_recipe_id = recipe.id
		blueprint.production_cost = recipe.inputs.duplicate(true)
		blueprint.production_time_seconds = recipe.duration_seconds
	return blueprint

static func _make_stats(data: Variant) -> UnitStats:
	var stats := UnitStats.new()
	if typeof(data) != TYPE_DICTIONARY:
		return stats
	stats.max_hp = int(data.get("max_hp", stats.max_hp))
	stats.speed = float(data.get("speed", stats.speed))
	stats.lifespan_seconds = float(data.get("lifespan_seconds", stats.lifespan_seconds))
	stats.radar_radius = float(data.get("radar_radius", stats.radar_radius))
	stats.fire_range = float(data.get("fire_range", stats.fire_range))
	stats.damage = int(data.get("damage", stats.damage))
	stats.fire_cooldown_seconds = float(data.get("fire_cooldown_seconds", stats.fire_cooldown_seconds))
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
