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
@export var show_region_debug_rects: bool = false
@export var show_region_visual_features: bool = true
@export var show_editor_region_preview: bool = false
@export_file("*.json") var editor_region_preview_config_path: String = "res://Resources/data/maps/mvp_stage3_map.json"
@export_range(0.0, 1.0, 0.01) var editor_region_preview_min_alpha: float = 0.14
@export_range(0.0, 1.0, 0.01) var editor_region_preview_outline_alpha: float = 0.42

const TERRAIN_SIGNATURE_ASSETS := {
	"water_ripple_mark": "res://Resources/art/map/terrain_signatures/water_ripple_mark.svg",
	"shoreline_dash": "res://Resources/art/map/terrain_signatures/shoreline_dash.svg",
	"pump_anchor": "res://Resources/art/map/terrain_signatures/pump_anchor.svg",
	"crystal_cluster_small": "res://Resources/art/map/terrain_signatures/crystal_cluster_small.svg",
	"fracture_line_mark": "res://Resources/art/map/terrain_signatures/fracture_line_mark.svg",
	"interference_tick": "res://Resources/art/map/terrain_signatures/interference_tick.svg",
	"wreckage_mark": "res://Resources/art/map/terrain_signatures/wreckage_mark.svg",
	"core_ring_mark": "res://Resources/art/map/terrain_signatures/core_ring_mark.svg",
}

var region_states: Dictionary = {}
var region_signal_cells: Dictionary = {}
var region_visuals: Array = []
var region_block_defs: Dictionary = {}
var region_routes: Array = []
var water_bodies: Array = []
var _terrain_signature_cache: Dictionary = {}

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

func set_region_visuals(next_region_visuals: Array, next_region_block_defs: Dictionary) -> void:
	region_visuals = next_region_visuals.duplicate(true)
	region_block_defs = next_region_block_defs.duplicate(true)
	_queue_stable_redraw()

func set_region_routes(next_region_routes: Array) -> void:
	region_routes = next_region_routes.duplicate(true)
	_queue_stable_redraw()

func set_water_bodies(next_water_bodies: Array) -> void:
	water_bodies = next_water_bodies.duplicate(true)
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

func _draw_region_visuals() -> void:
	_draw_region_base_tints()
	if show_region_visual_features:
		_draw_region_outlines()
		_draw_region_features()
	if show_region_debug_rects:
		_draw_region_debug_rects()

func _draw_region_base_tints() -> void:
	for region_value in region_visuals:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		var fill_color := _color_from_value(region.get("fill_color", []), Color.TRANSPARENT)
		if _is_editor_region_preview_active():
			fill_color.a = clampf(maxf(fill_color.a, editor_region_preview_min_alpha), 0.0, 0.28)
		else:
			fill_color.a = minf(fill_color.a, 0.16)
		var rects: Array = region.get("grid_rects", [])
		for rect_value in rects:
			var rect := _grid_rect_from_value(rect_value)
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				continue
			if fill_color.a > 0.0:
				draw_rect(rect, fill_color, true)

