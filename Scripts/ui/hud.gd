extends CanvasLayer
class_name MvpHud

signal build_mode_requested(building_id: StringName)
signal processor_recipe_selected(processor: Node, recipe_id: StringName)
signal forge_rally_point_requested(forge: Node)
signal blueprint_library_requested
signal blueprint_save_requested(source_blueprint_id: StringName, display_name: String, embedded_rules: Array, state_flag_defaults: Dictionary, save_as_new: bool)
signal forge_blueprint_selected(forge: Node, blueprint_id: StringName)

const BottomPromptScript := preload("res://Scripts/ui/bottom_prompt.gd")
const BlueprintManagementOverlayScript := preload("res://Scripts/ui/blueprint_management_overlay.gd")
const VictorySummaryPanelScript := preload("res://Scripts/ui/victory_summary_panel.gd")

@onready var current_goal_label: Label = %CurrentGoalLabel
@onready var resource_summary_label: Label = %ResourceSummaryLabel
@onready var bottom_hint_label: Label = %BottomHintLabel
@onready var object_inspector: PanelContainer = %ObjectInspector
@onready var debug_event_panel: PanelContainer = %DebugEventPanel
@onready var build_button_row: HBoxContainer = %BuildButtonRow
@onready var root_control: Control = $Root

var _building_defs: Array[BuildingDef] = []
var _inventory_amounts: Dictionary = {}
var _cost_panel: PanelContainer = null
var _cost_list: VBoxContainer = null
var _cost_preview_content_key: String = ""
var _operation_panel: PanelContainer = null
var _operation_list: VBoxContainer = null
var _operation_mode: StringName = &""
var _operation_processor: Node = null
var _operation_recipes: Array[RecipeDef] = []
var _operation_blueprints: Array[UnitBlueprint] = []
var _operation_forge: Node = null
var _operation_current_label: Label = null
var _operation_recipe_detail_label: Label = null
var _operation_status_label: Label = null
var _operation_progress_label: Label = null
var _operation_progress_bar: ProgressBar = null
var _operation_input_cache_label: Label = null
var _operation_output_cache_label: Label = null
var _operation_recipe_buttons: Dictionary = {}
var _operation_blueprint_label: Label = null
var _operation_alive_label: Label = null
var _operation_rally_label: Label = null
var _operation_cost_label: Label = null
var _bottom_prompt: BottomPrompt = null
var _blueprint_button: Button = null
var _blueprints: Array[UnitBlueprint] = []
var _blueprint_panel: PanelContainer = null
var _blueprint_list: VBoxContainer = null
var _blueprint_source_option: OptionButton = null
var _blueprint_name_edit: LineEdit = null
var _forge_blueprint_picker: PanelContainer = null
var _forge_blueprint_list: VBoxContainer = null
var _blueprint_overlay: Control = null
var _victory_summary_panel: Control = null

func _ready() -> void:
	set_current_goal("阶段 0：验证 MVP 测试入口")
	set_resource_summary("资源面板占位")
	set_bottom_hint("左侧检查器 / 右侧事件面板为阶段 0 占位 UI")
	if object_inspector:
		object_inspector.show_placeholder("未选择对象")
	if debug_event_panel:
		debug_event_panel.add_event_line("MVP HUD 已加载")
	_ensure_bottom_prompt()
	_ensure_blueprint_button()

func set_current_goal(text: String) -> void:
	if current_goal_label:
		current_goal_label.text = "目标：%s" % text

func set_resource_summary(text: String) -> void:
	if resource_summary_label:
		resource_summary_label.text = text

func set_bottom_hint(text: String) -> void:
	if bottom_hint_label:
		bottom_hint_label.text = text

func inspect_node(node: Node) -> void:
	if object_inspector:
		object_inspector.inspect_node(node)

func inspect_cell(cell: Vector2i) -> void:
	if object_inspector and object_inspector.has_method("inspect_cell"):
		object_inspector.call("inspect_cell", cell)

func push_debug_event(text: String) -> void:
	if debug_event_panel:
		debug_event_panel.add_event_line(text)

