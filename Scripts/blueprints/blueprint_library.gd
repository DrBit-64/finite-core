extends RefCounted
class_name BlueprintLibrary

const TacticalTemplateCompilerScript := preload("res://Scripts/ai/tactical_template_compiler.gd")

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
	blueprint.tactical_templates = [
		TacticalTemplateCompilerScript.make_rally_then_attack_instance()
	]
	var compiled: Dictionary = TacticalTemplateCompilerScript.compile_templates(blueprint.tactical_templates)
	blueprint.state_flag_defaults = compiled.get("state_flag_defaults", {}).duplicate(true)
	blueprint.embedded_rules = compiled.get("rules", []).duplicate(true)
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
	var compiled: Dictionary = TacticalTemplateCompilerScript.compile_templates([
		TacticalTemplateCompilerScript.make_rally_then_attack_instance()
	])
	return compiled.get("rules", [])
