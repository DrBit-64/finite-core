extends Resource
class_name MapObjectDef

enum Kind {
	UNKNOWN,
	BUILDING,
	RESOURCE_NODE,
	ENEMY_NEST,
	RALLY_POINT,
}

@export var id: StringName
@export var display_name: String = ""
@export var kind: Kind = Kind.UNKNOWN
@export var icon_path: String = ""
@export var grid_size: Vector2i = Vector2i.ONE
