extends "res://Scripts/buildings/base_building.gd"
class_name RobotForgeBuilding

signal forge_state_changed
signal robot_production_completed(forge: Node, blueprint: UnitBlueprint)

const BuildingStatusMarkerScript := preload("res://Scripts/map/building_status_marker.gd")
const STATE_NO_BLUEPRINT := &"no_blueprint"
const STATE_WAITING_BASE := &"waiting_base"
const STATE_WAITING_RESOURCES := &"waiting_resources"
const STATE_TARGET_REACHED := &"target_reached"
const STATE_RUNNING := &"running"
const STATE_PAUSED := &"paused"

@export var target_alive_count: int = 5

var blueprint: UnitBlueprint = null
var target_inventory: Variant = null
var status_text: String = "未绑定蓝图"
var state_id: StringName = STATE_NO_BLUEPRINT
var progress_seconds: float = 0.0
var is_paused: bool = false
var has_rally_point: bool = false
var rally_point_cell: Vector2i = Vector2i.ZERO
var rally_point_position: Vector2 = Vector2.ZERO
var rally_marker: Node = null

var _tracked_robots: Array[Node] = []
var _status_marker: Node2D = null

func setup_forge(next_blueprint: UnitBlueprint, inventory: Variant) -> void:
	_ensure_status_marker()
	target_inventory = inventory
	set_blueprint_snapshot(next_blueprint)

func set_blueprint_snapshot(next_blueprint: UnitBlueprint) -> void:
	blueprint = next_blueprint
	progress_seconds = 0.0
	_update_status()
	forge_state_changed.emit()

func set_paused(paused: bool) -> void:
	if is_paused == paused:
		return
	is_paused = paused
	_update_status()
	forge_state_changed.emit()

func toggle_paused() -> void:
	set_paused(not is_paused)

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

func is_tracking_robot(robot: Node) -> bool:
	_prune_robot_list()
	return robot != null and _tracked_robots.has(robot)

func get_alive_count() -> int:
	_prune_robot_list()
	var count := 0
	var current_snapshot_key := _get_current_snapshot_key()
	for robot in _tracked_robots:
		if _robot_matches_current_snapshot(robot, current_snapshot_key):
			count += 1
	return count

func get_tracked_snapshot_ids() -> Array[StringName]:
	_prune_robot_list()
	var result: Array[StringName] = []
	for robot in _tracked_robots:
		if robot == null or not is_instance_valid(robot):
			continue
		if robot.has_method("get_blueprint_snapshot_key"):
			var snapshot_id := StringName(str(robot.call("get_blueprint_snapshot_key")))
			if not String(snapshot_id).is_empty() and not result.has(snapshot_id):
				result.append(snapshot_id)
	return result

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
	if blueprint and not String(blueprint.get_snapshot_key()).is_empty():
		lines.append("蓝图快照：%s" % blueprint.get_snapshot_key())
	lines.append("存活：%s / %s" % [get_alive_count(), target_alive_count])
	lines.append("状态：%s" % status_text)
	lines.append("暂停：%s" % ("是" if is_paused else "否"))
	lines.append("进度：%d%%" % int(get_progress_ratio() * 100.0))
	lines.append("集结点：%s" % (_format_rally_point() if has_rally_point else "未设置"))
	return lines

func _process(delta: float) -> void:
	_ensure_status_marker()
	if is_paused:
		_set_status("已暂停", STATE_PAUSED)
		return
	if blueprint == null:
		_set_status("未绑定蓝图", STATE_NO_BLUEPRINT)
		progress_seconds = 0.0
		return
	if target_inventory == null:
		_set_status("等待主基地", STATE_WAITING_BASE)
		progress_seconds = 0.0
		return
	if get_alive_count() >= target_alive_count and progress_seconds <= 0.0:
		_set_status("已达到目标数量", STATE_TARGET_REACHED)
		return

	if progress_seconds <= 0.0:
		if not target_inventory.can_afford(blueprint.production_cost):
			_set_status("等待资源", STATE_WAITING_RESOURCES)
			return
		if not target_inventory.spend_resources(blueprint.production_cost, "%s 生产 %s" % [get_display_name(), blueprint.display_name]):
			_set_status("等待资源", STATE_WAITING_RESOURCES)
			return
		forge_state_changed.emit()

	progress_seconds += delta
	_set_status("生产中", STATE_RUNNING)
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

func _ensure_status_marker() -> void:
	if _status_marker != null and is_instance_valid(_status_marker):
		return
	_status_marker = BuildingStatusMarkerScript.new()
	_status_marker.name = "StatusMarker"
	_status_marker.z_index = 50
	_status_marker.position = Vector2(grid_size.x * cell_size - 7.0, 7.0)
	add_child(_status_marker)

func _refresh_status_marker() -> void:
	_ensure_status_marker()
	_status_marker.position = Vector2(grid_size.x * cell_size - 7.0, 7.0)
	if is_paused:
		_status_marker.set_marker_type(BuildingStatusMarkerScript.MARKER_PAUSED)
	elif state_id == STATE_WAITING_RESOURCES:
		_status_marker.set_marker_type(BuildingStatusMarkerScript.MARKER_MISSING_INPUTS)
	else:
		_status_marker.set_marker_type(BuildingStatusMarkerScript.MARKER_NONE)

func _get_current_snapshot_key() -> String:
	if blueprint == null:
		return ""
	return blueprint.get_snapshot_key()

func _robot_matches_current_snapshot(robot: Node, current_snapshot_key: String) -> bool:
	if robot == null or not is_instance_valid(robot):
		return false
	if current_snapshot_key.is_empty():
		return false
	if not robot.has_method("get_blueprint_snapshot_key"):
		return false
	return str(robot.call("get_blueprint_snapshot_key")) == current_snapshot_key

func _set_status(next_status: String, next_state_id: StringName) -> void:
	if status_text == next_status and state_id == next_state_id:
		return
	status_text = next_status
	state_id = next_state_id
	_refresh_status_marker()
	forge_state_changed.emit()

func _update_status() -> void:
	if is_paused:
		_set_status("已暂停", STATE_PAUSED)
	elif blueprint == null:
		_set_status("未绑定蓝图", STATE_NO_BLUEPRINT)
	elif target_inventory == null:
		_set_status("等待主基地", STATE_WAITING_BASE)
	else:
		_set_status("等待资源", STATE_WAITING_RESOURCES)

func _on_robot_lost(robot: Node, _reason: StringName) -> void:
	_tracked_robots.erase(robot)
	forge_state_changed.emit()

func _format_rally_point() -> String:
	return "%s, %s" % [rally_point_cell.x, rally_point_cell.y]
