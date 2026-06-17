extends Control
class_name MinimapPanel

const PANEL_SIZE := Vector2(256, 196)
const INNER_PADDING := 10.0

var _snapshot: Dictionary = {}
var _static_texture: ImageTexture = null
var _static_texture_key: String = ""
var _last_static_version: int = -1
var _last_redraw_key: String = ""

func _init() -> void:
	name = "MinimapPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	z_index = 120

func set_snapshot(next_snapshot: Dictionary) -> void:
	var next_static_version := int(next_snapshot.get("static_version", 0))
	if next_static_version != _last_static_version:
		_static_texture = null
		_static_texture_key = ""
		_last_static_version = next_static_version
	_snapshot = next_snapshot
	var redraw_key := _make_redraw_key(next_snapshot)
	if redraw_key != _last_redraw_key or _static_texture == null:
		_last_redraw_key = redraw_key
		queue_redraw()

func _draw() -> void:
	var map_size := _vector2_from_value(_snapshot.get("map_size", Vector2.ZERO))
	if map_size.x <= 0.0 or map_size.y <= 0.0:
		return

	var panel_rect := Rect2(Vector2.ZERO, size)
	draw_rect(panel_rect, Color(0.025, 0.030, 0.036, 0.76), true)
	draw_rect(panel_rect, Color(0.30, 0.38, 0.44, 0.72), false, 1.0)

	var content_rect := _get_content_rect(map_size)
	draw_rect(content_rect, Color(0.05, 0.065, 0.075, 0.82), true)

	_draw_static_minimap(content_rect, map_size)
	_draw_region_connections(content_rect, map_size)
	_draw_water_flows(content_rect, map_size)
	_draw_pump_candidates(content_rect, map_size)
	_draw_resources(content_rect, map_size)
	_draw_supply_points(content_rect, map_size)
	_draw_region_signals(content_rect, map_size)
	_draw_main_base(content_rect, map_size)
	_draw_enemy_nests(content_rect, map_size)
	_draw_camera(content_rect, map_size)

	draw_rect(content_rect, Color(0.34, 0.46, 0.52, 0.70), false, 1.0)
	_draw_title()

func _draw_title() -> void:
	var font := get_theme_default_font()
	var font_size := 13
	var text := "小地图"
	draw_string(font, Vector2(10, 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.88, 0.94, 1.0, 0.92))

func _draw_static_minimap(content_rect: Rect2, map_size: Vector2) -> void:
	var texture_key := "%s|%sx%s|%sx%s" % [
		str(_snapshot.get("static_version", 0)),
		roundi(content_rect.size.x),
		roundi(content_rect.size.y),
		roundi(map_size.x),
		roundi(map_size.y),
	]
	if _static_texture == null or _static_texture_key != texture_key:
		_static_texture = _build_static_minimap_texture(content_rect.size, map_size)
		_static_texture_key = texture_key
	if _static_texture:
		draw_texture_rect(_static_texture, content_rect, false)

func _build_static_minimap_texture(texture_size_value: Vector2, map_size: Vector2) -> ImageTexture:
	var texture_size := Vector2i(maxi(1, ceili(texture_size_value.x)), maxi(1, ceili(texture_size_value.y)))
	var image := Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	_paint_static_regions_to_image(image, texture_size, map_size)
	_paint_static_water_to_image(image, texture_size, map_size)
	_paint_static_frontiers_to_image(image, texture_size, map_size)
	return ImageTexture.create_from_image(image)

func _paint_static_regions_to_image(image: Image, texture_size: Vector2i, map_size: Vector2) -> void:
	var region_cells: Array = _snapshot.get("region_cells", [])
	if not region_cells.is_empty():
		for cell_value in region_cells:
			if typeof(cell_value) != TYPE_DICTIONARY:
				continue
			var cell_info: Dictionary = cell_value
			var color := _color_from_value(cell_info.get("minimap_color", []), Color(0.12, 0.16, 0.19, 1.0))
			color.a = 0.16
			_fill_image_map_rect(image, texture_size, map_size, _vector2_from_value(cell_info.get("cell", Vector2.ZERO)), Vector2.ONE, color)
		return
	for region_value in _snapshot.get("regions", []):
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		var color := _color_from_value(region.get("minimap_color", []), Color(0.12, 0.16, 0.19, 1.0))
		color.a = 0.22
		for rect_value in region.get("grid_rects", []):
			var rect := _grid_rect_array_to_origin_size(rect_value)
			if rect.size.x > 0.0 and rect.size.y > 0.0:
				_fill_image_map_rect(image, texture_size, map_size, rect.position, rect.size, color)

