extends Node2D
class_name RallyPointMarker

@export var marker_color: Color = Color(0.36, 0.92, 0.62, 0.96)
@export var fill_color: Color = Color(0.36, 0.92, 0.62, 0.14)

var grid_cell: Vector2i = Vector2i.ZERO
var cell_size: int = 64

@onready var icon_sprite: Sprite2D = get_node_or_null("IconSprite")

func _ready() -> void:
	_refresh_icon_scale()

func setup(cell: Vector2i, next_cell_size: int) -> void:
	grid_cell = cell
	cell_size = next_cell_size
	position = Vector2((float(cell.x) + 0.5) * float(cell_size), (float(cell.y) + 0.5) * float(cell_size))
	visible = true
	_refresh_icon_scale()
	queue_redraw()

func get_display_name() -> String:
	return "集结点"

func get_inspector_lines() -> Array[String]:
	var lines: Array[String] = [
		"类型：地图标记",
		"名称：集结点",
		"网格：%s, %s" % [grid_cell.x, grid_cell.y],
	]
	return lines

func _draw() -> void:
	var radius := float(cell_size) * 0.30
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, marker_color, 3.0)

func _refresh_icon_scale() -> void:
	if icon_sprite == null or icon_sprite.texture == null:
		return
	var texture_size := icon_sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var target_size := float(cell_size) * 0.56
	icon_sprite.scale = Vector2(target_size / texture_size.x, target_size / texture_size.y)
