extends SceneTree

const EnemyConfigLoaderScript := preload("res://Scripts/data/enemy_config_loader.gd")
const RuntimeConfigLoaderScript := preload("res://Scripts/data/runtime_config_loader.gd")
const MapConfigLoaderScript := preload("res://Scripts/map/map_config_loader.gd")

func _init() -> void:
	var runtime_profile := RuntimeConfigLoaderScript.load_runtime_config("res://Resources/data/debug/mvp_runtime_profile.json")
	_expect(runtime_profile.get("spawn_debug_wandering_enemy", false) == true, "Debug wandering enemy runtime switch should be enabled for development.")

	var enemy_config := EnemyConfigLoaderScript.load_enemy_config("res://Resources/data/enemies/mvp_enemies.json")
	var debug_enemy := EnemyConfigLoaderScript.get_type(enemy_config, "unit_types", &"debug_enemy")
	_expect(int(debug_enemy.get("max_hp", 0)) == 2000, "Debug wandering enemy should have 2000 HP.")

	var map_config := MapConfigLoaderScript.load_map_config("res://Resources/data/maps/mvp_stage3_map.json")
	var debug_enemies: Array = map_config.get("debug_enemies", [])
	_expect(not debug_enemies.is_empty(), "Map should declare a debug wandering enemy path.")
	var first_enemy: Dictionary = debug_enemies[0]
	_expect(str(first_enemy.get("id", "")) == "debug_wandering_target_001", "Debug wandering enemy id should be stable.")
	_expect((first_enemy.get("grid_path", []) as Array).size() >= 2, "Debug wandering enemy should have a patrol path.")

	print("DEBUG_WANDERING_ENEMY_CONFIG_OK")
	quit()

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
