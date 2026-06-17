@tool
extends Node2D
class_name FrontierPathPainter

@export_enum("Crystal Wasteland", "Wreckage Battlefield", "Interference Highland", "Core Perimeter")
var frontier_type: int = 0:
	set(value):
		frontier_type = clampi(value, 0, 3)
		queue_redraw()

@export var width_cells: int = 5:
	set(value):
		width_cells = maxi(1, value)
		queue_redraw()

@export_range(0.0, 1.0, 0.05) var noise_strength: float = 0.05:
	set(value):
		noise_strength = clampf(value, 0.0, 1.0)
		queue_redraw()

@export var noise_seed: int = 1307:
	set(value):
		noise_seed = value
		queue_redraw()

@export var close_inner_corners: bool = true:
	set(value):
		close_inner_corners = value
		queue_redraw()

@export var blocky_stair_edges: bool = true:
	set(value):
		blocky_stair_edges = value
		queue_redraw()

@export_node_path("TileMapLayer") var target_layer_path: NodePath = ^"../FrontierTerrainLayer"
@export var clear_previous_bake: bool = true
@export var protected_cells: Array[Vector2i] = []
@export var generated_cells: Array[Vector2i] = []

@export_tool_button("Bake Now") var bake_button := bake_to_tilemap
@export_tool_button("Clear Generated") var clear_generated_button := clear_generated_cells

const REGION_FRONTIER_SOURCE_ID := 20
const TILE_FILL := 0
const TILE_EDGE_H := 1
const TILE_EDGE_V := 2
const TILE_CORNER_NE := 3
const TILE_CORNER_NW := 4
const TILE_CORNER_SE := 5
const TILE_CORNER_SW := 6
const TILE_END_CAP := 7

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and visible:
		queue_redraw()

func bake_to_tilemap() -> void:
	if not Engine.is_editor_hint():
		return
	var target_layer := _get_target_layer()
	if target_layer == null:
		push_warning("FrontierPathPainter: target_layer_path is not a TileMapLayer.")
		return
	var control_cells := _collect_control_cells(target_layer)
	if control_cells.size() < 2:
		push_warning("FrontierPathPainter: add at least two Marker2D child nodes as path points.")
		return
	if clear_previous_bake:
		_clear_previous_bake(target_layer, control_cells)
	var cells := _build_frontier_mask(control_cells)
	for cell in cells:
		var tile_x := _choose_tile_x(cell, cells, control_cells)
		target_layer.set_cell(cell, REGION_FRONTIER_SOURCE_ID, Vector2i(tile_x, frontier_type), 0)
	generated_cells = cells
	notify_property_list_changed()
	queue_redraw()
	target_layer.notify_runtime_tile_data_update()
	target_layer.queue_redraw()

func clear_generated_cells() -> void:
	if not Engine.is_editor_hint():
		return
	var target_layer := _get_target_layer()
	if target_layer == null:
		return
	for cell in generated_cells:
		if target_layer.get_cell_source_id(cell) == REGION_FRONTIER_SOURCE_ID:
			target_layer.erase_cell(cell)
	generated_cells.clear()
	notify_property_list_changed()
	queue_redraw()
	target_layer.notify_runtime_tile_data_update()
	target_layer.queue_redraw()

func _clear_previous_bake(target_layer: TileMapLayer, control_cells: Array[Vector2i]) -> void:
	if not generated_cells.is_empty():
		clear_generated_cells()
		return
	var cells := _build_frontier_mask(control_cells)
	if cells.is_empty():
		return
	var min_cell := cells[0]
	var max_cell := cells[0]
	for cell in cells:
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
	var padding := maxi(2, width_cells + 2)
	for x in range(min_cell.x - padding, max_cell.x + padding + 1):
		for y in range(min_cell.y - padding, max_cell.y + padding + 1):
			var candidate := Vector2i(x, y)
			if candidate in protected_cells:
				continue
			if target_layer.get_cell_source_id(candidate) == REGION_FRONTIER_SOURCE_ID:
				target_layer.erase_cell(candidate)

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var points := _collect_marker_positions()
	if points.is_empty():
		return
	var preview_color := _frontier_color()
	for index in range(points.size()):
		var local_point := to_local(points[index])
		draw_circle(local_point, 12.0, Color(preview_color.r, preview_color.g, preview_color.b, 0.55))
		draw_arc(local_point, 18.0, 0.0, TAU, 32, Color(preview_color.r, preview_color.g, preview_color.b, 0.9), 2.0)
		if index > 0:
			draw_line(to_local(points[index - 1]), local_point, Color(preview_color.r, preview_color.g, preview_color.b, 0.8), 4.0)
	var target_layer := _get_target_layer()
	if target_layer == null:
		return
	var cell_preview := _build_frontier_mask(_collect_control_cells(target_layer))
	var cell_size := _cell_size_from_layer(target_layer)
	for cell in cell_preview:
		var center := to_local(target_layer.to_global(target_layer.map_to_local(cell)))
		draw_rect(Rect2(center - Vector2.ONE * float(cell_size) * 0.5, Vector2.ONE * float(cell_size)), Color(preview_color.r, preview_color.g, preview_color.b, 0.08), false, 1.0)

