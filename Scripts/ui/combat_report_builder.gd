extends RefCounted
class_name CombatReportBuilder

const DEFAULT_WINDOW_SECONDS := 300.0

static func build_report(
	event_log: Node,
	blueprints: Array[UnitBlueprint],
	resource_defs: Array[ResourceDef],
	window_seconds: float = DEFAULT_WINDOW_SECONDS
) -> Dictionary:
	var report := {
		"window_seconds": window_seconds,
		"resources": _make_resource_rows(resource_defs),
		"robots": {},
	}
	_seed_blueprint_rows(report["robots"], blueprints)
	if event_log == null or not event_log.has_method("get_recent_events"):
		return _finalize_report(report)

	for event in event_log.call("get_recent_events", window_seconds, ""):
		_consume_event(report, event)
	return _finalize_report(report)

static func _make_resource_rows(resource_defs: Array[ResourceDef]) -> Dictionary:
	var rows := {}
	for resource_def in resource_defs:
		rows[String(resource_def.id)] = {
			"resource_id": String(resource_def.id),
			"display_name": resource_def.display_name,
			"produced": 0,
			"consumed": 0,
			"net": 0,
		}
	return rows

static func _seed_blueprint_rows(rows: Dictionary, blueprints: Array[UnitBlueprint]) -> void:
	for blueprint in blueprints:
		if blueprint == null:
			continue
		var row := _ensure_robot_row(rows, String(blueprint.id), blueprint.version, blueprint.display_name)
		for rule in blueprint.embedded_rules:
			var rule_id := str(_read(rule, "id", _read(rule, "name", "unnamed_rule")))
			var rule_name := str(_read(rule, "name", rule_id))
			if not rule_id.is_empty():
				row["rules"][rule_id] = {
					"name": rule_name,
					"triggered": 0,
				}

static func _consume_event(report: Dictionary, event: Dictionary) -> void:
	var event_type := str(event.get("type", ""))
	var payload: Dictionary = event.get("payload", {})
	match event_type:
		"resource_gained":
			_update_resource(report["resources"], payload, true)
		"resource_spent":
			_update_resource(report["resources"], payload, false)
		"robot_produced":
			var row := _robot_row_from_payload(report["robots"], payload)
			row["produced"] += 1
			for rule_item in payload.get("blueprint_rules", []):
				var rule_id := str(rule_item.get("id", ""))
				if not rule_id.is_empty() and not row["rules"].has(rule_id):
					row["rules"][rule_id] = {
						"name": str(rule_item.get("name", rule_id)),
						"triggered": 0,
					}
		"robot_lost":
			var row := _robot_row_from_payload(report["robots"], payload)
			row["lost"] += 1
			var reason := str(payload.get("reason", "unknown"))
			row["loss_reasons"][reason] = int(row["loss_reasons"].get(reason, 0)) + 1
		"enemy_killed":
			var blueprint_id := str(payload.get("killer_blueprint_id", ""))
			if not blueprint_id.is_empty():
				var row := _ensure_robot_row(
					report["robots"],
					blueprint_id,
					int(payload.get("killer_blueprint_version", 0)),
					str(payload.get("killer_blueprint_name", blueprint_id))
				)
				row["kills"] += 1
		"rule_triggered":
			var row := _robot_row_from_payload(report["robots"], payload)
			row["rule_triggered"] += 1
			var rule_id := str(payload.get("rule_id", "unnamed_rule"))
			if not row["rules"].has(rule_id):
				row["rules"][rule_id] = {
					"name": str(payload.get("rule_name", rule_id)),
					"triggered": 0,
				}
			row["rules"][rule_id]["triggered"] += 1

static func _update_resource(rows: Dictionary, payload: Dictionary, is_gain: bool) -> void:
	var resource_id := str(payload.get("resource_id", "unknown"))
	if not rows.has(resource_id):
		rows[resource_id] = {
			"resource_id": resource_id,
			"display_name": resource_id,
			"produced": 0,
			"consumed": 0,
			"net": 0,
		}
	var amount := absi(int(payload.get("delta", 0)))
	if is_gain:
		rows[resource_id]["produced"] += amount
	else:
		rows[resource_id]["consumed"] += amount
	rows[resource_id]["net"] = int(rows[resource_id]["produced"]) - int(rows[resource_id]["consumed"])

static func _robot_row_from_payload(rows: Dictionary, payload: Dictionary) -> Dictionary:
	return _ensure_robot_row(
		rows,
		str(payload.get("blueprint_id", "unknown_blueprint")),
		int(payload.get("blueprint_version", 0)),
		str(payload.get("blueprint_name", payload.get("blueprint_id", "未知蓝图")))
	)

static func _ensure_robot_row(rows: Dictionary, blueprint_id: String, version: int, display_name: String) -> Dictionary:
	var row_key := "%s_v%d" % [blueprint_id, version]
	if not rows.has(row_key):
		rows[row_key] = {
			"blueprint_id": blueprint_id,
			"blueprint_version": version,
			"display_name": display_name,
			"produced": 0,
			"lost": 0,
			"kills": 0,
			"rule_triggered": 0,
			"loss_reasons": {},
			"rules": {},
			"never_triggered_rules": [],
		}
	elif str(rows[row_key].get("display_name", "")).is_empty():
		rows[row_key]["display_name"] = display_name
	return rows[row_key]

static func _finalize_report(report: Dictionary) -> Dictionary:
	var resource_rows: Array = report["resources"].values()
	resource_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")) < str(b.get("display_name", ""))
	)
	report["resources"] = resource_rows

	var robot_rows: Array = report["robots"].values()
	for row in robot_rows:
		_assign_rule_display_names(row["rules"])
		var never_triggered: Array[String] = []
		for rule in row["rules"].values():
			if int(rule.get("triggered", 0)) <= 0:
				never_triggered.append(str(rule.get("display_name", rule.get("name", "未命名规则"))))
		never_triggered.sort()
		row["never_triggered_rules"] = never_triggered
	robot_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")) < str(b.get("display_name", ""))
	)
	report["robots"] = robot_rows
	return report

static func _assign_rule_display_names(rules: Dictionary) -> void:
	var name_counts := {}
	for rule in rules.values():
		var rule_name := str(rule.get("name", "未命名规则"))
		name_counts[rule_name] = int(name_counts.get(rule_name, 0)) + 1

	var rule_ids: Array = rules.keys()
	rule_ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var name_a := str(rules[a].get("name", "未命名规则"))
		var name_b := str(rules[b].get("name", "未命名规则"))
		return str(a) < str(b) if name_a == name_b else name_a < name_b
	)
	var name_indexes := {}
	for rule_id in rule_ids:
		var rule: Dictionary = rules[rule_id]
		var rule_name := str(rule.get("name", "未命名规则"))
		var duplicate_count := int(name_counts.get(rule_name, 0))
		if duplicate_count <= 1:
			rule["display_name"] = rule_name
			continue
		var next_index := int(name_indexes.get(rule_name, 0)) + 1
		name_indexes[rule_name] = next_index
		rule["display_name"] = "%s (%d)" % [rule_name, next_index]

static func _read(source: Variant, key: String, fallback: Variant = null) -> Variant:
	if typeof(source) == TYPE_DICTIONARY:
		return source.get(key, fallback)
	if source is Object:
		var value = source.get(key)
		return fallback if value == null else value
	return fallback
