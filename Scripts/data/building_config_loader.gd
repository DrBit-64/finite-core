extends RefCounted
class_name BuildingConfigLoader

static func load_building_defs(path: String, recipe_defs: Array[RecipeDef], fallback: Array[BuildingDef] = []) -> Array[BuildingDef]:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Building config not found: %s. Using fallback." % path)
		return fallback

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Building config must be a JSON object: %s. Using fallback." % path)
		return fallback

	var result: Array[BuildingDef] = []
	for item in parsed.get("buildings", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		result.append(_make_building(item, recipe_defs))
	return result if not result.is_empty() else fallback

static func _make_building(data: Dictionary, recipe_defs: Array[RecipeDef]) -> BuildingDef:
	var building_id := StringName(str(data.get("id", "")))
	var def := BuildingDef.new()
	def.id = building_id
	def.display_name = str(data.get("display_name", building_id))
	def.icon_path = str(data.get("icon_path", ""))
	def.grid_size = _vector2i(data.get("grid_size", [1, 1]), Vector2i.ONE)
	def.max_hp = maxi(1, int(data.get("max_hp", def.max_hp)))
	def.build_bar_visible = bool(data.get("build_bar_visible", def.build_bar_visible))
	def.unlock_stage = maxi(0, int(data.get("unlock_stage", def.unlock_stage)))
	def.requires_campaign_unlock = bool(data.get("requires_campaign_unlock", def.requires_campaign_unlock))

	var recipe := _find_recipe_by_target(recipe_defs, building_id)
	if recipe:
		def.build_recipe_id = recipe.id
		def.build_cost = recipe.inputs.duplicate(true)
	return def

static func _find_recipe_by_target(recipe_defs: Array[RecipeDef], target_id: StringName) -> RecipeDef:
	for recipe in recipe_defs:
		if recipe.recipe_type == &"building" and recipe.target_id == target_id:
			return recipe
	return null

static func _vector2i(value: Variant, fallback: Vector2i) -> Vector2i:
	if typeof(value) != TYPE_ARRAY or value.size() < 2:
		return fallback
	return Vector2i(int(value[0]), int(value[1]))
