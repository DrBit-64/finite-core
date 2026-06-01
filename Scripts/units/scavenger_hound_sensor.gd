extends "res://Scripts/units/unit_enemy_sensor.gd"
class_name ScavengerHoundSensor

func get_initial_targets(unit_owner: Node2D, owner_team: String, source_nest: Node, aggro_radius: float) -> Array[Node2D]:
	var guard_center := unit_owner.global_position
	if source_nest != null and is_instance_valid(source_nest):
		if source_nest.has_method("get_target_position"):
			guard_center = source_nest.call("get_target_position")
		elif source_nest is Node2D:
			guard_center = (source_nest as Node2D).global_position
	return get_enemies_in_radius(unit_owner, owner_team, guard_center, aggro_radius)

func get_follow_up_targets(unit_owner: Node2D, owner_team: String, follow_up_radius: float) -> Array[Node2D]:
	return get_enemies_in_radius(unit_owner, owner_team, unit_owner.global_position, follow_up_radius)
