extends Node2D
class_name GridSelectionMarker

@export var outline_color: Color = Color(0.98, 0.86, 0.26, 0.95)
@export var fill_color: Color = Color(0.98, 0.86, 0.26, 0.08)
@export var outline_width: float = 2.0

var cell_size: int = 64
var grid_size: Vector2i = Vector2i.ONE

func show_selection(origin: Vector2i, size: Vector2i, next_cell_size: int) -> void:
	cell_size = next_cell_size
	grid_size = size
	position = Vector2(origin.x * cell_size, origin.y * cell_size)
	visible = true
	queue_redraw()

func clear_selection() -> void:
	visible = false

func _draw() -> void:
	var pixel_size := Vector2(grid_size.x * cell_size, grid_size.y * cell_size)
	var rect := Rect2(Vector2.ZERO, pixel_size)
	draw_rect(rect, fill_color, true)
	draw_rect(rect, outline_color, false, outline_width)