func show_build_cost_preview(building_def: BuildingDef, resource_defs: Array[ResourceDef], amounts: Dictionary, screen_position: Vector2) -> void:
	_ensure_cost_panel()
	_cost_panel.visible = true
	var content_key := _make_cost_preview_content_key(building_def, amounts)
	if content_key != _cost_preview_content_key:
		_cost_preview_content_key = content_key
		_rebuild_cost_panel(building_def, resource_defs, amounts)
	_position_cost_panel(screen_position)

func hide_build_cost_preview() -> void:
	if _cost_panel:
		_cost_panel.visible = false
	_cost_preview_content_key = ""

func show_bottom_prompt(text: String, duration_seconds: float = 0.0, variant: StringName = &"info") -> void:
	_ensure_bottom_prompt()
	_bottom_prompt.show_prompt(text, duration_seconds, variant)

func hide_bottom_prompt() -> void:
	if _bottom_prompt:
		_bottom_prompt.hide_prompt()

func show_victory_summary(summary: Dictionary) -> void:
	_ensure_victory_summary_panel()
	_victory_summary_panel.show_summary(summary)

func show_processor_panel(processor: Node, recipes: Array[RecipeDef], resource_defs: Array[ResourceDef], screen_position: Vector2) -> void:
	_ensure_operation_panel()
	_operation_panel.visible = true
	if _operation_mode != &"processor" or _operation_processor != processor or _operation_recipes.size() != recipes.size():
		_operation_mode = &"processor"
		_operation_processor = processor
		_operation_forge = null
		_operation_recipes = recipes.duplicate()
		_operation_blueprints.clear()
		_rebuild_processor_panel(processor, recipes)
	_update_processor_panel(processor, resource_defs)
	_position_operation_panel(screen_position)

func show_forge_panel(forge: Node, blueprint: UnitBlueprint, blueprints: Array[UnitBlueprint], resource_defs: Array[ResourceDef], screen_position: Vector2) -> void:
	_ensure_operation_panel()
	_operation_panel.visible = true
	if _operation_mode != &"forge" or _operation_forge != forge or _operation_blueprints.size() != blueprints.size():
		_operation_mode = &"forge"
		_operation_forge = forge
		_operation_processor = null
		_operation_recipes.clear()
		_operation_blueprints = blueprints.duplicate()
		_rebuild_forge_panel(forge)
	_update_forge_panel(forge, blueprint, resource_defs)
	_position_operation_panel(screen_position)

func hide_operation_panel() -> void:
	if _operation_panel:
		_operation_panel.visible = false
	_operation_mode = &""
	_operation_processor = null
	_operation_forge = null
	_operation_blueprints.clear()
	if _forge_blueprint_picker:
		_forge_blueprint_picker.visible = false

func set_resource_amounts(resource_defs: Array[ResourceDef], amounts: Dictionary) -> void:
	_inventory_amounts = amounts.duplicate(true)
	var parts: Array[String] = []
	for resource_def in resource_defs:
		parts.append("%s %s" % [resource_def.display_name, int(amounts.get(resource_def.id, 0))])
	set_resource_summary(" / ".join(parts))
	_refresh_build_buttons()

func set_building_options(building_defs: Array[BuildingDef]) -> void:
	_building_defs = building_defs.duplicate()
	_refresh_build_buttons()

func set_blueprint_library(blueprints: Array[UnitBlueprint]) -> void:
	_blueprints = blueprints.duplicate()
	if _blueprint_overlay and _blueprint_overlay.has_method("set_blueprints"):
		_blueprint_overlay.call("set_blueprints", _blueprints)
	if _blueprint_panel and _blueprint_panel.visible:
		_rebuild_blueprint_panel()

func _refresh_build_buttons() -> void:
	if build_button_row == null:
		return
	for child in build_button_row.get_children():
		build_button_row.remove_child(child)
		child.queue_free()

	var title := Label.new()
	title.text = "建造"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	build_button_row.add_child(title)

	for building_def in _building_defs:
		var button := Button.new()
		button.text = building_def.display_name
		button.tooltip_text = _format_build_tooltip(building_def)
		button.custom_minimum_size = Vector2(120, 32)
		if not _can_afford(building_def.build_cost):
			button.modulate = Color(1.0, 0.68, 0.48, 1.0)
		var icon: Texture2D = null
		if not building_def.icon_path.is_empty():
			icon = load(building_def.icon_path) as Texture2D
		if icon:
			button.icon = icon
			button.expand_icon = true
		button.pressed.connect(_on_build_button_pressed.bind(building_def.id))
		build_button_row.add_child(button)

