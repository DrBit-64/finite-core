extends RefCounted
class_name RuntimeConfigLoader

static func load_runtime_config(path: String) -> Dictionary:
	var fallback := {
		"debug_enabled": false,
		"use_debug_starting_inventory": false,
		"spawn_debug_wandering_enemy": false,
		"unlock_all_technologies": false,
		"balance_starting_inventory_path": "res://Resources/data/balance/mvp_starting_inventory.json",
		"debug_starting_inventory_path": "res://Resources/data/debug/mvp_debug_starting_inventory.json",
	}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Runtime config not found: %s. Using fallback." % path)
		return fallback
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Runtime config must be a JSON object: %s. Using fallback." % path)
		return fallback
	for key in fallback.keys():
		if not parsed.has(key):
			parsed[key] = fallback[key]
	return parsed

static func get_starting_inventory_path(config: Dictionary) -> String:
	if is_debug_feature_enabled(config, "use_debug_starting_inventory"):
		return str(config.get("debug_starting_inventory_path", ""))
	return str(config.get("balance_starting_inventory_path", ""))

static func is_debug_enabled(config: Dictionary) -> bool:
	return bool(config.get("debug_enabled", false))

static func is_debug_feature_enabled(config: Dictionary, feature_key: String) -> bool:
	return is_debug_enabled(config) and bool(config.get(feature_key, false))
