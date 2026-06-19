extends Node2D
class_name RegionGateOverlay

var connections: Array = []
var gate_states: Dictionary = {}
var cell_size: int = 64
var opening_until_msec: Dictionary = {}

func setup(next_connections: Array, next_gate_states: Dictionary, next_cell_size: int) -> void:
	connections = next_connections.duplicate(true)
	gate_states = next_gate_states.duplicate(true)
	cell_size = maxi(1, next_cell_size)
	queue_redraw()

func animate_gate(gate_id: String) -> void:
	if gate_id.is_empty():
		return
	opening_until_msec[gate_id] = Time.get_ticks_msec() + 1200
	queue_redraw()

func _process(_delta: float) -> void:
	if opening_until_msec.is_empty():
		return
	var now := Time.get_ticks_msec()
	for gate_id in opening_until_msec.keys():
		if now >= int(opening_until_msec[gate_id]):
			opening_until_msec.erase(gate_id)
	if not opening_until_msec.is_empty():
		queue_redraw()

func _draw() -> void:
	var now := Time.get_ticks_msec()
	for connection_value in connections:
		if typeof(connection_value) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_value
		var gate_id := str(connection.get("id", ""))
		if gate_id.is_empty():
			continue
		var state := str(gate_states.get(gate_id, "open"))
		var gate_cells: Array = connection.get("gate_cells", [])
		if gate_cells.is_empty():
			continue
		if state != "locked" and opening_until_msec.has(gate_id):
			var remaining := maxf(0.0, float(int(opening_until_msec[gate_id]) - now) / 1200.0)
			_draw_opening_gate(gate_cells, remaining)

func _draw_locked_gate(gate_cells: Array) -> void:
	for cell_value in gate_cells:
		var cell := _cell_from_value(cell_value)
		var rect := Rect2(Vector2(cell) * float(cell_size), Vector2.ONE * float(cell_size))
		draw_rect(rect, Color(0.02, 0.025, 0.03, 0.50), true)
		draw_rect(rect.grow(-5.0), Color(1.0, 0.62, 0.18, 0.28), false, 2.0)
		var center := rect.get_center()
		var radius := float(cell_size) * 0.22
		draw_arc(center, radius, 0.0, TAU * 0.76, 24, Color(1.0, 0.68, 0.24, 0.58), 2.0)
		draw_line(center + Vector2(-radius, 0.0), center + Vector2(radius, 0.0), Color(1.0, 0.68, 0.24, 0.42), 1.5)

func _draw_opening_gate(gate_cells: Array, remaining_ratio: float) -> void:
	var alpha := clampf(remaining_ratio, 0.0, 1.0)
	for cell_value in gate_cells:
		var cell := _cell_from_value(cell_value)
		var center := (Vector2(cell) + Vector2(0.5, 0.5)) * float(cell_size)
		var radius := float(cell_size) * lerpf(0.18, 0.52, 1.0 - alpha)
		draw_circle(center, radius, Color(0.46, 0.92, 1.0, 0.12 * alpha))
		draw_arc(center, radius, 0.0, TAU, 36, Color(0.58, 0.94, 1.0, 0.85 * alpha), 2.0)

func _cell_from_value(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(roundi(value.x), roundi(value.y))
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO
