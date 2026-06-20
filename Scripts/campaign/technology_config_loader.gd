extends RefCounted
class_name TechnologyConfigLoader

const TechnologyDefScript := preload("res://Scripts/campaign/technology_def.gd")

static func load_technology_defs(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Technology config not found: %s" % path)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Technology config must be a JSON object: %s" % path)
		return []
	var result: Array = []
	for item in parsed.get("technologies", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		result.append(_make_technology(item))
	return result

static func _make_technology(data: Dictionary) -> Resource:
	var tech = TechnologyDefScript.new()
	tech.id = StringName(str(data.get("id", "")))
	tech.display_name = str(data.get("display_name", tech.id))
	tech.description = str(data.get("description", ""))
	tech.stage = int(data.get("stage", 0))
	tech.duration_seconds = maxf(0.1, float(data.get("duration_seconds", 1.0)))
	tech.icon_path = str(data.get("icon_path", ""))
	tech.tree_column = int(data.get("tree_column", -1))
	tech.tree_row = int(data.get("tree_row", -1))
	tech.key_item_requirements = _string_name_array(data.get("key_item_requirements", []))
	tech.prerequisites = _string_name_array(data.get("prerequisites", []))
	tech.costs = _string_name_dictionary(data.get("costs", {}))
	tech.unlocks = data.get("unlocks", {}).duplicate(true)
	return tech

static func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		result.append(StringName(str(item)))
	return result

static func _string_name_dictionary(value: Variant) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key in value.keys():
		result[StringName(str(key))] = int(value[key])
	return result
