extends CanvasLayer
class_name MvpHud

signal build_mode_requested(building_id: StringName)
signal processor_recipe_selected(processor: Node, recipe_id: StringName)
signal processor_pause_toggled(processor: Node)
signal building_demolish_requested(building: Node)
signal forge_rally_point_requested(forge: Node)
signal blueprint_library_requested
signal blueprint_save_requested(source_blueprint_id: StringName, display_name: String, unit_type_id: StringName, upgrade_ids: Array[StringName], tactical_templates: Array, embedded_rules: Array, state_flag_defaults: Dictionary, save_as_new: bool)
signal forge_blueprint_selected(forge: Node, blueprint_id: StringName)
signal technology_research_requested(technology_id: StringName)
signal new_game_requested
signal restart_requested
signal save_game_requested
signal load_game_requested

const BottomPromptScript := preload("res://Scripts/ui/bottom_prompt.gd")
const BuildingOperationPanelScript := preload("res://Scripts/ui/building_operation_panel.gd")
const BlueprintManagementOverlayScript := preload("res://Scripts/ui/blueprint_management_overlay.gd")
const CombatReportOverlayScript := preload("res://Scripts/ui/combat_report_overlay.gd")
const VictorySummaryPanelScript := preload("res://Scripts/ui/victory_summary_panel.gd")
const MinimapPanelScript := preload("res://Scripts/ui/minimap_panel.gd")
const BLUEPRINT_MENU_ICON_PATH := "res://Resources/art/ui/blueprint_menu.svg"
const STATISTICS_MENU_ICON_PATH := "res://Resources/art/ui/statistics_menu.svg"
const TECHNOLOGY_MENU_ICON_PATH := "res://Resources/art/ui/technology_unlocked.svg"
const STATE_RALLY_ICON_PATH := "res://Resources/art/ui/state_rally.svg"

@onready var current_goal_label: Label = %CurrentGoalLabel
@onready var resource_summary_label: Label = %ResourceSummaryLabel
@onready var elapsed_time_label: Label = %ElapsedTimeLabel
@onready var objective_direction_label: Label = %ObjectiveDirectionLabel
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
var _building_operation_panel: Control = null
var _bottom_prompt: BottomPrompt = null
var _blueprint_button: Button = null
var _statistics_button: Button = null
var _technology_button: Button = null
var _resource_defs: Array[ResourceDef] = []
var _blueprints: Array[UnitBlueprint] = []
var _logistics_diagnostics: Dictionary = {}
var _campaign_state: Variant = null
var _technology_defs: Array = []
var _campaign_inventory_amounts: Dictionary = {}
var _research_terminal_status: Dictionary = {}
var _unlocked_template_ids: Array[StringName] = []
var _unlocked_unit_type_ids: Array[StringName] = []
var _unlocked_upgrade_ids: Array[StringName] = []
var _blueprint_panel: PanelContainer = null
var _blueprint_list: VBoxContainer = null
var _blueprint_source_option: OptionButton = null
var _blueprint_name_edit: LineEdit = null
var _forge_blueprint_picker: PanelContainer = null
var _forge_blueprint_list: VBoxContainer = null
var _forge_picker_blueprints: Array[UnitBlueprint] = []
var _blueprint_overlay: Control = null
var _combat_report_overlay: Control = null
var _victory_summary_panel: Control = null
var _technology_overlay: PanelContainer = null
var _technology_list: VBoxContainer = null
var _pause_overlay: PanelContainer = null
var _main_menu_overlay: PanelContainer = null
var _settings_overlay: PanelContainer = null
var _minimap_panel: Control = null
var _master_volume_slider: HSlider = null
var _music_volume_slider: HSlider = null
var _sfx_volume_slider: HSlider = null
var _music_enabled_check: CheckBox = null
var _sfx_enabled_check: CheckBox = null
var _guidance_building_ids: Array[StringName] = []
var _guidance_blueprint_button: bool = false
var _guidance_technology_button: bool = false
var _guidance_forge_blueprint_picker: bool = false
var _guidance_highlight_key: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if root_control:
		root_control.process_mode = Node.PROCESS_MODE_ALWAYS
	set_current_goal("阶段 0：验证 MVP 测试入口")
	set_resource_summary("资源面板占位")
	set_bottom_hint("左侧检查器 / 右侧事件面板为阶段 0 占位 UI")
	if object_inspector:
		object_inspector.show_placeholder("未选择对象")
	if debug_event_panel:
		debug_event_panel.add_event_line("MVP HUD 已加载")
	_ensure_bottom_prompt()
	_ensure_blueprint_button()
	_ensure_statistics_button()
	_ensure_technology_button()
	_ensure_minimap_panel()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			if _pause_overlay != null and _pause_overlay.visible:
				_on_pause_continue_pressed()
			elif _main_menu_overlay != null and _main_menu_overlay.visible:
				_on_main_menu_continue_pressed()
			else:
				_show_pause_menu()
			get_viewport().set_input_as_handled()

func set_current_goal(text: String) -> void:
	if current_goal_label:
		current_goal_label.text = "目标：%s" % text

