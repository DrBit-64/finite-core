@tool
extends Node2D
class_name MvpGridMap

@export var map_size_cells: Vector2i = Vector2i(64, 64)
@export var cell_size: int = 64
@export_file("*.json") var editor_map_preview_config_path: String = "res://Resources/data/maps/mvp_stage3_map.json"

const SEMANTIC_TILE_LAYERS := [
	"BaseRegionLayer",
	"FrontierTerrainLayer",
	"PassabilityLayer",
	"GateLayer",
]
const REGION_BASE_TILE_IDS := [
	"starting_basin",
	"crystal_wasteland",
	"wreckage_battlefield",
	"interference_highlands",
	"brain_core_outer",
]
const REGION_BASE_TILE_NAMES := [
	"起始盆地",
	"晶体荒原",
	"残骸战场",
	"干扰高地",
	"主脑外围",
]

const REGION_BASE_TILE_TYPES := REGION_BASE_TILE_IDS
const REGION_BASE_TILE_THREATS := [0, 2, 3, 3, 4]
const REGION_BASE_TILE_RECOMMENDED_STAGES := [0, 2, 3, 3, 4]

@onready var grid_overlay: Node2D = $TerrainLayer/GridOverlay
@onready var combat_target_registry: Node = $CombatTargetRegistry

var _painted_region_cells_cache: Array[Dictionary] = []
var _painted_region_cells_cache_valid: bool = false
var _semantic_cells_by_tag_cache: Dictionary = {}
var _semantic_cells_by_tag_cache_valid: bool = false

func _ready() -> void:
	_load_editor_map_preview_config()
	_sync_overlay()

func configure(next_map_size_cells: Vector2i, next_cell_size: int = -1) -> void:
	map_size_cells = next_map_size_cells
	if next_cell_size > 0:
		cell_size = next_cell_size
	invalidate_semantic_cache()
	_sync_overlay()

func _load_editor_map_preview_config() -> void:
	if not Engine.is_editor_hint():
		return
	if editor_map_preview_config_path.is_empty():
		return
	if not FileAccess.file_exists(editor_map_preview_config_path):
		return
	var file := FileAccess.open(editor_map_preview_config_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	if parsed.has("map_size"):
		var preview_size := _vector2i_from_value(parsed.get("map_size"))
		if preview_size.x > 0 and preview_size.y > 0:
			map_size_cells = preview_size
	if parsed.has("cell_size"):
		var preview_cell_size := int(parsed.get("cell_size", cell_size))
		if preview_cell_size > 0:
			cell_size = preview_cell_size

func get_world_size() -> Vector2:
	return Vector2(map_size_cells.x * cell_size, map_size_cells.y * cell_size)

func grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		(float(cell.x) + 0.5) * float(cell_size),
		(float(cell.y) + 0.5) * float(cell_size)
	)

func world_to_grid(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_position.x / float(cell_size)),
		floori(world_position.y / float(cell_size))
	)

func get_cell_rect(origin: Vector2i, size: Vector2i = Vector2i.ONE) -> Rect2:
	return Rect2(
		Vector2(origin.x * cell_size, origin.y * cell_size),
		Vector2(size.x * cell_size, size.y * cell_size)
	)

func is_cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < map_size_cells.x and cell.y < map_size_cells.y

func is_rect_in_bounds(origin: Vector2i, size: Vector2i = Vector2i.ONE) -> bool:
	if size.x <= 0 or size.y <= 0:
		return false
	return origin.x >= 0 \
		and origin.y >= 0 \
		and origin.x + size.x <= map_size_cells.x \
		and origin.y + size.y <= map_size_cells.y

func get_semantic_tile_info(cell: Vector2i) -> Dictionary:
	var result := {
		"blocked": false,
		"force_passable": false,
		"tags": [],
	}
	for layer_name in SEMANTIC_TILE_LAYERS:
		var layer := get_node_or_null("TerrainLayer/%s" % layer_name)
		if layer == null or not layer.has_method("get_cell_source_id"):
			continue
		var source_id := int(layer.call("get_cell_source_id", cell))
		if source_id < 0:
			continue
		var atlas_coords: Vector2i = layer.call("get_cell_atlas_coords", cell)
		var tile_info := _semantic_for_frontier_tile(layer_name, source_id, atlas_coords)
		if bool(tile_info.get("force_passable", false)):
			result["force_passable"] = true
		if bool(tile_info.get("blocked", false)):
			result["blocked"] = true
		for tag in tile_info.get("tags", []):
			_append_unique_tag(result["tags"], str(tag))
	if bool(result["force_passable"]):
		result["blocked"] = false
	return result

func is_cell_blocked_by_semantic_tile(cell: Vector2i) -> bool:
	return bool(get_semantic_tile_info(cell).get("blocked", false))

