extends Node2D
class_name SalvagePickup

const MapConfigLoaderScript := preload("res://Scripts/map/map_config_loader.gd")

signal depleted(pickup: Node)

@export var icon_size: Vector2 = Vector2(54, 54)

var pickup_id: StringName = &""
var resource_id: StringName = &""
var key_item_id: StringName = &""
var display_name: String = ""
var icon_path: String = ""
var grid_origin: Vector2i = Vector2i.ZERO
var grid_size: Vector2i = Vector2i.ONE
var cell_size: int = 64
var amount: int = 0
var value: int = 1
var salvage_type: StringName = &"scrap"
var source_enemy: StringName = &""
var requires_tether: bool = false
var turn_in_target: StringName = &"main_base"
var strategic_reward: bool = false
var interaction_locked: bool = false
var lock_reason: String = ""

@onready var icon_sprite: Sprite2D = $IconSprite

func setup(data: Dictionary, resource_def: ResourceDef, next_cell_size: int) -> void:
	pickup_id = StringName(str(data.get("id", "")))
	resource_id = StringName(str(data.get("resource_id", "")))
	key_item_id = StringName(str(data.get("key_item_id", "")))
	grid_origin = MapConfigLoaderScript.get_vector2i(data, "grid_origin", Vector2i.ZERO)
	grid_size = MapConfigLoaderScript.get_vector2i(data, "grid_size", Vector2i.ONE)
	cell_size = next_cell_size
	amount = maxi(0, int(data.get("amount", 0)))
	value = maxi(1, int(data.get("value", amount)))
	salvage_type = StringName(str(data.get("salvage_type", "scrap")))
	source_enemy = StringName(str(data.get("source_enemy", "")))
	requires_tether = bool(data.get("requires_tether", false))
	turn_in_target = StringName(str(data.get("turn_in_target", "main_base")))
	strategic_reward = bool(data.get("strategic_reward", false))
	if resource_def != null:
		display_name = resource_def.display_name
		icon_path = resource_def.icon_path
	display_name = str(data.get("display_name", display_name if not display_name.is_empty() else resource_id))
	icon_path = str(data.get("icon_path", icon_path))
	position = Vector2(grid_origin.x * cell_size, grid_origin.y * cell_size)
	_update_visuals()
	queue_redraw()

func get_display_name() -> String:
	return display_name if not display_name.is_empty() else String(resource_id)

func get_target_position() -> Vector2:
	return global_position + Vector2(grid_size.x * cell_size, grid_size.y * cell_size) * 0.5

func set_interaction_locked(locked: bool, reason: String = "") -> void:
	interaction_locked = locked
	lock_reason = reason
	modulate = Color(0.76, 0.82, 0.88, 0.50) if locked else Color.WHITE
	queue_redraw()

func is_interaction_locked() -> bool:
	return interaction_locked

func get_all_resources() -> Dictionary:
	if amount <= 0 or String(resource_id).is_empty():
		return {}
	return {resource_id: amount}

func get_amount(next_resource_id: StringName) -> int:
	if interaction_locked or next_resource_id != resource_id:
		return 0
	return amount

func remove_resource(next_resource_id: StringName, requested_amount: int, _reason: String = "") -> int:
	if interaction_locked or next_resource_id != resource_id or requested_amount <= 0:
		return 0
	var removed := mini(amount, requested_amount)
	amount -= removed
	if amount <= 0:
		amount = 0
		depleted.emit(self)
		queue_free()
	queue_redraw()
	return removed

func get_salvage_value() -> int:
	return value

func get_inspector_lines() -> Array[String]:
	var lines: Array[String] = [
		"类型：战场残骸",
		"名称：%s" % get_display_name(),
		"网格：%s, %s" % [grid_origin.x, grid_origin.y],
		"数量：%s" % amount,
		"价值：%s" % value,
		"分类：%s" % String(salvage_type),
	]
	if requires_tether:
		lines.append("需求：残骸牵引模块")
	if strategic_reward:
		lines.append("收益：战略收益")
	if interaction_locked:
		lines.append("状态：未解锁 / %s" % (lock_reason if not lock_reason.is_empty() else "区域锁定"))
	return lines

func _ready() -> void:
	_update_visuals()

func _draw() -> void:
	var pixel_size := Vector2(grid_size.x * cell_size, grid_size.y * cell_size)
	draw_rect(Rect2(Vector2.ZERO, pixel_size), Color(0.22, 0.15, 0.09, 0.28), true)
	var border_color := Color(1.0, 0.60, 0.26, 0.78) if strategic_reward else Color(0.86, 0.54, 0.30, 0.50)
	draw_rect(Rect2(Vector2(4.0, 4.0), pixel_size - Vector2(8.0, 8.0)), border_color, false, 2.0)
	if interaction_locked:
		draw_line(Vector2(8.0, 8.0), pixel_size - Vector2(8.0, 8.0), Color(1.0, 0.78, 0.30, 0.58), 2.0)

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
		var max_size := minf(icon_size.x, minf(pixel_size.x, pixel_size.y) * 0.86)
		icon_sprite.scale = Vector2(max_size / texture_size.x, max_size / texture_size.y)
