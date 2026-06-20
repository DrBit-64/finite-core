extends Node
class_name DefaultBrain

@export var preferred_range_ratio: float = 0.85
@export var range_dead_zone: float = 12.0

func setup(next_preferred_range_ratio: float, next_range_dead_zone: float) -> void:
	preferred_range_ratio = clampf(next_preferred_range_ratio, 0.1, 0.98)
	range_dead_zone = maxf(0.0, next_range_dead_zone)

func tick(robot) -> void:
	if robot == null:
		return

	var enemy: Node2D = robot.get_current_enemy() if robot.has_method("get_current_enemy") else null
	robot.current_target = enemy
	if enemy == null:
		robot.current_action = "闲置"
		robot.current_fire_state = "无目标"
		robot.current_distance_to_target = -1.0
		if robot.movement_component:
			robot.movement_component.stop(&"idle")
		robot.record_brain_trigger(&"default_idle", "默认脑干：无目标")
		return

	var target_position: Vector2 = enemy.global_position
	if robot.has_method("get_target_position"):
		target_position = robot.get_target_position(enemy)
	robot.current_distance_to_target = robot.global_position.distance_to(target_position)
	if robot.has_method("uses_melee_default_combat") and bool(robot.call("uses_melee_default_combat")):
		_tick_melee_default(robot, enemy, target_position)
		return
	var fire_range: float = robot.fire_range
	var desired_distance := fire_range * preferred_range_ratio
	var lower_bound := maxf(24.0, desired_distance - range_dead_zone)
	var upper_bound := minf(fire_range - 4.0, desired_distance + range_dead_zone)

	if robot.movement_component:
		if robot.current_distance_to_target > fire_range:
			robot.move_towards(target_position, enemy)
			robot.current_action = "接近敌人"
		elif robot.current_distance_to_target < lower_bound:
			robot.flee_from(target_position, 0.82)
			robot.current_action = "后退拉开"
		elif robot.current_distance_to_target > upper_bound:
			robot.move_towards(target_position, enemy, 0.48)
			robot.current_action = "微调射程"
		else:
			robot.movement_component.stop(&"hold_range")
			robot.current_action = "保持射程"

	if robot.current_distance_to_target <= fire_range:
		robot.fire_weapon(enemy)
	else:
		robot.current_fire_state = "目标超出射程"

	robot.record_brain_trigger(
		StringName("default_combat_%s_%s" % [robot.current_action, robot.current_fire_state]),
		"默认脑干：%s / %s" % [robot.current_action, robot.current_fire_state]
	)

func _tick_melee_default(robot, enemy: Node2D, target_position: Vector2) -> void:
	var attack_range := maxf(12.0, float(robot.get("fire_range")))
	if robot.get("melee_range") != null:
		attack_range = maxf(attack_range, float(robot.get("melee_range")))
	if robot.movement_component:
		if robot.current_distance_to_target > attack_range:
			robot.move_towards(target_position, enemy)
			robot.current_action = "贴近敌人"
		else:
			robot.movement_component.stop(&"hold_range")
			robot.current_action = "贴身攻击"
	if robot.current_distance_to_target <= float(robot.get("fire_range")):
		robot.fire_weapon(enemy)
	else:
		robot.current_fire_state = "目标超出近战范围"
	robot.record_brain_trigger(
		StringName("default_melee_%s_%s" % [robot.current_action, robot.current_fire_state]),
		"默认近战脑干：%s / %s" % [robot.current_action, robot.current_fire_state]
	)
