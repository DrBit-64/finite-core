extends Resource
class_name BuildingDef

@export var id: StringName
@export var display_name: String = ""
@export var icon_path: String = ""
@export var grid_size: Vector2i = Vector2i.ONE
@export var build_recipe_id: StringName
@export var build_cost: Dictionary = {}
@export var max_hp: int = 500
@export var build_bar_visible: bool = true
@export var unlock_stage: int = 0
@export var requires_campaign_unlock: bool = false

func get_grid_area() -> int:
	return maxi(0, grid_size.x) * maxi(0, grid_size.y)