func _paint_static_water_to_image(image: Image, texture_size: Vector2i, map_size: Vector2) -> void:
	var water_cells: Array = _snapshot.get("water_cells", [])
	if not water_cells.is_empty():
		var water_color := Color(0.08, 0.62, 0.86, 0.46)
		for cell_value in water_cells:
			_fill_image_map_rect(image, texture_size, map_size, _vector2_from_value(cell_value), Vector2.ONE, water_color)
		return
	for water_value in _snapshot.get("water_bodies", []):
		if typeof(water_value) != TYPE_DICTIONARY:
			continue
		var water: Dictionary = water_value
		var water_color := Color(0.08, 0.62, 0.86, 0.50)
		for rect_value in water.get("grid_rects", []):
			var rect := _grid_rect_array_to_origin_size(rect_value)
			if rect.size.x > 0.0 and rect.size.y > 0.0:
				_fill_image_map_rect(image, texture_size, map_size, rect.position, rect.size, water_color)

func _paint_static_frontiers_to_image(image: Image, texture_size: Vector2i, map_size: Vector2) -> void:
	var groups: Dictionary = _snapshot.get("frontier_cell_groups", {})
	var typed_frontier_found := false
	for tag in groups.keys():
		var color := _frontier_color(str(tag))
		for cell_value in groups[tag]:
			typed_frontier_found = true
			_fill_image_map_rect(image, texture_size, map_size, _vector2_from_value(cell_value), Vector2.ONE, color)
	if not typed_frontier_found:
		for cell_value in _snapshot.get("frontier_cells", []):
			_fill_image_map_rect(image, texture_size, map_size, _vector2_from_value(cell_value), Vector2.ONE, Color(0.46, 0.78, 0.86, 0.58))
	for cell_value in _snapshot.get("gate_cells", []):
		_fill_image_map_rect(image, texture_size, map_size, _vector2_from_value(cell_value), Vector2.ONE, Color(0.80, 0.96, 1.0, 0.72))
	for cell_value in _snapshot.get("risk_bypass_cells", []):
		_fill_image_map_rect(image, texture_size, map_size, _vector2_from_value(cell_value), Vector2.ONE, Color(1.0, 0.62, 0.28, 0.70))

func _frontier_color(tag: String) -> Color:
	match tag:
		"crystal_frontier":
			return Color(0.10, 0.82, 1.0, 0.64)
		"wreckage_frontier":
			return Color(1.0, 0.52, 0.18, 0.62)
		"interference_frontier":
			return Color(0.66, 0.98, 0.28, 0.58)
		"core_frontier":
			return Color(0.76, 0.38, 1.0, 0.64)
	return Color(0.46, 0.78, 0.86, 0.58)

func _draw_pump_candidates(content_rect: Rect2, map_size: Vector2) -> void:
	for cell_value in _snapshot.get("pump_candidate_cells", []):
		var point := _map_point(_vector2_from_value(cell_value) + Vector2(0.5, 0.5), content_rect, map_size)
		draw_circle(point, 2.6, Color(0.76, 1.0, 0.94, 0.95))
		draw_circle(point, 4.3, Color(0.20, 0.85, 1.0, 0.25))

func _fill_image_map_rect(image: Image, texture_size: Vector2i, map_size: Vector2, origin: Vector2, rect_size: Vector2, color: Color) -> void:
	var start := Vector2i(
		clampi(floori(origin.x / maxf(map_size.x, 0.001) * float(texture_size.x)), 0, texture_size.x),
		clampi(floori(origin.y / maxf(map_size.y, 0.001) * float(texture_size.y)), 0, texture_size.y)
	)
	var end := Vector2i(
		clampi(ceili((origin.x + rect_size.x) / maxf(map_size.x, 0.001) * float(texture_size.x)), 0, texture_size.x),
		clampi(ceili((origin.y + rect_size.y) / maxf(map_size.y, 0.001) * float(texture_size.y)), 0, texture_size.y)
	)
	var pixel_size := end - start
	if pixel_size.x <= 0 or pixel_size.y <= 0:
		return
	image.fill_rect(Rect2i(start, pixel_size), color)

func _grid_rect_array_to_origin_size(value: Variant) -> Rect2:
	if typeof(value) != TYPE_ARRAY or value.size() < 4:
		return Rect2()
	return Rect2(Vector2(float(value[0]), float(value[1])), Vector2(float(value[2]), float(value[3])))

