extends "res://Scripts/buildings/base_building.gd"
class_name ProcessorBuilding

signal processor_state_changed

const BuildingStatusMarkerScript := preload("res://Scripts/map/building_status_marker.gd")
const STATE_NO_RECIPE := &"no_recipe"
const STATE_WAITING_BASE := &"waiting_base"
const STATE_WAITING_INPUTS := &"waiting_inputs"
const STATE_RUNNING := &"running"
const STATE_PAUSED := &"paused"

var selected_recipe: RecipeDef = null
var available_recipes: Array[RecipeDef] = []
var target_inventory: Variant = null
var input_cache: Dictionary = {}
var output_cache: Dictionary = {}
var status_text: String = "未选择配方"
var state_id: StringName = STATE_NO_RECIPE
var progress_seconds: float = 0.0
var is_paused: bool = false
var _status_marker: Node2D = null

func setup_processor(recipes: Array[RecipeDef], inventory: Variant) -> void:
	_ensure_status_marker()
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

func set_paused(paused: bool) -> void:
	if is_paused == paused:
		return
	is_paused = paused
	_update_status()
	processor_state_changed.emit()

func toggle_paused() -> void:
	set_paused(not is_paused)

func _process(delta: float) -> void:
	if is_paused:
		_set_status("已暂停", STATE_PAUSED)
		return
	_flush_output_cache_to_inventory()
	if selected_recipe == null:
		_set_status("未选择配方", STATE_NO_RECIPE)
		return
	if target_inventory == null:
		_set_status("等待主基地", STATE_WAITING_BASE)
		return
	if progress_seconds > 0.0:
		_advance_production(delta)
		return

	var cache_changed := _pull_missing_inputs_from_inventory()
	if not _cache_can_afford(input_cache, selected_recipe.inputs):
		progress_seconds = 0.0
		_set_status("等待原料", STATE_WAITING_INPUTS)
		if cache_changed:
			processor_state_changed.emit()
		return

	if progress_seconds <= 0.0:
		_spend_from_cache(input_cache, selected_recipe.inputs)
		processor_state_changed.emit()

	_advance_production(delta)

func _advance_production(delta: float) -> void:
	progress_seconds += delta
	_set_status("运行中", STATE_RUNNING)
	if progress_seconds < selected_recipe.duration_seconds:
		return

	progress_seconds = 0.0
	_add_to_cache(output_cache, selected_recipe.outputs)
	_flush_output_cache_to_inventory()
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

func _ensure_status_marker() -> void:
	if _status_marker != null and is_instance_valid(_status_marker):
		return
	_status_marker = BuildingStatusMarkerScript.new()
	_status_marker.name = "StatusMarker"
	_status_marker.z_index = 50
	_status_marker.position = Vector2(grid_size.x * cell_size - 7.0, 7.0)
	add_child(_status_marker)

func _refresh_status_marker() -> void:
	_ensure_status_marker()
	_status_marker.position = Vector2(grid_size.x * cell_size - 7.0, 7.0)
	if is_paused:
		_status_marker.set_marker_type(BuildingStatusMarkerScript.MARKER_PAUSED)
	elif state_id == STATE_WAITING_INPUTS:
		_status_marker.set_marker_type(BuildingStatusMarkerScript.MARKER_MISSING_INPUTS)
	else:
		_status_marker.set_marker_type(BuildingStatusMarkerScript.MARKER_NONE)

func _add_to_cache(cache: Dictionary, resources: Dictionary) -> void:
	for resource_id in resources.keys():
		cache[resource_id] = int(cache.get(resource_id, 0)) + int(resources[resource_id])

func _flush_output_cache_to_inventory() -> bool:
	if target_inventory == null or output_cache.is_empty():
		return false
	var transferred := output_cache.duplicate(true)
	output_cache.clear()
	for resource_id in transferred.keys():
		var amount := int(transferred[resource_id])
		if amount <= 0:
			continue
		target_inventory.add_resource(resource_id, amount, "%s 抽象物流转入主库存" % get_display_name())
	processor_state_changed.emit()
	return true

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

func _set_status(next_status: String, next_state_id: StringName) -> void:
	if status_text == next_status and state_id == next_state_id:
		return
	status_text = next_status
	state_id = next_state_id
	_refresh_status_marker()
	processor_state_changed.emit()

func _update_status() -> void:
	if is_paused:
		_set_status("已暂停", STATE_PAUSED)
	elif selected_recipe == null:
		_set_status("未选择配方", STATE_NO_RECIPE)
	elif target_inventory == null:
		_set_status("等待主基地", STATE_WAITING_BASE)
	elif progress_seconds > 0.0:
		_set_status("运行中", STATE_RUNNING)
	else:
		_set_status("等待原料", STATE_WAITING_INPUTS)
