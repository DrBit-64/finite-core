extends VBoxContainer
class_name LogicBoardUI

signal rules_exported(rules: Array[AIRule])

const RULE_BLOCK_SCENE := preload("res://Scenes/ui/rule_block_ui.tscn")

@export var export_directory: String = "res://debug_exports/rules"
@export var export_file_prefix: String = "logic_rules"

@onready var rules_container: VBoxContainer = $RulesContainer
@onready var add_rule_button: Button = $Controls/BtnAddRule
@onready var export_rules_button: Button = $Controls/BtnExportRules

func _ready() -> void:
	add_rule_button.pressed.connect(_on_add_rule_pressed)
	export_rules_button.pressed.connect(_on_export_rules_pressed)

	if rules_container.get_child_count() == 0:
		_add_rule_block(null)

func _on_add_rule_pressed() -> void:
	_add_rule_block(null)

func _on_export_rules_pressed() -> void:
	var rules := export_rules()
	var saved_path := save_rules_as_json(rules)
	rules_exported.emit(rules)
	if saved_path.is_empty():
		print("LogicBoardUI export failed. rules=", rules.size())
	else:
		print("LogicBoardUI exported rules: ", rules.size(), " -> ", saved_path)

func _add_rule_block(rule: AIRule) -> void:
	var block := RULE_BLOCK_SCENE.instantiate() as RuleBlockUI
	if block == null:
		return
	rules_container.add_child(block)
	block.move_up_requested.connect(_on_block_move_up)
	block.move_down_requested.connect(_on_block_move_down)
	block.remove_requested.connect(_on_block_remove)
	block.reorder_requested.connect(_on_block_reorder_requested)
	if rule:
		block.set_from_rule(rule)

func _on_block_move_up(block: RuleBlockUI) -> void:
	var idx := block.get_index()
	if idx <= 0:
		return
	rules_container.move_child(block, idx - 1)

func _on_block_move_down(block: RuleBlockUI) -> void:
	var idx := block.get_index()
	var max_idx := rules_container.get_child_count() - 1
	if idx >= max_idx:
		return
	rules_container.move_child(block, idx + 1)

func _on_block_remove(block: RuleBlockUI) -> void:
	block.queue_free()
	if rules_container.get_child_count() == 0:
		_add_rule_block(null)

func _on_block_reorder_requested(source: RuleBlockUI, target: RuleBlockUI, insert_after: bool) -> void:
	if source == null or target == null:
		return
	if source == target or source.get_parent() != rules_container or target.get_parent() != rules_container:
		return
	var final_order := rules_container.get_children()
	final_order.erase(source)
	var target_index := final_order.find(target)
	if target_index < 0:
		return
	var insert_index := target_index + (1 if insert_after else 0)
	rules_container.move_child(source, clampi(insert_index, 0, rules_container.get_child_count() - 1))

func export_rules() -> Array[AIRule]:
	var rules: Array[AIRule] = []
	for child in rules_container.get_children():
		var block := child as RuleBlockUI
		if block == null:
			continue
		rules.append(block.to_rule())
	return rules

