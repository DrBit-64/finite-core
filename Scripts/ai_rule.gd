extends Resource
class_name AIRule

enum Subject {
	SELF,
	TARGET_NEAREST,
	TARGET_LOWEST_HP,
}

enum MatchMode {
	MATCH_ALL,
	MATCH_ANY,
}

enum Action {
	APPROACH,
	FLEE,
	FIRE_MAIN,
	STOP_ACTION,
}

@export var subject: Subject = Subject.TARGET_NEAREST
@export var match_mode: MatchMode = MatchMode.MATCH_ALL
@export var conditions: Array = []
@export var action: Action = Action.STOP_ACTION
