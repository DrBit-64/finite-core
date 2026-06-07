extends PanelContainer
class_name BlueprintManagementOverlay

signal save_requested(source_blueprint_id: StringName, display_name: String, tactical_templates: Array, embedded_rules: Array, state_flag_defaults: Dictionary, save_as_new: bool)

const TacticalTemplateCompilerScript := preload("res://Scripts/ai/tactical_template_compiler.gd")

var _blueprints: Array[UnitBlueprint] = []
var _selected_source_id: StringName = &""
var _selected_template_index: int = -1
var _draft_templates: Array[Dictionary] = []
var _compiled_rules: Array = []
var _compiled_state_defaults: Dictionary = {}
var _unlocked_template_ids: Array[StringName] = []

var _blueprint_list: VBoxContainer
var _source_option: OptionButton
var _name_edit: LineEdit
var _detail_label: Label
var _template_list: VBoxContainer
var _template_option: OptionButton
var _param_list: VBoxContainer
var _rule_preview_list: VBoxContainer
var _quick_rally_button: Button

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

func set_unlocked_template_ids(template_ids: Array[StringName]) -> void:
	_unlocked_template_ids = template_ids.duplicate()
	if is_inside_tree():
		_rebuild_template_options()
		_update_quick_rally_button_state()

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
	library_column.custom_minimum_size = Vector2(370, 0)
	library_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_column.add_theme_constant_override("separation", 8)
	body.add_child(library_column)

	library_column.add_child(_make_label("已保存蓝图", 14, Color(0.78, 0.86, 0.94, 1.0)))
	var blueprint_scroll := ScrollContainer.new()
	blueprint_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blueprint_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_column.add_child(blueprint_scroll)

	_blueprint_list = VBoxContainer.new()
	_blueprint_list.custom_minimum_size = Vector2(350, 0)
	_blueprint_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blueprint_list.add_theme_constant_override("separation", 6)
	blueprint_scroll.add_child(_blueprint_list)

	var editor_column := VBoxContainer.new()
	editor_column.custom_minimum_size = Vector2(820, 0)
	editor_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_column.add_theme_constant_override("separation", 10)
	body.add_child(editor_column)

	editor_column.add_child(_make_label("编辑草稿", 14, Color(0.78, 0.86, 0.94, 1.0)))

	_source_option = OptionButton.new()
	_source_option.custom_minimum_size = Vector2(460, 32)
	_source_option.item_selected.connect(_on_source_option_selected)
	editor_column.add_child(_source_option)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "蓝图名称"
	_name_edit.text = "集结步枪机器人"
	_name_edit.custom_minimum_size = Vector2(460, 32)
	editor_column.add_child(_name_edit)

	_detail_label = _make_wrapped_label("", 13, Color(0.84, 0.90, 0.96, 1.0))
	_detail_label.custom_minimum_size = Vector2(760, 24)
	editor_column.add_child(_detail_label)

	var part_row := HBoxContainer.new()
	part_row.add_theme_constant_override("separation", 10)
	part_row.add_child(_make_label("底盘", 13, Color(0.72, 0.80, 0.88, 1.0)))
	part_row.add_child(_make_disabled_button("轻型底盘"))
	part_row.add_child(_make_label("功能模块", 13, Color(0.72, 0.80, 0.88, 1.0)))
	part_row.add_child(_make_disabled_button("步枪模块"))
	editor_column.add_child(part_row)

	editor_column.add_child(_make_label("战术模板", 14, Color(0.78, 0.86, 0.94, 1.0)))
	var template_toolbar := HBoxContainer.new()
	template_toolbar.add_theme_constant_override("separation", 8)
	editor_column.add_child(template_toolbar)

	_template_option = OptionButton.new()
	_template_option.custom_minimum_size = Vector2(300, 32)
	_rebuild_template_options()
	template_toolbar.add_child(_template_option)

	var add_template_button := Button.new()
	add_template_button.text = "添加模板"
	add_template_button.custom_minimum_size = Vector2(108, 32)
	add_template_button.pressed.connect(_on_add_template_pressed)
	template_toolbar.add_child(add_template_button)

	_quick_rally_button = Button.new()
	_quick_rally_button.text = "套用集结后进攻"
	_quick_rally_button.custom_minimum_size = Vector2(154, 32)
	_quick_rally_button.pressed.connect(_on_apply_rally_template_pressed)
	template_toolbar.add_child(_quick_rally_button)
	_update_quick_rally_button_state()

	var template_and_params := HBoxContainer.new()
	template_and_params.add_theme_constant_override("separation", 12)
	template_and_params.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_column.add_child(template_and_params)

	var template_panel := PanelContainer.new()
	template_panel.custom_minimum_size = Vector2(390, 160)
	template_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	template_panel.add_theme_stylebox_override("panel", _make_section_style())
	template_and_params.add_child(template_panel)

	var template_margin := MarginContainer.new()
	template_margin.add_theme_constant_override("margin_left", 10)
	template_margin.add_theme_constant_override("margin_top", 8)
	template_margin.add_theme_constant_override("margin_right", 10)
	template_margin.add_theme_constant_override("margin_bottom", 8)
	template_panel.add_child(template_margin)

	_template_list = VBoxContainer.new()
	_template_list.add_theme_constant_override("separation", 6)
	template_margin.add_child(_template_list)

	var param_panel := PanelContainer.new()
	param_panel.custom_minimum_size = Vector2(330, 160)
	param_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	param_panel.add_theme_stylebox_override("panel", _make_section_style())
	template_and_params.add_child(param_panel)

	var param_margin := MarginContainer.new()
	param_margin.add_theme_constant_override("margin_left", 10)
	param_margin.add_theme_constant_override("margin_top", 8)
	param_margin.add_theme_constant_override("margin_right", 10)
	param_margin.add_theme_constant_override("margin_bottom", 8)
	param_panel.add_child(param_margin)

	_param_list = VBoxContainer.new()
	_param_list.add_theme_constant_override("separation", 6)
	param_margin.add_child(_param_list)

	var preview_header := HBoxContainer.new()
	preview_header.add_theme_constant_override("separation", 8)
	editor_column.add_child(preview_header)
	preview_header.add_child(_make_label("展开底层规则（只读）", 14, Color(0.78, 0.86, 0.94, 1.0)))
	var readonly_label := _make_label("模板会自动生成这些规则；玩家暂不直接编辑。", 12, Color(0.58, 0.68, 0.76, 1.0))
	readonly_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_header.add_child(readonly_label)

	var rule_scroll := ScrollContainer.new()
	rule_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rule_scroll.custom_minimum_size = Vector2(780, 180)
	editor_column.add_child(rule_scroll)

	_rule_preview_list = VBoxContainer.new()
	_rule_preview_list.custom_minimum_size = Vector2(760, 0)
	_rule_preview_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rule_preview_list.add_theme_constant_override("separation", 6)
	rule_scroll.add_child(_rule_preview_list)

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

