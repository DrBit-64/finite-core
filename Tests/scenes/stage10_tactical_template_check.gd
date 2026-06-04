extends Node

const TacticalTemplateCompilerScript := preload("res://Scripts/ai/tactical_template_compiler.gd")
const BlueprintLibraryScript := preload("res://Scripts/blueprints/blueprint_library.gd")
const ReportBuilderScript := preload("res://Scripts/ui/combat_report_builder.gd")
const ReportOverlayScript := preload("res://Scripts/ui/combat_report_overlay.gd")

func _ready() -> void:
	var event_log := get_node("/root/CombatEventLog")
	event_log.clear()

	var basic_blueprint := MvpDataDefaults.create_basic_rifle_blueprint()
	_expect(basic_blueprint.embedded_rules.is_empty(), "默认基础步枪蓝图不应内置自定义规则")
	_expect(basic_blueprint.tactical_templates.is_empty(), "默认基础步枪蓝图不应内置战术模板")

	var template := TacticalTemplateCompilerScript.make_rally_then_attack_instance(4, 90.0, 20.0)
	var compiled: Dictionary = TacticalTemplateCompilerScript.compile_templates([template])
	_expect(compiled.get("rules", []).size() == 5, "集结后进攻模板应编译为 5 条底层规则")
	_expect(bool(compiled.get("state_flag_defaults", {}).has("rallied")), "集结模板应声明 rallied 状态")
	_expect(bool(compiled.get("state_flag_defaults", {}).has("squad_ready")), "集结模板应声明 squad_ready 状态")

	var library := BlueprintLibraryScript.new()
	var rally_blueprint: UnitBlueprint = library.create_rally_variant(basic_blueprint, "测试集结模板蓝图")
	_expect(rally_blueprint.tactical_templates.size() == 1, "集结变体应保存战术模板实例")
	_expect(rally_blueprint.embedded_rules.size() == 5, "集结变体应保存编译后的只读底层规则")
	_expect(str(rally_blueprint.embedded_rules[0].get("template_id", "")) == "rally_then_attack", "底层规则应带有模板来源")

	event_log.record(&"robot_produced", {
		"blueprint_id": String(rally_blueprint.id),
		"blueprint_name": rally_blueprint.display_name,
		"blueprint_version": rally_blueprint.version,
		"blueprint_templates": [{"id": "rally_then_attack", "name": "集结后进攻"}],
		"blueprint_rules": [{"id": "move_to_rally", "name": "前往集结点"}],
	})
	event_log.record(&"rule_triggered", {
		"blueprint_id": String(rally_blueprint.id),
		"blueprint_name": rally_blueprint.display_name,
		"blueprint_version": rally_blueprint.version,
		"rule_id": "move_to_rally",
		"rule_name": "前往集结点",
		"template_id": "rally_then_attack",
		"template_name": "集结后进攻",
		"template_stage": "前往集结点",
	})

	var report: Dictionary = ReportBuilderScript.build_report(event_log, [basic_blueprint, rally_blueprint], MvpDataDefaults.create_resource_defs())
	var rally_row := _find_row(report.get("robots", []), "blueprint_id", String(rally_blueprint.id))
	_expect(int(rally_row.get("template_triggered", 0)) == 1, "复盘应统计模板触发次数")
	_expect(int(rally_row.get("templates", {}).get("rally_then_attack", {}).get("triggered", 0)) == 1, "复盘应按模板 ID 聚合触发次数")
	_expect(int(rally_row.get("rules", {}).get("move_to_rally", {}).get("triggered", 0)) == 1, "复盘仍应保留底层规则触发明细")

	var overlay := ReportOverlayScript.new()
	add_child(overlay)
	overlay.configure(event_log, MvpDataDefaults.create_resource_defs(), [rally_blueprint])
	overlay.call("_on_category_pressed", &"robots")
	overlay.refresh_report()

	print("STAGE10_TACTICAL_TEMPLATE_OK")
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
