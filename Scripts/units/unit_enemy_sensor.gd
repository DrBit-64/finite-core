extends Node
class_name UnitEnemySensor

const CombatTargetRegistryScript := preload("res://Scripts/map/combat_target_registry.gd")

const ENEMY_LIST_CACHE_MSEC := 180

@export var require_reachable_targets: bool = true
@export var reachability_cache_msec: int = 250
@export var max_reachability_candidates: int = 8

var _reachability_cache: Dictionary = {}
var _enemy_list_cache: Dictionary = {}

func get_enemies(unit_owner: Node2D, owner_team: String) -> Array[Node2D]:
	if unit_owner == null:
		return []
	var cached := _get_cached_enemy_list(unit_owner, owner_team)
	if not cached.is_empty() or _has_fresh_empty_enemy_cache(unit_owner, owner_team):
		return cached
	var enemies: Array[Node2D] = []
	var registry := CombatTargetRegistryScript.find_for(unit_owner)
	if registry != null:
		enemies = registry.get_enemy_targets(owner_team)
	else:
		enemies = _get_group_enemies(unit_owner, owner_team)
	_sort_nearest_first(enemies, unit_owner)
	enemies = _filter_reachable_enemies(enemies, unit_owner)
	_sort_nearest_first(enemies, unit_owner)
	_store_enemy_list_cache(unit_owner, owner_team, enemies)
	return enemies

func _get_cached_enemy_list(unit_owner: Node2D, owner_team: String) -> Array[Node2D]:
	var cached: Dictionary = _enemy_list_cache.get(_enemy_list_cache_key(unit_owner, owner_team), {})
	if cached.is_empty():
		return []
	var now := Time.get_ticks_msec()
	if now - int(cached.get("time", 0)) > ENEMY_LIST_CACHE_MSEC:
		return []
	var result: Array[Node2D] = []
	for candidate in cached.get("enemies", []):
		if is_valid_enemy(unit_owner, owner_team, candidate):
			result.append(candidate as Node2D)
	return result

func _has_fresh_empty_enemy_cache(unit_owner: Node2D, owner_team: String) -> bool:
	var cached: Dictionary = _enemy_list_cache.get(_enemy_list_cache_key(unit_owner, owner_team), {})
	if cached.is_empty():
		return false
	if int(cached.get("count", 0)) != 0:
		return false
	return Time.get_ticks_msec() - int(cached.get("time", 0)) <= ENEMY_LIST_CACHE_MSEC

func _store_enemy_list_cache(unit_owner: Node2D, owner_team: String, enemies: Array[Node2D]) -> void:
	var stored: Array = []
	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy):
			stored.append(enemy)
	_enemy_list_cache[_enemy_list_cache_key(unit_owner, owner_team)] = {
		"time": Time.get_ticks_msec(),
		"count": stored.size(),
		"enemies": stored,
	}
	if _enemy_list_cache.size() > 16:
		_enemy_list_cache.clear()

func _enemy_list_cache_key(unit_owner: Node2D, owner_team: String) -> String:
	var cell := Vector2i(
		floori(unit_owner.global_position.x / 64.0),
		floori(unit_owner.global_position.y / 64.0)
	)
	return "%s:%s:%s" % [owner_team, cell.x, cell.y]

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

func _filter_reachable_enemies(enemies: Array[Node2D], unit_owner: Node2D) -> Array[Node2D]:
	if not require_reachable_targets or unit_owner == null:
		return enemies
	var result: Array[Node2D] = []
	var path_provider := _get_path_provider(unit_owner)
	if path_provider == null:
		return enemies
	var owner_cell := _get_navigation_cell(path_provider, unit_owner.global_position)
	var checked := 0
	for enemy in enemies:
		if checked >= max_reachability_candidates:
			break
		checked += 1
		if _is_target_reachable(unit_owner, enemy, path_provider, owner_cell):
			result.append(enemy)
	return result

func _is_target_reachable(unit_owner: Node2D, target: Node2D, path_provider: Node, owner_cell: Vector2i) -> bool:
	if unit_owner == null or target == null or not is_instance_valid(target):
		return false
	var now := Time.get_ticks_msec()
	var target_cell := _get_navigation_cell(path_provider, get_target_position(target))
	var cache_key := "%s:%s:%s:%s:%s" % [
		unit_owner.get_instance_id(),
		target.get_instance_id(),
		owner_cell.x,
		owner_cell.y,
		"%d,%d" % [target_cell.x, target_cell.y],
	]
	var cached: Dictionary = _reachability_cache.get(cache_key, {})
	if not cached.is_empty() and now - int(cached.get("time", 0)) <= reachability_cache_msec:
		return bool(cached.get("reachable", false))
	var reachable := _query_target_reachable(unit_owner, target, path_provider)
	_reachability_cache[cache_key] = {
		"time": now,
		"reachable": reachable,
	}
	_prune_reachability_cache(now)
	return reachable

func _query_target_reachable(unit_owner: Node2D, target: Node2D, path_provider: Node) -> bool:
	if path_provider.has_method("has_navigation_path_to_node"):
		return bool(path_provider.call("has_navigation_path_to_node", unit_owner.global_position, target))
	if path_provider.has_method("has_navigation_path_to_world"):
		return bool(path_provider.call("has_navigation_path_to_world", unit_owner.global_position, get_target_position(target)))
	if path_provider.has_method("get_navigation_path_points_to_node"):
		var node_path: PackedVector2Array = path_provider.call("get_navigation_path_points_to_node", unit_owner.global_position, target)
		return _path_points_reachable(unit_owner.global_position, get_target_position(target), node_path)
	if path_provider.has_method("get_navigation_path_points"):
		var world_path: PackedVector2Array = path_provider.call("get_navigation_path_points", unit_owner.global_position, get_target_position(target))
		return _path_points_reachable(unit_owner.global_position, get_target_position(target), world_path)
	return true

func _path_points_reachable(origin_world: Vector2, target_world: Vector2, points: PackedVector2Array) -> bool:
	if points.size() > 1:
		return true
	if origin_world.distance_to(target_world) <= 24.0:
		return true
	return false

func _get_path_provider(unit_owner: Node2D) -> Node:
	if unit_owner == null or unit_owner.get_tree() == null:
		return null
	var current: Node = unit_owner
	while current != null:
		if current.has_method("has_navigation_path_to_node") or current.has_method("get_navigation_path_points_to_node"):
			return current
		current = current.get_parent()
	return unit_owner.get_tree().get_first_node_in_group("stage_path_provider")

func _get_navigation_cell(path_provider: Node, world_position: Vector2) -> Vector2i:
	if path_provider != null and path_provider.has_method("get_navigation_cell_for_world"):
		return path_provider.call("get_navigation_cell_for_world", world_position)
	return Vector2i(floori(world_position.x / 64.0), floori(world_position.y / 64.0))

func _prune_reachability_cache(now_msec: int) -> void:
	if _reachability_cache.size() <= 256:
		return
	var ttl := maxi(50, reachability_cache_msec * 4)
	for key in _reachability_cache.keys():
		var cached: Dictionary = _reachability_cache.get(key, {})
		if cached.is_empty() or now_msec - int(cached.get("time", 0)) > ttl:
			_reachability_cache.erase(key)

func get_target_position(target: Node2D) -> Vector2:
	if target and target.has_method("get_target_position"):
		return target.call("get_target_position")
	if target:
		return target.global_position
	return Vector2.ZERO
