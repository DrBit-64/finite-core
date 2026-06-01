extends Node
class_name CombatTargetRegistry

const UNIT_COUNT_CACHE_MSEC := 100

var _targets_by_team: Dictionary = {}
var _unit_count_cache: Dictionary = {}

func _ready() -> void:
	add_to_group("combat_target_registry")

func register_target(target: Node) -> void:
	if target == null or not is_instance_valid(target) or target.get("team") == null:
		return
	unregister_target(target)
	var team_id := String(target.get("team"))
	if not _targets_by_team.has(team_id):
		_targets_by_team[team_id] = []
	var targets: Array = _targets_by_team[team_id]
	targets.append(target)
	_unit_count_cache.clear()

func unregister_target(target: Node) -> void:
	if target == null:
		return
	for team_id in _targets_by_team.keys():
		var targets: Array = _targets_by_team[team_id]
		targets.erase(target)
	_unit_count_cache.clear()

func get_enemy_targets(owner_team: String) -> Array[Node2D]:
	_prune_targets()
	var enemies: Array[Node2D] = []
	for team_id in _targets_by_team.keys():
		if String(team_id) == owner_team:
			continue
		for target in _targets_by_team[team_id]:
			if target is Node2D:
				enemies.append(target as Node2D)
	return enemies

func count_units_near(team_id: String, center: Vector2, radius: float) -> int:
	var cache_key := "%s:%.2f:%.2f:%.2f" % [team_id, center.x, center.y, radius]
	var now := Time.get_ticks_msec()
	var cached: Dictionary = _unit_count_cache.get(cache_key, {})
	if not cached.is_empty() and now - int(cached.get("time", 0)) < UNIT_COUNT_CACHE_MSEC:
		return int(cached.get("count", 0))

	_prune_targets()
	var count := 0
	var radius_squared := radius * radius
	var targets: Array = _targets_by_team.get(team_id, [])
	for target in targets:
		if target is Node2D and target.is_in_group("combat_unit"):
			if center.distance_squared_to((target as Node2D).global_position) <= radius_squared:
				count += 1
	_unit_count_cache[cache_key] = {
		"time": now,
		"count": count,
	}
	return count

static func find_for(requester: Node) -> Node:
	if requester == null:
		return null
	var current := requester
	while current != null:
		if current.has_method("get_combat_target_registry"):
			var registry: Node = current.call("get_combat_target_registry")
			if registry != null:
				return registry
		current = current.get_parent()
	var tree := requester.get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("combat_target_registry")

func _prune_targets() -> void:
	for team_id in _targets_by_team.keys():
		var targets: Array = _targets_by_team[team_id]
		for index in range(targets.size() - 1, -1, -1):
			var target: Variant = targets[index]
			if not _is_active_target(target):
				targets.remove_at(index)

func _is_active_target(target: Variant) -> bool:
	if target == null or not is_instance_valid(target) or not (target is Node2D):
		return false
	var node := target as Node2D
	if not node.is_in_group("combat_target"):
		return false
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return false
	if node.has_method("is_alive") and not bool(node.call("is_alive")):
		return false
	return true
