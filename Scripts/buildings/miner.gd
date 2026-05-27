extends "res://Scripts/buildings/base_building.gd"
class_name MinerBuilding

@export var output_per_minute: int = 30

var bound_resource_node: Node = null
var output_resource_id: StringName
var target_inventory: Variant = null
var _production_accumulator: float = 0.0

func setup_miner(resource_node: Node, inventory: Variant) -> void:
	bound_resource_node = resource_node
	target_inventory = inventory
	if bound_resource_node:
		output_resource_id = bound_resource_node.get("resource_id")
		if bound_resource_node.has_method("bind_miner"):
			bound_resource_node.call("bind_miner", self)
	queue_redraw()

func _process(delta: float) -> void:
	if target_inventory == null or String(output_resource_id).is_empty():
		return
	var amount_per_second := float(output_per_minute) / 60.0
	_production_accumulator += amount_per_second * delta
	var whole_amount := floori(_production_accumulator)
	if whole_amount <= 0:
		return
	_production_accumulator -= whole_amount
	target_inventory.add_resource(output_resource_id, whole_amount, "%s 采矿" % get_display_name())

func get_inspector_lines() -> Array[String]:
	var lines := super.get_inspector_lines()
	lines.append("绑定矿点：%s" % _get_bound_node_name())
	lines.append("产出：%s / 分钟" % output_per_minute)
	lines.append("资源：%s" % String(output_resource_id))
	lines.append("状态：%s" % ("运行中" if target_inventory != null else "等待主基地"))
	return lines

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
