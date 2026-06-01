extends Node
class_name UnitEnemySensor

const CombatTargetRegistryScript := preload("res://Scripts/map/combat_target_registry.gd")

func get_enemies(unit_owner: Node2D, owner_team: String) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	var registry := CombatTargetRegistryScript.find_for(unit_owner)
	if registry != null:
		enemies = registry.get_enemy_targets(owner_team)
	else:
		enemies = _get_group_enemies(unit_owner, owner_team)
	_sort_nearest_first(enemies, unit_owner)
	return enemies

func get_enemies_in_radius(unit_owner: Node2D, owner_team: String, center: Vector2, radius: float) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	if unit_owner == null or unit_owner.get_tree() == null or radius < 0.0:
		return enemies

	var radius_squared := radius * radius
	for unit in get_enemies(unit_owner, owner_team):
		if center.distance_squared_to(get_target_position(unit)) <= radius_squared:
			enemies.append(unit)

	_sort_nearest_first(enemies, unit_owner)
	return enemies

func is_valid_enemy(unit_owner: Node2D, owner_team: String, candidate: Variant) -> bool:
	if candidate == null or candidate == unit_owner or not is_instance_valid(candidate) or not (candidate is Node2D):
		return false
	var unit := candidate as Node2D
	if not unit.is_in_group("combat_target"):
		return false
	if unit is CanvasItem and not (unit as CanvasItem).is_visible_in_tree():
		return false
	if unit.get("team") == null or String(unit.get("team")) == owner_team:
		return false
	if unit.has_method("is_alive") and not bool(unit.call("is_alive")):
		return false
	return true

func _get_group_enemies(unit_owner: Node2D, owner_team: String) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	if unit_owner == null or unit_owner.get_tree() == null:
		return enemies
	for candidate in unit_owner.get_tree().get_nodes_in_group("combat_target"):
		if is_valid_enemy(unit_owner, owner_team, candidate):
			enemies.append(candidate as Node2D)
	return enemies

func _sort_nearest_first(enemies: Array[Node2D], unit_owner: Node2D) -> void:
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return unit_owner.global_position.distance_squared_to(get_target_position(a)) < unit_owner.global_position.distance_squared_to(get_target_position(b))
	)

func get_target_position(target: Node2D) -> Vector2:
	if target and target.has_method("get_target_position"):
		return target.call("get_target_position")
	if target:
		return target.global_position
	return Vector2.ZERO
