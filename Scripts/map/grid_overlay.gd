@tool
extends Node2D
class_name GridOverlay

@export var map_size_cells: Vector2i = Vector2i(64, 64)
@export var cell_size: int = 64
@export var background_color: Color = Color(0.071, 0.086, 0.102, 1.0)
@export var grid_line_color: Color = Color(0.18, 0.20, 0.22, 0.58)
@export var major_grid_line_color: Color = Color(0.24, 0.27, 0.30, 0.7)
@export var major_line_every: int = 4
@export var grid_line_width: float = 1.25
@export var major_grid_line_width: float = 1.5

func _ready() -> void:
	_connect_viewport_redraw()
	_queue_stable_redraw()

func configure(next_map_size_cells: Vector2i, next_cell_size: int) -> void:
	map_size_cells = next_map_size_cells
	cell_size = next_cell_size
	_queue_stable_redraw()

func _draw() -> void:
	var world_size := Vector2(map_size_cells.x * cell_size, map_size_cells.y * cell_size)
	draw_rect(Rect2(Vector2.ZERO, world_size), background_color, true)

	for x in range(map_size_cells.x + 1):
		var line_x := _pixel_aligned(float(x * cell_size))
		var color := _line_color_for_index(x)
		var width := _line_width_for_index(x)
		draw_line(Vector2(line_x, 0.0), Vector2(line_x, world_size.y), color, width)

	for y in range(map_size_cells.y + 1):
		var line_y := _pixel_aligned(float(y * cell_size))
		var color := _line_color_for_index(y)
		var width := _line_width_for_index(y)
		draw_line(Vector2(0.0, line_y), Vector2(world_size.x, line_y), color, width)

func _line_color_for_index(index: int) -> Color:
	if major_line_every > 0 and index % major_line_every == 0:
		return major_grid_line_color
	return grid_line_color

func _line_width_for_index(index: int) -> float:
	if major_line_every > 0 and index % major_line_every == 0:
		return major_grid_line_width
	return grid_line_width

func _pixel_aligned(value: float) -> float:
	return floorf(value) + 0.5

func _connect_viewport_redraw() -> void:
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_queue_stable_redraw):
		viewport.size_changed.connect(_queue_stable_redraw)

func _queue_stable_redraw() -> void:
	queue_redraw()
	if is_inside_tree():
		call_deferred("_redraw_after_layout")

func _redraw_after_layout() -> void:
	queue_redraw()