func set_resource_summary(text: String) -> void:
	if resource_summary_label:
		resource_summary_label.text = text

func set_elapsed_seconds(elapsed_seconds: float) -> void:
	if elapsed_time_label:
		var total_seconds := maxi(0, floori(elapsed_seconds))
		elapsed_time_label.text = "用时 %02d:%02d" % [floori(float(total_seconds) / 60.0), total_seconds % 60]

func set_objective_direction(text: String) -> void:
	if objective_direction_label:
		objective_direction_label.text = text

func set_minimap_snapshot(snapshot: Dictionary) -> void:
	_ensure_minimap_panel()
	if _minimap_panel and _minimap_panel.has_method("set_snapshot"):
		_minimap_panel.call("set_snapshot", snapshot)

func set_bottom_hint(text: String) -> void:
	if bottom_hint_label:
		bottom_hint_label.text = text

func inspect_node(node: Node) -> void:
	if object_inspector:
		object_inspector.inspect_node(node)

func inspect_cell(cell: Vector2i, region_info: Dictionary = {}, region_state: String = "") -> void:
	if object_inspector and object_inspector.has_method("inspect_cell"):
		object_inspector.call("inspect_cell", cell, region_info, region_state)

func push_debug_event(text: String) -> void:
	if debug_event_panel:
		debug_event_panel.add_event_line(text)

func is_pointer_over_ui(screen_position: Vector2) -> bool:
	var controls := [
		object_inspector,
		debug_event_panel,
		build_button_row,
		bottom_hint_label,
		_cost_panel,
		_building_operation_panel,
		_blueprint_button,
		_statistics_button,
		_technology_button,
		_blueprint_panel,
		_forge_blueprint_picker,
		_blueprint_overlay,
		_combat_report_overlay,
		_victory_summary_panel,
		_technology_overlay,
		_pause_overlay,
		_main_menu_overlay,
		_settings_overlay,
	]
	for control in controls:
		if _control_contains_screen_position(control, screen_position):
			return true
	return false

func _control_contains_screen_position(control: Control, screen_position: Vector2) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	if not control.visible or not control.is_visible_in_tree():
		return false
	return control.get_global_rect().has_point(screen_position)

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
	_building_operation_panel.show_processor_panel(processor, recipes, resource_defs, screen_position)

func show_miner_panel(miner: Node, resource_defs: Array[ResourceDef], screen_position: Vector2) -> void:
	_ensure_operation_panel()
	_building_operation_panel.show_miner_panel(miner, resource_defs, screen_position)

func show_producer_panel(producer: Node, resource_defs: Array[ResourceDef], screen_position: Vector2) -> void:
	_ensure_operation_panel()
	_building_operation_panel.show_producer_panel(producer, resource_defs, screen_position)

func show_forge_panel(forge: Node, blueprint: UnitBlueprint, blueprints: Array[UnitBlueprint], resource_defs: Array[ResourceDef], screen_position: Vector2) -> void:
	_ensure_operation_panel()
	_building_operation_panel.show_forge_panel(forge, blueprint, blueprints, resource_defs, screen_position)

func show_research_terminal_panel(terminal: Node, technology_defs: Array, resource_defs: Array[ResourceDef], screen_position: Vector2) -> void:
	_ensure_operation_panel()
	_building_operation_panel.show_research_terminal_panel(terminal, technology_defs, resource_defs, screen_position)

func show_cargo_robot_panel(robot: Node, resource_defs: Array[ResourceDef], screen_position: Vector2) -> void:
	_ensure_operation_panel()
	_building_operation_panel.show_cargo_robot_panel(robot, resource_defs, screen_position)

func show_inventory_storage_panel(storage_node: Node, resource_defs: Array[ResourceDef], screen_position: Vector2) -> void:
	_ensure_operation_panel()
	_building_operation_panel.show_inventory_storage_panel(storage_node, resource_defs, screen_position)

func show_supply_point_panel(supply_point: Node, resource_defs: Array[ResourceDef], screen_position: Vector2) -> void:
	show_inventory_storage_panel(supply_point, resource_defs, screen_position)

func show_basic_building_panel(building: Node, screen_position: Vector2) -> void:
	_ensure_operation_panel()
	_building_operation_panel.show_basic_building_panel(building, screen_position)

func hide_operation_panel() -> void:
	if _building_operation_panel:
		_building_operation_panel.hide_panel()
	if _forge_blueprint_picker:
		_forge_blueprint_picker.visible = false

func set_guidance_highlights(highlights: Dictionary) -> void:
	var next_building_ids: Array[StringName] = []
	for building_id in highlights.get("building_ids", []):
		next_building_ids.append(StringName(str(building_id)))
	var next_blueprint_button := bool(highlights.get("blueprint_button", false))
	var next_technology_button := bool(highlights.get("technology_button", false))
	var next_forge_blueprint_picker := bool(highlights.get("forge_blueprint_picker", false))
	var next_key := _make_guidance_highlight_key(
		next_building_ids,
		next_blueprint_button,
		next_technology_button,
		next_forge_blueprint_picker
	)
	if next_key == _guidance_highlight_key:
		return
	_guidance_highlight_key = next_key
	_guidance_building_ids = next_building_ids
	_guidance_blueprint_button = next_blueprint_button
	_guidance_technology_button = next_technology_button
	_guidance_forge_blueprint_picker = next_forge_blueprint_picker
	_refresh_build_buttons()
	_apply_global_button_guidance()
	if _building_operation_panel and _building_operation_panel.has_method("set_guidance_highlights"):
		_building_operation_panel.call("set_guidance_highlights", {
			"forge_blueprint_picker": _guidance_forge_blueprint_picker,
		})

