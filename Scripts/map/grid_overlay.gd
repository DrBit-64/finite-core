@tool
extends Node2D
class_name GridOverlay

@export var map_size_cells: Vector2i = Vector2i(64, 64)
@export var cell_size: int = 64
@export var background_color: Color = Color(0.071, 0.086, 0.102, 1.0)
@export var grid_line_color: Color = Color(0.18, 0.20, 0.22, 0.58)
@export var major_grid_line_color: Color = Color(0.24, 0.27, 0.30, 0.7)
@export var major_line_every: int = 4

func _ready() -> void:
	queue_redraw()

func configure(next_map_size_cells: Vector2i, next_cell_size: int) -> void:
	map_size_cells = next_map_size_cells
	cell_size = next_cell_size
	queue_redraw()

func _draw() -> void:
	var world_size := Vector2(map_size_cells.x * cell_size, map_size_cells.y * cell_size)
	draw_rect(Rect2(Vector2.ZERO, world_size), background_color, true)

	for x in range(map_size_cells.x + 1):
		var line_x := float(x * cell_size)
		var color := _line_color_for_index(x)
		draw_line(Vector2(line_x, 0.0), Vector2(line_x, world_size.y), color, 1.0)

	for y in range(map_size_cells.y + 1):
		var line_y := float(y * cell_size)
		var color := _line_color_for_index(y)
		draw_line(Vector2(0.0, line_y), Vector2(world_size.x, line_y), color, 1.0)

func _line_color_for_index(index: int) -> Color:
	if major_line_every > 0 and index % major_line_every == 0:
		return major_grid_line_color
	return grid_line_color