func save_rules_as_json(rules: Array[AIRule]) -> String:
	var export_file_path := _get_next_export_file_path()
	if export_file_path.is_empty():
		return ""

	var export_data := _rules_to_export_data(rules)
	var json_text := JSON.stringify(export_data, "\t")
	var file := FileAccess.open(export_file_path, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		push_error("Failed to export logic rules to %s: %s" % [export_file_path, error_string(err)])
		return ""

	file.store_string(json_text)
	file.close()
	return ProjectSettings.globalize_path(export_file_path)

func _get_next_export_file_path() -> String:
	var absolute_directory := ProjectSettings.globalize_path(export_directory)
	var make_dir_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if make_dir_error != OK:
		push_error("Failed to create logic rules export directory %s: %s" % [absolute_directory, error_string(make_dir_error)])
		return ""

	var next_index := _get_next_export_index()
	for index in range(next_index, 10000):
		var file_name := "%s_%03d.json" % [export_file_prefix, index]
		var candidate_path := export_directory.path_join(file_name)
		if not FileAccess.file_exists(candidate_path):
			return candidate_path

	push_error("Failed to allocate logic rules export file name in %s" % export_directory)
	return ""

func _get_next_export_index() -> int:
	var dir := DirAccess.open(export_directory)
	if dir == null:
		return 1

	var highest_index := 0
	var number_prefix := "%s_" % export_file_prefix
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.begins_with(number_prefix) and file_name.ends_with(".json"):
			var number_text := file_name.trim_prefix(number_prefix).trim_suffix(".json")
			if number_text.is_valid_int():
				highest_index = maxi(highest_index, number_text.to_int())
		file_name = dir.get_next()
	dir.list_dir_end()

	return highest_index + 1

func _rules_to_export_data(rules: Array[AIRule]) -> Dictionary:
	var exported_rules: Array[Dictionary] = []
	for i in range(rules.size()):
		exported_rules.append(_rule_to_export_data(rules[i], i))

	return {
		"schema_version": 1,
		"generated_at": Time.get_datetime_string_from_system(),
		"rule_count": rules.size(),
		"rules": exported_rules,
	}

func _rule_to_export_data(rule: AIRule, priority: int) -> Dictionary:
	var exported_conditions: Array[Dictionary] = []
	if rule != null:
		for i in range(rule.conditions.size()):
			exported_conditions.append(_condition_to_export_data(rule.conditions[i], i))

	return {
		"priority": priority,
		"subject": _enum_export(rule.subject if rule else -1, _subject_code(rule.subject if rule else -1), _subject_label(rule.subject if rule else -1)),
		"match_mode": _enum_export(rule.match_mode if rule else -1, _match_mode_code(rule.match_mode if rule else -1), _match_mode_label(rule.match_mode if rule else -1)),
		"conditions": exported_conditions,
		"action": _enum_export(rule.action if rule else -1, _action_code(rule.action if rule else -1), _action_label(rule.action if rule else -1)),
	}

func _condition_to_export_data(cond: AICondition, index: int) -> Dictionary:
	return {
		"index": index,
		"type": _enum_export(cond.type if cond else -1, _condition_type_code(cond.type if cond else -1), _condition_type_label(cond.type if cond else -1)),
		"param": cond.param if cond else "",
	}

func _enum_export(id: int, code: String, label: String) -> Dictionary:
	return {
		"id": id,
		"code": code,
		"label": label,
	}

func _subject_code(value: int) -> String:
	match value:
		AIRule.Subject.SELF:
			return "SELF"
		AIRule.Subject.TARGET_NEAREST:
			return "TARGET_NEAREST"
		AIRule.Subject.TARGET_LOWEST_HP:
			return "TARGET_LOWEST_HP"
	return "UNKNOWN"

func _subject_label(value: int) -> String:
	match value:
		AIRule.Subject.SELF:
			return "自己"
		AIRule.Subject.TARGET_NEAREST:
			return "最近敌人"
		AIRule.Subject.TARGET_LOWEST_HP:
			return "低血敌人"
	return "未知目标"

func _match_mode_code(value: int) -> String:
	match value:
		AIRule.MatchMode.MATCH_ALL:
			return "MATCH_ALL"
		AIRule.MatchMode.MATCH_ANY:
			return "MATCH_ANY"
	return "UNKNOWN"

func _match_mode_label(value: int) -> String:
	match value:
		AIRule.MatchMode.MATCH_ALL:
			return "全部满足"
		AIRule.MatchMode.MATCH_ANY:
			return "任一满足"
	return "未知条件模式"

func _action_code(value: int) -> String:
	match value:
		AIRule.Action.APPROACH:
			return "APPROACH"
		AIRule.Action.FLEE:
			return "FLEE"
		AIRule.Action.FIRE_MAIN:
			return "FIRE_MAIN"
		AIRule.Action.STOP_ACTION:
			return "STOP_ACTION"
	return "UNKNOWN"

func _action_label(value: int) -> String:
	match value:
		AIRule.Action.APPROACH:
			return "接近"
		AIRule.Action.FLEE:
			return "远离"
		AIRule.Action.FIRE_MAIN:
			return "开火"
		AIRule.Action.STOP_ACTION:
			return "停止"
	return "未知动作"

func _condition_type_code(value: int) -> String:
	match value:
		AICondition.Type.DISTANCE_LESS:
			return "DISTANCE_LESS"
		AICondition.Type.HP_LESS_PERCENT:
			return "HP_LESS_PERCENT"
		AICondition.Type.HAS_TAG:
			return "HAS_TAG"
	return "UNKNOWN"

func _condition_type_label(value: int) -> String:
	match value:
		AICondition.Type.DISTANCE_LESS:
			return "距离 <"
		AICondition.Type.HP_LESS_PERCENT:
			return "血量 % <"
		AICondition.Type.HAS_TAG:
			return "拥有标签"
	return "未知条件"
