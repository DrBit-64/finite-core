extends Node

# 存储池化的对象: { "bullet_type_A": [node1, node2...], "robot_type_B": [...] }
var _pools: Dictionary = {}

# 获取对象
func get_instance(scene_to_load: PackedScene, parent: Node, pool_name: String) -> Node:
    if not _pools.has(pool_name):
        _pools[pool_name] = []
        
    var instance: Node
    if _pools[pool_name].is_empty():
        # 如果池子空了，实例化一个新的
        instance = scene_to_load.instantiate()
        parent.add_child(instance)
    else:
        # 如果池子里有，拿出来重新激活
        instance = _pools[pool_name].pop_back()
        # 注意：不要把它从树里移除，只需重新显示并重置状态
        
    # 唤醒节点
    if instance.has_method("reset_state"):
        instance.reset_state() # 必须在对象脚本里写这个方法，重置血量、位置等
    
    # 恢复物理和进程
    instance.process_mode = Node.PROCESS_MODE_INHERIT
    instance.show()
    return instance

# 回收对象（替代 queue_free）
func return_instance(instance: Node, pool_name: String):
    # 停止节点的运行和物理计算，将其隐藏
    instance.process_mode = Node.PROCESS_MODE_DISABLED
    instance.hide()
    
    # 放回池中
    if _pools.has(pool_name):
        _pools[pool_name].append(instance)
    else:
        _pools[pool_name] = [instance]