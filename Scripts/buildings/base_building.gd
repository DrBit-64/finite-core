extends Node2D
class_name BaseBuilding

@export var icon_size: Vector2 = Vector2(56, 56)

var building_def: BuildingDef
var grid_origin: Vector2i = Vector2i.ZERO
var grid_size: Vector2i = Vector2i.ONE
var cell_size: int = 64

@onready var icon_sprite: Sprite2D = $IconSprite
@onready var footprint: Polygon2D = $Footprint

func setup(def: BuildingDef, origin: Vector2i, next_cell_size: int) -> void:
	building_def = def
	grid_origin = origin
	grid_size = def.grid_size if def else Vector2i.ONE
	cell_size = next_cell_size
	position = Vector2(origin.x * cell_size, origin.y * cell_size)
	_update_visuals()
	queue_redraw()

func get_display_name() -> String:
	if building_def:
		return building_def.display_name
	return "建筑"

func get_inspector_lines() -> Array[String]:
	return [
		"类型：建筑",
		"名称：%s" % get_display_name(),
		"网格：%s, %s" % [grid_origin.x, grid_origin.y],
		"占格：%sx%s" % [grid_size.x, grid_size.y],
		"建造配方：%s" % String(building_def.build_recipe_id if building_def else &""),
	]

func _ready() -> void:
	_update_visuals()

func _update_visuals() -> void:
	if building_def == null or icon_sprite == null or footprint == null:
		return

	var pixel_size := Vector2(grid_size.x * cell_size, grid_size.y * cell_size)
	footprint.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(pixel_size.x, 0.0),
		pixel_size,
		Vector2(0.0, pixel_size.y),
	])
	icon_sprite.position = pixel_size * 0.5

	var texture := load(building_def.icon_path) as Texture2D
	if texture:
		icon_sprite.texture = texture
		var texture_size := texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			icon_sprite.scale = Vector2(
				minf(icon_size.x, pixel_size.x * 0.82) / texture_size.x,
				minf(icon_size.y, pixel_size.y * 0.82) / texture_size.y
			)