func _can_afford(cost: Dictionary) -> bool:
	for resource_id in cost.keys():
		if int(_inventory_amounts.get(resource_id, 0)) < int(cost[resource_id]):
			return false
	return true

func _format_build_tooltip(building_def: BuildingDef) -> String:
	var parts: Array[String] = []
	for resource_id in building_def.build_cost.keys():
		parts.append("%s: %s" % [String(resource_id), int(building_def.build_cost[resource_id])])
	return "%s\n成本：%s" % [building_def.display_name, " / ".join(parts)]

func _on_build_button_pressed(building_id: StringName) -> void:
	build_mode_requested.emit(building_id)

func _ensure_cost_panel() -> void:
	if _cost_panel != null:
		return

	_cost_panel = PanelContainer.new()
	_cost_panel.name = "BuildCostPreview"
	_cost_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_panel.visible = false
	_cost_panel.z_index = 100
	_cost_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_cost_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_cost_panel.add_theme_stylebox_override("panel", _make_cost_panel_style())
	root_control.add_child(_cost_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	_cost_panel.add_child(margin)

	_cost_list = VBoxContainer.new()
	_cost_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_list.add_theme_constant_override("separation", 4)
	margin.add_child(_cost_list)

func _rebuild_cost_panel(building_def: BuildingDef, resource_defs: Array[ResourceDef], amounts: Dictionary) -> void:
	for child in _cost_list.get_children():
		_cost_list.remove_child(child)
		child.queue_free()
	_cost_panel.size = Vector2.ZERO

	var title := _make_cost_label(building_def.display_name, Color(0.95, 0.97, 1.0, 1.0), 14)
	_cost_list.add_child(title)

	if building_def.build_cost.is_empty():
		_cost_list.add_child(_make_cost_label("无需资源", Color(0.72, 0.86, 0.72, 1.0), 13))
		_cost_panel.size = _cost_panel.get_combined_minimum_size()
		return

	for resource_id in building_def.build_cost.keys():
		var required := int(building_def.build_cost[resource_id])
		var current := int(amounts.get(resource_id, 0))
		var enough := current >= required
		var color := Color(0.86, 0.94, 0.86, 1.0) if enough else Color(1.0, 0.34, 0.30, 1.0)
		var text := "%s  %s / %s" % [
			_get_resource_display_name(resource_defs, resource_id),
			current,
			required,
		]
		_cost_list.add_child(_make_cost_label(text, color, 13))
	_cost_panel.size = _cost_panel.get_combined_minimum_size()

func _make_cost_preview_content_key(building_def: BuildingDef, amounts: Dictionary) -> String:
	var parts: Array[String] = [String(building_def.id)]
	for resource_id in building_def.build_cost.keys():
		parts.append("%s:%s/%s" % [
			String(resource_id),
			int(amounts.get(resource_id, 0)),
			int(building_def.build_cost[resource_id]),
		])
	return "|".join(parts)

func _position_cost_panel(screen_position: Vector2) -> void:
	var popup_offset := Vector2(18, 18)
	var desired_position := screen_position + popup_offset
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := _cost_panel.get_combined_minimum_size()
	if panel_size == Vector2.ZERO:
		panel_size = Vector2(120, 72)
	desired_position.x = clampf(desired_position.x, 8.0, maxf(8.0, viewport_size.x - panel_size.x - 8.0))
	desired_position.y = clampf(desired_position.y, 8.0, maxf(8.0, viewport_size.y - panel_size.y - 8.0))
	_cost_panel.position = desired_position

func _make_cost_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.045, 0.05, 0.64)
	style.border_color = Color(0.32, 0.38, 0.42, 0.72)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style

func _make_cost_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _get_resource_display_name(resource_defs: Array[ResourceDef], resource_id: StringName) -> String:
	for resource_def in resource_defs:
		if resource_def.id == resource_id:
			return resource_def.display_name
	return String(resource_id)

