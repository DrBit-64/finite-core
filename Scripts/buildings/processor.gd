extends "res://Scripts/buildings/base_building.gd"
class_name ProcessorBuilding

signal processor_state_changed

var selected_recipe: RecipeDef = null
var available_recipes: Array[RecipeDef] = []
var target_inventory: Variant = null
var input_cache: Dictionary = {}
var output_cache: Dictionary = {}
var status_text: String = "未选择配方"
var progress_seconds: float = 0.0

func setup_processor(recipes: Array[RecipeDef], inventory: Variant) -> void:
	available_recipes = recipes.duplicate()
	target_inventory = inventory
	_update_status()

func set_recipe(recipe_id: StringName) -> void:
	for recipe in available_recipes:
		if recipe.id == recipe_id:
			selected_recipe = recipe
			progress_seconds = 0.0
			_update_status()
			processor_state_changed.emit()
			return

func _process(delta: float) -> void:
	if selected_recipe == null:
		_set_status("未选择配方")
		return
	if target_inventory == null:
		_set_status("等待主基地")
		return
	if progress_seconds > 0.0:
		_advance_production(delta)
		return

	var cache_changed := _pull_missing_inputs_from_inventory()
	if not _cache_can_afford(input_cache, selected_recipe.inputs):
		progress_seconds = 0.0
		_set_status("等待原料")
		if cache_changed:
			processor_state_changed.emit()
		return

	if progress_seconds <= 0.0:
		_spend_from_cache(input_cache, selected_recipe.inputs)
		processor_state_changed.emit()

	_advance_production(delta)

func _advance_production(delta: float) -> void:
	progress_seconds += delta
	_set_status("运行中")
	if progress_seconds < selected_recipe.duration_seconds:
		return

	progress_seconds = 0.0
	_add_to_cache(output_cache, selected_recipe.outputs)
	for resource_id in selected_recipe.outputs.keys():
		target_inventory.add_resource(resource_id, int(selected_recipe.outputs[resource_id]), "%s 产出" % get_display_name())
	processor_state_changed.emit()

func get_progress_ratio() -> float:
	if selected_recipe == null or selected_recipe.duration_seconds <= 0.0:
		return 0.0
	return clampf(progress_seconds / selected_recipe.duration_seconds, 0.0, 1.0)

func get_inspector_lines() -> Array[String]:
	var lines := super.get_inspector_lines()
	lines.append("当前配方：%s" % (selected_recipe.display_name if selected_recipe else "未选择"))
	lines.append("状态：%s" % status_text)
	lines.append("进度：%d%%" % int(get_progress_ratio() * 100.0))
	return lines

func _add_to_cache(cache: Dictionary, resources: Dictionary) -> void:
	for resource_id in resources.keys():
		cache[resource_id] = int(cache.get(resource_id, 0)) + int(resources[resource_id])

func _pull_missing_inputs_from_inventory() -> bool:
	var changed := false
	for resource_id in selected_recipe.inputs.keys():
		var required := int(selected_recipe.inputs[resource_id])
		var cached := int(input_cache.get(resource_id, 0))
		var missing := required - cached
		if missing <= 0:
			continue
		var available := int(target_inventory.get_amount(resource_id))
		var amount_to_pull = mini(missing, available)
		if amount_to_pull <= 0:
			continue
		var pulled := {resource_id: amount_to_pull}
		if target_inventory.spend_resources(pulled, "%s 缓存原料" % get_display_name()):
			_add_to_cache(input_cache, pulled)
			changed = true
	return changed

func _cache_can_afford(cache: Dictionary, cost: Dictionary) -> bool:
	for resource_id in cost.keys():
		if int(cache.get(resource_id, 0)) < int(cost[resource_id]):
			return false
	return true

func _spend_from_cache(cache: Dictionary, cost: Dictionary) -> void:
	for resource_id in cost.keys():
		var next_amount := int(cache.get(resource_id, 0)) - int(cost[resource_id])
		if next_amount > 0:
			cache[resource_id] = next_amount
		else:
			cache.erase(resource_id)

func _set_status(next_status: String) -> void:
	if status_text == next_status:
		return
	status_text = next_status
	processor_state_changed.emit()

func _update_status() -> void:
	if selected_recipe == null:
		_set_status("未选择配方")
	elif target_inventory == null:
		_set_status("等待主基地")
	else:
		_set_status("等待原料")