func _make_redraw_key(snapshot: Dictionary) -> String:
	return JSON.stringify([
		snapshot.get("static_version", 0),
		snapshot.get("resources", []),
		snapshot.get("enemy_nests", []),
		snapshot.get("main_base", {}),
		snapshot.get("supply_points", []),
		snapshot.get("region_signals", []),
		snapshot.get("water_flow_target_cell", []),
		snapshot.get("viewport_rect", {}),
	])

func _draw_regions(content_rect: Rect2, map_size: Vector2) -> void:
	var region_cells: Array = _snapshot.get("region_cells", [])
	if not region_cells.is_empty():
		for cell_value in region_cells:
			if typeof(cell_value) != TYPE_DICTIONARY:
				continue
			var cell_info: Dictionary = cell_value
			var color := _color_from_value(cell_info.get("minimap_color", []), Color(0.12, 0.16, 0.19, 1.0))
			color.a = 0.16
			var cell := _vector2_from_value(cell_info.get("cell", Vector2.ZERO))
			draw_rect(_map_rect_from_origin_size(cell, Vector2.ONE, content_rect, map_size), color, true)
		return

	var regions: Array = _snapshot.get("regions", [])
	for region_value in regions:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		var color := _color_from_value(region.get("minimap_color", []), Color(0.12, 0.16, 0.19, 1.0))
		color.a = 0.22
		for rect_value in region.get("grid_rects", []):
			var rect := _map_rect_from_grid_rect(rect_value, content_rect, map_size)
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				continue
			draw_rect(rect, color, true)
		var outline_cells: Array = region.get("visual_outline_cells", [])
		if outline_cells.size() >= 2:
			var outline_color := _color_from_value(region.get("minimap_color", []), Color(0.5, 0.7, 0.8, 1.0))
			outline_color.a = 0.72
			_draw_cell_polyline(outline_cells, content_rect, map_size, outline_color, true)

func _draw_water_bodies(content_rect: Rect2, map_size: Vector2) -> void:
	var water_cells: Array = _snapshot.get("water_cells", [])
	if not water_cells.is_empty():
		var water_color := Color(0.08, 0.62, 0.86, 0.46)
		for cell_value in water_cells:
			var rect := _map_rect_from_origin_size(cell_value, Vector2.ONE, content_rect, map_size)
			draw_rect(rect, water_color, true)
		for cell_value in _snapshot.get("pump_candidate_cells", []):
			var point := _map_point(_vector2_from_value(cell_value) + Vector2(0.5, 0.5), content_rect, map_size)
			draw_circle(point, 2.6, Color(0.76, 1.0, 0.94, 0.95))
			draw_circle(point, 4.3, Color(0.20, 0.85, 1.0, 0.25))
		return

	for water_value in _snapshot.get("water_bodies", []):
		if typeof(water_value) != TYPE_DICTIONARY:
			continue
		var water: Dictionary = water_value
		var water_color := Color(0.08, 0.62, 0.86, 0.50)
		for rect_value in water.get("grid_rects", []):
			var rect := _map_rect_from_grid_rect(rect_value, content_rect, map_size)
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				continue
			draw_rect(rect, water_color, true)
			draw_rect(rect, Color(0.56, 0.90, 1.0, 0.70), false, 1.0)
		for cell_value in water.get("pump_candidate_cells", []):
			var point := _map_point(_vector2_from_value(cell_value) + Vector2(0.5, 0.5), content_rect, map_size)
			draw_circle(point, 2.6, Color(0.76, 1.0, 0.94, 0.95))
			draw_circle(point, 4.3, Color(0.20, 0.85, 1.0, 0.25))

func _draw_region_connections(content_rect: Rect2, map_size: Vector2) -> void:
	for connection_value in _snapshot.get("region_connections", []):
		if typeof(connection_value) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_value
		var gate_cells: Array = connection.get("gate_cells", [])
		if gate_cells.is_empty():
			continue
		var color := Color(0.74, 0.95, 1.0, 0.62)
		if str(connection.get("connection_type", "")) == "risk_bypass":
			color = Color(1.0, 0.66, 0.32, 0.62)
		_draw_cell_polyline(gate_cells, content_rect, map_size, color, false)
		for cell_value in gate_cells:
			var point := _map_point(_vector2_from_value(cell_value) + Vector2(0.5, 0.5), content_rect, map_size)
			draw_circle(point, 1.7, color)

