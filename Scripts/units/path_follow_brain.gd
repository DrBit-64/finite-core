extends Node
class_name PathFollowBrain

@export var patrol_loop: bool = true

var patrol_points: Array[Vector2] = []
var patrol_index: int = 0

func set_path(path_points: Array[Vector2], loop_path: bool = true) -> void:
	patrol_points = path_points.duplicate()
	patrol_loop = loop_path
	patrol_index = 0

func tick(robot) -> void:
	if robot == null:
		return
	robot.current_target = null
	robot.current_distance_to_target = -1.0
	robot.current_fire_state = "禁用"
	if robot.movement_component == null:
		return
	if patrol_points.is_empty():
		robot.movement_component.stop(&"idle")
		robot.current_action = "路径等待"
		robot.record_brain_trigger(&"path_wait", "路径脑干：等待路径")
		return

	var target_pos := patrol_points[patrol_index]
	if robot.global_position.distance_to(target_pos) <= robot.movement_component.arrival_tolerance:
		if patrol_index < patrol_points.size() - 1:
			patrol_index += 1
		elif patrol_loop:
			patrol_index = 0
		else:
			robot.movement_component.stop(&"arrived")
			robot.current_action = "路径完成"
			robot.record_brain_trigger(&"path_arrived", "路径脑干：路径完成")
			return
		target_pos = patrol_points[patrol_index]

	robot.movement_component.move_towards(robot.global_position, target_pos)
	robot.current_action = "沿路径移动"
	robot.record_brain_trigger(
		StringName("path_move_%s" % patrol_index),
		"路径脑干：前往点 %s/%s" % [patrol_index + 1, patrol_points.size()]
	)
