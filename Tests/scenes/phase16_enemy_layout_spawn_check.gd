extends Node

const MvpTestMapScene := preload("res://Scenes/mvp/mvp_test_map.tscn")

func _ready() -> void:
	var scene := MvpTestMapScene.instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var patrol := _find_descendant(scene, "crystal_entrance_armored_patrol_001")
	_expect(patrol != null, "Stage 16 entrance armored patrol should spawn.")
	_expect(str(patrol.get("pool_name")) == "armored_scout", "Entrance patrol should use the weak armored scout unit type.")
	_expect(int(patrol.get("max_hp")) == 125, "Entrance armored patrol should stay weak enough for rifle robots.")
	_expect(patrol.get("visual_size").x >= 44.0, "Entrance armored patrol should render larger than basic hounds.")

	var outpost := _find_descendant(scene, "crystal_resource_outpost_001")
	_expect(outpost != null, "Stage 16 crystal resource outpost should spawn.")
	_expect(str(outpost.get("nest_type")) == "crystal_armored_outpost", "Resource outpost should use the crystal outpost nest type.")
	_expect(_count_descendants_by_pool(scene, "armored_patroller") >= 3, "Resource outpost should spawn standard armored patroller guards.")

	var command_nest := _find_descendant(scene, "armored_scavenger_command_nest_001")
	_expect(command_nest != null, "Stage 16 command nest should spawn.")
	_expect(str(command_nest.get("nest_type")) == "armored_scavenger_command_nest", "Command nest should use the boss-like nest type.")
	_expect(int(command_nest.get("max_hp")) == 820, "Command nest should have elevated structure HP.")
	_expect(_count_descendants_by_pool(scene, "armored_rhino") >= 7, "Command nest should spawn armored charger guards.")

	print("PHASE16_ENEMY_LAYOUT_SPAWN_OK")
	get_tree().quit()

func _find_descendant(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	if root.name == target_name:
		return root
	for child in root.get_children():
		var found := _find_descendant(child, target_name)
		if found != null:
			return found
	return null

func _count_descendants_by_pool(root: Node, expected_pool: String) -> int:
	if root == null:
		return 0
	var count := 0
	if root.get("pool_name") != null and str(root.get("pool_name")) == expected_pool:
		count += 1
	for child in root.get_children():
		count += _count_descendants_by_pool(child, expected_pool)
	return count

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(1)
