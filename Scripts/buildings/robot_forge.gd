extends "res://Scripts/buildings/base_building.gd"
class_name RobotForgeBuilding

signal forge_state_changed
signal robot_production_completed(forge: Node, blueprint: UnitBlueprint)

@export var target_alive_count: int = 5

var blueprint: UnitBlueprint = null
var target_inventory: Variant = null
var status_text: String = "未绑定蓝图"
var progress_seconds: float = 0.0
var has_rally_point: bool = false
var rally_point_cell: Vector2i = Vector2i.ZERO
var rally_point_position: Vector2 = Vector2.ZERO
var rally_marker: Node = null

var _tracked_robots: Array[Node] = []

func setup_forge(next_blueprint: UnitBlueprint, inventory: Variant) -> void:
	blueprint = next_blueprint
	target_inventory = inventory
	_update_status()

func set_rally_point(cell: Vector2i, world_position: Vector2) -> void:
	rally_point_cell = cell
	rally_point_position = world_position
	has_rally_point = true
	forge_state_changed.emit()

func register_robot(robot: Node) -> void:
	if robot == null or _tracked_robots.has(robot):
		return
	_tracked_robots.append(robot)
	if robot.has_signal("robot_lost") and not robot.is_connected("robot_lost", Callable(self, "_on_robot_lost")):
		robot.connect("robot_lost", Callable(self, "_on_robot_lost"))
	forge_state_changed.emit()

func get_alive_count() -> int:
	_prune_robot_list()
	return _tracked_robots.size()

func get_spawn_position() -> Vector2:
	var center := Vector2(grid_size.x * cell_size, grid_size.y * cell_size) * 0.5
	return global_position + center + Vector2(float(cell_size) * 0.78, 0.0)

func get_progress_ratio() -> float:
	if blueprint == null or blueprint.production_time_seconds <= 0.0:
		return 0.0
	return clampf(progress_seconds / blueprint.production_time_seconds, 0.0, 1.0)

func get_missing_resources() -> Dictionary:
	if blueprint == null or target_inventory == null:
		return {}
	return target_inventory.get_missing(blueprint.production_cost)

func get_inspector_lines() -> Array[String]:
	var lines := super.get_inspector_lines()
	lines.append("蓝图：%s" % (blueprint.display_name if blueprint else "未绑定"))
	lines.append("存活：%s / %s" % [get_alive_count(), target_alive_count])
	lines.append("状态：%s" % status_text)
	lines.append("进度：%d%%" % int(get_progress_ratio() * 100.0))
	lines.append("集结点：%s" % (_format_rally_point() if has_rally_point else "未设置"))
	return lines

func _process(delta: float) -> void:
	if blueprint == null:
		_set_status("未绑定蓝图")
		progress_seconds = 0.0
		return
	if target_inventory == null:
		_set_status("等待主基地")
		progress_seconds = 0.0
		return
	if get_alive_count() >= target_alive_count and progress_seconds <= 0.0:
		_set_status("已达到目标数量")
		return

	if progress_seconds <= 0.0:
		if not target_inventory.can_afford(blueprint.production_cost):
			_set_status("等待资源")
			return
		if not target_inventory.spend_resources(blueprint.production_cost, "%s 生产 %s" % [get_display_name(), blueprint.display_name]):
			_set_status("等待资源")
			return
		forge_state_changed.emit()

	progress_seconds += delta
	_set_status("生产中")
	if progress_seconds < blueprint.production_time_seconds:
		return

	progress_seconds = 0.0
	robot_production_completed.emit(self, blueprint)
	forge_state_changed.emit()

func _prune_robot_list() -> void:
	for i in range(_tracked_robots.size() - 1, -1, -1):
		var robot := _tracked_robots[i]
		if robot == null or not is_instance_valid(robot):
			_tracked_robots.remove_at(i)
		elif robot.has_method("is_alive") and not bool(robot.call("is_alive")):
			_tracked_robots.remove_at(i)
		elif robot is CanvasItem and not (robot as CanvasItem).visible:
			_tracked_robots.remove_at(i)

func _set_status(next_status: String) -> void:
	if status_text == next_status:
		return
	status_text = next_status
	forge_state_changed.emit()

func _update_status() -> void:
	if blueprint == null:
		_set_status("未绑定蓝图")
	elif target_inventory == null:
		_set_status("等待主基地")
	else:
		_set_status("等待资源")

func _on_robot_lost(robot: Node, _reason: StringName) -> void:
	_tracked_robots.erase(robot)
	forge_state_changed.emit()

func _format_rally_point() -> String:
	return "%s, %s" % [rally_point_cell.x, rally_point_cell.y]
