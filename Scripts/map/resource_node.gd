extends Node2D
class_name ResourceNode

const MapConfigLoaderScript := preload("res://Scripts/map/map_config_loader.gd")

@export var icon_size: Vector2 = Vector2(48, 48)

var node_id: StringName
var resource_id: StringName
var display_name: String = ""
var icon_path: String = ""
var grid_origin: Vector2i = Vector2i.ZERO
var grid_size: Vector2i = Vector2i.ONE
var cell_size: int = 64
var amount: int = 0
var bound_miner: Node = null

@onready var icon_sprite: Sprite2D = $IconSprite

func setup(data: Dictionary, resource_def: ResourceDef, next_cell_size: int) -> void:
	node_id = StringName(str(data.get("id", "")))
	resource_id = StringName(str(data.get("resource_id", "")))
	grid_origin = MapConfigLoaderScript.get_vector2i(data, "grid_origin", Vector2i.ZERO)
	grid_size = MapConfigLoaderScript.get_vector2i(data, "grid_size", Vector2i.ONE)
	amount = int(data.get("amount", 0))
	cell_size = next_cell_size
	if resource_def:
		display_name = resource_def.display_name
		icon_path = resource_def.icon_path
	position = Vector2(grid_origin.x * cell_size, grid_origin.y * cell_size)
	_update_visuals()
	queue_redraw()

func is_bound() -> bool:
	return bound_miner != null

func bind_miner(miner: Node) -> void:
	bound_miner = miner
	modulate = Color(1.0, 1.0, 1.0, 0.72)

func get_display_name() -> String:
	return display_name if not display_name.is_empty() else String(resource_id)

func get_inspector_lines() -> Array[String]:
	return [
		"类型：资源点",
		"名称：%s" % get_display_name(),
		"网格：%s, %s" % [grid_origin.x, grid_origin.y],
		"占格：%sx%s" % [grid_size.x, grid_size.y],
		"储量：%s" % amount,
		"绑定：%s" % ("已绑定" if is_bound() else "未绑定"),
	]

func _ready() -> void:
	_update_visuals()

func _draw() -> void:
	var pixel_size := Vector2(grid_size.x * cell_size, grid_size.y * cell_size)
	draw_rect(Rect2(Vector2.ZERO, pixel_size), Color(0.12, 0.13, 0.12, 0.32), true)

func _update_visuals() -> void:
	if icon_sprite == null or icon_path.is_empty():
		return
	var texture := load(icon_path) as Texture2D
	if texture == null:
		return
	icon_sprite.texture = texture
	var pixel_size := Vector2(grid_size.x * cell_size, grid_size.y * cell_size)
	icon_sprite.position = pixel_size * 0.5
	var texture_size := texture.get_size()
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		var max_size := minf(icon_size.x, minf(pixel_size.x, pixel_size.y) * 0.82)
		icon_sprite.scale = Vector2(max_size / texture_size.x, max_size / texture_size.y)