func is_rect_blocked_by_semantic_tile(origin: Vector2i, size: Vector2i = Vector2i.ONE) -> bool:
	for x in range(origin.x, origin.x + size.x):
		for y in range(origin.y, origin.y + size.y):
			if is_cell_blocked_by_semantic_tile(Vector2i(x, y)):
				return true
	return false

func get_semantic_cells_by_tag(tag: String) -> Array[Vector2i]:
	_ensure_semantic_cells_by_tag_cache()
	var result: Array[Vector2i] = []
	for cell_value in _semantic_cells_by_tag_cache.get(tag, []):
		var cell: Vector2i = cell_value
		result.append(cell)
	return result

func get_semantic_cells_by_tags(tags: Array) -> Dictionary:
	_ensure_semantic_cells_by_tag_cache()
	var result := {}
	for tag_value in tags:
		var tag := str(tag_value)
		var cells: Array[Vector2i] = []
		for cell_value in _semantic_cells_by_tag_cache.get(tag, []):
			var cell: Vector2i = cell_value
			cells.append(cell)
		result[tag] = cells
	return result

func get_painted_region_info(cell: Vector2i) -> Dictionary:
	var layer := get_node_or_null("TerrainLayer/BaseRegionLayer")
	if layer == null or not layer.has_method("get_cell_source_id"):
		return {}
	if int(layer.call("get_cell_source_id", cell)) < 0:
		return {}
	var atlas_coords: Vector2i = layer.call("get_cell_atlas_coords", cell)
	return _region_base_info_for_tile_x(atlas_coords.x)

func get_painted_region_cells() -> Array[Dictionary]:
	_ensure_painted_region_cells_cache()
	var result: Array[Dictionary] = []
	for item in _painted_region_cells_cache:
		result.append(item.duplicate(true))
	return result

func invalidate_semantic_cache() -> void:
	_painted_region_cells_cache.clear()
	_painted_region_cells_cache_valid = false
	_semantic_cells_by_tag_cache.clear()
	_semantic_cells_by_tag_cache_valid = false

func _ensure_painted_region_cells_cache() -> void:
	if _painted_region_cells_cache_valid:
		return
	_painted_region_cells_cache.clear()
	var layer := get_node_or_null("TerrainLayer/BaseRegionLayer")
	if layer == null or not layer.has_method("get_used_cells"):
		_painted_region_cells_cache_valid = true
		return
	for cell_value in layer.call("get_used_cells"):
		var cell: Vector2i = cell_value
		var info := get_painted_region_info(cell)
		if info.is_empty():
			continue
		info["cell"] = cell
		_painted_region_cells_cache.append(info)
	_painted_region_cells_cache_valid = true

func _ensure_semantic_cells_by_tag_cache() -> void:
	if _semantic_cells_by_tag_cache_valid:
		return
	_semantic_cells_by_tag_cache.clear()
	var seen_cells := {}
	for layer_name in SEMANTIC_TILE_LAYERS:
		var layer := get_node_or_null("TerrainLayer/%s" % layer_name)
		if layer == null or not layer.has_method("get_used_cells"):
			continue
		for cell_value in layer.call("get_used_cells"):
			var cell: Vector2i = cell_value
			var key := "%d,%d" % [cell.x, cell.y]
			if seen_cells.has(key):
				continue
			seen_cells[key] = true
			var tile_info := get_semantic_tile_info(cell)
			for tag_value in tile_info.get("tags", []):
				var tag := str(tag_value)
				if not _semantic_cells_by_tag_cache.has(tag):
					_semantic_cells_by_tag_cache[tag] = []
				_semantic_cells_by_tag_cache[tag].append(cell)
	_semantic_cells_by_tag_cache_valid = true

func get_area_info_for_cell(cell: Vector2i) -> Dictionary:
	var semantic := get_semantic_tile_info(cell)
	var tags: Array = semantic.get("tags", [])
	var boundary_info := _boundary_info_from_tags(tags)
	if not boundary_info.is_empty():
		return boundary_info
	return get_painted_region_info(cell)

func get_layer(layer_name: String) -> Node2D:
	return get_node_or_null(layer_name) as Node2D

func get_combat_target_registry() -> Node:
	return combat_target_registry

func describe() -> String:
	return "%sx%s cells, %spx cell, %sx%s world px" % [
		map_size_cells.x,
		map_size_cells.y,
		cell_size,
		int(get_world_size().x),
		int(get_world_size().y),
	]

func _sync_overlay() -> void:
	if grid_overlay == null:
		return
	if grid_overlay.has_method("configure"):
		grid_overlay.call("configure", map_size_cells, cell_size)

