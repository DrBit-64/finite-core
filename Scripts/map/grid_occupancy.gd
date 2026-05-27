extends RefCounted
class_name GridOccupancy

var map_size_cells: Vector2i = Vector2i.ZERO
var _cells: Dictionary = {}

func configure(next_map_size_cells: Vector2i) -> void:
	map_size_cells = next_map_size_cells
	_cells.clear()

func can_place(origin: Vector2i, size: Vector2i) -> bool:
	if not _is_rect_in_bounds(origin, size):
		return false
	for cell in _iter_rect_cells(origin, size):
		if _cells.has(cell):
			return false
	return true

func register_rect(origin: Vector2i, size: Vector2i, value: Variant) -> bool:
	if not can_place(origin, size):
		return false
	for cell in _iter_rect_cells(origin, size):
		_cells[cell] = value
	return true

func get_at(cell: Vector2i) -> Variant:
	return _cells.get(cell, null)

func clear_rect(origin: Vector2i, size: Vector2i) -> void:
	for cell in _iter_rect_cells(origin, size):
		_cells.erase(cell)

func _is_rect_in_bounds(origin: Vector2i, size: Vector2i) -> bool:
	if size.x <= 0 or size.y <= 0:
		return false
	return origin.x >= 0 \
		and origin.y >= 0 \
		and origin.x + size.x <= map_size_cells.x \
		and origin.y + size.y <= map_size_cells.y

func _iter_rect_cells(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(origin.y, origin.y + size.y):
		for x in range(origin.x, origin.x + size.x):
			cells.append(Vector2i(x, y))
	return cells
