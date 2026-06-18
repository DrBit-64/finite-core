extends Node

const MvpTestMapScene := preload("res://Scenes/mvp/mvp_test_map.tscn")

func _ready() -> void:
	var scene := MvpTestMapScene.instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var target := _find_descendant(scene, "debug_wandering_target_001")
	_expect(target != null, "Debug wandering enemy should spawn when runtime profile switch is enabled.")
	_expect(int(target.get("max_hp")) == 2000, "Spawned debug wandering enemy should use 2000 HP from enemy JSON.")
	_expect(str(target.get("brain_mode")) == "path_patrol", "Debug wandering enemy should use path patrol brain.")

	print("DEBUG_WANDERING_ENEMY_SPAWN_OK")
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

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(1)
