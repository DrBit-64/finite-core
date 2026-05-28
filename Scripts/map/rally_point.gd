extends Node2D
class_name RallyPointMarker

@export var marker_color: Color = Color(0.36, 0.92, 0.62, 0.96)
@export var fill_color: Color = Color(0.36, 0.92, 0.62, 0.14)

var grid_cell: Vector2i = Vector2i.ZERO
var cell_size: int = 64

func setup(cell: Vector2i, next_cell_size: int) -> void:
	grid_cell = cell
	cell_size = next_cell_size
	position = Vector2((float(cell.x) + 0.5) * float(cell_size), (float(cell.y) + 0.5) * float(cell_size))
	visible = true
	queue_redraw()

func get_display_name() -> String:
	return "集结点"

func get_inspector_lines() -> Array[String]:
	return [
		"类型：地图标记",
		"名称：集结点",
		"网格：%s, %s" % [grid_cell.x, grid_cell.y],
	]

func _draw() -> void:
	var radius := float(cell_size) * 0.30
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, marker_color, 3.0)
	draw_line(Vector2(0.0, -radius), Vector2(0.0, radius), marker_color, 2.0)
	draw_line(Vector2(-radius, 0.0), Vector2(radius, 0.0), marker_color, 2.0)

	var pole_top := Vector2(0.0, -radius - 16.0)
	var pole_bottom := Vector2(0.0, -radius + 18.0)
	draw_line(pole_top, pole_bottom, marker_color, 3.0)
	var flag := PackedVector2Array([
		pole_top,
		pole_top + Vector2(18.0, 6.0),
		pole_top + Vector2(0.0, 12.0),
	])
	draw_colored_polygon(flag, Color(marker_color.r, marker_color.g, marker_color.b, 0.86))