func set_resource_amounts(resource_defs: Array[ResourceDef], amounts: Dictionary) -> void:
	_resource_defs = resource_defs.duplicate()
	_inventory_amounts = amounts.duplicate(true)
	var parts: Array[String] = []
	for resource_def in resource_defs:
		if resource_def.id == &"initial_sensor_coil" and not amounts.has(resource_def.id):
			continue
		parts.append("%s %s" % [resource_def.display_name, int(amounts.get(resource_def.id, 0))])
	set_resource_summary(" / ".join(parts))
	_refresh_build_buttons()

func set_resource_definitions(resource_defs: Array[ResourceDef]) -> void:
	_resource_defs = resource_defs.duplicate()
	if _combat_report_overlay and _combat_report_overlay.has_method("configure"):
		_combat_report_overlay.call("configure", _get_combat_event_log(), _resource_defs, _blueprints, _logistics_diagnostics)

func set_building_options(building_defs: Array[BuildingDef]) -> void:
	_building_defs = building_defs.duplicate()
	_refresh_build_buttons()

func set_blueprint_library(blueprints: Array[UnitBlueprint]) -> void:
	_blueprints = blueprints.duplicate()
	if _blueprint_overlay and _blueprint_overlay.has_method("set_blueprints"):
		_blueprint_overlay.call("set_blueprints", _blueprints)
	if _blueprint_overlay and _blueprint_overlay.has_method("set_blueprint_unlocks"):
		_blueprint_overlay.call("set_blueprint_unlocks", _unlocked_unit_type_ids, _unlocked_upgrade_ids, _unlocked_template_ids)
	if _blueprint_panel and _blueprint_panel.visible:
		_rebuild_blueprint_panel()
	if _combat_report_overlay and _combat_report_overlay.has_method("configure"):
		_combat_report_overlay.call("configure", _get_combat_event_log(), _resource_defs, _blueprints, _logistics_diagnostics)

func set_logistics_diagnostics(diagnostics: Dictionary) -> void:
	_logistics_diagnostics = diagnostics.duplicate(true)
	if _combat_report_overlay and _combat_report_overlay.has_method("configure"):
		_combat_report_overlay.call("configure", _get_combat_event_log(), _resource_defs, _blueprints, _logistics_diagnostics)

func set_unlocked_template_ids(template_ids: Array[StringName]) -> void:
	_unlocked_template_ids = template_ids.duplicate()
	if _blueprint_overlay and _blueprint_overlay.has_method("set_unlocked_template_ids"):
		_blueprint_overlay.call("set_unlocked_template_ids", _unlocked_template_ids)

func set_blueprint_unlocks(unit_type_ids: Array[StringName], upgrade_ids: Array[StringName], template_ids: Array[StringName]) -> void:
	_unlocked_unit_type_ids = unit_type_ids.duplicate()
	_unlocked_upgrade_ids = upgrade_ids.duplicate()
	_unlocked_template_ids = template_ids.duplicate()
	if _blueprint_overlay and _blueprint_overlay.has_method("set_blueprint_unlocks"):
		_blueprint_overlay.call("set_blueprint_unlocks", _unlocked_unit_type_ids, _unlocked_upgrade_ids, _unlocked_template_ids)

func set_campaign_data(
	state: Variant,
	technology_defs: Array,
	resource_defs: Array[ResourceDef],
	amounts: Dictionary,
	research_terminal_status: Dictionary
) -> void:
	_campaign_state = state
	_technology_defs = technology_defs.duplicate()
	_resource_defs = resource_defs.duplicate()
	_campaign_inventory_amounts = amounts.duplicate(true)
	_research_terminal_status = research_terminal_status.duplicate(true)
	if _technology_overlay and _technology_overlay.visible:
		_rebuild_technology_overlay()

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
		_apply_guidance_button_style(button, _guidance_building_ids.has(building_def.id))
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
		parts.append("%s: %s" % [_get_resource_display_name(_resource_defs, resource_id), int(building_def.build_cost[resource_id])])
	return "%s\n成本：%s" % [building_def.display_name, " / ".join(parts)]

func _on_build_button_pressed(building_id: StringName) -> void:
	_play_ui_click()
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
		_cost_list.add_child(_make_cost_resource_row(resource_defs, resource_id, text, color))
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