func _load_editor_region_preview() -> void:
	if not Engine.is_editor_hint():
		return
	if not show_editor_region_preview:
		return
	if not region_visuals.is_empty():
		return
	if editor_region_preview_config_path.is_empty():
		return
	if not FileAccess.file_exists(editor_region_preview_config_path):
		return
	var file := FileAccess.open(editor_region_preview_config_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	if parsed.has("map_size"):
		var next_map_size := _cell_from_value(parsed.get("map_size"))
		if next_map_size.x > 0 and next_map_size.y > 0:
			map_size_cells = next_map_size
	if parsed.has("cell_size"):
		var next_cell_size := int(parsed.get("cell_size", cell_size))
		if next_cell_size > 0:
			cell_size = next_cell_size
	var regions: Array = parsed.get("regions", [])
	var preview_regions: Array = []
	for region_value in regions:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value.duplicate(true)
		region["visual_features"] = []
		preview_regions.append(region)
	region_visuals = preview_regions

func _is_editor_region_preview_active() -> bool:
	return Engine.is_editor_hint() and show_editor_region_preview

func _draw_region_debug_rects() -> void:
	for region_value in region_visuals:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		var border_color := _color_from_value(region.get("border_color", []), Color(0.6, 0.8, 1.0, 0.35))
		border_color.a = maxf(border_color.a, 0.35)
		for rect_value in region.get("grid_rects", []):
			var rect := _grid_rect_from_value(rect_value)
			if rect.size.x > 0.0 and rect.size.y > 0.0:
				draw_rect(rect, border_color, false, 2.0)

func _draw_region_outlines() -> void:
	for region_value in region_visuals:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		var outline_cells: Array = region.get("visual_outline_cells", [])
		if outline_cells.size() < 2:
			continue
		var color := _color_from_value(region.get("border_color", []), _color_from_value(region.get("pattern_color", []), Color(0.6, 0.8, 1.0, 0.20)))
		var width := 1.35
		if _is_editor_region_preview_active():
			color.a = maxf(color.a, editor_region_preview_outline_alpha)
			width = 2.2
		else:
			color.a = maxf(color.a, 0.18)
		_draw_dashed_cell_polyline(outline_cells, color, width, false)

func _draw_region_features() -> void:
	for region_value in region_visuals:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		var color := _color_from_value(region.get("pattern_color", []), Color(0.7, 0.9, 1.0, 0.16))
		var features: Array = region.get("visual_features", [])
		for feature_value in features:
			if typeof(feature_value) != TYPE_DICTIONARY:
				continue
			_draw_visual_feature(feature_value, color)

func _draw_visual_feature(feature: Dictionary, base_color: Color) -> void:
	var feature_type := str(feature.get("type", ""))
	match feature_type:
		"basin_scan_ring":
			_draw_basin_scan_ring(feature, base_color)
		"crystal_cluster":
			_draw_crystal_clusters(feature.get("cells", []), base_color)
		"fracture_line":
			_draw_fracture_line(feature.get("path_cells", []), base_color)
		"scan_noise_band":
			_draw_scan_noise_bands(feature.get("grid_rects", []), base_color)
		"interference_ticks":
			_draw_interference_ticks(feature.get("cells", []), base_color)
		"wreckage_marks":
			_draw_wreckage_marks(feature.get("cells", []), base_color)
		"hazard_stripes":
			_draw_hazard_stripes(feature.get("grid_rects", []), base_color)
		"core_rings":
			_draw_core_rings(feature, base_color)
		"asset_stamp":
			_draw_asset_stamps(feature, base_color)
		"asset_scatter":
			_draw_asset_scatter(feature, base_color)

func _draw_basin_scan_ring(feature: Dictionary, color: Color) -> void:
	var center := (_vector2_from_value(feature.get("center_cell", Vector2.ZERO)) + Vector2(0.5, 0.5)) * float(cell_size)
	var radius := float(feature.get("radius_cells", 8)) * float(cell_size)
	var ring_color := Color(color.r, color.g, color.b, minf(maxf(color.a, 0.08), 0.16))
	for i in range(3):
		var start_angle := float(i) * TAU / 3.0 + 0.18
		draw_arc(center, radius, start_angle, start_angle + TAU * 0.22, 48, ring_color, 1.1)

func _draw_crystal_clusters(cells: Array, color: Color) -> void:
	var crystal_color := Color(color.r, color.g, color.b, maxf(color.a, 0.22))
	for cell_value in cells:
		var center := (_vector2_from_value(cell_value) + Vector2(0.5, 0.5)) * float(cell_size)
		var radius := float(cell_size) * 0.18
		var points := PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius * 0.72, radius * 0.86),
			center + Vector2(-radius * 0.86, radius * 0.62),
		])
		draw_polyline(points, crystal_color, 1.4, true)
		draw_line(center + Vector2(-radius * 0.28, radius * 0.46), center + Vector2(radius * 0.20, -radius * 0.55), Color(crystal_color.r, crystal_color.g, crystal_color.b, crystal_color.a * 0.75), 1.0)

