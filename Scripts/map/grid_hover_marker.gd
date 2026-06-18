extends Node2D
class_name GridHoverMarker

@export var outline_color: Color = Color(0.58, 0.76, 0.88, 0.72)
@export var fill_color: Color = Color(0.42, 0.68, 0.84, 0.07)
@export var outline_width: float = 1.0

var cell_size: int = 64
var _hovered_cell: Vector2i = Vector2i(-999999, -999999)

func show_hover(cell: Vector2i, next_cell_size: int) -> void:
	var changed := cell != _hovered_cell or cell_size != next_cell_size or not visible
	_hovered_cell = cell
	cell_size = next_cell_size
	position = Vector2(cell.x * cell_size, cell.y * cell_size)
	visible = true
	if changed:
		queue_redraw()

func clear_hover() -> void:
	if not visible:
		return
	visible = false

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2.ONE * float(cell_size))
	draw_rect(rect, fill_color, true)
	draw_rect(rect, outline_color, false, outline_width)