func _ensure_bottom_prompt() -> void:
	if _bottom_prompt != null:
		return
	_bottom_prompt = BottomPromptScript.new()
	_bottom_prompt.name = "BottomPrompt"
	_bottom_prompt.anchor_left = 0.5
	_bottom_prompt.anchor_top = 1.0
	_bottom_prompt.anchor_right = 0.5
	_bottom_prompt.anchor_bottom = 1.0
	_bottom_prompt.offset_left = -420.0
	_bottom_prompt.offset_top = -150.0
	_bottom_prompt.offset_right = 420.0
	_bottom_prompt.offset_bottom = -102.0
	_bottom_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bottom_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root_control.add_child(_bottom_prompt)

func _ensure_blueprint_button() -> void:
	if _blueprint_button != null:
		return
	_blueprint_button = Button.new()
	_blueprint_button.name = "BlueprintLibraryButton"
	_blueprint_button.text = "蓝图"
	_blueprint_button.tooltip_text = "打开机器人蓝图管理"
	_blueprint_button.anchor_left = 1.0
	_blueprint_button.anchor_top = 1.0
	_blueprint_button.anchor_right = 1.0
	_blueprint_button.anchor_bottom = 1.0
	_blueprint_button.offset_left = -142.0
	_blueprint_button.offset_top = -150.0
	_blueprint_button.offset_right = -24.0
	_blueprint_button.offset_bottom = -112.0
	_blueprint_button.z_index = 135
	_blueprint_button.pressed.connect(_on_blueprint_button_pressed)
	root_control.add_child(_blueprint_button)

func _ensure_victory_summary_panel() -> void:
	if _victory_summary_panel != null:
		return
	_victory_summary_panel = VictorySummaryPanelScript.new()
	_victory_summary_panel.name = "VictorySummaryPanel"
	_victory_summary_panel.visible = false
	_victory_summary_panel.z_index = 180
	_victory_summary_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(_victory_summary_panel)

func _on_blueprint_button_pressed() -> void:
	blueprint_library_requested.emit()
	_ensure_blueprint_overlay()
	if _blueprint_panel:
		_blueprint_panel.visible = false
	_blueprint_overlay.call("set_blueprints", _blueprints)
	_blueprint_overlay.visible = not _blueprint_overlay.visible

func _ensure_blueprint_overlay() -> void:
	if _blueprint_overlay != null:
		return
	_blueprint_overlay = BlueprintManagementOverlayScript.new()
	_blueprint_overlay.name = "BlueprintManagementOverlay"
	_blueprint_overlay.visible = false
	_blueprint_overlay.z_index = 150
	_blueprint_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_blueprint_overlay.save_requested.connect(_on_blueprint_overlay_save_requested)
	root_control.add_child(_blueprint_overlay)

func _on_blueprint_overlay_save_requested(source_blueprint_id: StringName, display_name: String, embedded_rules: Array, state_flag_defaults: Dictionary, save_as_new: bool) -> void:
	blueprint_save_requested.emit(source_blueprint_id, display_name, embedded_rules, state_flag_defaults, save_as_new)

func _ensure_blueprint_panel() -> void:
	if _blueprint_panel != null:
		return
	_blueprint_panel = PanelContainer.new()
	_blueprint_panel.name = "BlueprintLibraryPanel"
	_blueprint_panel.visible = false
	_blueprint_panel.z_index = 95
	_blueprint_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_blueprint_panel.anchor_left = 1.0
	_blueprint_panel.anchor_top = 1.0
	_blueprint_panel.anchor_right = 1.0
	_blueprint_panel.anchor_bottom = 1.0
	_blueprint_panel.offset_left = -388.0
	_blueprint_panel.offset_top = -470.0
	_blueprint_panel.offset_right = -24.0
	_blueprint_panel.offset_bottom = -160.0
	_blueprint_panel.add_theme_stylebox_override("panel", _make_operation_panel_style())
	root_control.add_child(_blueprint_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_blueprint_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var title := _make_operation_label("机器人蓝图库", Color(0.96, 0.98, 1.0, 1.0), 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(64, 28)
	close_button.pressed.connect(func() -> void:
		_blueprint_panel.visible = false
	)
	header.add_child(close_button)
	root.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 148)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_blueprint_list = VBoxContainer.new()
	_blueprint_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_blueprint_list)

	root.add_child(_make_operation_label("新建蓝图", Color(0.78, 0.86, 0.94, 1.0), 13))
	_blueprint_source_option = OptionButton.new()
	_blueprint_source_option.custom_minimum_size = Vector2(320, 28)
	root.add_child(_blueprint_source_option)
	_blueprint_name_edit = LineEdit.new()
	_blueprint_name_edit.placeholder_text = "蓝图名称"
	_blueprint_name_edit.text = "集结步枪机器人"
	_blueprint_name_edit.custom_minimum_size = Vector2(320, 28)
	root.add_child(_blueprint_name_edit)
	var save_button := Button.new()
	save_button.text = "保存为先集结再战斗蓝图"
	save_button.custom_minimum_size = Vector2(320, 30)
	save_button.pressed.connect(_on_save_rally_blueprint_pressed)
	root.add_child(save_button)

