extends Node2D

const UnitEnemySensorScript := preload("res://Scripts/units/unit_enemy_sensor.gd")

class FakeUnit:
	extends Node2D

	var team: String = "Team_B"
	var alive := true

	func _ready() -> void:
		add_to_group("combat_target")

	func is_alive() -> bool:
		return alive

	func get_target_position() -> Vector2:
		return global_position

class FakePathProvider:
	extends Node2D

	var blocked_target: Node = null

	func _ready() -> void:
		add_to_group("stage_path_provider")

	func has_navigation_path_to_node(_origin_world: Vector2, target_node: Node) -> bool:
		return target_node != blocked_target

	func get_navigation_cell_for_world(world_position: Vector2) -> Vector2i:
		return Vector2i(floori(world_position.x / 64.0), floori(world_position.y / 64.0))

func _ready() -> void:
	var root := FakePathProvider.new()
	root.name = "ReachableTargetSelectionSmoke"
	root.blocked_target = null
	add_child(root)

	var owner := FakeUnit.new()
	owner.team = "Team_A"
	owner.global_position = Vector2.ZERO
	root.add_child(owner)

	var blocked_near := FakeUnit.new()
	blocked_near.name = "blocked_near"
	blocked_near.global_position = Vector2(64.0, 0.0)
	root.add_child(blocked_near)

	var reachable_far := FakeUnit.new()
	reachable_far.name = "reachable_far"
	reachable_far.global_position = Vector2(320.0, 0.0)
	root.add_child(reachable_far)

	root.blocked_target = blocked_near

	var sensor := UnitEnemySensorScript.new()
	owner.add_child(sensor)
	var enemies := sensor.get_enemies(owner, owner.team)
	if enemies.is_empty():
		push_error("Reachable target sensor returned no enemies.")
		get_tree().quit(1)
		return
	if enemies[0] != reachable_far:
		push_error("Nearest unreachable enemy should be skipped in favor of nearest reachable enemy.")
		get_tree().quit(1)
		return
	print("REACHABLE_TARGET_SELECTION_OK first=%s count=%d" % [enemies[0].name, enemies.size()])
	get_tree().quit(0)
