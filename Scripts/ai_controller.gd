extends Node
class_name AIController

const AI_RULE_SCRIPT := preload("res://Scripts/ai_rule.gd")
const AI_CONDITION_SCRIPT := preload("res://Scripts/ai_condition.gd")

@export var logic_rules: Array = []
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
		var subject: int = int(rule.get("subject"))
		var target := _resolve_subject_target(subject)
		if evaluate_single_rule(rule, target):
			var action: int = int(rule.get("action"))
			execute_action(action, target)
			return

func _resolve_subject_target(subject: int) -> Node2D:
	if robot == null:
		return null
	match subject:
		AI_RULE_SCRIPT.Subject.SELF:
			return robot
		AI_RULE_SCRIPT.Subject.TARGET_NEAREST:
			if robot.has_method("get_current_enemy"):
				return robot.get_current_enemy()
		AI_RULE_SCRIPT.Subject.TARGET_LOWEST_HP:
			if robot.has_method("get_lowest_hp_enemy"):
				return robot.get_lowest_hp_enemy()
	return null

func evaluate_single_rule(rule: Variant, target: Node2D) -> bool:
	if rule == null:
		return false
	var conditions: Array = rule.get("conditions")
	if conditions.is_empty():
		return true

	var match_mode: int = int(rule.get("match_mode"))
	if match_mode == AI_RULE_SCRIPT.MatchMode.MATCH_ALL:
		for cond in conditions:
			if not check_condition(target, cond):
				return false
		return true

	for cond in conditions:
		if check_condition(target, cond):
			return true
	return false

func check_condition(target: Node2D, cond: Variant) -> bool:
	if robot == null or cond == null:
		return false
	var cond_type: int = int(cond.get("type"))
	var cond_param: String = str(cond.get("param"))
	match cond_type:
		AI_CONDITION_SCRIPT.Type.DISTANCE_LESS:
			if target == null:
				return false
			var threshold: float = cond_param.to_float()
			return robot.global_position.distance_to(target.global_position) <= threshold
		AI_CONDITION_SCRIPT.Type.HP_LESS_PERCENT:
			if target == null:
				return false
			if not target.has_method("hp_ratio"):
				return false
			var threshold: float = cond_param.to_float()
			if threshold > 1.0:
				threshold = threshold / 100.0
			return target.hp_ratio() <= threshold
		AI_CONDITION_SCRIPT.Type.HAS_TAG:
			if target == null:
				return false
			if cond_param.is_empty():
				return false
			return target.is_in_group(cond_param)
	return false

func execute_action(act: int, target: Node2D) -> void:
	if robot == null:
		return
	match act:
		AI_RULE_SCRIPT.Action.APPROACH:
			if target and robot.has_method("move_towards"):
				robot.move_towards(target.global_position)
				_record_rule_trigger("规则：接近目标")
		AI_RULE_SCRIPT.Action.FLEE:
			if not robot.has_method("flee_from"):
				return
			var flee_target := target
			if flee_target == robot and robot.has_method("get_current_enemy"):
				flee_target = robot.get_current_enemy()
			if flee_target:
				robot.flee_from(flee_target.global_position)
				_record_rule_trigger("规则：远离目标")
		AI_RULE_SCRIPT.Action.FIRE_MAIN:
			if target and robot.has_method("fire_weapon"):
				robot.fire_weapon(target)
				_record_rule_trigger("规则：主武器开火")
		AI_RULE_SCRIPT.Action.STOP_ACTION:
			if robot.has_method("stop_and_idle"):
				robot.stop_and_idle()
				_record_rule_trigger("规则：停止")

func _on_tick_timer_timeout() -> void:
	evaluate_logic()

func _record_rule_trigger(description: String) -> void:
	if robot and robot.has_method("record_brain_trigger"):
		robot.record_brain_trigger(StringName(description), description)
