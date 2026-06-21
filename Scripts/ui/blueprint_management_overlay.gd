extends PanelContainer
class_name BlueprintManagementOverlay

signal save_requested(source_blueprint_id: StringName, display_name: String, unit_type_id: StringName, upgrade_ids: Array[StringName], tactical_templates: Array, embedded_rules: Array, state_flag_defaults: Dictionary, save_as_new: bool)

const TacticalTemplateCompilerScript := preload("res://Scripts/ai/tactical_template_compiler.gd")
const UnitDesignConfigLoaderScript := preload("res://Scripts/data/unit_design_config_loader.gd")
const ItemIconSlotScript := preload("res://Scripts/ui/components/item_icon_slot.gd")
const MvpDataDefaultsScript := preload("res://Scripts/data/mvp_data_defaults.gd")

class TemplateDragRow:
	extends HBoxContainer

	signal reorder_requested(source_index: int, target_index: int, insert_after: bool)

	var template_index: int = -1

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var preview := PanelContainer.new()
		var label := Label.new()
		label.text = "移动模板"
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.90, 0.96, 1.0, 1.0))
		preview.add_child(label)
		set_drag_preview(preview)
		return {
			"type": "blueprint_template_row",
			"source_index": template_index,
		}

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if typeof(data) != TYPE_DICTIONARY:
			return false
		if str(data.get("type", "")) != "blueprint_template_row":
			return false
		var source_index := int(data.get("source_index", -1))
		return source_index >= 0 and source_index != template_index

	func _drop_data(at_position: Vector2, data: Variant) -> void:
		if not _can_drop_data(at_position, data):
			return
		var source_index := int(data.get("source_index", -1))
		reorder_requested.emit(source_index, template_index, at_position.y > size.y * 0.5)

var _blueprints: Array[UnitBlueprint] = []
var _selected_source_id: StringName = &""
var _selected_unit_type_id: StringName = &"basic_rifle_robot"
var _draft_upgrade_ids: Array[StringName] = []
var _unit_design_config: Dictionary = {}
var _selected_template_index: int = -1
var _draft_templates: Array[Dictionary] = []
var _compiled_rules: Array = []
var _compiled_state_defaults: Dictionary = {}
var _resource_defs: Array[ResourceDef] = []
var _unlocked_template_ids: Array[StringName] = []
var _unlocked_unit_type_ids: Array[StringName] = []
var _unlocked_upgrade_ids: Array[StringName] = []
var _unlock_filter_configured: bool = false
var _selected_template_option_id: String = TacticalTemplateCompilerScript.TEMPLATE_DEFAULT_ATTACK
var _available_enemy_target_tags: Array[String] = ["frontline", "backline"]

var _blueprint_list: VBoxContainer
var _source_option: OptionButton
var _name_edit: LineEdit
var _detail_label: Label
var _unit_type_option: OptionButton
var _unit_summary_label: Label
var _preview_base_texture: TextureRect
var _preview_module_texture: TextureRect
var _preview_caption_label: Label
var _upgrade_list: GridContainer
var _upgrade_summary_label: Label
var _stat_summary_label: Label
var _cost_summary_label: Label
var _cost_summary_grid: GridContainer
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
	_unit_design_config = UnitDesignConfigLoaderScript.load_design_config()
	_resource_defs = MvpDataDefaultsScript.create_resource_defs()
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

func set_blueprint_unlocks(unit_type_ids: Array[StringName], upgrade_ids: Array[StringName], template_ids: Array[StringName]) -> void:
	_unlock_filter_configured = true
	_unlocked_unit_type_ids = unit_type_ids.duplicate()
	_unlocked_upgrade_ids = upgrade_ids.duplicate()
	_unlocked_template_ids = template_ids.duplicate()
	if is_inside_tree():
		_rebuild_blueprint_list()
		_rebuild_unit_type_options()
		_rebuild_source_options()
		_rebuild_upgrade_list()
		_rebuild_template_options()
		_sanitize_draft_templates_for_unit()
		_recompile_and_rebuild()

func set_available_enemy_target_tags(tags: Array[String]) -> void:
	var next_tags: Array[String] = []
	for tag in tags:
		if not tag.is_empty() and not next_tags.has(tag):
			next_tags.append(tag)
	if next_tags.is_empty():
		next_tags = ["frontline", "backline"]
	next_tags.sort()
	if next_tags == _available_enemy_target_tags:
		return
	_available_enemy_target_tags = next_tags
	if is_inside_tree():
		_rebuild_param_list()

