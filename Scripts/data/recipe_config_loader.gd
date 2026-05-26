extends RefCounted
class_name RecipeConfigLoader

static func load_recipe_defs(path: String) -> Array[RecipeDef]:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Recipe config not found: %s" % path)
		return []

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Recipe config must be a JSON object: %s" % path)
		return []

	var recipe_items: Array = parsed.get("recipes", [])
	var recipes: Array[RecipeDef] = []
	for item in recipe_items:
		if typeof(item) != TYPE_DICTIONARY:
			push_warning("Recipe entry skipped because it is not an object in %s" % path)
			continue
		recipes.append(_make_recipe(item, path))
	return recipes

static func _make_recipe(data: Dictionary, source_path: String) -> RecipeDef:
	var recipe := RecipeDef.new()
	recipe.id = StringName(str(data.get("id", "")))
	recipe.display_name = str(data.get("display_name", recipe.id))
	recipe.recipe_type = StringName(str(data.get("type", "resource")))
	recipe.target_id = StringName(str(data.get("target_id", "")))
	recipe.duration_seconds = float(data.get("duration_seconds", 1.0))
	recipe.inputs = _string_name_dictionary(data.get("inputs", {}))
	recipe.outputs = _string_name_dictionary(data.get("outputs", {}))
	recipe.source_path = source_path
	return recipe

static func _string_name_dictionary(value: Variant) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result

	for key in value.keys():
		result[StringName(str(key))] = int(value[key])
	return result
