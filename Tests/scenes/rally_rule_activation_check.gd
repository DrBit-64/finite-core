extends Node

const PlayerRobotScene := preload("res://Scenes/robot.tscn")
const CombatTargetRegistryScript := preload("res://Scripts/map/combat_target_registry.gd")
const MvpDataDefaultsScript := preload("res://Scripts/data/mvp_data_defaults.gd")

func _ready() -> void:
	CombatEventLog.clear()
	var target_registry := CombatTargetRegistryScript.new()
	add_child(target_registry)

	var robot := PlayerRobotScene.instantiate()
	add_child(robot)
	robot.global_position = Vector2.ZERO
	robot.setup_from_blueprint(MvpDataDefaultsScript.create_basic_rifle_blueprint(), Vector2(256.0, 0.0), true)
	robot.set_physics_process(false)

	var ai_controller: Node = robot.get_node("AIController")
	ai_controller.call("evaluate_logic")
	ai_controller.call("evaluate_logic")
	_expect(_rule_event_count() == 1, "同一规则在同一决策窗口内重复求值时只能记录一次触发")

	await get_tree().create_timer(0.25).timeout
	ai_controller.call("evaluate_logic")
	_expect(_rule_event_count() == 1, "持续满足同一规则时不能重复记录触发")

	robot.global_position = Vector2(256.0, 0.0)
	await get_tree().create_timer(0.25).timeout
	ai_controller.call("evaluate_logic")
	_expect(_rule_event_count() == 2, "进入设置已集结标记规则时应记录一次新触发")

	await get_tree().create_timer(0.25).timeout
	ai_controller.call("evaluate_logic")
	_expect(_rule_event_count() == 3, "进入等待队友规则时应记录一次新触发")

	await get_tree().create_timer(0.25).timeout
	ai_controller.call("evaluate_logic")
	_expect(_rule_event_count() == 3, "持续等待队友时不能重复记录触发")

	print("RALLY_RULE_ACTIVATION_OK")
	get_tree().quit()

func _rule_event_count() -> int:
	return CombatEventLog.count_events("rule_triggered")

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(1)
