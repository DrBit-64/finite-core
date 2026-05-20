extends VBoxContainer
class_name RuleBlockUI

signal move_up_requested(block: RuleBlockUI)
signal move_down_requested(block: RuleBlockUI)
signal remove_requested(block: RuleBlockUI)

const AI_RULE_SCRIPT := preload("res://Scripts/ai_rule.gd")
const CONDITION_ROW_SCENE := preload("res://Scenes/ui/condition_row_ui.tscn")

@onready var btn_up: Button = $Header/BtnUp
@onready var btn_down: Button = $Header/BtnDown
@onready var btn_remove_rule: Button = $Header/BtnRemoveRule
@onready var subject_option: OptionButton = $Header/SubjectOption
@onready var match_mode_option: OptionButton = $Header/MatchModeOption
@onready var action_option: OptionButton = $Header/ActionOption
@onready var conditions_box: VBoxContainer = $Body/ConditionsBox
@onready var add_condition_button: Button = $Footer/BtnAddCondition

func _ready() -> void:
	_populate_header_options()
	btn_up.pressed.connect(func() -> void: move_up_requested.emit(self))
	btn_down.pressed.connect(func() -> void: move_down_requested.emit(self))
	btn_remove_rule.pressed.connect(func() -> void: remove_requested.emit(self))
	add_condition_button.pressed.connect(_on_add_condition_pressed)

	if conditions_box.get_child_count() == 0:
		_add_condition_row(null)

func _populate_header_options() -> void:
	subject_option.clear()
	subject_option.add_item("自己", AI_RULE_SCRIPT.Subject.SELF)
	subject_option.add_item("最近敌人", AI_RULE_SCRIPT.Subject.TARGET_NEAREST)
	subject_option.add_item("低血敌人", AI_RULE_SCRIPT.Subject.TARGET_LOWEST_HP)
	subject_option.select(1)

	match_mode_option.clear()
	match_mode_option.add_item("全部满足", AI_RULE_SCRIPT.MatchMode.MATCH_ALL)
	match_mode_option.add_item("任一满足", AI_RULE_SCRIPT.MatchMode.MATCH_ANY)
	match_mode_option.select(0)

	action_option.clear()
	action_option.add_item("接近", AI_RULE_SCRIPT.Action.APPROACH)
	action_option.add_item("远离", AI_RULE_SCRIPT.Action.FLEE)
	action_option.add_item("开火", AI_RULE_SCRIPT.Action.FIRE_MAIN)
	action_option.add_item("停止", AI_RULE_SCRIPT.Action.STOP_ACTION)
	action_option.select(0)

func _on_add_condition_pressed() -> void:
	_add_condition_row(null)

func _add_condition_row(cond: AICondition) -> void:
	var row := CONDITION_ROW_SCENE.instantiate() as ConditionRowUI
	if row == null:
		return
	conditions_box.add_child(row)
	row.remove_requested.connect(_on_condition_remove_requested)
	if cond:
		row.set_from_condition(cond)

func _on_condition_remove_requested(row: ConditionRowUI) -> void:
	row.queue_free()
	if conditions_box.get_child_count() == 0:
		_add_condition_row(null)

func to_rule() -> AIRule:
	var rule := AI_RULE_SCRIPT.new() as AIRule
	rule.subject = subject_option.get_selected_id() as AIRule.Subject
	rule.match_mode = match_mode_option.get_selected_id() as AIRule.MatchMode
	rule.action = action_option.get_selected_id() as AIRule.Action

	var conds: Array[AICondition] = []
	for child in conditions_box.get_children():
		var row := child as ConditionRowUI
		if row == null:
			continue
		conds.append(row.to_condition())
	rule.conditions = conds
	return rule

func set_from_rule(rule: AIRule) -> void:
	if rule == null:
		return
	_select_option_by_id(subject_option, rule.subject)
	_select_option_by_id(match_mode_option, rule.match_mode)
	_select_option_by_id(action_option, rule.action)

	for child in conditions_box.get_children():
		child.queue_free()

	if rule.conditions.is_empty():
		_add_condition_row(null)
		return

	for cond in rule.conditions:
		_add_condition_row(cond)

func _select_option_by_id(option: OptionButton, id: int) -> void:
	for i in range(option.item_count):
		if option.get_item_id(i) == id:
			option.select(i)
			return
