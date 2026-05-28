extends RefCounted
class_name StartingInventoryConfigLoader

static func load_starting_inventory(path: String, fallback: Dictionary = {}) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Starting inventory config not found: %s" % path)
		return fallback.duplicate(true)

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Starting inventory config must be a JSON object: %s" % path)
		return fallback.duplicate(true)

	var inventory_value: Variant = parsed.get("starting_inventory", {})
	if typeof(inventory_value) != TYPE_DICTIONARY:
		push_error("Starting inventory config missing starting_inventory object: %s" % path)
		return fallback.duplicate(true)

	return _string_name_dictionary(inventory_value)

static func _string_name_dictionary(value: Dictionary) -> Dictionary:
	var result := {}
	for key in value.keys():
		result[StringName(str(key))] = int(value[key])
	return result
