extends RefCounted
class_name Team

enum Id {
	NEUTRAL,
	PLAYER,
	ENEMY,
}

static func display_name(team: Id) -> String:
	match team:
		Id.PLAYER:
			return "玩家"
		Id.ENEMY:
			return "敌人"
	return "中立"