func _rebuild_template_options() -> void:
	if _template_option == null:
		return
	_template_option.clear()
	for template_def in TacticalTemplateCompilerScript.get_template_defs():
		var template_id := StringName(str(template_def.get("id", "")))
		if not _is_template_available(template_id):
			continue
		_template_option.add_item(str(template_def.get("display_name", template_def.get("id", ""))))
		_template_option.set_item_metadata(_template_option.item_count - 1, String(template_id))
	_update_quick_rally_button_state()

func _update_quick_rally_button_state() -> void:
	if _quick_rally_button == null:
		return
	var unlocked := _is_template_available(StringName(TacticalTemplateCompilerScript.TEMPLATE_RALLY_THEN_ATTACK))
	_quick_rally_button.disabled = not unlocked
	_quick_rally_button.tooltip_text = "" if unlocked else "需要先完成阶段 1 的集结战术研究"

func _is_template_available(template_id: StringName) -> bool:
	if _unlocked_template_ids.is_empty():
		return true
	return _unlocked_template_ids.has(template_id)

func _make_blueprint_row(blueprint: UnitBlueprint) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(350, 64)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	var label := _make_wrapped_label(_format_blueprint_summary(blueprint), 13, Color(0.88, 0.94, 1.0, 1.0))
	label.custom_minimum_size = Vector2(236, 58)
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
	_detail_label.text = "来源：%s v%s | 底盘：%s | 模块：%s | 模板：%d | 底层规则：%d" % [
		source.display_name,
		source.version,
		source.chassis_display_name,
		" / ".join(source.module_display_names),
		source.tactical_templates.size(),
		source.embedded_rules.size(),
	]
	_draft_templates = source.tactical_templates.duplicate(true)
	if _draft_templates.is_empty():
		_draft_templates = [TacticalTemplateCompilerScript.make_default_attack_instance()]
	_selected_template_index = 0 if not _draft_templates.is_empty() else -1
	_recompile_draft()
	_rebuild_template_list()
	_rebuild_param_list()
	_rebuild_rule_preview()