func _make_cost_resource_row(resource_defs: Array[ResourceDef], resource_id: StringName, text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var icon_texture := _get_resource_icon(resource_defs, resource_id)
	if icon_texture:
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = icon_texture
		icon.custom_minimum_size = Vector2(18, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
	row.add_child(_make_cost_label(text, color, 13))
	return row

func _apply_global_button_guidance() -> void:
	_apply_guidance_button_style(_blueprint_button, _guidance_blueprint_button)
	_apply_guidance_button_style(_technology_button, _guidance_technology_button)

func _make_guidance_highlight_key(
	building_ids: Array[StringName],
	blueprint_button: bool,
	technology_button: bool,
	forge_blueprint_picker: bool
) -> String:
	var parts: Array[String] = []
	for building_id in building_ids:
		parts.append(String(building_id))
	parts.sort()
	return "%s|bp=%s|tech=%s|forge_bp=%s" % [
		",".join(parts),
		"1" if blueprint_button else "0",
		"1" if technology_button else "0",
		"1" if forge_blueprint_picker else "0",
	]

func _apply_guidance_button_style(button: Button, active: bool) -> void:
	if button == null or not is_instance_valid(button):
		return
	var states := ["normal", "hover", "pressed", "focus", "disabled"]
	if active:
		for state in states:
			button.add_theme_stylebox_override(state, _make_guidance_button_style(state))
		button.add_theme_color_override("font_color", Color(1.0, 0.95, 0.70, 1.0))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.78, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.50, 1.0))
	else:
		for state in states:
			button.remove_theme_stylebox_override(state)
		button.remove_theme_color_override("font_color")
		button.remove_theme_color_override("font_hover_color")
		button.remove_theme_color_override("font_pressed_color")