func _rebuild_blueprint_panel() -> void:
	if _blueprint_list == null or _blueprint_source_option == null:
		return
	for child in _blueprint_list.get_children():
		_blueprint_list.remove_child(child)
		child.queue_free()
	_blueprint_source_option.clear()
	if _blueprints.is_empty():
		_blueprint_list.add_child(_make_operation_label("暂无蓝图", Color(0.84, 0.88, 0.92, 1.0), 13))
		return
	for blueprint in _blueprints:
		_blueprint_list.add_child(_make_blueprint_summary_row(blueprint))
		_blueprint_source_option.add_item("%s v%s" % [blueprint.display_name, blueprint.version])
		_blueprint_source_option.set_item_metadata(_blueprint_source_option.item_count - 1, blueprint.id)
	_blueprint_source_option.select(0)

func _make_blueprint_summary_row(blueprint: UnitBlueprint) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := _make_operation_label(_format_blueprint_summary(blueprint), Color(0.88, 0.94, 1.0, 1.0), 13)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var clone_button := Button.new()
	clone_button.text = "集结版"
	clone_button.custom_minimum_size = Vector2(74, 26)
	clone_button.pressed.connect(_on_blueprint_clone_rally_pressed.bind(blueprint.id), CONNECT_DEFERRED)
	row.add_child(clone_button)
	return row

func _format_blueprint_summary(blueprint: UnitBlueprint) -> String:
	var modules := " / ".join(blueprint.module_display_names)
	var rule_count := blueprint.embedded_rules.size()
	return "%s v%s | %s | %s | 规则 %d" % [
		blueprint.display_name,
		blueprint.version,
		blueprint.chassis_display_name,
		modules,
		rule_count,
	]

func _on_save_rally_blueprint_pressed() -> void:
	if _blueprint_source_option == null or _blueprint_source_option.item_count <= 0:
		return
	var selected_index := _blueprint_source_option.selected
	var source_id := StringName(str(_blueprint_source_option.get_item_metadata(selected_index)))
	blueprint_save_requested.emit(source_id, _blueprint_name_edit.text if _blueprint_name_edit else "", [], {}, true)

func _on_blueprint_clone_rally_pressed(source_blueprint_id: StringName) -> void:
	var display_name := "集结蓝图"
	for blueprint in _blueprints:
		if blueprint.id == source_blueprint_id:
			display_name = "%s 集结版" % blueprint.display_name
			break
	blueprint_save_requested.emit(source_blueprint_id, display_name, [], {}, true)

func _on_forge_blueprint_picker_pressed(forge: Node) -> void:
	_show_forge_blueprint_picker(forge)

func _show_forge_blueprint_picker(forge: Node) -> void:
	_ensure_forge_blueprint_picker()
	for child in _forge_blueprint_list.get_children():
		_forge_blueprint_list.remove_child(child)
		child.queue_free()
	var available_blueprints := _operation_blueprints if not _operation_blueprints.is_empty() else _blueprints
	for blueprint in available_blueprints:
		var button := Button.new()
		button.text = "%s v%s" % [blueprint.display_name, blueprint.version]
		button.tooltip_text = _format_blueprint_summary(blueprint)
		button.custom_minimum_size = Vector2(210, 28)
		button.pressed.connect(_on_forge_blueprint_selected.bind(forge, blueprint.id), CONNECT_DEFERRED)
		_forge_blueprint_list.add_child(button)
	if available_blueprints.is_empty():
		_forge_blueprint_list.add_child(_make_operation_label("暂无可选蓝图", Color(0.84, 0.88, 0.92, 1.0), 13))
	var panel_size := Vector2(236, minf(260.0, maxf(64.0, _forge_blueprint_list.get_combined_minimum_size().y + 20.0)))
	_forge_blueprint_picker.visible = true
	_forge_blueprint_picker.size = panel_size
	_forge_blueprint_picker.position = get_viewport().get_mouse_position()

