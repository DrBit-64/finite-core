extends Node2D
class_name BuildingPlacementGhost

@export var valid_color: Color = Color(0.16, 0.85, 0.42, 0.38)
@export var invalid_color: Color = Color(0.95, 0.18, 0.18, 0.42)

var building_def: BuildingDef
var cell_size: int = 64
var is_valid_position: bool = false

@onready var sprite: Sprite2D = $IconSprite

func setup(def: BuildingDef, next_cell_size: int) -> void:
	building_def = def
	cell_size = next_cell_size
	_update_sprite()
	queue_redraw()

func set_grid_origin(origin: Vector2i) -> void:
	position = Vector2(origin.x * cell_size, origin.y * cell_size)

func set_valid(next_valid: bool) -> void:
	is_valid_position = next_valid
	queue_redraw()

func _draw() -> void:
	if building_def == null:
		return
	var pixel_size := Vector2(building_def.grid_size.x * cell_size, building_def.grid_size.y * cell_size)
	var color := valid_color if is_valid_position else invalid_color
	draw_rect(Rect2(Vector2.ZERO, pixel_size), color, true)
	draw_rect(Rect2(Vector2.ZERO, pixel_size), color.darkened(0.25), false, 2.0)

func _update_sprite() -> void:
	if building_def == null or sprite == null:
		return
	if building_def.icon_path.is_empty():
		return
	var texture := load(building_def.icon_path) as Texture2D
	if texture == null:
		return
	sprite.texture = texture
	sprite.modulate = Color(1, 1, 1, 0.72)
	var pixel_size := Vector2(building_def.grid_size.x * cell_size, building_def.grid_size.y * cell_size)
	sprite.position = pixel_size * 0.5
	var texture_size := texture.get_size()
	if texture_size.x > 0.0 and texture_size.y > 0.0:
		var max_size := minf(pixel_size.x, pixel_size.y) * 0.78
		sprite.scale = Vector2(max_size / texture_size.x, max_size / texture_size.y)
