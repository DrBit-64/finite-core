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
		for template in blueprint.tactical_templates:
			var template_id := str(_read(template, "id", ""))
			if not template_id.is_empty():
				row["templates"][template_id] = {
					"name": str(_read(template, "display_name", template_id)),
					"triggered": 0,
				}
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
			for template_item in payload.get("blueprint_templates", []):
				_seed_template(row, template_item)
			for rule_item in payload.get("blueprint_rules", []):
				_seed_rule(row, rule_item)
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
			_consume_rule_trigger(row, payload)

static func _consume_rule_trigger(row: Dictionary, payload: Dictionary) -> void:
	var template_id := str(payload.get("template_id", ""))
	if not template_id.is_empty():
		if not row["templates"].has(template_id):
			row["templates"][template_id] = {
				"name": str(payload.get("template_name", template_id)),
				"triggered": 0,
			}
		row["templates"][template_id]["triggered"] += 1
		row["template_triggered"] += 1

	var rule_id := str(payload.get("rule_id", "unnamed_rule"))
	if not row["rules"].has(rule_id):
		row["rules"][rule_id] = {
			"name": str(payload.get("rule_name", rule_id)),
			"triggered": 0,
		}
	row["rules"][rule_id]["triggered"] += 1

static func _seed_template(row: Dictionary, template_item: Dictionary) -> void:
	var template_id := str(template_item.get("id", ""))
	if template_id.is_empty() or row["templates"].has(template_id):
		return
	row["templates"][template_id] = {
		"name": str(template_item.get("name", template_id)),
		"triggered": 0,
	}

static func _seed_rule(row: Dictionary, rule_item: Dictionary) -> void:
	var rule_id := str(rule_item.get("id", ""))
	if rule_id.is_empty() or row["rules"].has(rule_id):
		return
	row["rules"][rule_id] = {
		"name": str(rule_item.get("name", rule_id)),
		"triggered": 0,
	}

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
			"template_triggered": 0,
			"loss_reasons": {},
			"templates": {},
			"rules": {},
			"never_triggered_rules": [],
			"never_triggered_templates": [],
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
		_assign_display_names(row["templates"])
		_assign_display_names(row["rules"])
		row["never_triggered_templates"] = _never_triggered_names(row["templates"])
		row["never_triggered_rules"] = _never_triggered_names(row["rules"])
	robot_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("display_name", "")) < str(b.get("display_name", ""))
	)
	report["robots"] = robot_rows
	return report

static func _never_triggered_names(items: Dictionary) -> Array[String]:
	var never_triggered: Array[String] = []
	for item in items.values():
		if int(item.get("triggered", 0)) <= 0:
			never_triggered.append(str(item.get("display_name", item.get("name", "未命名"))))
	never_triggered.sort()
	return never_triggered

static func _assign_display_names(items: Dictionary) -> void:
	var name_counts := {}
	for item in items.values():
		var item_name := str(item.get("name", "未命名"))
		name_counts[item_name] = int(name_counts.get(item_name, 0)) + 1

	var item_ids: Array = items.keys()
	item_ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var name_a := str(items[a].get("name", "未命名"))
		var name_b := str(items[b].get("name", "未命名"))
		if name_a == name_b:
			return str(a) < str(b)
		return name_a < name_b
	)
	var name_indexes := {}
	for item_id in item_ids:
		var item: Dictionary = items[item_id]
		var item_name := str(item.get("name", "未命名"))
		var duplicate_count := int(name_counts.get(item_name, 0))
		if duplicate_count <= 1:
			item["display_name"] = item_name
			continue
		var next_index := int(name_indexes.get(item_name, 0)) + 1
		name_indexes[item_name] = next_index
		item["display_name"] = "%s (%d)" % [item_name, next_index]

static func _read(source: Variant, key: String, fallback: Variant = null) -> Variant:
	if typeof(source) == TYPE_DICTIONARY:
		return source.get(key, fallback)
	if source is Object:
		var value = source.get(key)
		return fallback if value == null else value
	return fallback
