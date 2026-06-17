extends "res://Scripts/buildings/base_building.gd"
class_name WaterPumpBuilding

signal water_pump_state_changed

@export var output_per_minute: int = 24

var target_inventory: Variant = null
var output_cache: Dictionary = {}
var status_text: String = "等待主基地"
var progress_seconds: float = 0.0
var requires_logistics_delivery: bool = false

var _production_accumulator: float = 0.0
var _operation_recipe: RecipeDef = null

func setup_water_pump(inventory: Variant, use_entity_logistics: bool = false) -> void:
	target_inventory = inventory
	requires_logistics_delivery = use_entity_logistics
	_update_status_text()
	water_pump_state_changed.emit()

func _process(delta: float) -> void:
	_flush_output_cache_to_inventory()
	if target_inventory == null:
		_update_status_text()
		return

	var amount_per_second := float(output_per_minute) / 60.0
	if amount_per_second <= 0.0:
		_update_status_text()
		return

	_production_accumulator += amount_per_second * delta
	progress_seconds = _production_accumulator / amount_per_second
	var whole_amount := floori(_production_accumulator)
	if whole_amount <= 0:
		_update_status_text()
		return

	_production_accumulator -= whole_amount
	progress_seconds = _production_accumulator / amount_per_second
	output_cache[MvpDataDefaults.RES_WATER] = int(output_cache.get(MvpDataDefaults.RES_WATER, 0)) + whole_amount
	_flush_output_cache_to_inventory()
	_update_status_text()
	water_pump_state_changed.emit()

func get_progress_ratio() -> float:
	return clampf(_production_accumulator, 0.0, 1.0)

func get_operation_recipe() -> RecipeDef:
	if _operation_recipe == null:
		_rebuild_operation_recipe()
	return _operation_recipe

func get_inspector_lines() -> Array[String]:
	var lines := super.get_inspector_lines()
	lines.append("产出：%s / 分钟" % output_per_minute)
	lines.append("资源：水")
	lines.append("状态：%s" % status_text)
	lines.append("进度：%d%%" % int(get_progress_ratio() * 100.0))
	return lines

func _flush_output_cache_to_inventory() -> void:
	if target_inventory == null or output_cache.is_empty():
		return
	if requires_logistics_delivery:
		return
	for resource_id in output_cache.keys():
		var amount := int(output_cache[resource_id])
		if amount <= 0:
			continue
		target_inventory.add_resource(StringName(resource_id), amount, "%s 抽水" % get_display_name())
	output_cache.clear()

func _update_status_text() -> void:
	if target_inventory == null:
		status_text = "等待主基地"
	elif requires_logistics_delivery:
		status_text = "等待物流取水"
	else:
		status_text = "运行中"

func _rebuild_operation_recipe() -> void:
	_operation_recipe = RecipeDef.new()
	_operation_recipe.id = &"pump_water"
	_operation_recipe.display_name = "抽取水"
	_operation_recipe.recipe_type = &"pumping"
	_operation_recipe.target_id = MvpDataDefaults.RES_WATER
	_operation_recipe.duration_seconds = 60.0 / maxf(1.0, float(output_per_minute))
	_operation_recipe.inputs = {}
	_operation_recipe.outputs = {
		MvpDataDefaults.RES_WATER: 1,
	}

func _draw() -> void:
	var pixel_size := Vector2(grid_size.x * cell_size, grid_size.y * cell_size)
	var rect := Rect2(Vector2(4.0, 4.0), pixel_size - Vector2(8.0, 8.0))
	draw_rect(rect, Color(0.05, 0.42, 0.56, 0.16), true)
	draw_rect(rect, Color(0.34, 0.86, 1.0, 0.82), false, 2.0)
	var y := rect.position.y + rect.size.y * 0.66
	draw_line(Vector2(rect.position.x + 10.0, y), Vector2(rect.end.x - 10.0, y), Color(0.54, 0.94, 1.0, 0.72), 2.0)
