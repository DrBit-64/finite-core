extends RefCounted
class_name BlueprintLibrary

var _blueprints: Dictionary = {}
var _snapshots: Dictionary = {}
var _snapshot_ref_counts: Dictionary = {}
var _next_custom_index: int = 1

func add_blueprint(blueprint: UnitBlueprint) -> void:
	if blueprint == null:
		return
	blueprint.is_snapshot = false
	blueprint.snapshot_id = &""
	_blueprints[blueprint.id] = blueprint

func get_blueprints() -> Array[UnitBlueprint]:
	var result: Array[UnitBlueprint] = []
	for key in _blueprints.keys():
		result.append(_blueprints[key])
	result.sort_custom(func(a: UnitBlueprint, b: UnitBlueprint) -> bool:
		return a.display_name < b.display_name
	)
	return result

func get_blueprint(blueprint_id: StringName) -> UnitBlueprint:
	return _blueprints.get(blueprint_id, null)

func save_blueprint(blueprint: UnitBlueprint) -> UnitBlueprint:
	if blueprint == null:
		return null
	var existing := get_blueprint(blueprint.id)
	if existing:
		blueprint.version = existing.version + 1
	else:
		blueprint.version = max(1, blueprint.version)
	add_blueprint(blueprint)
	return blueprint

func create_rally_variant(source: UnitBlueprint, display_name: String) -> UnitBlueprint:
	if source == null:
		return null
	var blueprint := source.make_snapshot()
	blueprint.id = StringName("custom_rally_%03d" % _next_custom_index)
	_next_custom_index += 1
	blueprint.display_name = display_name
	blueprint.version = 1
	blueprint.source_blueprint_id = &""
	blueprint.snapshot_id = &""
	blueprint.is_snapshot = false
	blueprint.state_flag_defaults = {"rallied": false, "squad_ready": false}
	blueprint.embedded_rules = _make_rally_rules()
	add_blueprint(blueprint)
	return blueprint

func create_snapshot(blueprint: UnitBlueprint) -> UnitBlueprint:
	if blueprint == null:
		return null
	var snapshot_id := StringName("%s_v%d_snapshot_%d" % [
		String(blueprint.id),
		blueprint.version,
		Time.get_ticks_msec(),
	])
	var snapshot := blueprint.make_snapshot(snapshot_id)
	_snapshots[snapshot.snapshot_id] = snapshot
	_snapshot_ref_counts[snapshot.snapshot_id] = int(_snapshot_ref_counts.get(snapshot.snapshot_id, 0))
	return snapshot

func retain_snapshot(snapshot: UnitBlueprint) -> void:
	if snapshot == null or String(snapshot.snapshot_id).is_empty():
		return
	_snapshots[snapshot.snapshot_id] = snapshot
	_snapshot_ref_counts[snapshot.snapshot_id] = int(_snapshot_ref_counts.get(snapshot.snapshot_id, 0)) + 1

func release_snapshot(snapshot: UnitBlueprint) -> void:
	if snapshot == null or String(snapshot.snapshot_id).is_empty():
		return
	var count := int(_snapshot_ref_counts.get(snapshot.snapshot_id, 0)) - 1
	if count <= 0:
		_snapshot_ref_counts.erase(snapshot.snapshot_id)
		_snapshots.erase(snapshot.snapshot_id)
	else:
		_snapshot_ref_counts[snapshot.snapshot_id] = count

func prune_unused_snapshots(active_snapshot_ids: Array[StringName]) -> int:
	var active := {}
	for snapshot_id in active_snapshot_ids:
		active[snapshot_id] = true
	var removed := 0
	for snapshot_id in _snapshots.keys():
		if active.has(snapshot_id):
			continue
		if int(_snapshot_ref_counts.get(snapshot_id, 0)) > 0:
			continue
		_snapshots.erase(snapshot_id)
		_snapshot_ref_counts.erase(snapshot_id)
		removed += 1
	return removed

func _make_rally_rules() -> Array:
	return [
		{
			"id": "move_to_rally",
			"name": "前往集结点",
			"subject": "self",
			"match_mode": "all",
			"conditions": [
				{"type": "has_rally_point"},
				{"type": "self_flag_is", "flag": "rallied", "value": false},
				{"type": "distance_to_rally_greater", "value": 20.0}
			],
			"action": "move_to_rally"
		},
		{
			"id": "mark_rallied",
			"name": "标记已集结",
			"subject": "self",
			"match_mode": "all",
			"conditions": [
				{"type": "has_rally_point"},
				{"type": "self_flag_is", "flag": "rallied", "value": false},
				{"type": "distance_to_rally_less_equal", "value": 20.0}
			],
			"action": "set_self_flag",
			"flag": "rallied",
			"value": true
		},
		{
			"id": "wait_for_squad",
			"name": "等待队友",
			"subject": "self",
			"match_mode": "all",
			"conditions": [
				{"type": "has_rally_point"},
				{"type": "self_flag_is", "flag": "rallied", "value": true},
				{"type": "self_flag_is", "flag": "squad_ready", "value": false},
				{"type": "allies_near_rally_less", "value": 4, "radius": 90.0}
			],
			"action": "wait"
		},
		{
			"id": "mark_squad_ready",
			"name": "等待队友",
			"subject": "self",
			"match_mode": "all",
			"conditions": [
				{"type": "has_rally_point"},
				{"type": "self_flag_is", "flag": "rallied", "value": true},
				{"type": "self_flag_is", "flag": "squad_ready", "value": false},
				{"type": "allies_near_rally_at_least", "value": 4, "radius": 90.0}
			],
			"action": "set_self_flag",
			"flag": "squad_ready",
			"value": true
		},
		{
			"id": "default_after_rally",
			"name": "默认脑干接管",
			"subject": "self",
			"match_mode": "all",
			"conditions": [
				{"type": "self_flag_is", "flag": "squad_ready", "value": true}
			],
			"action": "default_combat"
		}
	]