func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	var title := _make_label("机器人蓝图工作台", 22, Color(0.96, 0.98, 1.0, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(76, 34)
	close_button.pressed.connect(func() -> void:
		visible = false
	)
	header.add_child(close_button)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var library_column := _make_column(310.0)
	body.add_child(library_column)
	_build_library_column(library_column)

	var design_column := _make_column(560.0)
	body.add_child(design_column)
	_build_design_column(design_column)

	var rules_column := _make_column(430.0)
	body.add_child(rules_column)
	_build_rules_column(rules_column)

	_rebuild_blueprint_list()
	_rebuild_unit_type_options()
	_rebuild_source_options()

func _build_library_column(column: VBoxContainer) -> void:
	column.add_child(_make_section_title("蓝图库"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_blueprint_list = VBoxContainer.new()
	_blueprint_list.add_theme_constant_override("separation", 6)
	_blueprint_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_blueprint_list)

	column.add_child(_make_separator())
	column.add_child(_make_section_title("当前草稿"))
	_source_option = OptionButton.new()
	_source_option.custom_minimum_size = Vector2(260, 32)
	_source_option.item_selected.connect(_on_source_option_selected)
	column.add_child(_source_option)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "蓝图名称"
	_name_edit.custom_minimum_size = Vector2(260, 32)
	column.add_child(_name_edit)
	_detail_label = _make_wrapped_label("", 12, Color(0.72, 0.82, 0.90, 1.0))
	_detail_label.custom_minimum_size = Vector2(260, 48)
	column.add_child(_detail_label)

	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 8)
	column.add_child(save_row)
	var update_button := Button.new()
	update_button.text = "更新"
	update_button.custom_minimum_size = Vector2(86, 34)
	update_button.pressed.connect(_on_save_modification_pressed)
	save_row.add_child(update_button)
	var save_button := Button.new()
	save_button.text = "另存"
	save_button.custom_minimum_size = Vector2(86, 34)
	save_button.pressed.connect(_on_save_as_new_pressed)
	save_row.add_child(save_button)

func _build_design_column(column: VBoxContainer) -> void:
	column.add_child(_make_section_title("型号"))
	var unit_panel := _make_panel()
	column.add_child(unit_panel)
	var unit_box := _panel_box(unit_panel)
	_unit_type_option = OptionButton.new()
	_unit_type_option.custom_minimum_size = Vector2(460, 34)
	_unit_type_option.item_selected.connect(_on_unit_type_selected)
	unit_box.add_child(_unit_type_option)
	_unit_summary_label = _make_wrapped_label("", 12, Color(0.74, 0.84, 0.92, 1.0))
	_unit_summary_label.custom_minimum_size = Vector2(500, 42)
	unit_box.add_child(_unit_summary_label)

	var preview_panel := _make_panel()
	preview_panel.custom_minimum_size = Vector2(520, 126)
	column.add_child(preview_panel)
	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 10)
	preview_margin.add_theme_constant_override("margin_top", 8)
	preview_margin.add_theme_constant_override("margin_right", 10)
	preview_margin.add_theme_constant_override("margin_bottom", 8)
	preview_panel.add_child(preview_margin)
	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 12)
	preview_margin.add_child(preview_row)
	var preview_stage := Control.new()
	preview_stage.custom_minimum_size = Vector2(108, 92)
	preview_stage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview_row.add_child(preview_stage)
	_preview_base_texture = _make_preview_texture_rect(Vector2(96, 96), Vector2(6, -2))
	preview_stage.add_child(_preview_base_texture)
	_preview_module_texture = null
	var preview_text_box := VBoxContainer.new()
	preview_text_box.add_theme_constant_override("separation", 4)
	preview_text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_row.add_child(preview_text_box)
	preview_text_box.add_child(_make_label("外观预览", 13, Color(0.78, 0.86, 0.94, 1.0)))
	_preview_caption_label = _make_wrapped_label("", 12, Color(0.70, 0.80, 0.88, 1.0))
	_preview_caption_label.custom_minimum_size = Vector2(350, 48)
	preview_text_box.add_child(_preview_caption_label)

	var upgrade_header := HBoxContainer.new()
	upgrade_header.add_theme_constant_override("separation", 8)
	column.add_child(upgrade_header)
	var upgrade_title := _make_section_title("数值升级")
	upgrade_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_header.add_child(upgrade_title)
	_upgrade_summary_label = _make_label("", 12, Color(0.58, 0.72, 0.82, 1.0))
	upgrade_header.add_child(_upgrade_summary_label)

	var upgrade_scroll := ScrollContainer.new()
	upgrade_scroll.custom_minimum_size = Vector2(520, 390)
	upgrade_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(upgrade_scroll)
	_upgrade_list = GridContainer.new()
	_upgrade_list.columns = 2
	_upgrade_list.add_theme_constant_override("h_separation", 8)
	_upgrade_list.add_theme_constant_override("v_separation", 8)
	_upgrade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_scroll.add_child(_upgrade_list)