func _draw_water_flows(content_rect: Rect2, map_size: Vector2) -> void:
	var flow_target := _vector2_from_value(_snapshot.get("water_flow_target_cell", Vector2(-1, -1)))
	if flow_target.x < 0.0 or flow_target.y < 0.0:
		return
	var target := _map_point(flow_target + Vector2(0.5, 0.5), content_rect, map_size)
	var pump_cells: Array = _snapshot.get("pump_candidate_cells", [])
	if not pump_cells.is_empty():
		for cell_value in pump_cells:
			var start := _map_point(_vector2_from_value(cell_value) + Vector2(0.5, 0.5), content_rect, map_size)
			draw_line(start, target, Color(0.26, 0.82, 1.0, 0.20), 1.0)
		return

	for water_value in _snapshot.get("water_bodies", []):
		if typeof(water_value) != TYPE_DICTIONARY:
			continue
		var water: Dictionary = water_value
		for cell_value in water.get("pump_candidate_cells", []):
			var start := _map_point(_vector2_from_value(cell_value) + Vector2(0.5, 0.5), content_rect, map_size)
			draw_line(start, target, Color(0.26, 0.82, 1.0, 0.20), 1.0)

func _draw_resources(content_rect: Rect2, map_size: Vector2) -> void:
	for item_value in _snapshot.get("resources", []):
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		if not bool(item.get("discovered", false)):
			continue
		var cell := _vector2_from_value(item.get("cell", Vector2.ZERO))
		var color := Color(0.78, 0.82, 0.84, 0.95)
		if str(item.get("resource_id", "")) == "copper_ore":
			color = Color(0.95, 0.52, 0.22, 0.96)
		elif str(item.get("resource_id", "")) == "crystal":
			color = Color(0.42, 0.95, 1.0, 0.96)
		var point := _map_point(cell + Vector2(0.5, 0.5), content_rect, map_size)
		_draw_diamond(point, 2.8, color)

func _draw_main_base(content_rect: Rect2, map_size: Vector2) -> void:
	var base: Dictionary = _snapshot.get("main_base", {})
	if base.is_empty():
		return
	var rect := _map_rect_from_origin_size(base.get("origin", Vector2.ZERO), base.get("size", Vector2.ONE), content_rect, map_size)
	draw_rect(rect.grow(1.5), Color(0.18, 0.74, 1.0, 0.92), true)
	draw_rect(rect.grow(3.0), Color(0.18, 0.74, 1.0, 0.30), false, 1.0)

func _draw_enemy_nests(content_rect: Rect2, map_size: Vector2) -> void:
	for nest_value in _snapshot.get("enemy_nests", []):
		if typeof(nest_value) != TYPE_DICTIONARY:
			continue
		var nest: Dictionary = nest_value
		if not bool(nest.get("discovered", false)):
			continue
		var rect := _map_rect_from_origin_size(nest.get("origin", Vector2.ZERO), nest.get("size", Vector2.ONE), content_rect, map_size)
		var center := rect.get_center()
		draw_circle(center, maxf(4.0, rect.size.length() * 0.55), Color(1.0, 0.28, 0.16, 0.24))
		draw_rect(rect.grow(1.5), Color(1.0, 0.28, 0.16, 0.92), false, 2.0)
		draw_line(center + Vector2(-4, 0), center + Vector2(4, 0), Color(1.0, 0.52, 0.32, 0.95), 1.5)
		draw_line(center + Vector2(0, -4), center + Vector2(0, 4), Color(1.0, 0.52, 0.32, 0.95), 1.5)

func _draw_region_signals(content_rect: Rect2, map_size: Vector2) -> void:
	for signal_value in _snapshot.get("region_signals", []):
		if typeof(signal_value) != TYPE_DICTIONARY:
			continue
		var signal_info: Dictionary = signal_value
		var point := _map_point(_vector2_from_value(signal_info.get("cell", Vector2.ZERO)), content_rect, map_size)
		var color := Color(1.0, 0.42, 0.20, 0.86)
		draw_circle(point, 4.5, Color(color.r, color.g, color.b, 0.18))
		draw_circle(point, 2.3, color)
		draw_line(point + Vector2(-6, 0), point + Vector2(6, 0), Color(color.r, color.g, color.b, 0.54), 1.0)
		draw_line(point + Vector2(0, -6), point + Vector2(0, 6), Color(color.r, color.g, color.b, 0.54), 1.0)

