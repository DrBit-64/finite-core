extends HBoxContainer
class_name ConditionRowUI

signal remove_requested(row: ConditionRowUI)

const AI_CONDITION_SCRIPT := preload("res://Scripts/ai_condition.gd")

@onready var type_option: OptionButton = $TypeOption
@onready var param_input: LineEdit = $ParamInput
@onready var remove_button: Button = $RemoveButton

func _ready() -> void:
	_populate_type_options()
	remove_button.pressed.connect(_on_remove_pressed)

func _populate_type_options() -> void:
	type_option.clear()
	type_option.add_item("距离 <", AI_CONDITION_SCRIPT.Type.DISTANCE_LESS)
	type_option.add_item("血量 % <", AI_CONDITION_SCRIPT.Type.HP_LESS_PERCENT)
	type_option.add_item("拥有标签", AI_CONDITION_SCRIPT.Type.HAS_TAG)
	type_option.select(0)

func to_condition() -> AICondition:
	var cond := AI_CONDITION_SCRIPT.new() as AICondition
	cond.type = type_option.get_selected_id() as AICondition.Type
	cond.param = param_input.text.strip_edges()
	return cond

func set_from_condition(cond: AICondition) -> void:
	if cond == null:
		return
	for i in range(type_option.item_count):
		if type_option.get_item_id(i) == cond.type:
			type_option.select(i)
			break
	param_input.text = cond.param

func _on_remove_pressed() -> void:
	remove_requested.emit(self)
