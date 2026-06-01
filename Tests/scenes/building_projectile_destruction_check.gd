extends Node

const EnemyNestScene := preload("res://Scenes/map/enemy_nest.tscn")
const BulletScene := preload("res://Scenes/bullet.tscn")
const CombatTargetRegistryScript := preload("res://Scripts/map/combat_target_registry.gd")

func _ready() -> void:
	var target_registry := CombatTargetRegistryScript.new()
	add_child(target_registry)

	var nest := EnemyNestScene.instantiate()
	add_child(nest)
	nest.setup_nest(&"projectile_test_nest", &"weak_scavenger_nest", {
		"display_name": "子弹测试敌巢",
		"grid_size": [2, 2],
		"max_hp": 1,
		"initial_guard_count": 0,
		"max_guard_count": 0,
		"guard_replenish_seconds": 30.0,
	}, Vector2i(3, 3), 64)

	var bullet := BulletScene.instantiate()
	add_child(bullet)
	bullet.global_position = nest.get_target_position()
	bullet.setup("Team_A", 1, Vector2.RIGHT)

	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(not nest.is_alive(), "子弹碰撞回调应摧毁生命耗尽的敌巢")
	_expect(not target_registry.get_enemy_targets("Team_A").has(nest), "被摧毁敌巢应从地图目标注册表注销")

	print("BUILDING_PROJECTILE_DESTRUCTION_OK")
	get_tree().quit()

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(1)