func _on_add_template_pressed() -> void:
	if _template_option == null or _template_option.item_count <= 0:
		return
	var template_id := str(_template_option.get_item_metadata(_template_option.selected))
	_draft_templates.append(TacticalTemplateCompilerScript.make_instance(template_id))
	_selected_template_index = _draft_templates.size() - 1
	_recompile_and_rebuild()

func _on_apply_rally_template_pressed() -> void:
	if not _is_template_available(StringName(TacticalTemplateCompilerScript.TEMPLATE_RALLY_THEN_ATTACK)):
		return
	_draft_templates = [
		TacticalTemplateCompilerScript.make_rally_then_attack_instance()
	]
	_selected_template_index = 0
	_recompile_and_rebuild()

func _on_save_modification_pressed() -> void:
	_emit_save_requested(false)

func _on_save_as_new_pressed() -> void:
	_emit_save_requested(true)

func _emit_save_requested(save_as_new: bool) -> void:
	var templates := _make_templates_for_save()
	var compiled: Dictionary = TacticalTemplateCompilerScript.compile_templates(templates)
	save_requested.emit(
		_selected_source_id,
		_name_edit.text,
		templates,
		compiled.get("rules", []),
		compiled.get("state_flag_defaults", {}),
		save_as_new
	)

func _make_templates_for_save() -> Array:
	var templates := TacticalTemplateCompilerScript.normalize_templates(_draft_templates)
	if templates.size() == 1 and str(templates[0].get("id", "")) == TacticalTemplateCompilerScript.TEMPLATE_DEFAULT_ATTACK:
		return []
	return templates

func _recompile_and_rebuild() -> void:
	_recompile_draft()
	_rebuild_template_list()
	_rebuild_param_list()
	_rebuild_rule_preview()

func _recompile_draft() -> void:
	var templates := _make_templates_for_save()
	var compiled: Dictionary = TacticalTemplateCompilerScript.compile_templates(templates)
	_compiled_rules = compiled.get("rules", [])
	_compiled_state_defaults = compiled.get("state_flag_defaults", {})

func _rebuild_template_list() -> void:
	if _template_list == null:
		return
	for child in _template_list.get_children():
		child.queue_free()
	_template_list.add_child(_make_label("当前模板", 13, Color(0.72, 0.80, 0.88, 1.0)))
	if _draft_templates.is_empty():
		_template_list.add_child(_make_label("未选择模板。默认脑干会直接接管。", 13, Color(0.84, 0.88, 0.92, 1.0)))
		return
	for i in range(_draft_templates.size()):
		_template_list.add_child(_make_template_row(i, _draft_templates[i]))