func _build_rules_column(column: VBoxContainer) -> void:
	column.add_child(_make_section_title("摘要"))
	var summary_panel := _make_panel()
	column.add_child(summary_panel)
	var summary_box := _panel_box(summary_panel)
	_stat_summary_label = _make_wrapped_label("", 12, Color(0.82, 0.92, 0.98, 1.0))
	_stat_summary_label.custom_minimum_size = Vector2(380, 40)
	summary_box.add_child(_stat_summary_label)
	summary_box.add_child(_make_label("生产成本", 12, Color(0.94, 0.82, 0.58, 1.0)))
	_cost_summary_grid = GridContainer.new()
	_cost_summary_grid.columns = 6
	_cost_summary_grid.add_theme_constant_override("h_separation", 5)
	_cost_summary_grid.add_theme_constant_override("v_separation", 5)
	_cost_summary_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	summary_box.add_child(_cost_summary_grid)
	_cost_summary_label = _make_wrapped_label("", 12, Color(0.72, 0.82, 0.90, 1.0))
	_cost_summary_label.custom_minimum_size = Vector2(380, 22)
	summary_box.add_child(_cost_summary_label)

	column.add_child(_make_section_title("规则"))
	var template_toolbar := HBoxContainer.new()
	template_toolbar.add_theme_constant_override("separation", 8)
	column.add_child(template_toolbar)
	_template_option = OptionButton.new()
	_template_option.custom_minimum_size = Vector2(178, 32)
	_template_option.item_selected.connect(_on_template_option_selected)
	_rebuild_template_options()
	template_toolbar.add_child(_template_option)
	var add_template_button := Button.new()
	add_template_button.text = "添加"
	add_template_button.custom_minimum_size = Vector2(64, 32)
	add_template_button.pressed.connect(_on_add_template_pressed)
	template_toolbar.add_child(add_template_button)
	_quick_rally_button = Button.new()
	_quick_rally_button.text = "集结进攻"
	_quick_rally_button.custom_minimum_size = Vector2(92, 32)
	_quick_rally_button.pressed.connect(_on_apply_rally_template_pressed)
	template_toolbar.add_child(_quick_rally_button)
	_update_quick_rally_button_state()

	var template_panel := _make_panel()
	template_panel.custom_minimum_size = Vector2(380, 128)
	column.add_child(template_panel)
	_template_list = VBoxContainer.new()
	_template_list.add_theme_constant_override("separation", 6)
	_panel_box(template_panel).add_child(_template_list)

	var param_panel := _make_panel()
	param_panel.custom_minimum_size = Vector2(380, 120)
	column.add_child(param_panel)
	_param_list = VBoxContainer.new()
	_param_list.add_theme_constant_override("separation", 6)
	_panel_box(param_panel).add_child(_param_list)

	column.add_child(_make_section_title("规则预览"))
	var rule_scroll := ScrollContainer.new()
	rule_scroll.custom_minimum_size = Vector2(390, 210)
	rule_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(rule_scroll)
	_rule_preview_list = VBoxContainer.new()
	_rule_preview_list.add_theme_constant_override("separation", 6)
	_rule_preview_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule_scroll.add_child(_rule_preview_list)

func _rebuild_blueprint_list() -> void:
	if _blueprint_list == null:
		return
	for child in _blueprint_list.get_children():
		child.queue_free()
	if _blueprints.is_empty():
		_blueprint_list.add_child(_make_label("暂无蓝图", 13, Color(0.84, 0.88, 0.92, 1.0)))
		return
	var visible_count := 0
	for blueprint in _blueprints:
		if not _is_blueprint_available(blueprint):
			continue
		_blueprint_list.add_child(_make_blueprint_row(blueprint))
		visible_count += 1
	if visible_count <= 0:
		_blueprint_list.add_child(_make_label("No unlocked blueprints", 13, Color(0.84, 0.88, 0.92, 1.0)))

func _rebuild_source_options() -> void:
	if _source_option == null:
		return
	var previous_source_id := _selected_source_id
	_source_option.clear()
	var selected_index := -1
	for blueprint in _blueprints:
		if not _is_blueprint_available(blueprint):
			continue
		_source_option.add_item("%s v%s" % [blueprint.display_name, blueprint.version])
		_source_option.set_item_metadata(_source_option.item_count - 1, blueprint.id)
		if blueprint.id == previous_source_id:
			selected_index = _source_option.item_count - 1
	if _source_option.item_count > 0:
		if selected_index >= 0:
			_source_option.select(selected_index)
		else:
			var fallback_source_id := StringName(str(_source_option.get_item_metadata(0)))
			_source_option.select(0)
			_select_source(fallback_source_id)

func _rebuild_unit_type_options() -> void:
	if _unit_type_option == null:
		return
	_unit_type_option.clear()
	for unit_type in UnitDesignConfigLoaderScript.get_unit_types(_unit_design_config):
		var unit_type_id := StringName(str(unit_type.get("id", "")))
		if String(unit_type_id).is_empty():
			continue
		if not _is_unit_type_available(unit_type_id):
			continue
		_unit_type_option.add_item(str(unit_type.get("display_name", unit_type_id)))
		_unit_type_option.set_item_metadata(_unit_type_option.item_count - 1, unit_type_id)
	if _unit_type_option.item_count <= 0:
		return
	if _is_unit_type_available(_selected_unit_type_id):
		_select_unit_type_option(_selected_unit_type_id)
	else:
		_selected_unit_type_id = StringName(str(_unit_type_option.get_item_metadata(0)))
		_unit_type_option.select(0)

func _on_unit_type_selected(index: int) -> void:
	if _unit_type_option == null or index < 0 or index >= _unit_type_option.item_count:
		return
	_selected_unit_type_id = StringName(str(_unit_type_option.get_item_metadata(index)))
	_draft_upgrade_ids = UnitDesignConfigLoaderScript.sanitize_upgrade_ids(_unit_design_config, _selected_unit_type_id, _draft_upgrade_ids)
	_draft_upgrade_ids = _filter_unlocked_upgrade_ids(_draft_upgrade_ids)
	_sanitize_draft_templates_for_unit()
	_rebuild_upgrade_list()
	_rebuild_template_options()
	_update_design_summary()