func _make_guidance_button_style(state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var is_hover := state == "hover" or state == "pressed" or state == "focus"
	var is_disabled := state == "disabled"
	style.bg_color = Color(0.12, 0.10, 0.04, 0.88) if not is_hover else Color(0.20, 0.16, 0.06, 0.94)
	if is_disabled:
		style.bg_color = Color(0.10, 0.09, 0.06, 0.62)
	style.border_color = Color(1.0, 0.82, 0.18, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _get_resource_display_name(resource_defs: Array[ResourceDef], resource_id: StringName) -> String:
	for resource_def in resource_defs:
		if resource_def.id == resource_id:
			return resource_def.display_name
	return String(resource_id)

func _get_resource_icon(resource_defs: Array[ResourceDef], resource_id: StringName) -> Texture2D:
	for resource_def in resource_defs:
		if resource_def.id == resource_id and not resource_def.icon_path.is_empty():
			return load(resource_def.icon_path) as Texture2D
	return null

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
	_blueprint_button.icon = _load_ui_icon(BLUEPRINT_MENU_ICON_PATH)
	_blueprint_button.expand_icon = true
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
	_apply_global_button_guidance()

func _ensure_statistics_button() -> void:
	if _statistics_button != null:
		return
	_statistics_button = Button.new()
	_statistics_button.name = "CombatReportButton"
	_statistics_button.text = "统计"
	_statistics_button.icon = _load_ui_icon(STATISTICS_MENU_ICON_PATH)
	_statistics_button.expand_icon = true
	_statistics_button.tooltip_text = "打开最近 5 分钟生产统计"
	_statistics_button.anchor_left = 1.0
	_statistics_button.anchor_top = 1.0
	_statistics_button.anchor_right = 1.0
	_statistics_button.anchor_bottom = 1.0
	_statistics_button.offset_left = -270.0
	_statistics_button.offset_top = -150.0
	_statistics_button.offset_right = -152.0
	_statistics_button.offset_bottom = -112.0
	_statistics_button.z_index = 135
	_statistics_button.pressed.connect(_on_statistics_button_pressed)
	root_control.add_child(_statistics_button)
	_apply_global_button_guidance()

func _ensure_technology_button() -> void:
	if _technology_button != null:
		return
	_technology_button = Button.new()
	_technology_button.name = "TechnologyButton"
	_technology_button.text = "科技"
	_technology_button.icon = _load_ui_icon(TECHNOLOGY_MENU_ICON_PATH)
	_technology_button.expand_icon = true
	_technology_button.tooltip_text = "打开科技研究菜单"
	_technology_button.anchor_left = 1.0
	_technology_button.anchor_top = 1.0
	_technology_button.anchor_right = 1.0
	_technology_button.anchor_bottom = 1.0
	_technology_button.offset_left = -398.0
	_technology_button.offset_top = -150.0
	_technology_button.offset_right = -280.0
	_technology_button.offset_bottom = -112.0
	_technology_button.z_index = 135
	_technology_button.pressed.connect(_on_technology_button_pressed)
	root_control.add_child(_technology_button)
	_apply_global_button_guidance()

func _ensure_minimap_panel() -> void:
	if _minimap_panel != null:
		return
	_minimap_panel = MinimapPanelScript.new()
	_minimap_panel.anchor_left = 1.0
	_minimap_panel.anchor_top = 1.0
	_minimap_panel.anchor_right = 1.0
	_minimap_panel.anchor_bottom = 1.0
	_minimap_panel.offset_left = -292.0
	_minimap_panel.offset_top = -360.0
	_minimap_panel.offset_right = -24.0
	_minimap_panel.offset_bottom = -160.0
	_minimap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(_minimap_panel)

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
	_play_ui_click()
	blueprint_library_requested.emit()
	_ensure_blueprint_overlay()
	if _combat_report_overlay:
		_combat_report_overlay.visible = false
	if _technology_overlay:
		_technology_overlay.visible = false
	if _blueprint_panel:
		_blueprint_panel.visible = false
	_blueprint_overlay.call("set_blueprints", _blueprints)
	if _blueprint_overlay.has_method("set_blueprint_unlocks"):
		_blueprint_overlay.call("set_blueprint_unlocks", _unlocked_unit_type_ids, _unlocked_upgrade_ids, _unlocked_template_ids)
	elif _blueprint_overlay.has_method("set_unlocked_template_ids"):
		_blueprint_overlay.call("set_unlocked_template_ids", _unlocked_template_ids)
	_blueprint_overlay.visible = not _blueprint_overlay.visible

func _on_statistics_button_pressed() -> void:
	_play_ui_click()
	_ensure_combat_report_overlay()
	if _blueprint_overlay:
		_blueprint_overlay.visible = false
	if _technology_overlay:
		_technology_overlay.visible = false
	_combat_report_overlay.call("configure", _get_combat_event_log(), _resource_defs, _blueprints, _logistics_diagnostics)
	_combat_report_overlay.visible = not _combat_report_overlay.visible
	if _combat_report_overlay.visible and _combat_report_overlay.has_method("refresh_report"):
		_combat_report_overlay.call("refresh_report")

func _on_technology_button_pressed() -> void:
	_play_ui_click()
	_ensure_technology_overlay()
	if _blueprint_overlay:
		_blueprint_overlay.visible = false
	if _combat_report_overlay:
		_combat_report_overlay.visible = false
	_rebuild_technology_overlay()
	_technology_overlay.visible = not _technology_overlay.visible

func _ensure_technology_overlay() -> void:
	if _technology_overlay != null:
		return
	_technology_overlay = PanelContainer.new()
	_technology_overlay.name = "TechnologyOverlay"
	_technology_overlay.visible = false
	_technology_overlay.z_index = 155
	_technology_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_technology_overlay.anchor_left = 0.16
	_technology_overlay.anchor_top = 0.12
	_technology_overlay.anchor_right = 0.84
	_technology_overlay.anchor_bottom = 0.88
	_technology_overlay.add_theme_stylebox_override("panel", _make_operation_panel_style())
	root_control.add_child(_technology_overlay)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_technology_overlay.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	var title := _make_operation_label("科技研究", Color(0.96, 0.98, 1.0, 1.0), 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(78, 34)
	close_button.pressed.connect(func() -> void:
		_technology_overlay.visible = false
	)
	header.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_technology_list = VBoxContainer.new()
	_technology_list.add_theme_constant_override("separation", 10)
	_technology_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_technology_list)

func _rebuild_technology_overlay() -> void:
	if _technology_list == null:
		return
	for child in _technology_list.get_children():
		_technology_list.remove_child(child)
		child.queue_free()
	_technology_list.add_child(_make_wrapped_operation_label(_format_research_terminal_status(), 14, Color(0.78, 0.88, 1.0, 1.0)))
	if _technology_defs.is_empty():
		_technology_list.add_child(_make_operation_label("暂无科技节点", Color(0.84, 0.88, 0.92, 1.0), 14))
		return
	for technology in _technology_defs:
		_technology_list.add_child(_make_technology_row(technology))

func _make_technology_row(technology: Variant) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_section_panel_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var text_column := VBoxContainer.new()
	text_column.add_theme_constant_override("separation", 4)
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_column)
	text_column.add_child(_make_operation_label("%s  阶段 %d" % [technology.display_name, technology.stage], Color(0.96, 0.98, 1.0, 1.0), 16))
	text_column.add_child(_make_wrapped_operation_label(technology.description, 13, Color(0.78, 0.84, 0.90, 1.0)))
	text_column.add_child(_make_wrapped_operation_label("需求：%s | 耗时：%.1fs" % [
		_format_resource_dictionary(technology.costs, _resource_defs),
		technology.duration_seconds,
	], 13, Color(0.86, 0.90, 0.96, 1.0)))
	text_column.add_child(_make_wrapped_operation_label("状态：%s" % _get_technology_state_text(technology), 13, _get_technology_state_color(technology)))

	var button := Button.new()
	button.custom_minimum_size = Vector2(112, 34)
	button.text = _get_technology_button_text(technology)
	button.disabled = not _can_press_research(technology)
	button.pressed.connect(func() -> void:
		_play_ui_click()
		technology_research_requested.emit(technology.id)
	)
	row.add_child(button)
	return panel

func _format_research_terminal_status() -> String:
	if _research_terminal_status.is_empty() or not bool(_research_terminal_status.get("has_terminal", false)):
		return "研究终端：未建造。建造研究终端后可以执行科技研究。"
	if bool(_research_terminal_status.get("busy", false)):
		return "研究终端：研究中 - %s（%.0f%%）" % [
			str(_research_terminal_status.get("active_technology_name", "")),
			float(_research_terminal_status.get("progress_ratio", 0.0)) * 100.0,
		]
	return "研究终端：空闲"

func _get_technology_state_text(technology: Variant) -> String:
	if _campaign_state == null:
		return "等待战役状态"
	if _campaign_state.unlocked_technologies.has(technology.id):
		return "已解锁"
	if not technology.can_meet_key_items(_campaign_state.key_items):
		return "缺少关键道具"
	if not technology.can_meet_prerequisites(_campaign_state.unlocked_technologies):
		return "前置科技未完成"
	if not _can_afford(technology.costs):
		return "材料不足"
	return "可研究"

func _get_technology_state_color(technology: Variant) -> Color:
	var text := _get_technology_state_text(technology)
	if text == "已解锁":
		return Color(0.62, 1.0, 0.72, 1.0)
	if text == "可研究":
		return Color(0.72, 0.92, 1.0, 1.0)
	return Color(1.0, 0.70, 0.48, 1.0)

func _get_technology_button_text(technology: Variant) -> String:
	if _campaign_state and _campaign_state.unlocked_technologies.has(technology.id):
		return "已完成"
	if bool(_research_terminal_status.get("busy", false)):
		return "终端忙碌"
	return "研究"

func _can_press_research(technology: Variant) -> bool:
	if _campaign_state == null:
		return false
	if bool(_research_terminal_status.get("busy", false)):
		return false
	if not bool(_research_terminal_status.get("has_terminal", false)):
		return false
	if not _campaign_state.can_research(technology):
		return false
	return _can_afford(technology.costs)

func _make_section_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.065, 0.078, 0.74)
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

