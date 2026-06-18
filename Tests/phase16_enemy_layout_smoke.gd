extends SceneTree

const EnemyConfigLoaderScript := preload("res://Scripts/data/enemy_config_loader.gd")
const MapConfigLoaderScript := preload("res://Scripts/map/map_config_loader.gd")

func _init() -> void:
	var enemy_config := EnemyConfigLoaderScript.load_enemy_config("res://Resources/data/enemies/mvp_enemies.json")
	var armored_scout := EnemyConfigLoaderScript.get_type(enemy_config, "unit_types", &"armored_scout")
	_require(not armored_scout.is_empty(), "Stage 16 weak armored scout is missing.")
	_require(int(armored_scout.get("max_hp", 0)) <= 140, "Entrance armored scout should stay weak enough for rifle robots.")
	_require(str(armored_scout.get("armor_type", "")) == "armored", "Entrance patrol should demonstrate armored damage resistance.")
	_require(str(armored_scout.get("icon_path", "")) == "res://Resources/art/enemies/armored_rhino.svg", "Weak armored scout should share the existing patrol art.")
	_require(_visual_size_x(armored_scout) >= 44.0, "Armored scouts should render larger than basic hounds.")

	var armored_patroller := EnemyConfigLoaderScript.get_type(enemy_config, "unit_types", &"armored_patroller")
	_require(not armored_patroller.is_empty(), "Stage 16 standard armored patroller is missing.")
	_require(str(armored_patroller.get("icon_path", "")) == "res://Resources/art/enemies/armored_rhino.svg", "Armored patroller should use the existing armored art.")
	_require(_visual_size_x(armored_patroller) > _visual_size_x(armored_scout), "Standard armored patroller should be visually larger than the weakened entrance variant.")

	var armored_rhino := EnemyConfigLoaderScript.get_type(enemy_config, "unit_types", &"armored_rhino")
	_require(not armored_rhino.is_empty(), "Stage 16 armored charger is missing.")
	_require(str(armored_rhino.get("icon_path", "")) == "res://Resources/art/enemies/armored_charger.svg", "Armored charger should use the new charger art.")

	var outpost := EnemyConfigLoaderScript.get_type(enemy_config, "nest_types", &"crystal_armored_outpost")
	_require(not outpost.is_empty(), "Crystal armored outpost is missing.")
	_require(str(outpost.get("guard_unit_type", "")) == "armored_patroller", "Resource outpost should use standard armored patrollers.")

	var command_nest := EnemyConfigLoaderScript.get_type(enemy_config, "nest_types", &"armored_scavenger_command_nest")
	_require(not command_nest.is_empty(), "Armored scavenger command nest is missing.")
	_require(str(command_nest.get("display_name", "")) == "装甲拾荒指挥巢", "Command nest display name should make the stage goal explicit.")
	_require(int(command_nest.get("initial_guard_count", 0)) >= 6, "Command nest should feel like a small boss encounter.")
	_require(int(command_nest.get("max_guard_count", 0)) >= 8, "Command nest should support 6-8 armored guards.")
	var reward: Dictionary = command_nest.get("reward", {})
	_require(str(reward.get("technology_item", "")) == "high_frequency_oscillator", "Command nest should reward the oscillator key item.")

	var map_config := MapConfigLoaderScript.load_map_config("res://Resources/data/maps/mvp_stage3_map.json")
	var blocked_crystal_entrance_cells := _collect_crystal_entrance_blocked_cells(map_config)
	var patrols: Array = map_config.get("enemy_patrols", [])
	_require(patrols.size() == 3, "Crystal entrance should have exactly three weak armored patrol units.")
	for patrol in patrols:
		_require(typeof(patrol) == TYPE_DICTIONARY, "Enemy patrol entries should be dictionaries.")
		var patrol_entry: Dictionary = patrol
		_require(str(patrol_entry.get("unit_type", "")) == "armored_scout", "Entrance patrols should use armored_scout.")
		var patrol_cell := _vector2i_from_array(patrol_entry.get("grid_origin", []))
		_require(not blocked_crystal_entrance_cells.has(_cell_key(patrol_cell)), "Entrance patrols should not stand on the crystal route or gate cells.")
		_require(patrol_cell.x > 84, "Entrance patrols should stand behind the channel, not inside it.")

	var nest_ids := {}
	for nest in map_config.get("enemy_nests", []):
		if typeof(nest) == TYPE_DICTIONARY:
			var nest_entry: Dictionary = nest
			nest_ids[str(nest_entry.get("id", ""))] = str(nest_entry.get("nest_type", ""))
	_require(nest_ids.get("crystal_resource_outpost_001", "") == "crystal_armored_outpost", "Resource outpost should be placed on the map.")
	_require(nest_ids.get("armored_scavenger_command_nest_001", "") == "armored_scavenger_command_nest", "Command nest should be placed on the map.")

	print("PHASE16_ENEMY_LAYOUT_SMOKE_OK patrols=%d" % patrols.size())
	quit(0)

func _visual_size_x(config: Dictionary) -> float:
	var value: Variant = config.get("visual_size", [0.0, 0.0])
	if typeof(value) == TYPE_ARRAY and value.size() >= 1:
		return float(value[0])
	return 0.0

func _collect_crystal_entrance_blocked_cells(map_config: Dictionary) -> Dictionary:
	var blocked := {}
	for route in map_config.get("region_routes", []):
		if typeof(route) != TYPE_DICTIONARY:
			continue
		var route_entry: Dictionary = route
		if str(route_entry.get("id", "")) != "basin_to_crystal_main":
			continue
		for cell_value in route_entry.get("path_cells", []):
			blocked[_cell_key(_vector2i_from_array(cell_value))] = true
	for connection in map_config.get("region_connections", []):
		if typeof(connection) != TYPE_DICTIONARY:
			continue
		var connection_entry: Dictionary = connection
		if str(connection_entry.get("route_id", "")) != "basin_to_crystal_main":
			continue
		for cell_value in connection_entry.get("gate_cells", []):
			blocked[_cell_key(_vector2i_from_array(cell_value))] = true
	return blocked

func _vector2i_from_array(value: Variant) -> Vector2i:
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
