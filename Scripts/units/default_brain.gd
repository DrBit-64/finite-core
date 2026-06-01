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
	var fire_range: float = robot.fire_range
	var desired_distance := fire_range * preferred_range_ratio
	var lower_bound := maxf(24.0, desired_distance - range_dead_zone)
	var upper_bound := minf(fire_range - 4.0, desired_distance + range_dead_zone)

	if robot.movement_component:
		if robot.current_distance_to_target > fire_range:
			robot.movement_component.move_towards(robot.global_position, target_position)
			robot.current_action = "接近敌人"
		elif robot.current_distance_to_target < lower_bound:
			robot.movement_component.move_away_from(robot.global_position, target_position, 0.82)
			robot.current_action = "后退拉开"
		elif robot.current_distance_to_target > upper_bound:
			robot.movement_component.move_towards(robot.global_position, target_position, 0.48)
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