func _select_unit_type_option(unit_type_id: StringName) -> void:
	if _unit_type_option == null:
		return
	for i in range(_unit_type_option.item_count):
		if StringName(str(_unit_type_option.get_item_metadata(i))) == unit_type_id:
			_unit_type_option.select(i)
			return

func _rebuild_upgrade_list() -> void:
	if _upgrade_list == null:
		return
	for child in _upgrade_list.get_children():
		child.queue_free()
	var upgrades := UnitDesignConfigLoaderScript.get_available_upgrades(_unit_design_config, _selected_unit_type_id)
	upgrades = _filter_unlocked_upgrades(upgrades)
	if upgrades.is_empty():
		_upgrade_list.add_child(_make_wrapped_label("该型号暂无可用升级。", 12, Color(0.84, 0.88, 0.92, 1.0)))
		return
	for upgrade in upgrades:
		_upgrade_list.add_child(_make_upgrade_card(upgrade))

func _make_upgrade_card(upgrade: Dictionary) -> Control:
	var upgrade_id := StringName(str(upgrade.get("id", "")))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(250, 104)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_card_style(_draft_upgrade_ids.has(upgrade_id)))
	card.tooltip_text = str(upgrade.get("description", ""))

	var box := _panel_box(card)
	box.add_theme_constant_override("separation", 4)
	var checkbox := CheckBox.new()
	checkbox.text = "%s  %d点" % [str(upgrade.get("display_name", upgrade_id)), maxi(1, int(upgrade.get("point_cost", 1)))]
	checkbox.button_pressed = _draft_upgrade_ids.has(upgrade_id)
	checkbox.toggled.connect(_on_upgrade_toggled.bind(upgrade_id), CONNECT_DEFERRED)
	box.add_child(checkbox)

	var stat_text := UnitDesignConfigLoaderScript.describe_stat_delta(_unit_design_config, upgrade_id)
	box.add_child(_make_wrapped_label(stat_text if not stat_text.is_empty() else "-", 12, Color(0.74, 0.90, 1.0, 1.0)))
	var cost_add := _get_upgrade_cost_add(upgrade)
	if cost_add.is_empty():
		box.add_child(_make_wrapped_label("额外成本：无", 11, Color(0.72, 0.76, 0.80, 1.0)))
	else:
		box.add_child(_make_wrapped_label("额外成本：", 11, Color(0.92, 0.74, 0.48, 1.0)))
		box.add_child(_make_resource_cost_grid(cost_add, Vector2(30, 30), 5))
	return card

func _on_upgrade_toggled(enabled: bool, upgrade_id: StringName) -> void:
	if enabled:
		if not _draft_upgrade_ids.has(upgrade_id):
			_draft_upgrade_ids.append(upgrade_id)
	else:
		_draft_upgrade_ids.erase(upgrade_id)
	var sanitized := UnitDesignConfigLoaderScript.sanitize_upgrade_ids(_unit_design_config, _selected_unit_type_id, _draft_upgrade_ids)
	sanitized = _filter_unlocked_upgrade_ids(sanitized)
	var accepted := sanitized.has(upgrade_id) or not enabled
	_draft_upgrade_ids = sanitized
	if not accepted and _upgrade_summary_label:
		_upgrade_summary_label.text = "点数已满"
	_rebuild_upgrade_list()
	_update_design_summary()

func _make_preview_blueprint() -> UnitBlueprint:
	var source := _find_blueprint(_selected_source_id)
	var preview := source.make_snapshot() if source else UnitBlueprint.new()
	var recipe_defs: Array[RecipeDef] = []
	UnitDesignConfigLoaderScript.apply_design_to_blueprint(preview, _selected_unit_type_id, _draft_upgrade_ids, recipe_defs)
	return preview

func _update_design_summary() -> void:
	var unit_type := UnitDesignConfigLoaderScript.get_unit_type(_unit_design_config, _selected_unit_type_id)
	var preview := _make_preview_blueprint()
	if _unit_summary_label:
		_unit_summary_label.text = str(unit_type.get("description", preview.unit_type_display_name))
	if _upgrade_summary_label:
		var point_limit := int(unit_type.get("upgrade_point_limit", 3))
		var point_used := UnitDesignConfigLoaderScript.get_upgrade_point_used(_unit_design_config, _draft_upgrade_ids)
		_upgrade_summary_label.text = "%d / %d 点" % [point_used, point_limit]
	if _stat_summary_label:
		_stat_summary_label.text = "属性  %s" % UnitDesignConfigLoaderScript.format_stats(preview.stats)
	if _cost_summary_label:
		_cost_summary_label.text = "生产时间：%.1fs" % preview.production_time_seconds
	if _cost_summary_grid:
		_rebuild_resource_cost_grid(_cost_summary_grid, preview.production_cost, Vector2(34, 34), 6)
	_update_visual_preview(preview)
	if _detail_label:
		var upgrade_text := "无升级" if preview.upgrade_display_names.is_empty() else " / ".join(preview.upgrade_display_names)
		_detail_label.text = "%s | %s | 规则 %d" % [
			preview.unit_type_display_name,
			upgrade_text,
			_compiled_rules.size(),
		]

