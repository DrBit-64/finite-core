extends Resource
class_name ResourceDef

@export var id: StringName
@export var display_name: String = ""
@export var icon_path: String = ""
@export_multiline var description: String = ""

func is_valid() -> bool:
	return not String(id).is_empty()