func _show_pause_menu() -> void:
	_ensure_pause_overlay()
	_set_game_paused(true)
	_pause_overlay.visible = true

func _ensure_pause_overlay() -> void:
	if _pause_overlay != null:
		return
	_pause_overlay = _make_center_menu_panel("PauseMenu", "Pause", [
		{"text": "Continue", "callable": Callable(self, "_on_pause_continue_pressed")},
		{"text": "Save Game", "callable": Callable(self, "_on_pause_save_pressed")},
		{"text": "Load Game", "callable": Callable(self, "_on_pause_load_pressed")},
		{"text": "Settings", "callable": Callable(self, "_on_pause_settings_pressed")},
		{"text": "Restart", "callable": Callable(self, "_on_pause_restart_pressed")},
		{"text": "Main Menu", "callable": Callable(self, "_on_pause_main_menu_pressed")},
	])
	root_control.add_child(_pause_overlay)

func _show_main_menu() -> void:
	_ensure_main_menu_overlay()
	_main_menu_overlay.visible = true

func _ensure_main_menu_overlay() -> void:
	if _main_menu_overlay != null:
		return
	_main_menu_overlay = _make_center_menu_panel("MainMenu", "Finite Core", [
		{"text": "New Game", "callable": Callable(self, "_on_main_menu_new_game_pressed")},
		{"text": "Continue", "callable": Callable(self, "_on_main_menu_continue_pressed")},
		{"text": "Quit", "callable": Callable(self, "_on_main_menu_quit_pressed")},
	])
	root_control.add_child(_main_menu_overlay)

func _on_pause_continue_pressed() -> void:
	_play_ui_click()
	if _pause_overlay:
		_pause_overlay.visible = false
	_set_game_paused(false)

func _on_pause_settings_pressed() -> void:
	_play_ui_click()
	_show_settings_overlay()

func _on_pause_save_pressed() -> void:
	_play_ui_click()
	save_game_requested.emit()

func _on_pause_load_pressed() -> void:
	_play_ui_click()
	load_game_requested.emit()

func _on_pause_restart_pressed() -> void:
	_play_ui_click()
	_set_game_paused(false)
	restart_requested.emit()

func _on_pause_main_menu_pressed() -> void:
	_play_ui_click()
	if _pause_overlay:
		_pause_overlay.visible = false
	_show_main_menu()

func _on_main_menu_new_game_pressed() -> void:
	_play_ui_click()
	_set_game_paused(false)
	new_game_requested.emit()

func _on_main_menu_continue_pressed() -> void:
	_play_ui_click()
	if _main_menu_overlay:
		_main_menu_overlay.visible = false
	_set_game_paused(false)

func _on_main_menu_quit_pressed() -> void:
	_play_ui_click()
	_set_game_paused(false)
	get_tree().quit()

func _set_game_paused(paused: bool) -> void:
	get_tree().paused = paused

