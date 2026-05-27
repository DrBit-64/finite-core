extends RefCounted
class_name MapConfigLoader

static func load_map_config(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Map config not found: %s" % path)
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Map config must be a JSON object: %s" % path)
		return {}

	return parsed

static func get_vector2i(data: Dictionary, key: String, fallback: Vector2i = Vector2i.ZERO) -> Vector2i:
	var value: Variant = data.get(key, [])
	if typeof(value) != TYPE_ARRAY or value.size() < 2:
		return fallback
	return Vector2i(int(value[0]), int(value[1]))