func _draw_supply_points(content_rect: Rect2, map_size: Vector2) -> void:
	for point_value in _snapshot.get("supply_points", []):
		if typeof(point_value) != TYPE_DICTIONARY:
			continue
		var supply: Dictionary = point_value
		if not bool(supply.get("discovered", true)):
			continue
		var point := _map_point(_vector2_from_value(supply.get("cell", Vector2.ZERO)) + Vector2(0.5, 0.5), content_rect, map_size)
		draw_circle(point, 4.0, Color(0.75, 1.0, 0.56, 0.94))
		draw_line(point + Vector2(-5, 0), point + Vector2(5, 0), Color(0.12, 0.28, 0.12, 0.9), 1.2)
		draw_line(point + Vector2(0, -5), point + Vector2(0, 5), Color(0.12, 0.28, 0.12, 0.9), 1.2)

func _draw_camera(content_rect: Rect2, map_size: Vector2) -> void:
	var viewport_rect := _rect2_from_value(_snapshot.get("viewport_rect", {}))
	if viewport_rect.size.x > 0.0 and viewport_rect.size.y > 0.0:
		var mini_rect := Rect2(
			_map_point(viewport_rect.position, content_rect, map_size),
			_view_size_to_minimap(viewport_rect.size, content_rect, map_size)
		)
		draw_rect(mini_rect, Color(1.0, 1.0, 1.0, 0.22), true)
		draw_rect(mini_rect, Color(1.0, 1.0, 1.0, 0.88), false, 1.0)

func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius, 0),
	])
	draw_colored_polygon(points, color)

func _draw_cell_polyline(cells: Array, content_rect: Rect2, map_size: Vector2, color: Color, closed: bool) -> void:
	var points := PackedVector2Array()
	for cell_value in cells:
		points.append(_map_point(_vector2_from_value(cell_value) + Vector2(0.5, 0.5), content_rect, map_size))
	if points.size() < 2:
		return
	var segment_count := points.size() if closed else points.size() - 1
	for index in range(segment_count):
		var start: Vector2 = points[index]
		var end: Vector2 = points[(index + 1) % points.size()]
		draw_line(start, end, color, 1.0)

func _get_content_rect(map_size: Vector2) -> Rect2:
	var title_height := 20.0
	var available := Rect2(
		Vector2(INNER_PADDING, title_height + INNER_PADDING * 0.45),
		size - Vector2(INNER_PADDING * 2.0, title_height + INNER_PADDING * 1.45)
	)
	var map_scale := minf(available.size.x / map_size.x, available.size.y / map_size.y)
	var content_size := map_size * map_scale
	return Rect2(available.position + (available.size - content_size) * 0.5, content_size)

func _map_point(cell_position: Vector2, content_rect: Rect2, map_size: Vector2) -> Vector2:
	return content_rect.position + Vector2(
		cell_position.x / maxf(map_size.x, 0.001) * content_rect.size.x,
		cell_position.y / maxf(map_size.y, 0.001) * content_rect.size.y
	)

func _view_size_to_minimap(world_size: Vector2, content_rect: Rect2, map_size: Vector2) -> Vector2:
	return Vector2(
		world_size.x / maxf(map_size.x, 0.001) * content_rect.size.x,
		world_size.y / maxf(map_size.y, 0.001) * content_rect.size.y
	)

func _map_rect_from_grid_rect(value: Variant, content_rect: Rect2, map_size: Vector2) -> Rect2:
	if typeof(value) != TYPE_ARRAY or value.size() < 4:
		return Rect2()
	return _map_rect_from_origin_size(Vector2(float(value[0]), float(value[1])), Vector2(float(value[2]), float(value[3])), content_rect, map_size)

func _map_rect_from_origin_size(origin_value: Variant, size_value: Variant, content_rect: Rect2, map_size: Vector2) -> Rect2:
	var origin := _vector2_from_value(origin_value)
	var rect_size := _vector2_from_value(size_value)
	var start := _map_point(origin, content_rect, map_size)
	var end := _map_point(origin + rect_size, content_rect, map_size)
	return Rect2(start, end - start)

func _vector2_from_value(value: Variant) -> Vector2:
	match typeof(value):
		TYPE_VECTOR2:
			return value
		TYPE_VECTOR2I:
			var vector_i: Vector2i = value
			return Vector2(vector_i)
		TYPE_ARRAY:
			var array: Array = value
			if array.size() >= 2:
				return Vector2(float(array[0]), float(array[1]))
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
	return Vector2.ZERO

func _rect2_from_value(value: Variant) -> Rect2:
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var dict: Dictionary = value
	return Rect2(_vector2_from_value(dict.get("position", Vector2.ZERO)), _vector2_from_value(dict.get("size", Vector2.ZERO)))

func _color_from_value(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if typeof(value) != TYPE_ARRAY or value.size() < 4:
		return fallback
	return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