func _get_target_layer() -> TileMapLayer:
	return get_node_or_null(target_layer_path) as TileMapLayer

func _collect_marker_positions() -> Array[Vector2]:
	var points: Array[Vector2] = []
	var markers := get_children().filter(func(child: Node) -> bool:
		return child is Marker2D
	)
	markers.sort_custom(func(a: Node, b: Node) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0
	)
	for child in markers:
		var marker := child as Marker2D
		points.append(marker.global_position)
	return points

func _collect_control_cells(target_layer: TileMapLayer) -> Array[Vector2i]:
	var points := _collect_marker_positions()
	var result: Array[Vector2i] = []
	for index in range(points.size()):
		var cell := target_layer.local_to_map(target_layer.to_local(points[index]))
		if index == 0 or cell != result[result.size() - 1]:
			result.append(cell)
	return result

func _build_frontier_mask(control_cells: Array[Vector2i]) -> Array[Vector2i]:
	var cell_set := {}
	if control_cells.size() < 2:
		return []
	if blocky_stair_edges:
		return _build_blocky_frontier_mask(control_cells)
	var radius := maxf(0.5, float(width_cells) * 0.5)
	var padding := ceili(radius + 2.0)
	var min_cell := control_cells[0]
	var max_cell := control_cells[0]
	for control_cell in control_cells:
		min_cell.x = mini(min_cell.x, control_cell.x)
		min_cell.y = mini(min_cell.y, control_cell.y)
		max_cell.x = maxi(max_cell.x, control_cell.x)
		max_cell.y = maxi(max_cell.y, control_cell.y)
	for x in range(min_cell.x - padding, max_cell.x + padding + 1):
		for y in range(min_cell.y - padding, max_cell.y + padding + 1):
			var candidate := Vector2i(x, y)
			if candidate in protected_cells:
				continue
			var distance := _distance_to_polyline(Vector2(float(x) + 0.5, float(y) + 0.5), control_cells)
			var jitter := _cell_noise(candidate) * noise_strength
			if distance <= radius + jitter:
				cell_set[candidate] = true
	if close_inner_corners:
		_close_mask_inner_corners(cell_set)
	var result: Array[Vector2i] = []
	for key in cell_set.keys():
		result.append(key)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)
	return result

func _build_blocky_frontier_mask(control_cells: Array[Vector2i]) -> Array[Vector2i]:
	var cell_set := {}
	var brush_radius := maxi(0, int(floor(float(width_cells) * 0.5)))
	for index in range(control_cells.size() - 1):
		var line_cells := _line_cells_between(control_cells[index], control_cells[index + 1])
		for line_cell in line_cells:
			_stamp_square_brush(cell_set, line_cell, brush_radius)
	if close_inner_corners:
		_close_mask_inner_corners(cell_set)
	var result: Array[Vector2i] = []
	for key in cell_set.keys():
		result.append(key)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)
	return result

func _stamp_square_brush(cell_set: Dictionary, center: Vector2i, brush_radius: int) -> void:
	for x in range(center.x - brush_radius, center.x + brush_radius + 1):
		for y in range(center.y - brush_radius, center.y + brush_radius + 1):
			var candidate := Vector2i(x, y)
			if candidate in protected_cells:
				continue
			cell_set[candidate] = true