func _update_visual_preview(blueprint: UnitBlueprint) -> void:
	if _preview_base_texture == null or blueprint == null:
		return
	_preview_base_texture.texture = _load_preview_texture(blueprint.icon_path)
	_preview_base_texture.visible = _preview_base_texture.texture != null
	if _preview_module_texture:
		_preview_module_texture.visible = false
	if _preview_caption_label:
		_preview_caption_label.text = "%s\n%s" % [blueprint.unit_type_display_name, "一体化蓝图图标"]

func _get_preview_module_icon_path(blueprint: UnitBlueprint) -> String:
	if blueprint == null or blueprint.module_icon_paths.is_empty():
		return ""
	for i in range(blueprint.module_ids.size()):
		var module_text := String(blueprint.module_ids[i])
		if module_text.contains("chainsaw") and i < blueprint.module_icon_paths.size():
			return blueprint.module_icon_paths[i]
	return blueprint.module_icon_paths[0]

func _load_preview_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D

func _rebuild_template_options() -> void:
	if _template_option == null:
		return
	var desired_id := _selected_template_option_id
	if _template_option.item_count > 0 and _template_option.selected >= 0:
		var selected_metadata = _template_option.get_item_metadata(_template_option.selected)
		if selected_metadata != null:
			desired_id = str(selected_metadata)
	_template_option.clear()
	var desired_index := 0
	for template_def in TacticalTemplateCompilerScript.get_template_defs():
		var template_id := StringName(str(template_def.get("id", "")))
		if not _is_template_available(template_id):
			continue
		_template_option.add_item(str(template_def.get("display_name", template_def.get("id", ""))))
		_template_option.set_item_metadata(_template_option.item_count - 1, String(template_id))
		if String(template_id) == desired_id:
			desired_index = _template_option.item_count - 1
	if _template_option.item_count > 0:
		_template_option.select(clampi(desired_index, 0, _template_option.item_count - 1))
		_selected_template_option_id = str(_template_option.get_item_metadata(_template_option.selected))
	_update_quick_rally_button_state()

func _on_template_option_selected(index: int) -> void:
	if _template_option == null or index < 0 or index >= _template_option.item_count:
		return
	_selected_template_option_id = str(_template_option.get_item_metadata(index))

func _update_quick_rally_button_state() -> void:
	if _quick_rally_button == null:
		return
	var unlocked := _is_template_available(StringName(TacticalTemplateCompilerScript.TEMPLATE_RALLY_THEN_ATTACK))
	_quick_rally_button.disabled = not unlocked
	_quick_rally_button.tooltip_text = "" if unlocked else "需要先完成集结战术解锁"

func _is_template_available(template_id: StringName) -> bool:
	if _unlock_filter_configured and not _unlocked_template_ids.has(template_id):
		return false
	return _is_template_allowed_for_unit(template_id, _selected_unit_type_id)

func _is_blueprint_available(blueprint: UnitBlueprint) -> bool:
	if blueprint == null:
		return false
	var unit_type_id := blueprint.unit_type_id if not String(blueprint.unit_type_id).is_empty() else blueprint.id
	return _is_unit_type_available(unit_type_id)

func _is_unit_type_available(unit_type_id: StringName) -> bool:
	if not _unlock_filter_configured:
		return true
	return _unlocked_unit_type_ids.has(unit_type_id)

func _filter_unlocked_upgrades(upgrades: Array[Dictionary]) -> Array[Dictionary]:
	if not _unlock_filter_configured:
		return upgrades
	var result: Array[Dictionary] = []
	for upgrade in upgrades:
		if _unlocked_upgrade_ids.has(StringName(str(upgrade.get("id", "")))):
			result.append(upgrade)
	return result

func _filter_unlocked_upgrade_ids(upgrade_ids: Array[StringName]) -> Array[StringName]:
	if not _unlock_filter_configured:
		return upgrade_ids
	var result: Array[StringName] = []
	for upgrade_id in upgrade_ids:
		if _unlocked_upgrade_ids.has(upgrade_id):
			result.append(upgrade_id)
	return result

func _is_template_allowed_for_unit(template_id: StringName, unit_type_id: StringName) -> bool:
	if String(template_id) == TacticalTemplateCompilerScript.TEMPLATE_DEFAULT_ATTACK:
		return true
	var unit_type := UnitDesignConfigLoaderScript.get_unit_type(_unit_design_config, unit_type_id)
	if unit_type.is_empty():
		return false
	var tags := _string_array_from_variant(unit_type.get("tags", []))
	if String(template_id) == TacticalTemplateCompilerScript.TEMPLATE_LOCK_TARGET:
		return tags.has("locker")
	if String(template_id) == TacticalTemplateCompilerScript.TEMPLATE_LOCKED_MISSILE_STRIKE:
		return tags.has("missile")
	if tags.has("logistics") or tags.has("cargo"):
		return String(template_id) in [
			TacticalTemplateCompilerScript.TEMPLATE_SALVAGE_AND_RETURN,
			TacticalTemplateCompilerScript.TEMPLATE_SUPPLY_RUN,
			TacticalTemplateCompilerScript.TEMPLATE_HAZARD_AVOIDANCE,
		]
	return tags.has("combat")