func _draw_fracture_line(path_cells: Array, color: Color) -> void:
	if path_cells.size() < 2:
		return
	var points := _points_from_cells(path_cells)
	var line_color := Color(color.r, color.g, color.b, maxf(color.a, 0.20))
	for index in range(points.size() - 1):
		var start: Vector2 = points[index]
		var end: Vector2 = points[index + 1]
		draw_line(start, end, line_color, 1.4)
		var mid := start.lerp(end, 0.52)
		var dir := (end - start).normalized()
		var normal := Vector2(-dir.y, dir.x)
		draw_line(mid, mid + normal * float(cell_size) * 0.16, Color(line_color.r, line_color.g, line_color.b, line_color.a * 0.75), 1.0)

func _draw_scan_noise_bands(rect_values: Array, color: Color) -> void:
	var noise_color := Color(color.r, color.g, color.b, maxf(color.a, 0.12))
	for rect_value in rect_values:
		var rect := _grid_rect_from_value(rect_value)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var y := rect.position.y + float(cell_size) * 0.5
		var row := 0
		while y < rect.end.y:
			var offset := float((row % 3) - 1) * float(cell_size) * 0.22
			var start := Vector2(rect.position.x + offset, y)
			var end := Vector2(rect.end.x - float(cell_size) * 0.28 + offset, y + float(cell_size) * 0.12)
			draw_line(start, end, noise_color, 1.0)
			y += float(cell_size) * 0.85
			row += 1

func _draw_interference_ticks(cells: Array, color: Color) -> void:
	var tick_color := Color(color.r, color.g, color.b, maxf(color.a, 0.18))
	for cell_value in cells:
		var center := (_vector2_from_value(cell_value) + Vector2(0.5, 0.5)) * float(cell_size)
		draw_line(center + Vector2(-12, -2), center + Vector2(12, -2), tick_color, 1.2)
		draw_line(center + Vector2(-8, 5), center + Vector2(9, 5), Color(tick_color.r, tick_color.g, tick_color.b, tick_color.a * 0.65), 1.0)
		draw_arc(center, float(cell_size) * 0.20, -0.4, 1.2, 18, Color(tick_color.r, tick_color.g, tick_color.b, tick_color.a * 0.45), 1.0)

func _draw_wreckage_marks(cells: Array, color: Color) -> void:
	var mark_color := Color(color.r, color.g, color.b, maxf(color.a, 0.22))
	for cell_value in cells:
		var center := (_vector2_from_value(cell_value) + Vector2(0.5, 0.5)) * float(cell_size)
		draw_line(center + Vector2(-11, -8), center + Vector2(10, 9), mark_color, 1.6)
		draw_line(center + Vector2(-9, 8), center + Vector2(12, -6), Color(mark_color.r, mark_color.g, mark_color.b, mark_color.a * 0.72), 1.2)
		draw_rect(Rect2(center + Vector2(4, -12), Vector2(10, 6)), Color(mark_color.r, mark_color.g, mark_color.b, mark_color.a * 0.42), false, 1.0)

func _draw_hazard_stripes(rect_values: Array, color: Color) -> void:
	var stripe_color := Color(color.r, color.g, color.b, maxf(color.a, 0.18))
	for rect_value in rect_values:
		var rect := _grid_rect_from_value(rect_value)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var x := rect.position.x - rect.size.y
		while x < rect.end.x:
			draw_line(Vector2(x, rect.end.y), Vector2(x + rect.size.y, rect.position.y), stripe_color, 1.1)
			x += float(cell_size) * 0.72

func _draw_core_rings(feature: Dictionary, color: Color) -> void:
	var center := (_vector2_from_value(feature.get("center_cell", Vector2.ZERO)) + Vector2(0.5, 0.5)) * float(cell_size)
	var radius := float(feature.get("radius_cells", 5)) * float(cell_size)
	var ring_color := Color(color.r, color.g, color.b, maxf(color.a, 0.20))
	for i in range(2):
		draw_arc(center, radius * (0.68 + float(i) * 0.26), 0.0, TAU, 72, ring_color, 1.2)
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(center + dir * radius * 0.82, center + dir * radius * 1.08, Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * 0.72), 1.0)

