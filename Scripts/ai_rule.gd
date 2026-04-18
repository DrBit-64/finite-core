extends Resource
class_name AIRule

enum Condition {
	ENEMY_IN_RANGE,
	ENEMY_IN_FIRE_RANGE,
	HP_BELOW_30,
	ALWAYS,
}

enum Action {
	FIRE_MAIN_WEAPON,
	APPROACH_NEAREST_ENEMY,
	MOVE_AWAY,
	STOP_AND_IDLE,
}

@export var condition: Condition = Condition.ALWAYS
@export var action: Action = Action.STOP_AND_IDLE