func _ensure_forge_blueprint_picker() -> void:
	if _forge_blueprint_picker != null:
		return
	_forge_blueprint_picker = PanelContainer.new()
	_forge_blueprint_picker.name = "ForgeBlueprintPicker"
	_forge_blueprint_picker.visible = false
	_forge_blueprint_picker.z_index = 110
	_forge_blueprint_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	_forge_blueprint_picker.add_theme_stylebox_override("panel", _make_operation_panel_style())
	root_control.add_child(_forge_blueprint_picker)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_forge_blueprint_picker.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(220, 56)
	margin.add_child(scroll)
	_forge_blueprint_list = VBoxContainer.new()
	_forge_blueprint_list.add_theme_constant_override("separation", 5)
	scroll.add_child(_forge_blueprint_list)

func _on_forge_blueprint_selected(forge: Node, blueprint_id: StringName) -> void:
	if _forge_blueprint_picker:
		_forge_blueprint_picker.visible = false
	forge_blueprint_selected.emit(forge, blueprint_id)

func _ensure_operation_panel() -> void:
	if _operation_panel != null:
		return

	_operation_panel = PanelContainer.new()
	_operation_panel.name = "BuildingOperationPanel"
	_operation_panel.z_index = 90
	_operation_panel.visible = false
	_operation_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_operation_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_operation_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_operation_panel.add_theme_stylebox_override("panel", _make_operation_panel_style())
	root_control.add_child(_operation_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	_operation_panel.add_child(margin)

	_operation_list = VBoxContainer.new()
	_operation_list.add_theme_constant_override("separation", 4)
	_operation_list.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_operation_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_child(_operation_list)

func _rebuild_processor_panel(processor: Node, recipes: Array[RecipeDef]) -> void:
	_clear_operation_content()

	_operation_list.add_child(_make_operation_label(processor.call("get_display_name"), Color(0.96, 0.98, 1.0, 1.0), 15))
	_operation_list.add_child(_make_operation_label("配方", Color(0.72, 0.78, 0.84, 1.0), 12))

	var recipe_row := HBoxContainer.new()
	recipe_row.add_theme_constant_override("separation", 6)
	for recipe in recipes:
		var button := Button.new()
		button.text = recipe.display_name
		button.custom_minimum_size = Vector2(88, 28)
		button.pressed.connect(_on_processor_recipe_button_pressed.bind(processor, recipe.id), CONNECT_DEFERRED)
		recipe_row.add_child(button)
		_operation_recipe_buttons[recipe.id] = button
	_operation_list.add_child(recipe_row)

	_operation_current_label = _make_operation_label("", Color(0.9, 0.92, 0.95, 1.0), 13)
	_operation_list.add_child(_operation_current_label)
	_operation_recipe_detail_label = _make_operation_label("", Color(0.82, 0.88, 0.96, 1.0), 13)
	_operation_list.add_child(_operation_recipe_detail_label)
	_operation_status_label = _make_operation_label("", Color(0.9, 0.92, 0.95, 1.0), 13)
	_operation_list.add_child(_operation_status_label)
	_operation_progress_label = _make_operation_label("", Color(0.78, 0.88, 1.0, 1.0), 13)
	_operation_list.add_child(_operation_progress_label)

	_operation_progress_bar = ProgressBar.new()
	_operation_progress_bar.custom_minimum_size = Vector2(184, 10)
	_operation_progress_bar.min_value = 0.0
	_operation_progress_bar.max_value = 1.0
	_operation_progress_bar.show_percentage = false
	_operation_list.add_child(_operation_progress_bar)

	_operation_input_cache_label = _make_operation_label("", Color(0.78, 0.88, 1.0, 1.0), 13)
	_operation_list.add_child(_operation_input_cache_label)
	_operation_output_cache_label = _make_operation_label("", Color(0.82, 0.95, 0.82, 1.0), 13)
	_operation_list.add_child(_operation_output_cache_label)
	_operation_panel.size = _operation_panel.get_combined_minimum_size()

func _update_processor_panel(processor: Node, resource_defs: Array[ResourceDef]) -> void:
	var selected_recipe: RecipeDef = processor.get("selected_recipe")
	if _operation_current_label:
		_operation_current_label.text = "当前：%s" % (selected_recipe.display_name if selected_recipe else "未选择")
	if _operation_recipe_detail_label:
		_operation_recipe_detail_label.text = _format_processor_recipe_detail(selected_recipe, resource_defs)
	if _operation_status_label:
		_operation_status_label.text = "状态：%s" % str(processor.get("status_text"))
	if _operation_progress_label:
		_operation_progress_label.text = _format_processor_progress_text(processor, selected_recipe)
	if _operation_progress_bar:
		_operation_progress_bar.value = float(processor.call("get_progress_ratio"))
	if _operation_input_cache_label:
		_operation_input_cache_label.text = "原料缓存：%s" % _format_resource_dictionary(processor.get("input_cache"), resource_defs)
	if _operation_output_cache_label:
		_operation_output_cache_label.text = "产物缓存：%s" % _format_resource_dictionary(processor.get("output_cache"), resource_defs)
	_refresh_recipe_button_states(selected_recipe)
	_operation_panel.size = _operation_panel.get_combined_minimum_size()

func _rebuild_forge_panel(forge: Node) -> void:
	_clear_operation_content()

	_operation_list.add_child(_make_operation_label(forge.call("get_display_name"), Color(0.96, 0.98, 1.0, 1.0), 15))
	_operation_blueprint_label = _make_operation_label("", Color(0.84, 0.90, 1.0, 1.0), 13)
	_operation_list.add_child(_operation_blueprint_label)
	_operation_alive_label = _make_operation_label("", Color(0.90, 0.94, 0.98, 1.0), 13)
	_operation_list.add_child(_operation_alive_label)
	_operation_status_label = _make_operation_label("", Color(0.90, 0.94, 0.98, 1.0), 13)
	_operation_list.add_child(_operation_status_label)
	_operation_progress_label = _make_operation_label("", Color(0.78, 0.88, 1.0, 1.0), 13)
	_operation_list.add_child(_operation_progress_label)

	_operation_progress_bar = ProgressBar.new()
	_operation_progress_bar.custom_minimum_size = Vector2(206, 10)
	_operation_progress_bar.min_value = 0.0
	_operation_progress_bar.max_value = 1.0
	_operation_progress_bar.show_percentage = false
	_operation_list.add_child(_operation_progress_bar)

	_operation_cost_label = _make_operation_label("", Color(0.82, 0.88, 0.94, 1.0), 13)
	_operation_list.add_child(_operation_cost_label)
	_operation_rally_label = _make_operation_label("", Color(0.86, 0.94, 0.82, 1.0), 13)
	_operation_list.add_child(_operation_rally_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	var rally_button := Button.new()
	rally_button.text = "设置集结点"
	rally_button.custom_minimum_size = Vector2(112, 30)
	rally_button.pressed.connect(_on_forge_rally_button_pressed.bind(forge), CONNECT_DEFERRED)
	action_row.add_child(rally_button)
	var blueprint_button := Button.new()
	blueprint_button.text = "选择蓝图"
	blueprint_button.custom_minimum_size = Vector2(96, 30)
	blueprint_button.pressed.connect(_on_forge_blueprint_picker_pressed.bind(forge), CONNECT_DEFERRED)
	action_row.add_child(blueprint_button)
	_operation_list.add_child(action_row)
	_operation_panel.size = _operation_panel.get_combined_minimum_size()

func _update_forge_panel(forge: Node, blueprint: UnitBlueprint, resource_defs: Array[ResourceDef]) -> void:
	if _operation_blueprint_label:
		_operation_blueprint_label.text = "蓝图：%s v%s" % [
			blueprint.display_name if blueprint else "未绑定",
			blueprint.version if blueprint else 0,
		]
	if _operation_alive_label:
		_operation_alive_label.text = "存活：%s / %s" % [
			int(forge.call("get_alive_count")) if forge.has_method("get_alive_count") else 0,
			int(forge.get("target_alive_count")),
		]
	if _operation_status_label:
		_operation_status_label.text = "状态：%s" % str(forge.get("status_text"))
	if _operation_progress_label:
		_operation_progress_label.text = _format_forge_progress_text(forge, blueprint)
	if _operation_progress_bar:
		_operation_progress_bar.value = float(forge.call("get_progress_ratio")) if forge.has_method("get_progress_ratio") else 0.0
	if _operation_cost_label:
		_operation_cost_label.text = "成本：%s" % _format_resource_dictionary(blueprint.production_cost if blueprint else {}, resource_defs)
	if _operation_rally_label:
		_operation_rally_label.text = _format_forge_rally_text(forge)
	_operation_panel.size = _operation_panel.get_combined_minimum_size()

func _format_forge_progress_text(forge: Node, blueprint: UnitBlueprint) -> String:
	var current_seconds := float(forge.get("progress_seconds"))
	var total_seconds := blueprint.production_time_seconds if blueprint else 0.0
	return "进度：%.1fs / %.1fs" % [current_seconds, total_seconds]

func _format_forge_rally_text(forge: Node) -> String:
	if not bool(forge.get("has_rally_point")):
		return "集结点：未设置"
	var cell: Vector2i = forge.get("rally_point_cell")
	return "集结点：%s, %s" % [cell.x, cell.y]

func _refresh_recipe_button_states(selected_recipe: RecipeDef) -> void:
	for recipe_id in _operation_recipe_buttons.keys():
		var button := _operation_recipe_buttons[recipe_id] as Button
		if button:
			button.modulate = Color(0.68, 0.92, 1.0, 1.0) if selected_recipe and selected_recipe.id == recipe_id else Color.WHITE

func _format_processor_progress_text(processor: Node, selected_recipe: RecipeDef) -> String:
	var current_seconds := float(processor.get("progress_seconds"))
	var total_seconds := selected_recipe.duration_seconds if selected_recipe else 0.0
	return "进度：%.1fs / %.1fs" % [current_seconds, total_seconds]

func _format_processor_recipe_detail(selected_recipe: RecipeDef, resource_defs: Array[ResourceDef]) -> String:
	if selected_recipe == null:
		return "配方内容：未选择"
	return "配方内容：%s -> %s，%.1fs" % [
		_format_resource_dictionary(selected_recipe.inputs, resource_defs),
		_format_resource_dictionary(selected_recipe.outputs, resource_defs),
		selected_recipe.duration_seconds,
	]

func _clear_operation_content() -> void:
	for child in _operation_list.get_children():
		_operation_list.remove_child(child)
		child.queue_free()
	_operation_panel.size = Vector2.ZERO
	_operation_current_label = null
	_operation_recipe_detail_label = null
	_operation_status_label = null
	_operation_progress_label = null
	_operation_progress_bar = null
	_operation_input_cache_label = null
	_operation_output_cache_label = null
	_operation_recipe_buttons.clear()
	_operation_blueprint_label = null
	_operation_alive_label = null
	_operation_rally_label = null
	_operation_cost_label = null

func _position_operation_panel(screen_position: Vector2) -> void:
	var popup_offset := Vector2(24, -16)
	var desired_position := screen_position + popup_offset
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := _operation_panel.get_combined_minimum_size()
	if panel_size == Vector2.ZERO:
		panel_size = Vector2(196, 140)
	desired_position.x = clampf(desired_position.x, 8.0, maxf(8.0, viewport_size.x - panel_size.x - 8.0))
	desired_position.y = clampf(desired_position.y, 68.0, maxf(68.0, viewport_size.y - panel_size.y - 86.0))
	_operation_panel.position = desired_position

func _make_operation_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.048, 0.92)
	style.border_color = Color(0.30, 0.36, 0.42, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

func _make_operation_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _format_resource_dictionary(resources: Dictionary, resource_defs: Array[ResourceDef]) -> String:
	if resources.is_empty():
		return "空"
	var parts: Array[String] = []
	for resource_id in resources.keys():
		parts.append("%s %s" % [_get_resource_display_name(resource_defs, resource_id), int(resources[resource_id])])
	return " / ".join(parts)

func _on_processor_recipe_button_pressed(processor: Node, recipe_id: StringName) -> void:
	processor_recipe_selected.emit(processor, recipe_id)

func _on_forge_rally_button_pressed(forge: Node) -> void:
	forge_rally_point_requested.emit(forge)
