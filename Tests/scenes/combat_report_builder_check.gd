extends Node

const ReportBuilderScript := preload("res://Scripts/ui/combat_report_builder.gd")
const ReportOverlayScript := preload("res://Scripts/ui/combat_report_overlay.gd")
const BlueprintLibraryScript := preload("res://Scripts/blueprints/blueprint_library.gd")

func _ready() -> void:
	var event_log := get_node("/root/CombatEventLog")
	event_log.clear()

	var resource_defs := MvpDataDefaults.create_resource_defs()
	var basic_blueprint := MvpDataDefaults.create_basic_rifle_blueprint()
	var blueprint: UnitBlueprint = BlueprintLibraryScript.new().create_rally_variant(basic_blueprint, "测试集结蓝图")
	event_log.record(&"resource_gained", {
		"resource_id": "iron_plate",
		"delta": 12,
	})
	event_log.record(&"resource_spent", {
		"resource_id": "iron_plate",
		"delta": -5,
	})
	event_log.record(&"robot_produced", {
		"blueprint_id": String(blueprint.id),
		"blueprint_name": blueprint.display_name,
		"blueprint_version": blueprint.version,
	})
	event_log.record(&"robot_lost", {
		"blueprint_id": String(blueprint.id),
		"blueprint_name": blueprint.display_name,
		"blueprint_version": blueprint.version,
		"reason": "lifespan_expired",
	})
	event_log.record(&"rule_triggered", {
		"blueprint_id": String(blueprint.id),
		"blueprint_name": blueprint.display_name,
		"blueprint_version": blueprint.version,
		"rule_id": "move_to_rally",
		"rule_name": "集结小队",
	})
	event_log.record(&"enemy_killed", {
		"killer_blueprint_id": String(blueprint.id),
		"killer_blueprint_name": blueprint.display_name,
		"killer_blueprint_version": blueprint.version,
	})

	var report: Dictionary = ReportBuilderScript.build_report(event_log, [basic_blueprint, blueprint], resource_defs)
	var iron_plate := _find_row(report.get("resources", []), "resource_id", "iron_plate")
	_expect(int(iron_plate.get("produced", 0)) == 12, "铁板产出统计应为 12")
	_expect(int(iron_plate.get("consumed", 0)) == 5, "铁板消耗统计应为 5")
	_expect(int(iron_plate.get("net", 0)) == 7, "铁板净变化应为 +7")

	var robot_row := _find_row(report.get("robots", []), "blueprint_id", String(blueprint.id))
	var basic_robot_row := _find_row(report.get("robots", []), "blueprint_id", String(basic_blueprint.id))
	_expect(basic_robot_row.get("rules", {}).is_empty(), "基础步枪蓝图不应内嵌自定义规则")
	_expect(int(robot_row.get("produced", 0)) == 1, "蓝图机器人生产统计应为 1")
	_expect(int(robot_row.get("lost", 0)) == 1, "蓝图机器人损失统计应为 1")
	_expect(int(robot_row.get("kills", 0)) == 1, "蓝图机器人击杀统计应为 1")
	_expect(int(robot_row.get("rule_triggered", 0)) == 1, "蓝图规则触发统计应为 1")
	_expect(int(robot_row.get("rules", {}).get("move_to_rally", {}).get("triggered", 0)) == 1, "应逐条统计集结规则触发次数")
	_expect(str(robot_row.get("rules", {}).get("mark_squad_ready", {}).get("display_name", "")) == "等待队友 (1)", "同名规则应按规则 ID 稳定添加序号")
	_expect(str(robot_row.get("rules", {}).get("wait_for_squad", {}).get("display_name", "")) == "等待队友 (2)", "同名规则序号应避免统计面板歧义")
	_expect(int(robot_row.get("loss_reasons", {}).get("lifespan_expired", 0)) == 1, "应区分寿命耗尽损失")
	_expect(not robot_row.get("never_triggered_rules", []).is_empty(), "应列出从未触发规则")

	var overlay := ReportOverlayScript.new()
	add_child(overlay)
	overlay.configure(event_log, resource_defs, [blueprint])
	overlay.call("_on_category_pressed", &"robots")
	overlay.refresh_report()

	print("COMBAT_REPORT_BUILDER_OK")
	get_tree().quit()

func _find_row(rows: Array, field: String, expected: String) -> Dictionary:
	for row in rows:
		if str(row.get(field, "")) == expected:
			return row
	return {}

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(1)
