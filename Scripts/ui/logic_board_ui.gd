extends VBoxContainer
class_name LogicBoardUI

signal rules_exported(rules: Array[AIRule])

const RULE_BLOCK_SCENE := preload("res://Scenes/ui/rule_block_ui.tscn")

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
	rules_exported.emit(rules)
	print("LogicBoardUI exported rules: ", rules.size())

func _add_rule_block(rule: AIRule) -> void:
	var block := RULE_BLOCK_SCENE.instantiate() as RuleBlockUI
	if block == null:
		return
	rules_container.add_child(block)
	block.move_up_requested.connect(_on_block_move_up)
	block.move_down_requested.connect(_on_block_move_down)
	block.remove_requested.connect(_on_block_remove)
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

func export_rules() -> Array[AIRule]:
	var rules: Array[AIRule] = []
	for child in rules_container.get_children():
		var block := child as RuleBlockUI
		if block == null:
			continue
		rules.append(block.to_rule())
	return rules
