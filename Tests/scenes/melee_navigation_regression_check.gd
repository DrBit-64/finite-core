extends Node2D

const RobotScene := preload("res://Scenes/robot.tscn")
const HoundScene := preload("res://Scenes/units/scavenger_hound.tscn")

var player: RobotUnit
var hound: RobotUnit
var elapsed_seconds := 0.0
var initial_player_hp := 0

func _ready() -> void:
	add_to_group("stage_path_provider")
	player = RobotScene.instantiate() as RobotUnit
	hound = HoundScene.instantiate() as RobotUnit
	add_child(player)
	add_child(hound)
	player.global_position = Vector2(420.0, 320.0)
	hound.global_position = Vector2(180.0, 320.0)
	hound.setup_scavenger_hound({
		"id": "navigation_test_hound",
		"display_name": "近战寻路测试单位",
		"max_hp": 900,
		"speed": 135.0,
		"melee_damage": 16,
		"melee_range": 32.0,
		"melee_cooldown_seconds": 0.5,
		"guard_aggro_radius": 1000.0,
		"hound_follow_up_radius": 1000.0,
	})
	initial_player_hp = player.hp

func _physics_process(delta: float) -> void:
	elapsed_seconds += delta
	if elapsed_seconds < 5.0:
		return
	var distance := player.global_position.distance_to(hound.global_position)
	if player.hp >= initial_player_hp:
		push_error("Melee unit failed to damage a retreating ranged target. distance=%.2f" % distance)
		get_tree().quit(1)
		return
	print("MELEE_NAVIGATION_REGRESSION_OK hp=%d distance=%.2f" % [player.hp, distance])
	get_tree().quit(0)

func get_navigation_path_points(origin_world: Vector2, target_world: Vector2) -> PackedVector2Array:
	return PackedVector2Array([origin_world, target_world])

func get_navigation_path_points_to_node(origin_world: Vector2, target_node: Node) -> PackedVector2Array:
	var target_world := (target_node as Node2D).global_position
	return PackedVector2Array([origin_world, target_world])

func get_navigation_cell_for_world(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / 64.0), floori(world_position.y / 64.0))

func is_navigation_world_position_walkable(_world_position: Vector2) -> bool:
	return true
