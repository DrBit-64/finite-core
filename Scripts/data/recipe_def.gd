extends Resource
class_name RecipeDef

@export var id: StringName
@export var display_name: String = ""
@export var recipe_type: StringName = &"resource"
@export var target_id: StringName
@export var duration_seconds: float = 1.0
@export var inputs: Dictionary = {}
@export var outputs: Dictionary = {}
@export var source_path: String = ""

func can_afford(inventory: Dictionary) -> bool:
	for resource_id in inputs.keys():
		if int(inventory.get(resource_id, 0)) < int(inputs[resource_id]):
			return false
	return true

func get_input_amount(resource_id: StringName) -> int:
	return int(inputs.get(resource_id, 0))