func _make_template_row(index: int, template: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var select_button := Button.new()
	select_button.text = str(template.get("display_name", template.get("id", "未命名模板")))
	select_button.custom_minimum_size = Vector2(146, 30)
	select_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	select_button.modulate = Color(0.68, 0.92, 1.0, 1.0) if index == _selected_template_index else Color.WHITE
	select_button.pressed.connect(func() -> void:
		_selected_template_index = index
		_rebuild_template_list()
		_rebuild_param_list()
	)
	row.add_child(select_button)

	var intent := _make_wrapped_label(TacticalTemplateCompilerScript.describe_template(template), 12, Color(0.78, 0.86, 0.92, 1.0))
	intent.custom_minimum_size = Vector2(140, 0)
	intent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(intent)

	var remove_button := Button.new()
	remove_button.text = "移除"
	remove_button.custom_minimum_size = Vector2(58, 28)
	remove_button.pressed.connect(_on_remove_template_pressed.bind(index), CONNECT_DEFERRED)
	row.add_child(remove_button)
	return row

func _on_remove_template_pressed(index: int) -> void:
	if index < 0 or index >= _draft_templates.size():
		return
	_draft_templates.remove_at(index)
	if _draft_templates.is_empty():
		_draft_templates = [TacticalTemplateCompilerScript.make_default_attack_instance()]
	_selected_template_index = clampi(index, 0, _draft_templates.size() - 1)
	_recompile_and_rebuild()

func _rebuild_param_list() -> void:
	if _param_list == null:
		return
	for child in _param_list.get_children():
		child.queue_free()
	_param_list.add_child(_make_label("模板参数", 13, Color(0.72, 0.80, 0.88, 1.0)))
	if _selected_template_index < 0 or _selected_template_index >= _draft_templates.size():
		_param_list.add_child(_make_label("未选中模板。", 13, Color(0.84, 0.88, 0.92, 1.0)))
		return
	var template := _draft_templates[_selected_template_index]
	var template_def := TacticalTemplateCompilerScript.get_template_def(str(template.get("id", "")))
	var parameters: Array = template_def.get("parameters", [])
	if parameters.is_empty():
		_param_list.add_child(_make_wrapped_label("这个模板暂时没有可调参数。", 13, Color(0.84, 0.88, 0.92, 1.0)))
		return
	var params: Dictionary = template.get("params", {})
	for parameter in parameters:
		_param_list.add_child(_make_param_row(parameter, params.get(str(parameter.get("id", "")), parameter.get("default"))))

func _make_param_row(parameter: Dictionary, value: Variant) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := _make_label(str(parameter.get("display_name", parameter.get("id", "参数"))), 13, Color(0.86, 0.92, 0.98, 1.0))
	label.custom_minimum_size = Vector2(92, 28)
	row.add_child(label)

	var spin := SpinBox.new()
	spin.custom_minimum_size = Vector2(120, 30)
	spin.min_value = 1.0
	spin.max_value = 999.0
	spin.step = 1.0
	spin.value = float(value)
	if str(parameter.get("type", "")) == "float":
		spin.step = 5.0
	spin.value_changed.connect(_on_template_param_changed.bind(str(parameter.get("id", ""))))
	row.add_child(spin)
	return row

func _on_template_param_changed(value: float, param_id: String) -> void:
	if _selected_template_index < 0 or _selected_template_index >= _draft_templates.size():
		return
	var template := _draft_templates[_selected_template_index]
	var params: Dictionary = template.get("params", {})
	params[param_id] = value
	template["params"] = params
	_draft_templates[_selected_template_index] = TacticalTemplateCompilerScript.make_instance(str(template.get("id", "")), params)
	_recompile_draft()
	_rebuild_template_list()
	_rebuild_rule_preview()

func _rebuild_rule_preview() -> void:
	if _rule_preview_list == null:
		return
	for child in _rule_preview_list.get_children():
		child.queue_free()
	if _compiled_rules.is_empty():
		_rule_preview_list.add_child(_make_wrapped_label("无底层规则。机器人将直接使用默认脑干。", 13, Color(0.84, 0.88, 0.92, 1.0)))
		return
	for i in range(_compiled_rules.size()):
		var rule: Dictionary = _compiled_rules[i]
		_rule_preview_list.add_child(_make_rule_preview_row(i, rule))

func _make_rule_preview_row(index: int, rule: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var title := "%d. [%s] %s / %s" % [
		index + 1,
		str(rule.get("template_name", "底层规则")),
		str(rule.get("name", rule.get("id", "未命名规则"))),
		str(rule.get("template_stage", "")),
	]
	row.add_child(_make_label(title, 13, Color(0.90, 0.96, 1.0, 1.0)))
	row.add_child(_make_wrapped_label("IF %s THEN %s" % [_format_rule_conditions(rule), _format_rule_action(rule)], 12, Color(0.72, 0.82, 0.90, 1.0)))
	return row

func _format_blueprint_summary(blueprint: UnitBlueprint) -> String:
	var template_text := "默认脑干"
	if not blueprint.tactical_templates.is_empty():
		var names: Array[String] = []
		for template in blueprint.tactical_templates:
			if typeof(template) == TYPE_DICTIONARY:
				names.append(str(template.get("display_name", template.get("id", "模板"))))
		template_text = " / ".join(names)
	return "%s v%s\n%s | %s\n模板：%s" % [
		blueprint.display_name,
		blueprint.version,
		blueprint.chassis_display_name,
		" / ".join(blueprint.module_display_names),
		template_text,
	]

func _format_rule_conditions(rule: Dictionary) -> String:
	var parts: Array[String] = []
	for condition in rule.get("conditions", []):
		if typeof(condition) == TYPE_DICTIONARY:
			parts.append(_format_condition(condition))
	if parts.is_empty():
		return "总是"
	return " 且 ".join(parts)

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

func _make_section_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.065, 0.078, 0.72)
	style.border_color = Color(0.18, 0.26, 0.32, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	return style
