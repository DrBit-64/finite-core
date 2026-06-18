extends Node

const _POOL_RETURN_PENDING_META := "_pool_return_pending"

var _pools: Dictionary = {}

func get_instance(scene_to_load: PackedScene, parent: Node, pool_name: String) -> Node:
	if scene_to_load == null:
		return null
	if not _pools.has(pool_name):
		_pools[pool_name] = []

	var instance: Node = null
	var pool: Array = _pools[pool_name]
	while not pool.is_empty():
		var candidate: Node = pool.pop_back()
		if candidate != null and is_instance_valid(candidate):
			instance = candidate
			break

	if instance == null:
		instance = scene_to_load.instantiate()
		if parent != null:
			parent.add_child(instance)
	elif instance.get_parent() == null and parent != null:
		parent.add_child(instance)

	instance.set_meta(_POOL_RETURN_PENDING_META, false)
	if instance.has_method("reset_state"):
		instance.reset_state()

	if instance is CollisionObject2D:
		instance.set_deferred("disabled", false)

	instance.process_mode = Node.PROCESS_MODE_INHERIT
	instance.show()
	return instance

func return_instance(instance: Node, pool_name: String) -> void:
	if instance == null or not is_instance_valid(instance):
		return
	if instance.get_meta(_POOL_RETURN_PENDING_META, false):
		return

	instance.set_meta(_POOL_RETURN_PENDING_META, true)
	call_deferred("_deferred_return_instance", instance, pool_name)

func _deferred_return_instance(instance: Node, pool_name: String) -> void:
	if instance == null or not is_instance_valid(instance):
		return

	instance.set_meta(_POOL_RETURN_PENDING_META, false)
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	if instance is CollisionObject2D:
		instance.set_deferred("disabled", true)
	instance.hide()

	if _pools.has(pool_name):
		_pools[pool_name].append(instance)
	else:
		_pools[pool_name] = [instance]

func clear_all() -> void:
	for pool_name in _pools.keys():
		var pool: Array = _pools[pool_name]
		for instance in pool:
			if instance != null and is_instance_valid(instance):
				instance.queue_free()
	_pools.clear()
