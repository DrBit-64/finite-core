extends CanvasLayer
class_name MvpHud

signal build_mode_requested(building_id: StringName)

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

func _ready() -> void:
	set_current_goal("阶段 0：验证 MVP 测试入口")
	set_resource_summary("资源面板占位")
	set_bottom_hint("左侧检查器 / 右侧事件面板为阶段 0 占位 UI")
	if object_inspector:
		object_inspector.show_placeholder("未选择对象")
	if debug_event_panel:
		debug_event_panel.add_event_line("MVP HUD 已加载")

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
		var icon := load(building_def.icon_path) as Texture2D
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
	var offset := Vector2(18, 18)
	var desired_position := screen_position + offset
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
