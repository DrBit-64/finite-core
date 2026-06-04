extends "res://Scripts/buildings/base_building.gd"
class_name MinerBuilding

signal miner_state_changed

@export var output_per_minute: int = 30

var bound_resource_node: Node = null
var output_resource_id: StringName
var target_inventory: Variant = null
var input_cache: Dictionary = {}
var output_cache: Dictionary = {}
var status_text: String = "等待主基地"
var progress_seconds: float = 0.0

var _production_accumulator: float = 0.0
var _mining_recipe: RecipeDef = null

func setup_miner(resource_node: Node, inventory: Variant) -> void:
	bound_resource_node = resource_node
	target_inventory = inventory
	if bound_resource_node:
		output_resource_id = bound_resource_node.get("resource_id")
		if bound_resource_node.has_method("bind_miner"):
			bound_resource_node.call("bind_miner", self)
	_update_status_text()
	_rebuild_mining_recipe()
	queue_redraw()
	miner_state_changed.emit()

func _process(delta: float) -> void:
	_flush_output_cache_to_inventory()
	if target_inventory == null or String(output_resource_id).is_empty():
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
	output_cache[output_resource_id] = int(output_cache.get(output_resource_id, 0)) + whole_amount
	_flush_output_cache_to_inventory()
	_update_status_text()
	miner_state_changed.emit()

func get_mining_recipe() -> RecipeDef:
	if _mining_recipe == null:
		_rebuild_mining_recipe()
	return _mining_recipe

func get_progress_ratio() -> float:
	return clampf(_production_accumulator, 0.0, 1.0)

func get_inspector_lines() -> Array[String]:
	var lines := super.get_inspector_lines()
	lines.append("绑定矿点：%s" % _get_bound_node_name())
	lines.append("产出：%s / 分钟" % output_per_minute)
	lines.append("资源：%s" % String(output_resource_id))
	lines.append("状态：%s" % status_text)
	lines.append("进度：%d%%" % int(get_progress_ratio() * 100.0))
	return lines

func _flush_output_cache_to_inventory() -> void:
	if target_inventory == null or output_cache.is_empty():
		return
	for resource_id in output_cache.keys():
		var amount := int(output_cache[resource_id])
		if amount <= 0:
			continue
		target_inventory.add_resource(StringName(resource_id), amount, "%s 采矿" % get_display_name())
	output_cache.clear()

func _update_status_text() -> void:
	if target_inventory == null:
		status_text = "等待主基地"
	elif String(output_resource_id).is_empty():
		status_text = "未绑定矿点"
	else:
		status_text = "运行中"

func _rebuild_mining_recipe() -> void:
	_mining_recipe = RecipeDef.new()
	_mining_recipe.id = StringName("mine_%s" % String(output_resource_id))
	_mining_recipe.display_name = "开采%s" % _get_resource_display_name()
	_mining_recipe.recipe_type = &"mining"
	_mining_recipe.target_id = output_resource_id
	_mining_recipe.duration_seconds = 60.0 / maxf(1.0, float(output_per_minute))
	_mining_recipe.inputs = {}
	_mining_recipe.outputs = {}
	if not String(output_resource_id).is_empty():
		_mining_recipe.outputs[output_resource_id] = 1

func _get_resource_display_name() -> String:
	if bound_resource_node and bound_resource_node.has_method("get_display_name"):
		return bound_resource_node.call("get_display_name")
	if output_resource_id == MvpDataDefaults.RES_COPPER_ORE:
		return "铜矿"
	if output_resource_id == MvpDataDefaults.RES_IRON_ORE:
		return "铁矿"
	return String(output_resource_id)

func _get_bound_node_name() -> String:
	if bound_resource_node and bound_resource_node.has_method("get_display_name"):
		return bound_resource_node.call("get_display_name")
	return "未绑定"

func _draw() -> void:
	if bound_resource_node == null:
		return
	var color := _mined_resource_color()
	var rect := Rect2(Vector2(3.0, 3.0), Vector2(cell_size - 6.0, cell_size - 6.0))
	draw_rect(rect, Color(color.r, color.g, color.b, 0.12), true)
	draw_rect(rect, Color(color.r, color.g, color.b, 0.96), false, 3.0)

	var corner_length := 14.0
	var top_left := rect.position
	var top_right := rect.position + Vector2(rect.size.x, 0.0)
	var bottom_left := rect.position + Vector2(0.0, rect.size.y)
	var bottom_right := rect.position + rect.size
	draw_line(top_left, top_left + Vector2(corner_length, 0.0), color, 4.0)
	draw_line(top_left, top_left + Vector2(0.0, corner_length), color, 4.0)
	draw_line(top_right, top_right + Vector2(-corner_length, 0.0), color, 4.0)
	draw_line(top_right, top_right + Vector2(0.0, corner_length), color, 4.0)
	draw_line(bottom_left, bottom_left + Vector2(corner_length, 0.0), color, 4.0)
	draw_line(bottom_left, bottom_left + Vector2(0.0, -corner_length), color, 4.0)
	draw_line(bottom_right, bottom_right + Vector2(-corner_length, 0.0), color, 4.0)
	draw_line(bottom_right, bottom_right + Vector2(0.0, -corner_length), color, 4.0)

func _mined_resource_color() -> Color:
	if output_resource_id == MvpDataDefaults.RES_COPPER_ORE:
		return Color(0.95, 0.56, 0.25, 1.0)
	if output_resource_id == MvpDataDefaults.RES_IRON_ORE:
		return Color(0.76, 0.82, 0.88, 1.0)
	return Color(0.72, 0.90, 0.72, 1.0)