func _draw_asset_stamps(feature: Dictionary, fallback_color: Color) -> void:
	var texture := _get_terrain_signature_texture(str(feature.get("asset_id", "")), str(feature.get("asset_path", "")))
	if texture == null:
		return
	var cells: Array = feature.get("cells", [])
	if cells.is_empty() and feature.has("cell"):
		cells = [feature.get("cell")]
	var alpha := float(feature.get("alpha", maxf(fallback_color.a, 0.22)))
	var tint := _color_from_value(feature.get("tint", []), Color(fallback_color.r, fallback_color.g, fallback_color.b, alpha))
	tint.a = alpha
	for index in range(cells.size()):
		var center := (_vector2_from_value(cells[index]) + Vector2(0.5, 0.5)) * float(cell_size)
		var rotation_degrees := _rotation_degrees_for_stamp(feature.get("rotation_degrees", 0.0), index)
		var default_size_cells := 0.62 * maxf(0.1, float(feature.get("scale", 1.0)))
		var size_cells := _stamp_size_cells_for_index(feature.get("size_cells", default_size_cells), index, default_size_cells)
		_draw_texture_stamp(texture, center, size_cells, deg_to_rad(rotation_degrees), tint)

func _draw_asset_scatter(feature: Dictionary, fallback_color: Color) -> void:
	var texture := _get_terrain_signature_texture(str(feature.get("asset_id", "")), str(feature.get("asset_path", "")))
	if texture == null:
		return
	var anchor_rects: Array = feature.get("anchor_rects", [])
	if anchor_rects.is_empty():
		return
	var count: int = max(0, int(feature.get("count", 0)))
	var seed: int = int(feature.get("seed", 1))
	var distribution: String = str(feature.get("distribution", "interior"))
	var base_tint := _color_from_value(feature.get("tint", []), Color(fallback_color.r, fallback_color.g, fallback_color.b, maxf(fallback_color.a, 0.28)))
	for index in range(count):
		var rect := _cell_rect_from_value(anchor_rects[index % anchor_rects.size()])
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var center := _scatter_cell_position(rect, distribution, seed, index) * float(cell_size)
		var alpha := _ranged_float(feature.get("alpha", maxf(base_tint.a, 0.28)), index, seed, 11, maxf(base_tint.a, 0.28))
		var size_cells := _ranged_float(feature.get("size_cells", 0.85), index, seed, 23, 0.85)
		var rotation_degrees := _ranged_float(feature.get("rotation_degrees", 0.0), index, seed, 37, 0.0)
		var tint := Color(base_tint.r, base_tint.g, base_tint.b, alpha)
		_draw_texture_stamp(texture, center, size_cells, deg_to_rad(rotation_degrees), tint)

func _draw_texture_stamp(texture: Texture2D, center: Vector2, size_cells: float, rotation: float, tint: Color) -> void:
	var base_size := float(cell_size) * maxf(0.1, size_cells)
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var draw_size := Vector2(base_size, base_size * texture_size.y / texture_size.x)
	draw_set_transform(center, rotation, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-draw_size * 0.5, draw_size), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _rotation_degrees_for_stamp(value: Variant, index: int) -> float:
	if typeof(value) == TYPE_ARRAY:
		var rotations: Array = value
		if rotations.is_empty():
			return 0.0
		return float(rotations[index % rotations.size()])
	return float(value)

func _stamp_size_cells_for_index(value: Variant, index: int, fallback: float) -> float:
	if typeof(value) == TYPE_ARRAY:
		var sizes: Array = value
		if sizes.is_empty():
			return fallback
		return maxf(0.1, float(sizes[index % sizes.size()]))
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return maxf(0.1, float(value))
	return maxf(0.1, fallback)