func _make_center_menu_panel(panel_name: String, title_text: String, buttons: Array) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.visible = false
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.z_index = 220
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -160
	panel.offset_top = -140
	panel.offset_right = 160
	panel.offset_bottom = 140
	panel.add_theme_stylebox_override("panel", _make_operation_panel_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var title := _make_operation_label(title_text, Color(0.96, 0.98, 1.0, 1.0), 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	for button_data in buttons:
		var button := Button.new()
		button.text = str(button_data.get("text", "按钮"))
		button.custom_minimum_size = Vector2(220, 36)
		var callback := button_data.get("callable", Callable()) as Callable
		if callback.is_valid():
			button.pressed.connect(callback)
		root.add_child(button)
	return panel

func _show_settings_overlay() -> void:
	_ensure_settings_overlay()
	_sync_settings_controls_from_audio_manager()
	_settings_overlay.visible = true

func _ensure_settings_overlay() -> void:
	if _settings_overlay != null:
		return
	_settings_overlay = PanelContainer.new()
	_settings_overlay.name = "SettingsOverlay"
	_settings_overlay.visible = false
	_settings_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_settings_overlay.z_index = 240
	_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.anchor_left = 0.5
	_settings_overlay.anchor_top = 0.5
	_settings_overlay.anchor_right = 0.5
	_settings_overlay.anchor_bottom = 0.5
	_settings_overlay.offset_left = -220
	_settings_overlay.offset_top = -180
	_settings_overlay.offset_right = 220
	_settings_overlay.offset_bottom = 180
	_settings_overlay.add_theme_stylebox_override("panel", _make_operation_panel_style())
	root_control.add_child(_settings_overlay)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_settings_overlay.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	var title := _make_operation_label("音频设置", Color(0.96, 0.98, 1.0, 1.0), 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(76, 34)
	close_button.pressed.connect(func() -> void:
		_play_ui_click()
		_settings_overlay.visible = false
	)
	header.add_child(close_button)

	_master_volume_slider = _add_volume_slider(root, "主音量")
	_music_volume_slider = _add_volume_slider(root, "音乐音量")
	_sfx_volume_slider = _add_volume_slider(root, "音效音量")
	_music_enabled_check = _add_audio_check(root, "启用音乐")
	_sfx_enabled_check = _add_audio_check(root, "启用音效")

	_master_volume_slider.value_changed.connect(func(_value: float) -> void: _apply_settings_controls_to_audio_manager())
	_music_volume_slider.value_changed.connect(func(_value: float) -> void: _apply_settings_controls_to_audio_manager())
	_sfx_volume_slider.value_changed.connect(func(_value: float) -> void: _apply_settings_controls_to_audio_manager())
	_music_enabled_check.toggled.connect(func(_pressed: bool) -> void: _apply_settings_controls_to_audio_manager())
	_sfx_enabled_check.toggled.connect(func(_pressed: bool) -> void: _apply_settings_controls_to_audio_manager())

func _add_volume_slider(parent: VBoxContainer, label_text: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := _make_operation_label(label_text, Color(0.86, 0.92, 0.96, 1.0), 14)
	label.custom_minimum_size = Vector2(84, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	return slider

func _add_audio_check(parent: VBoxContainer, label_text: String) -> CheckBox:
	var check := CheckBox.new()
	check.text = label_text
	check.add_theme_font_size_override("font_size", 14)
	parent.add_child(check)
	return check

func _sync_settings_controls_from_audio_manager() -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager == null or not audio_manager.has_method("get_audio_settings"):
		return
	var settings: Dictionary = audio_manager.call("get_audio_settings")
	_master_volume_slider.value = float(settings.get("master_volume", 0.85))
	_music_volume_slider.value = float(settings.get("music_volume", 0.32))
	_sfx_volume_slider.value = float(settings.get("sfx_volume", 0.75))
	_music_enabled_check.button_pressed = bool(settings.get("music_enabled", true))
	_sfx_enabled_check.button_pressed = bool(settings.get("sfx_enabled", true))

func _apply_settings_controls_to_audio_manager() -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager == null or not audio_manager.has_method("set_audio_settings"):
		return
	audio_manager.call("set_audio_settings", {
		"master_volume": _master_volume_slider.value,
		"music_volume": _music_volume_slider.value,
		"sfx_volume": _sfx_volume_slider.value,
		"music_enabled": _music_enabled_check.button_pressed,
		"sfx_enabled": _sfx_enabled_check.button_pressed,
	})

func _play_ui_click() -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_ui_click"):
		audio_manager.call("play_ui_click")

func _ensure_combat_report_overlay() -> void:
	if _combat_report_overlay != null:
		return
	_combat_report_overlay = CombatReportOverlayScript.new()
	_combat_report_overlay.name = "CombatReportOverlay"
	_combat_report_overlay.visible = false
	_combat_report_overlay.z_index = 150
	_combat_report_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(_combat_report_overlay)

func _get_combat_event_log() -> Node:
	return get_node_or_null("/root/CombatEventLog")

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

func _on_blueprint_overlay_save_requested(source_blueprint_id: StringName, display_name: String, unit_type_id: StringName, upgrade_ids: Array[StringName], tactical_templates: Array, embedded_rules: Array, state_flag_defaults: Dictionary, save_as_new: bool) -> void:
	blueprint_save_requested.emit(source_blueprint_id, display_name, unit_type_id, upgrade_ids, tactical_templates, embedded_rules, state_flag_defaults, save_as_new)

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
		if not _is_blueprint_available(blueprint):
			continue
		_blueprint_list.add_child(_make_blueprint_summary_row(blueprint))
		_blueprint_source_option.add_item("%s v%s" % [blueprint.display_name, blueprint.version])
		_blueprint_source_option.set_item_metadata(_blueprint_source_option.item_count - 1, blueprint.id)
	if _blueprint_source_option.item_count > 0:
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
	var unit_type_text := blueprint.unit_type_display_name if not blueprint.unit_type_display_name.is_empty() else blueprint.chassis_display_name
	var upgrade_text := "无升级" if blueprint.upgrade_display_names.is_empty() else " / ".join(blueprint.upgrade_display_names)
	var rule_count := blueprint.embedded_rules.size()
	return "%s v%s | %s | %s | 规则 %d" % [
		blueprint.display_name,
		blueprint.version,
		unit_type_text,
		upgrade_text,
		rule_count,
	]

func _on_save_rally_blueprint_pressed() -> void:
	if _blueprint_source_option == null or _blueprint_source_option.item_count <= 0:
		return
	var selected_index := _blueprint_source_option.selected
	var source_id := StringName(str(_blueprint_source_option.get_item_metadata(selected_index)))
	var no_upgrades: Array[StringName] = []
	blueprint_save_requested.emit(source_id, _blueprint_name_edit.text if _blueprint_name_edit else "", &"", no_upgrades, [], [], {}, true)

func _on_blueprint_clone_rally_pressed(source_blueprint_id: StringName) -> void:
	var display_name := "集结蓝图"
	for blueprint in _blueprints:
		if blueprint.id == source_blueprint_id:
			display_name = "%s 集结版" % blueprint.display_name
			break
	var no_upgrades: Array[StringName] = []
	blueprint_save_requested.emit(source_blueprint_id, display_name, &"", no_upgrades, [], [], {}, true)

func _on_forge_blueprint_picker_pressed(forge: Node) -> void:
	_forge_picker_blueprints.clear()
	_show_forge_blueprint_picker(forge)

func _show_forge_blueprint_picker(forge: Node) -> void:
	_ensure_forge_blueprint_picker()
	for child in _forge_blueprint_list.get_children():
		_forge_blueprint_list.remove_child(child)
		child.queue_free()
	var available_blueprints := _filter_available_blueprints(_forge_picker_blueprints if not _forge_picker_blueprints.is_empty() else _blueprints)
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

func _filter_available_blueprints(blueprints: Array[UnitBlueprint]) -> Array[UnitBlueprint]:
	var result: Array[UnitBlueprint] = []
	for blueprint in blueprints:
		if _is_blueprint_available(blueprint):
			result.append(blueprint)
	return result

func _is_blueprint_available(blueprint: UnitBlueprint) -> bool:
	if blueprint == null:
		return false
	if _unlocked_unit_type_ids.is_empty():
		return true
	var unit_type_id := blueprint.unit_type_id if not String(blueprint.unit_type_id).is_empty() else blueprint.id
	return _unlocked_unit_type_ids.has(unit_type_id)

func _ensure_operation_panel() -> void:
	if _building_operation_panel != null:
		return
	_building_operation_panel = BuildingOperationPanelScript.new()
	_building_operation_panel.processor_recipe_selected.connect(_on_operation_processor_recipe_selected)
	_building_operation_panel.processor_pause_toggled.connect(_on_operation_processor_pause_toggled)
	_building_operation_panel.building_demolish_requested.connect(_on_operation_building_demolish_requested)
	_building_operation_panel.forge_rally_point_requested.connect(_on_operation_forge_rally_point_requested)
	_building_operation_panel.forge_blueprint_picker_requested.connect(_on_operation_forge_blueprint_picker_requested)
	_building_operation_panel.technology_panel_requested.connect(_on_operation_technology_panel_requested)
	root_control.add_child(_building_operation_panel)
	_building_operation_panel.call("set_guidance_highlights", {
		"forge_blueprint_picker": _guidance_forge_blueprint_picker,
	})

func _on_operation_processor_recipe_selected(processor: Node, recipe_id: StringName) -> void:
	processor_recipe_selected.emit(processor, recipe_id)

func _on_operation_processor_pause_toggled(processor: Node) -> void:
	processor_pause_toggled.emit(processor)

func _on_operation_building_demolish_requested(building: Node) -> void:
	building_demolish_requested.emit(building)

func _on_operation_forge_rally_point_requested(forge: Node) -> void:
	forge_rally_point_requested.emit(forge)

func _on_operation_forge_blueprint_picker_requested(forge: Node, blueprints: Array[UnitBlueprint]) -> void:
	_forge_picker_blueprints = blueprints.duplicate()
	_show_forge_blueprint_picker(forge)

func _on_operation_technology_panel_requested() -> void:
	_on_technology_button_pressed()

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

func _make_wrapped_operation_label(text: String, font_size: int, color: Color) -> Label:
	var label := _make_operation_label(text, color, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _format_resource_dictionary(resources: Dictionary, resource_defs: Array[ResourceDef]) -> String:
	if resources.is_empty():
		return "空"
	var parts: Array[String] = []
	for resource_id in resources.keys():
		parts.append("%s %s" % [_get_resource_display_name(resource_defs, resource_id), int(resources[resource_id])])
	return " / ".join(parts)

func _load_ui_icon(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
