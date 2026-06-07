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
@export var fog_region_size_cells: int = 4

var region_states: Dictionary = {}
var region_signal_cells: Dictionary = {}

func _ready() -> void:
	_connect_viewport_redraw()
	_queue_stable_redraw()

func configure(next_map_size_cells: Vector2i, next_cell_size: int) -> void:
	map_size_cells = next_map_size_cells
	cell_size = next_cell_size
	_queue_stable_redraw()

func set_region_states(next_region_states: Dictionary) -> void:
	region_states = next_region_states.duplicate(true)
	_queue_stable_redraw()

func set_region_signals(next_region_signal_cells: Dictionary) -> void:
	region_signal_cells = next_region_signal_cells.duplicate(true)
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

	_draw_region_fog()
	_draw_region_signals()

func _draw_region_fog() -> void:
	if region_states.is_empty() or fog_region_size_cells <= 0:
		return
	var region_world_size := float(fog_region_size_cells * cell_size)
	for key in region_states.keys():
		var region := _parse_region_key(str(key))
		var state := str(region_states[key])
		var color := _fog_color_for_state(state)
		if color.a <= 0.0:
			continue
		draw_rect(
			Rect2(Vector2(region.x * region_world_size, region.y * region_world_size), Vector2(region_world_size, region_world_size)),
			color,
			true
		)

func _fog_color_for_state(state: String) -> Color:
	match state:
		"unknown":
			return Color(0.0, 0.0, 0.0, 0.36)
		"signal":
			return Color(0.34, 0.20, 0.08, 0.24)
		"scanned":
			return Color(0.05, 0.07, 0.09, 0.10)
		"visible":
			return Color(0.04, 0.12, 0.16, 0.08)
		"controlled":
			return Color(0.04, 0.18, 0.12, 0.16)
	return Color.TRANSPARENT

func _draw_region_signals() -> void:
	if region_signal_cells.is_empty():
		return
	for key in region_signal_cells.keys():
		var centers: Array = region_signal_cells[key]
		for center_cell in centers:
			var center := Vector2(center_cell) * float(cell_size)
			_draw_nest_signal(center)

func _draw_nest_signal(center: Vector2) -> void:
	var radius := float(cell_size) * 0.32
	var inner_radius := float(cell_size) * 0.16
	var signal_color := Color(1.0, 0.48, 0.18, 0.80)
	var fill_color := Color(0.95, 0.28, 0.08, 0.16)
	draw_circle(center, radius, fill_color)
	draw_arc(center, radius, 0.0, TAU, 40, signal_color, 2.0)
	draw_arc(center, inner_radius, 0.0, TAU, 32, Color(1.0, 0.78, 0.42, 0.72), 1.5)
	draw_line(center + Vector2(-radius, 0.0), center + Vector2(-inner_radius, 0.0), signal_color, 2.0)
	draw_line(center + Vector2(inner_radius, 0.0), center + Vector2(radius, 0.0), signal_color, 2.0)
	draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, -inner_radius), signal_color, 2.0)
	draw_line(center + Vector2(0.0, inner_radius), center + Vector2(0.0, radius), signal_color, 2.0)

func _parse_region_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

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