func _ranged_float(value: Variant, index: int, seed: int, salt: int, fallback: float) -> float:
	if typeof(value) == TYPE_ARRAY:
		var values: Array = value
		if values.size() >= 2:
			var from_value := float(values[0])
			var to_value := float(values[1])
			return lerpf(from_value, to_value, _hash_unit(seed, index, salt))
		if values.size() == 1:
			return float(values[0])
		return fallback
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback

func _scatter_cell_position(rect: Rect2, distribution: String, seed: int, index: int) -> Vector2:
	if distribution == "boundary":
		var side := int(floorf(_hash_unit(seed, index, 41) * 4.0))
		var t := _hash_unit(seed, index, 43)
		var inset := lerpf(0.18, 0.82, _hash_unit(seed, index, 47))
		match side:
			0:
				return Vector2(lerpf(rect.position.x, rect.end.x, t), rect.position.y + inset)
			1:
				return Vector2(rect.end.x - inset, lerpf(rect.position.y, rect.end.y, t))
			2:
				return Vector2(lerpf(rect.position.x, rect.end.x, t), rect.end.y - inset)
			_:
				return Vector2(rect.position.x + inset, lerpf(rect.position.y, rect.end.y, t))
	return rect.position + Vector2(
		_hash_unit(seed, index, 53) * rect.size.x,
		_hash_unit(seed, index, 59) * rect.size.y
	)

func _hash_unit(seed: int, index: int, salt: int) -> float:
	var value := sin(float(seed * 928371 + index * 364479 + salt * 1013)) * 43758.5453
	return value - floorf(value)

func _get_terrain_signature_texture(asset_id: String, asset_path: String = "") -> Texture2D:
	var path := asset_path
	if path.is_empty():
		path = str(TERRAIN_SIGNATURE_ASSETS.get(asset_id, ""))
	if path.is_empty():
		return null
	if _terrain_signature_cache.has(path):
		return _terrain_signature_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	_terrain_signature_cache[path] = texture
	return texture

func _draw_dashed_cell_polyline(cells: Array, color: Color, width: float, closed: bool) -> void:
	var points := _points_from_cells(cells)
	if points.size() < 2:
		return
	var segment_count := points.size() if closed else points.size() - 1
	for index in range(segment_count):
		if index % 3 == 2:
			continue
		var start: Vector2 = points[index]
		var end: Vector2 = points[(index + 1) % points.size()]
		draw_line(start, end, color, width)
		draw_circle(start, width * 1.2, Color(color.r, color.g, color.b, color.a * 0.75))

func _points_from_cells(cells: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for cell_value in cells:
		points.append((_vector2_from_value(cell_value) + Vector2(0.5, 0.5)) * float(cell_size))
	return points

func _draw_region_pattern(rect: Rect2, pattern: String, color: Color) -> void:
	var step := float(cell_size * 4)
	match pattern:
		"crystal":
			var x := rect.position.x + step * 0.5
			while x < rect.end.x:
				var y := rect.position.y + step * 0.45
				while y < rect.end.y:
					var p := Vector2(x, y)
					draw_line(p + Vector2(-8, 10), p + Vector2(0, -12), color, 1.5)
					draw_line(p + Vector2(0, -12), p + Vector2(9, 9), color, 1.5)
					draw_line(p + Vector2(-8, 10), p + Vector2(9, 9), color, 1.0)
					y += step
				x += step
		"interference":
			var y := rect.position.y + step * 0.35
			while y < rect.end.y:
				draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y + step * 0.2), color, 1.2)
				y += step * 0.7
		"wreckage":
			var x := rect.position.x + step * 0.4
			while x < rect.end.x:
				var y := rect.position.y + step * 0.25
				while y < rect.end.y:
					draw_line(Vector2(x - 10, y + 10), Vector2(x + 12, y - 8), color, 2.0)
					draw_line(Vector2(x + 5, y + 12), Vector2(x + 17, y + 2), color, 1.4)
					y += step
				x += step
		"core":
			var center := rect.get_center()
			var max_radius := minf(rect.size.x, rect.size.y) * 0.42
			for i in range(3):
				draw_arc(center, max_radius * (0.45 + float(i) * 0.22), 0.0, TAU, 64, color, 1.2)
		_:
			var y := rect.position.y + step
			while y < rect.end.y:
				draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), color, 0.8)
				y += step

