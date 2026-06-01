extends PanelContainer
class_name BlueprintManagementOverlay

signal save_requested(source_blueprint_id: StringName, display_name: String, embedded_rules: Array, state_flag_defaults: Dictionary, save_as_new: bool)

var _blueprints: Array[UnitBlueprint] = []
var _selected_source_id: StringName = &""
var _draft_rules: Array = []

var _blueprint_list: VBoxContainer
var _source_option: OptionButton
var _name_edit: LineEdit
var _detail_label: Label
var _rule_template_option: OptionButton
var _rule_list: VBoxContainer

func _ready() -> void:
	anchor_left = 0.04
	anchor_top = 0.08
	anchor_right = 0.96
	anchor_bottom = 0.93
	add_theme_stylebox_override("panel", _make_panel_style())
	_build_layout()

func set_blueprints(blueprints: Array[UnitBlueprint]) -> void:
	_blueprints = blueprints.duplicate()
	if is_inside_tree():
		_rebuild_blueprint_list()
		_rebuild_source_options()

func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title := _make_label("机器人蓝图管理", 22, Color(0.96, 0.98, 1.0, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(78, 34)
	close_button.pressed.connect(func() -> void:
		visible = false
	)
	header.add_child(close_button)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var library_column := VBoxContainer.new()
	library_column.custom_minimum_size = Vector2(360, 0)
	library_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_column.add_theme_constant_override("separation", 8)
	body.add_child(library_column)

	library_column.add_child(_make_label("已保存蓝图", 14, Color(0.78, 0.86, 0.94, 1.0)))
	var blueprint_scroll := ScrollContainer.new()
	blueprint_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blueprint_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blueprint_scroll.custom_minimum_size = Vector2(360, 420)
	library_column.add_child(blueprint_scroll)

	_blueprint_list = VBoxContainer.new()
	_blueprint_list.custom_minimum_size = Vector2(340, 0)
	_blueprint_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blueprint_list.add_theme_constant_override("separation", 6)
	blueprint_scroll.add_child(_blueprint_list)

	var editor_column := VBoxContainer.new()
	editor_column.custom_minimum_size = Vector2(760, 0)
	editor_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_column.add_theme_constant_override("separation", 10)
	body.add_child(editor_column)

	editor_column.add_child(_make_label("编辑草稿", 14, Color(0.78, 0.86, 0.94, 1.0)))

	_source_option = OptionButton.new()
	_source_option.custom_minimum_size = Vector2(420, 32)
	_source_option.item_selected.connect(_on_source_option_selected)
	editor_column.add_child(_source_option)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "蓝图名称"
	_name_edit.text = "集结步枪机器人"
	_name_edit.custom_minimum_size = Vector2(420, 32)
	editor_column.add_child(_name_edit)

	_detail_label = _make_label("", 13, Color(0.84, 0.90, 0.96, 1.0))
	_detail_label.custom_minimum_size = Vector2(720, 24)
	_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_column.add_child(_detail_label)

	var part_row := HBoxContainer.new()
	part_row.add_theme_constant_override("separation", 10)
	part_row.add_child(_make_label("底盘", 13, Color(0.72, 0.80, 0.88, 1.0)))
	part_row.add_child(_make_disabled_button("轻型底盘"))
	part_row.add_child(_make_label("功能模块", 13, Color(0.72, 0.80, 0.88, 1.0)))
	part_row.add_child(_make_disabled_button("步枪模块"))
	editor_column.add_child(part_row)

	editor_column.add_child(_make_label("If-Then 规则", 14, Color(0.78, 0.86, 0.94, 1.0)))
	var rule_toolbar := HBoxContainer.new()
	rule_toolbar.add_theme_constant_override("separation", 8)
	editor_column.add_child(rule_toolbar)

	_rule_template_option = OptionButton.new()
	_rule_template_option.custom_minimum_size = Vector2(360, 32)
	_rule_template_option.add_item("IF 未集结且有集结点 THEN 前往集结点")
	_rule_template_option.set_item_metadata(0, "move_to_rally")
	_rule_template_option.add_item("IF 到达集结点 THEN 标记已集结")
	_rule_template_option.set_item_metadata(1, "mark_rallied")
	_rule_template_option.add_item("IF 已集结但队友不足 THEN 等待队友")
	_rule_template_option.set_item_metadata(2, "wait_for_squad")
	_rule_template_option.add_item("IF 队友到齐 THEN 标记小队就绪")
	_rule_template_option.set_item_metadata(3, "mark_squad_ready")
	_rule_template_option.add_item("IF 小队就绪 THEN 默认脑干接管")
	_rule_template_option.set_item_metadata(4, "default_after_rally")
	rule_toolbar.add_child(_rule_template_option)

	var add_rule_button := Button.new()
	add_rule_button.text = "添加规则"
	add_rule_button.custom_minimum_size = Vector2(106, 32)
	add_rule_button.pressed.connect(_on_add_rule_pressed)
	rule_toolbar.add_child(add_rule_button)

	var template_button := Button.new()
	template_button.text = "套用集结模板"
	template_button.custom_minimum_size = Vector2(136, 32)
	template_button.pressed.connect(_on_apply_rally_template_pressed)
	rule_toolbar.add_child(template_button)

	var rule_scroll := ScrollContainer.new()
	rule_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rule_scroll.custom_minimum_size = Vector2(760, 240)
	editor_column.add_child(rule_scroll)

	_rule_list = VBoxContainer.new()
	_rule_list.custom_minimum_size = Vector2(740, 0)
	_rule_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rule_list.add_theme_constant_override("separation", 6)
	rule_scroll.add_child(_rule_list)

	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 8)
	editor_column.add_child(save_row)

	var update_button := Button.new()
	update_button.text = "保存修改"
	update_button.custom_minimum_size = Vector2(140, 36)
	update_button.pressed.connect(_on_save_modification_pressed)
	save_row.add_child(update_button)

	var save_button := Button.new()
	save_button.text = "保存为新蓝图"
	save_button.custom_minimum_size = Vector2(160, 36)
	save_button.pressed.connect(_on_save_as_new_pressed)
	save_row.add_child(save_button)

	_rebuild_blueprint_list()
	_rebuild_source_options()

func _rebuild_blueprint_list() -> void:
	if _blueprint_list == null:
		return
	for child in _blueprint_list.get_children():
		_blueprint_list.remove_child(child)
		child.queue_free()
	if _blueprints.is_empty():
		_blueprint_list.add_child(_make_label("暂无蓝图", 13, Color(0.84, 0.88, 0.92, 1.0)))
		return
	for blueprint in _blueprints:
		_blueprint_list.add_child(_make_blueprint_row(blueprint))

func _rebuild_source_options() -> void:
	if _source_option == null:
		return
	_source_option.clear()
	for blueprint in _blueprints:
		_source_option.add_item("%s v%s" % [blueprint.display_name, blueprint.version])
		_source_option.set_item_metadata(_source_option.item_count - 1, blueprint.id)
	if _source_option.item_count > 0:
		_source_option.select(0)
		_select_source(StringName(str(_source_option.get_item_metadata(0))))

func _make_blueprint_row(blueprint: UnitBlueprint) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(340, 58)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	var label := _make_wrapped_label(_format_blueprint_summary(blueprint), 13, Color(0.88, 0.94, 1.0, 1.0))
	label.custom_minimum_size = Vector2(220, 52)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var edit_button := Button.new()
	edit_button.text = "作为模板"
	edit_button.custom_minimum_size = Vector2(96, 32)
	edit_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	edit_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	edit_button.pressed.connect(_select_source.bind(blueprint.id), CONNECT_DEFERRED)
	row.add_child(edit_button)
	return row

func _on_source_option_selected(index: int) -> void:
	if index < 0 or index >= _source_option.item_count:
		return
	_select_source(StringName(str(_source_option.get_item_metadata(index))))

func _select_source(source_id: StringName) -> void:
	_selected_source_id = source_id
	var source := _find_blueprint(source_id)
	if source == null:
		return
	for i in range(_source_option.item_count):
		if StringName(str(_source_option.get_item_metadata(i))) == source_id:
			_source_option.select(i)
			break
	_name_edit.text = source.display_name
	_detail_label.text = "来源：%s v%s | 底盘：%s | 模块：%s | 原规则：%d" % [
		source.display_name,
		source.version,
		source.chassis_display_name,
		" / ".join(source.module_display_names),
		source.embedded_rules.size(),
	]
	_draft_rules = source.embedded_rules.duplicate(true)
	_rebuild_rule_list()

func _on_add_rule_pressed() -> void:
	var template_id := str(_rule_template_option.get_item_metadata(_rule_template_option.selected))
	_draft_rules.append(_make_rule_template(template_id))
	_rebuild_rule_list()

func _on_apply_rally_template_pressed() -> void:
	_draft_rules = [
		_make_rule_template("move_to_rally"),
		_make_rule_template("mark_rallied"),
		_make_rule_template("wait_for_squad"),
		_make_rule_template("mark_squad_ready"),
		_make_rule_template("default_after_rally"),
	]
	_rebuild_rule_list()

func _on_save_modification_pressed() -> void:
	_emit_save_requested(false)

func _on_save_as_new_pressed() -> void:
	_emit_save_requested(true)

func _emit_save_requested(save_as_new: bool) -> void:
	save_requested.emit(
		_selected_source_id,
		_name_edit.text,
		_make_rules_for_save(),
		_infer_state_defaults(_draft_rules),
		save_as_new
	)

func _rebuild_rule_list() -> void:
	if _rule_list == null:
		return
	for child in _rule_list.get_children():
		_rule_list.remove_child(child)
		child.queue_free()
	if _draft_rules.is_empty():
		_rule_list.add_child(_make_label("还没有规则。可以添加规则，或套用“先集结再战斗”模板。", 13, Color(0.84, 0.88, 0.92, 1.0)))
		return
	for i in range(_draft_rules.size()):
		_rule_list.add_child(_make_rule_row(i, _draft_rules[i]))

func _make_rule_row(index: int, rule: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(740, 70)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	var index_label := _make_label("%d." % [index + 1], 13, Color(0.72, 0.80, 0.88, 1.0))
	index_label.custom_minimum_size = Vector2(28, 28)
	index_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(index_label)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	row.add_child(content)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	content.add_child(name_row)

	var name_label := _make_label("名称", 12, Color(0.72, 0.80, 0.88, 1.0))
	name_label.custom_minimum_size = Vector2(36, 28)
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_row.add_child(name_label)

	var name_edit := LineEdit.new()
	name_edit.text = str(rule.get("name", _format_rule_action(rule))).strip_edges()
	name_edit.placeholder_text = "规则名称"
	name_edit.custom_minimum_size = Vector2(220, 28)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_rule_name_changed.bind(index))
	name_row.add_child(name_edit)

	var summary := _make_wrapped_label("IF %s THEN %s" % [_format_rule_conditions(rule), _format_rule_action(rule)], 13, Color(0.88, 0.94, 1.0, 1.0))
	summary.custom_minimum_size = Vector2(560, 28)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(summary)

	var remove_button := Button.new()
	remove_button.text = "删除"
	remove_button.custom_minimum_size = Vector2(68, 28)
	remove_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	remove_button.pressed.connect(_on_remove_rule_pressed.bind(index), CONNECT_DEFERRED)
	row.add_child(remove_button)
	return row

func _on_rule_name_changed(text: String, index: int) -> void:
	if index < 0 or index >= _draft_rules.size():
		return
	if typeof(_draft_rules[index]) != TYPE_DICTIONARY:
		return
	_draft_rules[index]["name"] = text

func _on_remove_rule_pressed(index: int) -> void:
	if index < 0 or index >= _draft_rules.size():
		return
	_draft_rules.remove_at(index)
	_rebuild_rule_list()

func _make_rules_for_save() -> Array:
	var result: Array = _draft_rules.duplicate(true)
	for rule in result:
		if typeof(rule) != TYPE_DICTIONARY:
			continue
		var rule_name := str(rule.get("name", "")).strip_edges()
		if rule_name.is_empty():
			rule["name"] = _format_rule_action(rule)
	return result

func _make_rule_template(template_id: String) -> Dictionary:
	match template_id:
		"move_to_rally":
			return {
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
			}
		"mark_rallied":
			return {
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
			}
		"wait_for_squad":
			return {
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
			}
		"mark_squad_ready":
			return {
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
			}
		_:
			return {
				"id": "default_after_rally",
				"name": "默认脑干接管",
				"subject": "self",
				"match_mode": "all",
				"conditions": [
					{"type": "self_flag_is", "flag": "squad_ready", "value": true}
				],
				"action": "default_combat"
			}

func _infer_state_defaults(rules: Array) -> Dictionary:
	var result := {}
	for rule in rules:
		if typeof(rule) != TYPE_DICTIONARY:
			continue
		for condition in rule.get("conditions", []):
			if typeof(condition) == TYPE_DICTIONARY and str(condition.get("type", "")) == "self_flag_is":
				var flag_id := str(condition.get("flag", ""))
				if not flag_id.is_empty() and not result.has(flag_id):
					result[flag_id] = false
		var action := str(rule.get("action", ""))
		if action == "set_self_flag" or action == "clear_self_flag":
			var action_flag := str(rule.get("flag", ""))
			if not action_flag.is_empty() and not result.has(action_flag):
				result[action_flag] = false
	return result

func _format_blueprint_summary(blueprint: UnitBlueprint) -> String:
	return "%s v%s | %s | %s | 规则 %d" % [
		blueprint.display_name,
		blueprint.version,
		blueprint.chassis_display_name,
		" / ".join(blueprint.module_display_names),
		blueprint.embedded_rules.size(),
	]

func _format_rule_conditions(rule: Dictionary) -> String:
	var parts: Array[String] = []
	for condition in rule.get("conditions", []):
		if typeof(condition) == TYPE_DICTIONARY:
			parts.append(_format_condition(condition))
	return " 且 ".join(parts) if not parts.is_empty() else "总是"

func _format_condition(condition: Dictionary) -> String:
	match str(condition.get("type", "")):
		"has_rally_point":
			return "存在集结点"
		"self_flag_is":
			return "%s = %s" % [str(condition.get("flag", "")), "是" if bool(condition.get("value", false)) else "否"]
		"distance_to_rally_greater":
			return "距集结点 > %s" % str(condition.get("value", ""))
		"distance_to_rally_less_equal":
			return "距集结点 <= %s" % str(condition.get("value", ""))
		"allies_near_rally_less":
			return "集结点友军 < %s" % str(condition.get("value", ""))
		"allies_near_rally_at_least":
			return "集结点友军 >= %s" % str(condition.get("value", ""))
		"has_enemy":
			return "发现敌人"
		_:
			return str(condition.get("type", "未知条件"))

func _format_rule_action(rule: Dictionary) -> String:
	match str(rule.get("action", "")):
		"move_to_rally":
			return "前往集结点"
		"set_self_flag":
			return "设置 %s = %s" % [str(rule.get("flag", "")), "是" if bool(rule.get("value", true)) else "否"]
		"clear_self_flag":
			return "设置 %s = 否" % str(rule.get("flag", ""))
		"wait":
			return "原地等待"
		"default_combat":
			return "默认脑干接管"
		_:
			return str(rule.get("action", "未知动作"))

func _find_blueprint(blueprint_id: StringName) -> UnitBlueprint:
	for blueprint in _blueprints:
		if blueprint.id == blueprint_id:
			return blueprint
	return null

func _make_disabled_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = true
	button.custom_minimum_size = Vector2(128, 30)
	return button

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_wrapped_label(text: String, font_size: int, color: Color) -> Label:
	var label := _make_label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.048, 0.97)
	style.border_color = Color(0.32, 0.39, 0.46, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style
