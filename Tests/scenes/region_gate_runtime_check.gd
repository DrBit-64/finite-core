extends Node2D

const MvpScene := preload("res://Scenes/mvp/mvp_test_map.tscn")

func _ready() -> void:
	var scene := MvpScene.instantiate()
	add_child(scene)
	await get_tree().process_frame

	_expect(scene.get("enemy_nests_by_id").has(&"enemy_nest_001"), "Starting nest should spawn before the first gate opens.")
	_expect(not scene.get("enemy_nests_by_id").has(&"crystal_resource_outpost_001"), "Crystal outpost should be pending while crystal gate is locked.")
	_expect(int(scene.get("map_pending_enemy_nests").size()) >= 2, "Locked crystal enemies should stay pending.")
	_expect(int(scene.get("map_pending_enemy_patrols").size()) >= 3, "Locked crystal patrols should stay pending.")
	_expect(str(scene.get("map_region_gate_states").get("gate_basin_to_crystal_main", "")) == "locked", "Crystal main gate should start locked.")
	var gate_layer: Node = scene.get("grid_map").get_node_or_null("TerrainLayer/GateLayer")
	_expect(gate_layer != null, "GateLayer should exist.")
	var crystal_gate_cells: Array = scene.get("map_region_gate_cluster_cells_by_gate_id").get("gate_basin_to_crystal_main", [])
	_expect(not crystal_gate_cells.is_empty(), "Crystal gate should be mapped to a real GateLayer cluster.")
	var crystal_gate_cell: Vector2i = crystal_gate_cells[0]
	_expect(int(gate_layer.call("get_cell_source_id", crystal_gate_cell)) < 0, "Locked crystal gate tile should be hidden from GateLayer.")
	_expect(_all_locked_gate_clusters_hidden(scene, gate_layer), "All locked gate tile clusters should be hidden from GateLayer.")

	var resources: Dictionary = scene.get("resource_nodes_by_id")
	var crystal_node: Node = resources.get(&"crystal_ore_001", null)
	_expect(crystal_node != null, "Crystal resource should remain visible while locked.")
	_expect(crystal_node.has_method("is_interaction_locked") and bool(crystal_node.call("is_interaction_locked")), "Crystal resource should be visible but non-interactive before gate unlock.")

	var starting_nest: Node = scene.get("enemy_nests_by_id").get(&"enemy_nest_001", null)
	scene.call("_unlock_region_gates_for_nest", starting_nest)
	await get_tree().process_frame

	_expect(str(scene.get("map_region_gate_states").get("gate_basin_to_crystal_main", "")) == "open", "Crystal main gate should open after starting nest defeat.")
	_expect(str(scene.get("map_region_gate_states").get("gate_basin_to_crystal_risk_bypass", "")) == "open", "Crystal bypass gate should open after starting nest defeat.")
	_expect(int(gate_layer.call("get_cell_source_id", crystal_gate_cell)) >= 0, "Unlocked crystal gate tile should be restored to GateLayer.")
	_expect(scene.get("enemy_nests_by_id").has(&"crystal_resource_outpost_001"), "Crystal outpost should spawn after crystal gate opens.")
	_expect(scene.get("enemy_nests_by_id").has(&"armored_scavenger_command_nest_001"), "Crystal command nest should spawn after crystal gate opens.")
	_expect(not bool(crystal_node.call("is_interaction_locked")), "Crystal resource should become interactive after crystal gate opens.")

	print("REGION_GATE_RUNTIME_OK")
	get_tree().quit(0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(1)

func _all_locked_gate_clusters_hidden(scene: Node, gate_layer: Node) -> bool:
	var gate_states: Dictionary = scene.get("map_region_gate_states")
	var clusters: Dictionary = scene.get("map_region_gate_cluster_cells_by_gate_id")
	for gate_id in gate_states.keys():
		if str(gate_states[gate_id]) != "locked":
			continue
		for cell in clusters.get(str(gate_id), []):
			if int(gate_layer.call("get_cell_source_id", cell)) >= 0:
				return false
	return true