func _sanitize_draft_templates_for_unit() -> void:
	var sanitized: Array[Dictionary] = []
	for template in _draft_templates:
		if typeof(template) != TYPE_DICTIONARY:
			continue
		var template_id := StringName(str(template.get("id", "")))
		if _is_template_available(template_id):
			sanitized.append(template)
	if sanitized.is_empty():
		sanitized = [TacticalTemplateCompilerScript.make_default_attack_instance()]
	_draft_templates = sanitized
	_selected_template_index = clampi(_selected_template_index, 0, _draft_templates.size() - 1)

func _string_array_from_variant(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		result.append(str(value))
	return result

func _make_blueprint_row(blueprint: UnitBlueprint) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(280, 64)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	var label := _make_wrapped_label(_format_blueprint_summary(blueprint), 12, Color(0.88, 0.94, 1.0, 1.0))
	label.custom_minimum_size = Vector2(190, 58)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var edit_button := Button.new()
	edit_button.text = "编辑"
	edit_button.custom_minimum_size = Vector2(64, 30)
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
	_selected_unit_type_id = source.unit_type_id if not String(source.unit_type_id).is_empty() else source.id
	if not _is_unit_type_available(_selected_unit_type_id) and _unit_type_option != null and _unit_type_option.item_count > 0:
		_selected_unit_type_id = StringName(str(_unit_type_option.get_item_metadata(0)))
	_draft_upgrade_ids = UnitDesignConfigLoaderScript.sanitize_upgrade_ids(_unit_design_config, _selected_unit_type_id, source.upgrade_ids)
	_draft_upgrade_ids = _filter_unlocked_upgrade_ids(_draft_upgrade_ids)
	_select_unit_type_option(_selected_unit_type_id)
	_draft_templates = _dictionary_array_from_variant(source.tactical_templates)
	if _draft_templates.is_empty():
		_draft_templates = [TacticalTemplateCompilerScript.make_default_attack_instance()]
	_sanitize_draft_templates_for_unit()
	_selected_template_index = 0 if not _draft_templates.is_empty() else -1
	_recompile_draft()
	_rebuild_upgrade_list()
	_update_design_summary()
	_rebuild_template_list()
	_rebuild_param_list()
	_rebuild_rule_preview()

func _dictionary_array_from_variant(values: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		if typeof(value) == TYPE_DICTIONARY:
			result.append((value as Dictionary).duplicate(true))
	return result

func _on_add_template_pressed() -> void:
	if _template_option == null or _template_option.item_count <= 0:
		return
	var template_id := str(_template_option.get_item_metadata(_template_option.selected))
	_selected_template_option_id = template_id
	_draft_templates.append(TacticalTemplateCompilerScript.make_instance(template_id))
	_selected_template_index = _draft_templates.size() - 1
	_recompile_and_rebuild()

func _on_apply_rally_template_pressed() -> void:
	if not _is_template_available(StringName(TacticalTemplateCompilerScript.TEMPLATE_RALLY_THEN_ATTACK)):
		return
	_draft_templates = [TacticalTemplateCompilerScript.make_rally_then_attack_instance()]
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
		_selected_unit_type_id,
		_draft_upgrade_ids.duplicate(),
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
	_update_design_summary()
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
	if _draft_templates.is_empty():
		_template_list.add_child(_make_label("默认脑干接管", 12, Color(0.84, 0.88, 0.92, 1.0)))
		return
	for i in range(_draft_templates.size()):
		_template_list.add_child(_make_template_row(i, _draft_templates[i]))

func _make_template_row(index: int, template: Dictionary) -> Control:
	var row := TemplateDragRow.new()
	row.template_index = index
	row.tooltip_text = "拖拽模板可调整底层规则优先级"
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.reorder_requested.connect(_on_template_reorder_requested)
	var select_button := Button.new()
	select_button.text = str(template.get("display_name", template.get("id", "模板")))
	select_button.custom_minimum_size = Vector2(116, 28)
	select_button.modulate = Color(0.68, 0.92, 1.0, 1.0) if index == _selected_template_index else Color.WHITE
	select_button.pressed.connect(func() -> void:
		_selected_template_index = index
		_rebuild_template_list()
		_rebuild_param_list()
	)
	row.add_child(select_button)
	var intent := _make_wrapped_label(TacticalTemplateCompilerScript.describe_template(template), 11, Color(0.76, 0.86, 0.92, 1.0))
	intent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(intent)
	var remove_button := Button.new()
	remove_button.text = "×"
	remove_button.custom_minimum_size = Vector2(30, 28)
	remove_button.pressed.connect(_on_remove_template_pressed.bind(index), CONNECT_DEFERRED)
	row.add_child(remove_button)
	return row

func _on_template_reorder_requested(source_index: int, target_index: int, insert_after: bool) -> void:
	if source_index < 0 or source_index >= _draft_templates.size():
		return
	if target_index < 0 or target_index >= _draft_templates.size():
		return
	if source_index == target_index:
		return
	var template := _draft_templates[source_index]
	_draft_templates.remove_at(source_index)
	var insert_index := target_index
	if source_index < target_index:
		insert_index -= 1
	if insert_after:
		insert_index += 1
	insert_index = clampi(insert_index, 0, _draft_templates.size())
	_draft_templates.insert(insert_index, template)
	_selected_template_index = insert_index
	_recompile_and_rebuild()

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
	if _selected_template_index < 0 or _selected_template_index >= _draft_templates.size():
		_param_list.add_child(_make_label("未选中模板", 12, Color(0.84, 0.88, 0.92, 1.0)))
		return
	var template := _draft_templates[_selected_template_index]
	var template_def := TacticalTemplateCompilerScript.get_template_def(str(template.get("id", "")))
	var parameters: Array = template_def.get("parameters", [])
	if parameters.is_empty():
		_param_list.add_child(_make_label("无参数", 12, Color(0.84, 0.88, 0.92, 1.0)))
		return
	var params: Dictionary = template.get("params", {})
	for parameter in parameters:
		_param_list.add_child(_make_param_row(parameter, params.get(str(parameter.get("id", "")), parameter.get("default"))))

func _make_param_row(parameter: Dictionary, value: Variant) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := _make_label(str(parameter.get("display_name", parameter.get("id", "参数"))), 12, Color(0.86, 0.92, 0.98, 1.0))
	label.custom_minimum_size = Vector2(88, 28)
	row.add_child(label)
	var param_id := str(parameter.get("id", ""))
	if str(parameter.get("type", "")) == "tag":
		var option := OptionButton.new()
		option.custom_minimum_size = Vector2(150, 28)
		var options := _get_tag_parameter_options(str(value))
		var selected_index := 0
		for option_tag in options:
			option.add_item(option_tag)
			option.set_item_metadata(option.item_count - 1, option_tag)
			if option_tag == str(value):
				selected_index = option.item_count - 1
		if option.item_count > 0:
			option.select(selected_index)
		option.item_selected.connect(_on_template_param_option_selected.bind(param_id, option))
		row.add_child(option)
		return row
	var spin := SpinBox.new()
	spin.custom_minimum_size = Vector2(110, 28)
	spin.min_value = 1.0
	spin.max_value = 999.0
	spin.step = 1.0
	spin.value = float(value)
	if str(parameter.get("type", "")) == "float":
		spin.step = 5.0
	spin.value_changed.connect(_on_template_param_changed.bind(param_id))
	row.add_child(spin)
	return row

func _get_tag_parameter_options(current_value: String) -> Array[String]:
	var options := _available_enemy_target_tags.duplicate()
	if not current_value.is_empty() and not options.has(current_value):
		options.append(current_value)
	if options.is_empty():
		options = ["frontline", "backline"]
	options.sort()
	return options

func _on_template_param_option_selected(index: int, param_id: String, option: OptionButton) -> void:
	if option == null or index < 0 or index >= option.item_count:
		return
	_on_template_param_string_changed(str(option.get_item_metadata(index)), param_id)

func _on_template_param_string_changed(value: String, param_id: String) -> void:
	if _selected_template_index < 0 or _selected_template_index >= _draft_templates.size():
		return
	var template := _draft_templates[_selected_template_index]
	var params: Dictionary = template.get("params", {})
	params[param_id] = value
	template["params"] = params
	_draft_templates[_selected_template_index] = TacticalTemplateCompilerScript.make_instance(str(template.get("id", "")), params)
	_recompile_draft()
	_update_design_summary()
	_rebuild_template_list()
	_rebuild_rule_preview()

func _on_template_param_changed(value: float, param_id: String) -> void:
	if _selected_template_index < 0 or _selected_template_index >= _draft_templates.size():
		return
	var template := _draft_templates[_selected_template_index]
	var params: Dictionary = template.get("params", {})
	params[param_id] = value
	template["params"] = params
	_draft_templates[_selected_template_index] = TacticalTemplateCompilerScript.make_instance(str(template.get("id", "")), params)
	_recompile_draft()
	_update_design_summary()
	_rebuild_template_list()
	_rebuild_rule_preview()

func _rebuild_rule_preview() -> void:
	if _rule_preview_list == null:
		return
	for child in _rule_preview_list.get_children():
		child.queue_free()
	if _compiled_rules.is_empty():
		_rule_preview_list.add_child(_make_wrapped_label("无底层规则。", 12, Color(0.84, 0.88, 0.92, 1.0)))
		return
	for i in range(_compiled_rules.size()):
		var rule: Dictionary = _compiled_rules[i]
		_rule_preview_list.add_child(_make_rule_preview_row(i, rule))

func _make_rule_preview_row(index: int, rule: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.add_child(_make_label("%d. %s" % [index + 1, str(rule.get("name", rule.get("id", "规则")))], 12, Color(0.90, 0.96, 1.0, 1.0)))
	row.add_child(_make_wrapped_label("IF %s THEN %s" % [_format_rule_conditions(rule), _format_rule_action(rule)], 11, Color(0.72, 0.82, 0.90, 1.0)))
	return row

func _format_blueprint_summary(blueprint: UnitBlueprint) -> String:
	var template_text := "默认脑干"
	if not blueprint.tactical_templates.is_empty():
		var names: Array[String] = []
		for template in blueprint.tactical_templates:
			if typeof(template) == TYPE_DICTIONARY:
				names.append(str(template.get("display_name", template.get("id", "模板"))))
		template_text = " / ".join(names)
	var unit_type_text := blueprint.unit_type_display_name if not blueprint.unit_type_display_name.is_empty() else blueprint.chassis_display_name
	var upgrade_text := "无升级" if blueprint.upgrade_display_names.is_empty() else " / ".join(blueprint.upgrade_display_names)
	return "%s v%s\n%s | %s\n%s" % [blueprint.display_name, blueprint.version, unit_type_text, upgrade_text, template_text]

func _format_rule_conditions(rule: Dictionary) -> String:
	var parts: Array[String] = []
	for condition in rule.get("conditions", []):
		if typeof(condition) == TYPE_DICTIONARY:
			parts.append(_format_condition(condition))
	if parts.is_empty():
		return "总是"
	return " 与 ".join(parts)

func _format_condition(condition: Dictionary) -> String:
	match str(condition.get("type", "")):
		"has_rally_point":
			return "存在集结点"
		"self_flag_is":
			return "%s = %s" % [str(condition.get("flag", "")), "是" if condition.get("value", false) == true else "否"]
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
			return "设置 %s = %s" % [str(rule.get("flag", "")), "是" if rule.get("value", true) == true else "否"]
		"clear_self_flag":
			return "清除 %s" % str(rule.get("flag", ""))
		"wait":
			return "等待"
		"default_combat":
			return "默认脑干"
		_:
			return str(rule.get("action", "未知动作"))

func _get_upgrade_cost_add(upgrade: Dictionary) -> Dictionary:
	var cost_add: Variant = upgrade.get("cost_add", {})
	if typeof(cost_add) != TYPE_DICTIONARY:
		return {}
	var result: Dictionary = {}
	for key in (cost_add as Dictionary).keys():
		var amount := int((cost_add as Dictionary)[key])
		if amount > 0:
			result[StringName(str(key))] = amount
	return result

func _make_resource_cost_grid(resources: Dictionary, slot_size: Vector2 = Vector2(34, 34), next_columns: int = 6) -> GridContainer:
	var grid := GridContainer.new()
	_rebuild_resource_cost_grid(grid, resources, slot_size, next_columns)
	return grid

func _rebuild_resource_cost_grid(grid: GridContainer, resources: Dictionary, slot_size: Vector2 = Vector2(34, 34), next_columns: int = 6) -> void:
	if grid == null:
		return
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	grid.columns = maxi(1, next_columns)
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if resources.is_empty():
		grid.add_child(_make_label("无", 12, Color(0.62, 0.68, 0.74, 1.0)))
		return
	var keys := resources.keys()
	keys.sort()
	for key in keys:
		var resource_id := StringName(str(key))
		var amount := int(resources[key])
		var resource_def := _find_resource_def(resource_id)
		var display_name := _resource_display_name(resource_id, resource_def)
		var slot = ItemIconSlotScript.new()
		slot.slot_size = slot_size
		slot.setup(
			_resource_icon(resource_def),
			str(amount),
			Color(0.36, 0.78, 0.60, 0.92),
			"%s x%d" % [display_name, amount]
		)
		grid.add_child(slot)

func _find_resource_def(resource_id: StringName) -> ResourceDef:
	for resource_def in _resource_defs:
		if resource_def != null and resource_def.id == resource_id:
			return resource_def
	return null

func _resource_display_name(resource_id: StringName, resource_def: ResourceDef = null) -> String:
	return resource_def.display_name if resource_def != null else String(resource_id)

func _resource_icon(resource_def: ResourceDef) -> Texture2D:
	if resource_def == null or resource_def.icon_path.is_empty() or not ResourceLoader.exists(resource_def.icon_path, "Texture2D"):
		return null
	return load(resource_def.icon_path) as Texture2D

func _find_blueprint(blueprint_id: StringName) -> UnitBlueprint:
	for blueprint in _blueprints:
		if blueprint.id == blueprint_id:
			return blueprint
	return null

func _make_column(width: float) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(width, 0.0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	return column

func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_section_style())
	return panel

func _panel_box(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(box)
	return box

func _make_separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 8)
	return separator

func _make_preview_texture_rect(size: Vector2, position: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = size
	rect.size = size
	rect.position = position
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	return rect

func _make_section_title(text: String) -> Label:
	return _make_label(text, 14, Color(0.78, 0.86, 0.94, 1.0))

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

func _make_card_style(selected: bool) -> StyleBoxFlat:
	var style := _make_section_style()
	style.bg_color = Color(0.07, 0.09, 0.10, 0.88) if selected else Color(0.048, 0.057, 0.067, 0.78)
	style.border_color = Color(0.46, 0.76, 0.92, 0.95) if selected else Color(0.18, 0.26, 0.32, 0.92)
	return style
