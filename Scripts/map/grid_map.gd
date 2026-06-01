@tool
extends Node2D
class_name MvpGridMap

@export var map_size_cells: Vector2i = Vector2i(64, 64)
@export var cell_size: int = 64

@onready var grid_overlay: Node2D = $TerrainLayer/GridOverlay
@onready var combat_target_registry: Node = $CombatTargetRegistry

func _ready() -> void:
	_sync_overlay()

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