func _semantic_for_frontier_tile(layer_name: String, source_id: int, atlas_coords: Vector2i) -> Dictionary:
	var info := {
		"blocked": false,
		"force_passable": false,
		"tags": [],
	}
	if layer_name == "BaseRegionLayer":
		var region_info := _region_base_info_for_tile_x(atlas_coords.x)
		if not region_info.is_empty():
			info["tags"] = ["region", str(region_info.get("region_id", ""))]
		else:
			info["tags"] = ["region"]
		return info
	if source_id == 19:
		info["force_passable"] = true
		if atlas_coords.x >= 16:
			info["tags"] = ["bypass", "risk_bypass"]
		else:
			info["tags"] = ["gate"]
		return info
	if source_id == 20:
		info["blocked"] = true
		match atlas_coords.y:
			0:
				info["tags"] = ["frontier", "crystal_frontier"]
			1:
				info["tags"] = ["frontier", "wreckage_frontier"]
			2:
				info["tags"] = ["frontier", "interference_frontier"]
			3:
				info["tags"] = ["frontier", "core_frontier"]
		return info
	match atlas_coords.x:
		0:
			info["blocked"] = true
			info["tags"] = ["water"]
		1:
			info["blocked"] = true
			info["tags"] = ["water", "water_edge"]
		2:
			info["blocked"] = true
			info["tags"] = ["ridge"]
		3:
			info["blocked"] = true
			info["tags"] = ["ridge", "ridge_edge"]
		4:
			info["tags"] = ["frontier_noise"]
		5:
			info["blocked"] = true
			info["tags"] = ["wreckage"]
		6:
			info["force_passable"] = true
			info["tags"] = ["gate"]
		7:
			info["force_passable"] = true
			info["tags"] = ["bypass", "risk_bypass"]
		8:
			info["force_passable"] = true
			info["tags"] = ["pump_candidate"]
	if layer_name == "PassabilityLayer" and atlas_coords.x <= 5:
		info["blocked"] = true
	return info

func _region_base_info_for_tile_x(tile_x: int) -> Dictionary:
	if tile_x < 0 or tile_x >= REGION_BASE_TILE_IDS.size():
		return {}
	return {
		"region_id": REGION_BASE_TILE_IDS[tile_x],
		"display_name": REGION_BASE_TILE_NAMES[tile_x],
		"region_type": REGION_BASE_TILE_TYPES[tile_x],
		"threat_level": REGION_BASE_TILE_THREATS[tile_x],
		"recommended_stage": REGION_BASE_TILE_RECOMMENDED_STAGES[tile_x],
	}

func _boundary_info_from_tags(tags: Array) -> Dictionary:
	if "crystal_frontier" in tags:
		return _make_boundary_info("crystal_frontier", "晶体荒原边界", "crystal_frontier", 2, 2)
	if "wreckage_frontier" in tags:
		return _make_boundary_info("wreckage_frontier", "残骸战场边界", "wreckage_frontier", 3, 3)
	if "interference_frontier" in tags:
		return _make_boundary_info("interference_frontier", "干扰高地边界", "interference_frontier", 3, 3)
	if "core_frontier" in tags:
		return _make_boundary_info("core_frontier", "主脑外围边界", "core_frontier", 4, 4)
	if "water" in tags:
		return _make_boundary_info("water_frontier", "水体边界", "water", 2, 2)
	if "ridge" in tags:
		return _make_boundary_info("ridge_frontier", "断层边界", "ridge", 2, 2)
	if "wreckage" in tags:
		return _make_boundary_info("wreckage_frontier", "残骸边界", "wreckage", 3, 3)
	if "frontier_noise" in tags:
		return _make_boundary_info("noise_frontier", "信号干扰边界", "frontier_noise", 3, 3)
	if "gate" in tags:
		return _make_boundary_info("gate", "主通道", "gate", 0, 0)
	if "risk_bypass" in tags:
		return _make_boundary_info("risk_bypass", "高风险绕行通道", "risk_bypass", 3, 3)
	if "pump_candidate" in tags:
		return _make_boundary_info("pump_candidate", "水泵候选点", "pump_candidate", 2, 2)
	return {}

func _make_boundary_info(region_id: String, display_name: String, region_type: String, threat_level: int, recommended_stage: int) -> Dictionary:
	return {
		"region_id": region_id,
		"display_name": display_name,
		"region_type": region_type,
		"threat_level": threat_level,
		"recommended_stage": recommended_stage,
		"source": "boundary_tile",
	}

func _append_unique_tag(tags: Array, tag: String) -> void:
	if tag.is_empty() or tag in tags:
		return
	tags.append(tag)

func _vector2i_from_value(value: Variant) -> Vector2i:
	if typeof(value) == TYPE_VECTOR2I:
		return value
	if typeof(value) == TYPE_VECTOR2:
		return Vector2i(roundi(value.x), roundi(value.y))
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO
