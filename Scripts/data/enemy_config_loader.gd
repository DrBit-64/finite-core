extends RefCounted
class_name EnemyConfigLoader

static func load_enemy_config(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Enemy config not found: %s" % path)
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Enemy config must be a JSON object: %s" % path)
		return {}
	return parsed

static func get_type(config: Dictionary, collection: String, type_id: StringName) -> Dictionary:
	for item in config.get(collection, []):
		if typeof(item) == TYPE_DICTIONARY and StringName(str(item.get("id", ""))) == type_id:
			return item.duplicate(true)
	return {}