func _line_cells_between(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var current := start
	result.append(current)
	var delta := end - start
	var step_x := _int_sign(delta.x)
	var step_y := _int_sign(delta.y)
	var abs_x: int = abs(delta.x)
	var abs_y: int = abs(delta.y)
	if abs_x == 0 and abs_y == 0:
		return result
	var error: int = abs_x - abs_y
	while current != end:
		var previous := current
		var next := current
		var doubled_error: int = error * 2
		var move_x := false
		var move_y := false
		if doubled_error > -abs_y:
			error -= abs_y
			next.x += step_x
			move_x = true
		if doubled_error < abs_x:
			error += abs_x
			next.y += step_y
			move_y = true
		if move_x and move_y:
			var elbow := Vector2i(next.x, previous.y)
			if result.size() % 2 == 0:
				elbow = Vector2i(previous.x, next.y)
			if result[result.size() - 1] != elbow:
				result.append(elbow)
		current = next
		if result[result.size() - 1] != current:
			result.append(current)
	return result

func _int_sign(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0

func _distance_to_polyline(point: Vector2, control_cells: Array[Vector2i]) -> float:
	var best := INF
	for index in range(control_cells.size() - 1):
		var a := Vector2(float(control_cells[index].x) + 0.5, float(control_cells[index].y) + 0.5)
		var b := Vector2(float(control_cells[index + 1].x) + 0.5, float(control_cells[index + 1].y) + 0.5)
		best = minf(best, _distance_to_segment(point, a, b))
	return best

func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var segment := b - a
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(a + segment * t)

func _close_mask_inner_corners(cell_set: Dictionary) -> void:
	for _pass_index in range(2):
		var additions: Array[Vector2i] = []
		for cell_value in cell_set.keys():
			var cell: Vector2i = cell_value
			_queue_2x2_corner_additions(cell_set, additions, cell)
			_queue_2x2_corner_additions(cell_set, additions, cell + Vector2i.LEFT)
			_queue_2x2_corner_additions(cell_set, additions, cell + Vector2i.UP)
			_queue_2x2_corner_additions(cell_set, additions, cell + Vector2i(-1, -1))
		for addition in additions:
			if addition not in protected_cells:
				cell_set[addition] = true

func _queue_2x2_corner_additions(cell_set: Dictionary, additions: Array[Vector2i], origin: Vector2i) -> void:
	var nw := origin
	var ne := origin + Vector2i.RIGHT
	var sw := origin + Vector2i.DOWN
	var se := origin + Vector2i.ONE
	var has_nw := nw in cell_set
	var has_ne := ne in cell_set
	var has_sw := sw in cell_set
	var has_se := se in cell_set
	var count := int(has_nw) + int(has_ne) + int(has_sw) + int(has_se)
	if count >= 3:
		if not has_nw:
			_add_unique_cell(additions, nw)
		if not has_ne:
			_add_unique_cell(additions, ne)
		if not has_sw:
			_add_unique_cell(additions, sw)
		if not has_se:
			_add_unique_cell(additions, se)
		return
	if has_nw and has_se and not has_ne and not has_sw:
		_add_unique_cell(additions, ne)
		_add_unique_cell(additions, sw)
	elif has_ne and has_sw and not has_nw and not has_se:
		_add_unique_cell(additions, nw)
		_add_unique_cell(additions, se)

func _add_unique_cell(cells: Array[Vector2i], cell: Vector2i) -> void:
	if cell in cells or cell in protected_cells:
		return
	cells.append(cell)

func _choose_tile_x(cell: Vector2i, cells: Array[Vector2i], _control_cells: Array[Vector2i]) -> int:
	var cell_lookup := {}
	for mask_cell in cells:
		cell_lookup[mask_cell] = true
	var north := cell + Vector2i.UP in cell_lookup
	var south := cell + Vector2i.DOWN in cell_lookup
	var west := cell + Vector2i.LEFT in cell_lookup
	var east := cell + Vector2i.RIGHT in cell_lookup
	var neighbor_count := int(north) + int(south) + int(west) + int(east)
	if neighbor_count <= 1:
		return TILE_END_CAP
	var north_east := cell + Vector2i(1, -1) in cell_lookup
	var north_west := cell + Vector2i(-1, -1) in cell_lookup
	var south_east := cell + Vector2i(1, 1) in cell_lookup
	var south_west := cell + Vector2i(-1, 1) in cell_lookup
	var open_north := not north
	var open_south := not south
	var open_west := not west
	var open_east := not east
	if open_north and open_east:
		return TILE_CORNER_NE
	if open_north and open_west:
		return TILE_CORNER_NW
	if open_south and open_east:
		return TILE_CORNER_SE
	if open_south and open_west:
		return TILE_CORNER_SW
	if open_north or open_south:
		return TILE_EDGE_H
	if open_west or open_east:
		return TILE_EDGE_V
	if neighbor_count == 4:
		if not north_east:
			return TILE_CORNER_SW
		if not north_west:
			return TILE_CORNER_SE
		if not south_east:
			return TILE_CORNER_NW
		if not south_west:
			return TILE_CORNER_NE
	return TILE_FILL

func _cell_noise(cell: Vector2i) -> float:
	var n := int(cell.x * 374761393 + cell.y * 668265263 + noise_seed * 1442695041)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(abs(n) % 1000) / 1000.0 - 0.5

func _frontier_color() -> Color:
	match frontier_type:
		0:
			return Color("#73e7ff")
		1:
			return Color("#f0a058")
		2:
			return Color("#95ff72")
		3:
			return Color("#d091ff")
	return Color.WHITE

func _cell_size_from_layer(target_layer: TileMapLayer) -> int:
	var tile_set := target_layer.tile_set
	if tile_set == null:
		return 64
	return tile_set.tile_size.x