func _draw_boundary_water_edges(water_cells: Array, color: Color) -> void:
	var water_lookup := {}
	for cell in water_cells:
		water_lookup[_cell_key(cell)] = true
	var side_defs := [
		[Vector2i(0, -1), Vector2(0.0, 0.0), Vector2(1.0, 0.0)],
		[Vector2i(1, 0), Vector2(1.0, 0.0), Vector2(1.0, 1.0)],
		[Vector2i(0, 1), Vector2(1.0, 1.0), Vector2(0.0, 1.0)],
		[Vector2i(-1, 0), Vector2(0.0, 1.0), Vector2(0.0, 0.0)],
	]
	for cell in water_cells:
		var origin := Vector2(cell) * float(cell_size)
		for side in side_defs:
			var neighbor: Vector2i = cell + side[0]
			if water_lookup.has(_cell_key(neighbor)):
				continue
			var start: Vector2 = origin + side[1] * float(cell_size)
			var end: Vector2 = origin + side[2] * float(cell_size)
			draw_line(start, end, color, 1.2)

func _boundary_water_cells(boundary: Dictionary) -> Array:
	var cells: Array = []
	for rect_value in boundary.get("water_cell_rects", []):
		var rect := _cell_rect_from_value(rect_value)
		for x in range(int(rect.position.x), int(rect.position.x + rect.size.x)):
			for y in range(int(rect.position.y), int(rect.position.y + rect.size.y)):
				cells.append(Vector2i(x, y))
	for cell_value in boundary.get("water_cells", []):
		cells.append(_cell_from_value(cell_value))
	return _unique_cells(cells)

func _unique_cells(cells: Array) -> Array:
	var seen := {}
	var result: Array = []
	for cell in cells:
		var cell_key := _cell_key(cell)
		if seen.has(cell_key):
			continue
		seen[cell_key] = true
		result.append(cell)
	return result

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _cell_lookup_from_values(cell_values: Array) -> Dictionary:
	var result := {}
	for cell_value in cell_values:
		var cell := _cell_from_value(cell_value)
		result[_cell_key(cell)] = true
	return result

func _expanded_cell_lookup_from_values(cell_values: Array, radius: int) -> Dictionary:
	var result := {}
	var safe_radius: int = max(0, radius)
	for cell_value in cell_values:
		var cell: Vector2i = _cell_from_value(cell_value)
		for x in range(cell.x - safe_radius, cell.x + safe_radius + 1):
			for y in range(cell.y - safe_radius, cell.y + safe_radius + 1):
				result[_cell_key(Vector2i(x, y))] = true
	return result

func _cell_vectors_from_values(cell_values: Array) -> Array:
	var result: Array = []
	for cell_value in cell_values:
		result.append(_vector2_from_value(cell_value))
	return result

func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)

func _cell_noise(seed: int, cell: Vector2i, salt: int) -> float:
	return _hash_unit(seed + cell.x * 92821 + cell.y * 68917, cell.x - cell.y, salt)

func _draw_water_bodies() -> void:
	for water_value in water_bodies:
		if typeof(water_value) != TYPE_DICTIONARY:
			continue
		var water: Dictionary = water_value
		var fill_color := _color_from_value(water.get("fill_color", []), Color(0.05, 0.32, 0.45, 0.30))
		var border_color := _color_from_value(water.get("border_color", []), Color(0.28, 0.82, 0.95, 0.62))
		fill_color.a = minf(fill_color.a, 0.28)
		border_color.a = minf(border_color.a, 0.42)
		var rects: Array = water.get("grid_rects", [])
		for rect_value in rects:
			var rect := _grid_rect_from_value(rect_value)
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				continue
			draw_rect(rect, fill_color, true)
			_draw_water_lines(rect, border_color)
			_draw_shoreline_dashes(rect, border_color)
			if show_region_debug_rects:
				draw_rect(rect, border_color, false, 1.2)
		var pump_cells: Array = water.get("pump_candidate_cells", [])
		for cell_value in pump_cells:
			var cell := _cell_from_value(cell_value)
			var center := (Vector2(cell) + Vector2(0.5, 0.5)) * float(cell_size)
			draw_circle(center, float(cell_size) * 0.075, Color(0.65, 0.95, 1.0, 0.42))
			draw_arc(center, float(cell_size) * 0.16, 0.0, TAU, 24, border_color, 1.1)
			var pump_texture := _get_terrain_signature_texture("pump_anchor")
			if pump_texture:
				_draw_texture_stamp(pump_texture, center, 0.62, 0.0, Color(0.72, 1.0, 0.95, 0.42))
		_draw_water_asset_stamps(water, border_color)

func _draw_water_lines(rect: Rect2, color: Color) -> void:
	var y := rect.position.y + float(cell_size) * 0.55
	while y < rect.end.y:
		var x := rect.position.x + float(cell_size) * 0.25
		while x < rect.end.x - float(cell_size) * 0.3:
			var segment_width := minf(float(cell_size) * 0.68, rect.end.x - x - float(cell_size) * 0.2)
			draw_line(Vector2(x, y), Vector2(x + segment_width, y + sin(x * 0.011) * 2.0), Color(color.r, color.g, color.b, color.a * 0.48), 1.0)
			x += float(cell_size) * 1.08
		y += float(cell_size) * 1.2

func _draw_shoreline_dashes(rect: Rect2, color: Color) -> void:
	var dash_color := Color(color.r, color.g, color.b, color.a * 0.70)
	var step := float(cell_size) * 0.85
	var dash := float(cell_size) * 0.28
	var x := rect.position.x + float(cell_size) * 0.18
	while x < rect.end.x - dash:
		if int((x - rect.position.x) / step) % 2 == 0:
			draw_line(Vector2(x, rect.position.y), Vector2(x + dash, rect.position.y), dash_color, 1.0)
			draw_line(Vector2(x + step * 0.35, rect.end.y), Vector2(x + step * 0.35 + dash, rect.end.y), dash_color, 1.0)
		x += step
	var y := rect.position.y + float(cell_size) * 0.22
	while y < rect.end.y - dash:
		if int((y - rect.position.y) / step) % 2 == 0:
			draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x, y + dash), dash_color, 1.0)
			draw_line(Vector2(rect.end.x, y + step * 0.35), Vector2(rect.end.x, y + step * 0.35 + dash), dash_color, 1.0)
		y += step

func _draw_water_asset_stamps(water: Dictionary, color: Color) -> void:
	var ripple_texture := _get_terrain_signature_texture("water_ripple_mark")
	var shore_texture := _get_terrain_signature_texture("shoreline_dash")
	if ripple_texture == null and shore_texture == null:
		return
	var tint := Color(color.r, color.g, color.b, 0.30)
	for rect_value in water.get("grid_rects", []):
		var rect := _grid_rect_from_value(rect_value)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if ripple_texture:
			var center := rect.get_center()
			_draw_texture_stamp(ripple_texture, center, 0.72, 0.0, tint)
		if shore_texture:
			_draw_texture_stamp(shore_texture, rect.position + Vector2(rect.size.x * 0.28, float(cell_size) * 0.18), 0.58, -0.15, Color(color.r, color.g, color.b, 0.28))
			_draw_texture_stamp(shore_texture, rect.position + Vector2(rect.size.x * 0.72, rect.size.y - float(cell_size) * 0.18), 0.58, 3.05, Color(color.r, color.g, color.b, 0.24))

func _draw_region_routes() -> void:
	for route_value in region_routes:
		if typeof(route_value) != TYPE_DICTIONARY:
			continue
		var route: Dictionary = route_value
		var path_cells: Array = route.get("path_cells", [])
		if path_cells.size() < 2:
			continue
		var points := PackedVector2Array()
		for cell_value in path_cells:
			var cell := _cell_from_value(cell_value)
			points.append((Vector2(cell) + Vector2(0.5, 0.5)) * float(cell_size))
		var color := _color_from_value(route.get("color", []), Color(0.65, 0.82, 1.0, 0.55))
		var width := 1.6 if str(route.get("route_type", "main")) == "main" else 1.2
		draw_polyline(points, color, width)
		for point in points:
			draw_circle(point, width * 1.25, color)

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
		for signal_value in centers:
			var center_cell := Vector2.ZERO
			var signal_type := "weak_nest"
			if typeof(signal_value) == TYPE_DICTIONARY:
				center_cell = _vector2_from_value(signal_value.get("cell", Vector2.ZERO))
				signal_type = str(signal_value.get("signal_type", signal_type))
			else:
				center_cell = _vector2_from_value(signal_value)
			var center := center_cell * float(cell_size)
			_draw_nest_signal(center, signal_type)

func _draw_nest_signal(center: Vector2, signal_type: String = "weak_nest") -> void:
	var radius := float(cell_size) * 0.32
	var inner_radius := float(cell_size) * 0.16
	var signal_color := _signal_color(signal_type)
	var fill_color := Color(signal_color.r, signal_color.g, signal_color.b, 0.16)
	draw_circle(center, radius, fill_color)
	draw_arc(center, radius, 0.0, TAU, 40, signal_color, 2.0)
	draw_arc(center, inner_radius, 0.0, TAU, 32, Color(1.0, 0.78, 0.42, 0.72), 1.5)
	draw_line(center + Vector2(-radius, 0.0), center + Vector2(-inner_radius, 0.0), signal_color, 2.0)
	draw_line(center + Vector2(inner_radius, 0.0), center + Vector2(radius, 0.0), signal_color, 2.0)
	draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, -inner_radius), signal_color, 2.0)
	draw_line(center + Vector2(0.0, inner_radius), center + Vector2(0.0, radius), signal_color, 2.0)

func _signal_color(signal_type: String) -> Color:
	match signal_type:
		"armored_activity":
			return Color(0.95, 0.75, 0.32, 0.82)
		"high_energy":
			return Color(0.50, 0.86, 1.0, 0.82)
		"jammer_source":
			return Color(0.72, 1.0, 0.36, 0.82)
		"brain_core":
			return Color(0.82, 0.38, 1.0, 0.86)
	return Color(1.0, 0.48, 0.18, 0.80)

func _grid_rect_from_value(value: Variant) -> Rect2:
	if typeof(value) != TYPE_ARRAY or value.size() < 4:
		return Rect2()
	return Rect2(
		Vector2(float(value[0]) * float(cell_size), float(value[1]) * float(cell_size)),
		Vector2(float(value[2]) * float(cell_size), float(value[3]) * float(cell_size))
	)

func _cell_rect_from_value(value: Variant) -> Rect2:
	if typeof(value) != TYPE_ARRAY or value.size() < 4:
		return Rect2()
	return Rect2(
		Vector2(float(value[0]), float(value[1])),
		Vector2(float(value[2]), float(value[3]))
	)

func _cell_from_value(value: Variant) -> Vector2i:
	if typeof(value) == TYPE_VECTOR2I:
		return value
	if typeof(value) == TYPE_VECTOR2:
		return Vector2i(roundi(value.x), roundi(value.y))
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO

func _vector2_from_value(value: Variant) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value
	if typeof(value) == TYPE_VECTOR2I:
		return Vector2(value)
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO

func _color_from_value(value: Variant, fallback: Color) -> Color:
	if typeof(value) == TYPE_COLOR:
		return value
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		var alpha := float(value[3]) if value.size() >= 4 else 1.0
		return Color(float(value[0]), float(value[1]), float(value[2]), alpha)
	if typeof(value) == TYPE_STRING:
		return Color.from_string(str(value), fallback)
	return fallback

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
