extends Node

const EnemyNestScene := preload("res://Scenes/map/enemy_nest.tscn")
const ScavengerHoundScene := preload("res://Scenes/units/scavenger_hound.tscn")
const PlayerRobotScene := preload("res://Scenes/robot.tscn")
const CombatTargetRegistryScript := preload("res://Scripts/map/combat_target_registry.gd")

func _ready() -> void:
	var target_registry := CombatTargetRegistryScript.new()
	add_child(target_registry)

	var nest := EnemyNestScene.instantiate()
	add_child(nest)
	nest.setup_nest(&"test_nest", &"weak_scavenger_nest", {
		"display_name": "测试敌巢",
		"grid_size": [2, 2],
		"max_hp": 180,
		"initial_guard_count": 0,
		"max_guard_count": 6,
		"guard_replenish_seconds": 30.0,
	}, Vector2i(3, 3), 64)

	var player_robot := _spawn_player_robot(Vector2(-4096.0, 256.0))
	_expect(target_registry.get_enemy_targets("Team_A").has(nest), "敌巢应注册到地图维护的敌方目标列表")
	_expect(player_robot.get_current_enemy() == nest, "玩家机器人应能通过地图全局目标列表识别远距离敌巢")

	var guard := ScavengerHoundScene.instantiate()
	add_child(guard)
	guard.global_position = nest.get_spawn_position()
	guard.setup_scavenger_hound({
		"display_name": "测试守军",
		"max_hp": 90,
		"speed": 135.0,
		"melee_damage": 16,
		"melee_range": 32.0,
		"melee_cooldown_seconds": 1.0,
		"guard_aggro_radius": 100.0,
		"hound_follow_up_radius": 140.0,
	}, nest)
	nest.register_guard(guard)

	_expect(nest.get_guard_count() == 1, "守军登记后计数应为 1")
	_expect(target_registry.get_enemy_targets("Team_A").has(guard), "守军应注册到地图维护的敌方目标列表")
	_expect(player_robot.get_current_enemy() == nest, "普通机器人应在锁定窗口内保留原目标，不因新目标出现立刻切换")
	_expect(guard.get_current_enemy() == null, "远离敌巢的玩家单位不应触发守军")

	var intruder := _spawn_player_robot(nest.get_target_position() + Vector2(60.0, 0.0))
	_expect(guard.get_current_enemy() == intruder, "玩家进入敌巢警戒半径后守军应锁定目标")
	intruder.global_position = nest.get_target_position() + Vector2(460.0, 0.0)
	_expect(guard.get_current_enemy() == intruder, "已锁定目标离开敌巢警戒半径后守军应继续追杀")

	var follow_up := _spawn_player_robot(guard.global_position + Vector2(-28.0, -18.0))
	intruder.die(&"test_destroyed")
	_expect(guard.get_current_enemy() == follow_up, "原目标死亡后守军应在自身附近续接其它目标")

	guard.die(&"test_destroyed")
	await get_tree().process_frame
	_expect(nest.get_guard_count() == 0, "守军死亡后应立即从敌巢注销")
	_expect(not target_registry.get_enemy_targets("Team_A").has(guard), "守军死亡后应从地图维护的敌方目标列表注销")

	var countdown_before: float = nest.replenish_seconds_remaining
	nest._process(0.25)
	_expect(nest.replenish_seconds_remaining < countdown_before, "守军不足时补员倒计时应开始递减")

	print("STAGE7_GUARD_LIFECYCLE_OK")
	get_tree().quit()

func _spawn_player_robot(world_position: Vector2) -> Node2D:
	var robot := PlayerRobotScene.instantiate()
	add_child(robot)
	robot.global_position = world_position
	return robot

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(1)
