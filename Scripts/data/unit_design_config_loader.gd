extends RefCounted
class_name UnitDesignConfigLoader

const DEFAULT_CONFIG_PATH := "res://Resources/data/units/mvp_unit_designs.json"

static func load_design_config(path: String = DEFAULT_CONFIG_PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unit design config not found: %s" % path)
		return {"unit_types": [], "upgrades": []}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Unit design config must be a JSON object: %s" % path)
		return {"unit_types": [], "upgrades": []}
	return {
		"unit_types": _dictionary_array(parsed.get("unit_types", [])),
		"upgrades": _dictionary_array(parsed.get("upgrades", [])),
	}

static func get_unit_types(config: Dictionary) -> Array[Dictionary]:
	return _dictionary_array(config.get("unit_types", []))

static func get_upgrades(config: Dictionary) -> Array[Dictionary]:
	return _dictionary_array(config.get("upgrades", []))

static func get_unit_type(config: Dictionary, unit_type_id: StringName) -> Dictionary:
	for unit_type in get_unit_types(config):
		if StringName(str(unit_type.get("id", ""))) == unit_type_id:
			return unit_type
	return {}

static func get_upgrade(config: Dictionary, upgrade_id: StringName) -> Dictionary:
	for upgrade in get_upgrades(config):
		if StringName(str(upgrade.get("id", ""))) == upgrade_id:
			return upgrade
	return {}

static func get_available_upgrades(config: Dictionary, unit_type_id: StringName) -> Array[Dictionary]:
	var unit_type := get_unit_type(config, unit_type_id)
	var result: Array[Dictionary] = []
	if unit_type.is_empty():
		return result
	for upgrade in get_upgrades(config):
		if _upgrade_applies_to_unit_type(upgrade, unit_type):
			result.append(upgrade)
	return result

static func sanitize_upgrade_ids(config: Dictionary, unit_type_id: StringName, upgrade_ids: Array[StringName]) -> Array[StringName]:
	var unit_type := get_unit_type(config, unit_type_id)
	var result: Array[StringName] = []
	if unit_type.is_empty():
		return result
	var point_limit := int(unit_type.get("upgrade_point_limit", 3))
	var point_used := 0
	for upgrade_id in upgrade_ids:
		if result.has(upgrade_id):
			continue
		var upgrade := get_upgrade(config, upgrade_id)
		if upgrade.is_empty():
			continue
		if not _upgrade_applies_to_unit_type(upgrade, unit_type):
			continue
		var point_cost := maxi(1, int(upgrade.get("point_cost", 1)))
		if point_used + point_cost > point_limit:
			continue
		result.append(upgrade_id)
		point_used += point_cost
	return result

static func get_upgrade_point_used(config: Dictionary, upgrade_ids: Array[StringName]) -> int:
	var result := 0
	for upgrade_id in upgrade_ids:
		var upgrade := get_upgrade(config, upgrade_id)
		if not upgrade.is_empty():
			result += maxi(1, int(upgrade.get("point_cost", 1)))
	return result

static func apply_design_to_blueprint(blueprint: UnitBlueprint, unit_type_id: StringName, upgrade_ids: Array[StringName], recipe_defs: Array[RecipeDef], config_path: String = DEFAULT_CONFIG_PATH) -> void:
	if blueprint == null:
		return
	var config := load_design_config(config_path)
	var unit_type := get_unit_type(config, unit_type_id)
	if unit_type.is_empty():
		unit_type = get_unit_type(config, blueprint.unit_type_id)
	if unit_type.is_empty():
		unit_type = get_unit_type(config, blueprint.id)
	if unit_type.is_empty():
		return

	var clean_upgrade_ids := sanitize_upgrade_ids(config, StringName(str(unit_type.get("id", ""))), upgrade_ids)
	blueprint.unit_type_id = StringName(str(unit_type.get("id", "")))
	blueprint.unit_type_display_name = str(unit_type.get("display_name", blueprint.unit_type_id))
	blueprint.upgrade_ids = clean_upgrade_ids
	blueprint.upgrade_display_names = get_upgrade_display_names(config, clean_upgrade_ids)
	blueprint.icon_path = str(unit_type.get("icon_path", blueprint.icon_path))
	blueprint.chassis_id = StringName(str(unit_type.get("chassis_id", blueprint.chassis_id)))
	blueprint.chassis_display_name = str(unit_type.get("chassis_display_name", blueprint.chassis_display_name))
	blueprint.chassis_icon_path = str(unit_type.get("chassis_icon_path", blueprint.chassis_icon_path))
	blueprint.module_ids = _string_name_array(unit_type.get("module_ids", blueprint.module_ids))
	blueprint.module_display_names = _string_array(unit_type.get("module_display_names", blueprint.module_display_names))
	blueprint.module_icon_paths = _string_array(unit_type.get("module_icon_paths", blueprint.module_icon_paths))
	blueprint.default_brain_enabled = unit_type.get("default_brain_enabled", true) == true
	blueprint.stats = make_stats(config, blueprint.unit_type_id, clean_upgrade_ids)

	var recipe_id := StringName(str(unit_type.get("production_recipe_id", blueprint.production_recipe_id)))
	var recipe := _find_recipe(recipe_defs, recipe_id, blueprint.unit_type_id)
	blueprint.production_recipe_id = recipe.id if recipe else recipe_id
	var base_cost := recipe.inputs.duplicate(true) if recipe else _string_name_key_dictionary(unit_type.get("base_cost", {}))
	blueprint.production_cost = calculate_cost(config, base_cost, clean_upgrade_ids)
	var duration := recipe.duration_seconds if recipe else float(unit_type.get("production_time_seconds", blueprint.production_time_seconds))
	blueprint.production_time_seconds = calculate_duration(config, duration, clean_upgrade_ids)

static func make_stats(config: Dictionary, unit_type_id: StringName, upgrade_ids: Array[StringName]) -> UnitStats:
	var unit_type := get_unit_type(config, unit_type_id)
	var stats := _make_stats(unit_type.get("stats", {}))
	for upgrade_id in upgrade_ids:
		var upgrade := get_upgrade(config, upgrade_id)
		if upgrade.is_empty():
			continue
		_apply_stat_add(stats, upgrade.get("stat_add", {}))
		_apply_stat_mult(stats, upgrade.get("stat_mult", {}))
		_apply_stat_set(stats, upgrade.get("stat_set", {}))
	return stats

static func calculate_cost(config: Dictionary, base_cost: Dictionary, upgrade_ids: Array[StringName]) -> Dictionary:
	var result := base_cost.duplicate(true)
	for upgrade_id in upgrade_ids:
		var upgrade := get_upgrade(config, upgrade_id)
		if upgrade.is_empty():
			continue
		_add_cost(result, upgrade.get("cost_add", {}))
		_multiply_cost(result, upgrade.get("cost_mult", {}))
	return result

static func calculate_duration(config: Dictionary, base_duration: float, upgrade_ids: Array[StringName]) -> float:
	var result := base_duration
	for upgrade_id in upgrade_ids:
		var upgrade := get_upgrade(config, upgrade_id)
		if upgrade.is_empty():
			continue
		result += float(upgrade.get("production_time_add", 0.0))
		result *= float(upgrade.get("production_time_mult", 1.0))
	return maxf(0.1, result)

static func get_upgrade_display_names(config: Dictionary, upgrade_ids: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for upgrade_id in upgrade_ids:
		var upgrade := get_upgrade(config, upgrade_id)
		result.append(str(upgrade.get("display_name", upgrade_id)))
	return result

static func describe_stat_delta(config: Dictionary, upgrade_id: StringName) -> String:
	var upgrade := get_upgrade(config, upgrade_id)
	if upgrade.is_empty():
		return ""
	var parts: Array[String] = []
	var stat_add: Variant = upgrade.get("stat_add", {})
	if typeof(stat_add) == TYPE_DICTIONARY:
		for key in stat_add.keys():
			var amount := float(stat_add[key])
			parts.append("%s %s" % [_format_stat_name(str(key)), _format_signed_number(amount)])
	var stat_mult: Variant = upgrade.get("stat_mult", {})
	if typeof(stat_mult) == TYPE_DICTIONARY:
		for key in stat_mult.keys():
			var multiplier := float(stat_mult[key])
			parts.append("%s x%.2f" % [_format_stat_name(str(key)), multiplier])
	var stat_set: Variant = upgrade.get("stat_set", {})
	if typeof(stat_set) == TYPE_DICTIONARY:
		for key in stat_set.keys():
			parts.append("%s → %s" % [_format_stat_name(str(key)), str(stat_set[key])])
	return " / ".join(parts)

static func describe_cost_delta(config: Dictionary, upgrade_id: StringName) -> String:
	var upgrade := get_upgrade(config, upgrade_id)
	if upgrade.is_empty():
		return ""
	var cost_add: Variant = upgrade.get("cost_add", {})
	if typeof(cost_add) != TYPE_DICTIONARY or cost_add.is_empty():
		return ""
	var parts: Array[String] = []
	for key in cost_add.keys():
		parts.append("%s +%s" % [str(key), str(cost_add[key])])
	return " / ".join(parts)

static func format_stats(stats: UnitStats) -> String:
	if stats == null:
		return "-"
	var parts: Array[String] = [
		"HP %d" % stats.max_hp,
		"速度 %.1f" % stats.speed,
	]
	if stats.cargo_capacity > 0:
		parts.append("货舱 %d" % stats.cargo_capacity)
	else:
		parts.append("伤害 %d" % stats.damage)
		parts.append("类型 %s" % String(stats.damage_type))
		parts.append("射程 %.0f" % stats.fire_range)
		parts.append("间隔 %.2fs" % stats.fire_cooldown_seconds)
		if stats.heat_capacity > 0.0:
			parts.append("热量 %.0f" % stats.heat_capacity)
	parts.append("逻辑 %d" % stats.logic_capacity)
	return " | ".join(parts)

static func format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "-"
	var parts: Array[String] = []
	for key in cost.keys():
		parts.append("%s %s" % [str(key), str(cost[key])])
	return " / ".join(parts)

static func _upgrade_applies_to_unit_type(upgrade: Dictionary, unit_type: Dictionary) -> bool:
	var unit_type_id := StringName(str(unit_type.get("id", "")))
	var applies_to_unit_types := _string_name_array(upgrade.get("applies_to_unit_types", []))
	if not applies_to_unit_types.is_empty() and applies_to_unit_types.has(unit_type_id):
		return true
	var unit_tags := _string_array(unit_type.get("tags", []))
	var applies_to_tags := _string_array(upgrade.get("applies_to_tags", []))
	if applies_to_unit_types.is_empty() and applies_to_tags.is_empty():
		return true
	for tag in applies_to_tags:
		if unit_tags.has(tag):
			return true
	return false

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

static func _apply_stat_add(stats: UnitStats, values: Variant) -> void:
	if typeof(values) != TYPE_DICTIONARY:
		return
	for key in values.keys():
		match str(key):
			"max_hp":
				stats.max_hp += int(values[key])
			"speed":
				stats.speed += float(values[key])
			"lifespan_seconds":
				stats.lifespan_seconds += float(values[key])
			"target_lock_seconds":
				stats.target_lock_seconds += float(values[key])
			"fire_range":
				stats.fire_range += float(values[key])
			"damage":
				stats.damage += int(values[key])
			"fire_cooldown_seconds":
				stats.fire_cooldown_seconds += float(values[key])
			"heat_capacity":
				stats.heat_capacity += float(values[key])
			"heat_per_shot":
				stats.heat_per_shot += float(values[key])
			"heat_cooling_per_second":
				stats.heat_cooling_per_second += float(values[key])
			"overheat_threshold":
				stats.overheat_threshold += float(values[key])
			"overheated_resume_threshold":
				stats.overheated_resume_threshold += float(values[key])
			"cargo_capacity":
				stats.cargo_capacity += int(values[key])
			"logic_capacity":
				stats.logic_capacity += int(values[key])

static func _apply_stat_mult(stats: UnitStats, values: Variant) -> void:
	if typeof(values) != TYPE_DICTIONARY:
		return
	for key in values.keys():
		var multiplier := float(values[key])
		match str(key):
			"max_hp":
				stats.max_hp = roundi(float(stats.max_hp) * multiplier)
			"speed":
				stats.speed *= multiplier
			"lifespan_seconds":
				stats.lifespan_seconds *= multiplier
			"target_lock_seconds":
				stats.target_lock_seconds *= multiplier
			"fire_range":
				stats.fire_range *= multiplier
			"damage":
				stats.damage = roundi(float(stats.damage) * multiplier)
			"fire_cooldown_seconds":
				stats.fire_cooldown_seconds *= multiplier
			"heat_capacity":
				stats.heat_capacity *= multiplier
			"heat_per_shot":
				stats.heat_per_shot *= multiplier
			"heat_cooling_per_second":
				stats.heat_cooling_per_second *= multiplier
			"overheat_threshold":
				stats.overheat_threshold *= multiplier
			"overheated_resume_threshold":
				stats.overheated_resume_threshold *= multiplier
			"cargo_capacity":
				stats.cargo_capacity = roundi(float(stats.cargo_capacity) * multiplier)
			"logic_capacity":
				stats.logic_capacity = roundi(float(stats.logic_capacity) * multiplier)

static func _apply_stat_set(stats: UnitStats, values: Variant) -> void:
	if typeof(values) != TYPE_DICTIONARY:
		return
	for key in values.keys():
		match str(key):
			"damage_type":
				stats.damage_type = StringName(str(values[key]))
			"armor_type":
				stats.armor_type = StringName(str(values[key]))

static func _add_cost(target: Dictionary, values: Variant) -> void:
	if typeof(values) != TYPE_DICTIONARY:
		return
	for key in values.keys():
		var resource_id := StringName(str(key))
		target[resource_id] = int(target.get(resource_id, 0)) + int(values[key])

static func _multiply_cost(target: Dictionary, values: Variant) -> void:
	if typeof(values) != TYPE_DICTIONARY:
		return
	for key in values.keys():
		var resource_id := StringName(str(key))
		if not target.has(resource_id):
			continue
		target[resource_id] = ceili(float(target[resource_id]) * float(values[key]))

static func _find_recipe(recipe_defs: Array[RecipeDef], recipe_id: StringName, target_id: StringName) -> RecipeDef:
	for recipe in recipe_defs:
		if not String(recipe_id).is_empty() and recipe.id == recipe_id:
			return recipe
	for recipe in recipe_defs:
		if recipe.recipe_type == &"unit" and recipe.target_id == target_id:
			return recipe
	return null

static func _dictionary_array(values: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		if typeof(value) == TYPE_DICTIONARY:
			result.append((value as Dictionary).duplicate(true))
	return result

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

static func _string_name_key_dictionary(data: Variant) -> Dictionary:
	var result := {}
	if typeof(data) != TYPE_DICTIONARY:
		return result
	for key in data.keys():
		result[StringName(str(key))] = data[key]
	return result

static func _format_stat_name(stat_id: String) -> String:
	match stat_id:
		"max_hp":
			return "HP"
		"speed":
			return "速度"
		"lifespan_seconds":
			return "寿命"
		"target_lock_seconds":
			return "锁定"
		"fire_range":
			return "射程"
		"damage":
			return "伤害"
		"damage_type":
			return "伤害类型"
		"armor_type":
			return "装甲类型"
		"fire_cooldown_seconds":
			return "间隔"
		"heat_capacity":
			return "热量"
		"heat_per_shot":
			return "单发热量"
		"heat_cooling_per_second":
			return "散热"
		"overheat_threshold":
			return "过热阈值"
		"overheated_resume_threshold":
			return "恢复阈值"
		"cargo_capacity":
			return "货舱"
		"logic_capacity":
			return "逻辑"
	return stat_id

static func _format_signed_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		if value >= 0.0:
			return "+%d" % int(value)
		return "%d" % int(value)
	if value >= 0.0:
		return "+%.1f" % value
	return "%.1f" % value
