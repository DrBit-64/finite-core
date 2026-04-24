extends Resource
class_name AICondition

enum Type {
	DISTANCE_LESS,
	HP_LESS_PERCENT,
	HAS_TAG,
}

@export var type: Type = Type.DISTANCE_LESS
@export var param: String = ""
