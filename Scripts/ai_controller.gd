extends Node
class_name AIController

@export var logic_rules: Array[AIRule] = []
@export var tick_interval: float = 0.2

@onready var tick_timer: Timer = $TickTimer
@onready var robot: CharacterBody2D = get_parent() as CharacterBody2D

func _ready() -> void:
	if tick_timer:
		tick_timer.wait_time = tick_interval
		tick_timer.one_shot = false
		tick_timer.start()

func evaluate_logic() -> void:
	if robot == null:
		return
	for rule in logic_rules:
		if check_condition(rule.condition):
			execute_action(rule.action)
			return

func check_condition(cond: AIRule.Condition) -> bool:
	if robot == null:
		return false
	match cond:
		AIRule.Condition.ENEMY_IN_RANGE:
			return robot.has_method("has_enemy_in_range") and robot.has_enemy_in_range()
		AIRule.Condition.ENEMY_IN_FIRE_RANGE:
			return robot.has_method("is_current_enemy_in_fire_range") and robot.is_current_enemy_in_fire_range()
		AIRule.Condition.HP_BELOW_30:
			return robot.has_method("hp_ratio") and robot.hp_ratio() < 0.3
		AIRule.Condition.ALWAYS:
			return true
	return false

func execute_action(act: AIRule.Action) -> void:
	if robot == null:
		return
	match act:
		AIRule.Action.FIRE_MAIN_WEAPON:
			if robot.has_method("fire_main_weapon"):
				robot.fire_main_weapon()
		AIRule.Action.APPROACH_NEAREST_ENEMY:
			if robot.has_method("move_towards_nearest_enemy"):
				robot.move_towards_nearest_enemy()
		AIRule.Action.MOVE_AWAY:
			if robot.has_method("move_away_from_current_enemy"):
				robot.move_away_from_current_enemy()
		AIRule.Action.STOP_AND_IDLE:
			if robot.has_method("stop_and_idle"):
				robot.stop_and_idle()

func _on_tick_timer_timeout() -> void:
	evaluate_logic()
