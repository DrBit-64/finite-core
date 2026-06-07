extends PanelContainer
class_name BuildingOperationPanel

signal processor_recipe_selected(processor: Node, recipe_id: StringName)
signal forge_rally_point_requested(forge: Node)
signal forge_blueprint_picker_requested(forge: Node, blueprints: Array[UnitBlueprint])
signal technology_panel_requested

const ItemSlotGridScript := preload("res://Scripts/ui/components/item_slot_grid.gd")
const RecipeSummaryCardScript := preload("res://Scripts/ui/components/recipe_summary_card.gd")
const BlueprintPartSlotScript := preload("res://Scripts/ui/components/blueprint_part_slot.gd")
const BLUEPRINT_MENU_ICON_PATH := "res://Resources/art/ui/blueprint_menu.svg"
const STATE_RALLY_ICON_PATH := "res://Resources/art/ui/state_rally.svg"

var _list: VBoxContainer = null
var _mode: StringName = &""
var _processor: Node = null
var _miner: Node = null
var _forge: Node = null
var _recipes: Array[RecipeDef] = []
var _blueprints: Array[UnitBlueprint] = []

var _current_label: Label = null
var _recipe_card: PanelContainer = null
var _status_label: Label = null
var _progress_label: Label = null
var _progress_bar: ProgressBar = null
var _input_cache_list: VBoxContainer = null
var _output_cache_list: VBoxContainer = null
var _recipe_buttons: Dictionary = {}
var _blueprint_label: Label = null
var _alive_label: Label = null
var _rally_label: Label = null
var _blueprint_parts_row: HBoxContainer = null
var _cost_list: VBoxContainer = null

func _init() -> void:
	name = "BuildingOperationPanel"
	z_index = 90
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_theme_stylebox_override("panel", _make_panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_child(_list)

func show_processor_panel(processor: Node, recipes: Array[RecipeDef], resource_defs: Array[ResourceDef], screen_position: Vector2) -> void:
	visible = true
	if _mode != &"processor" or _processor != processor or _recipes.size() != recipes.size():
		_mode = &"processor"
		_processor = processor
		_miner = null
		_forge = null
		_recipes = recipes.duplicate()
		_blueprints.clear()
		_rebuild_processor_panel(processor, recipes)
	_update_processor_panel(processor, resource_defs)
	_position_panel(screen_position)

func show_miner_panel(miner: Node, resource_defs: Array[ResourceDef], screen_position: Vector2) -> void:
	visible = true
	if _mode != &"miner" or _miner != miner:
		_mode = &"miner"
		_miner = miner
		_processor = null
		_forge = null
		_recipes.clear()
		_blueprints.clear()
		_rebuild_miner_panel(miner)
	_update_miner_panel(miner, resource_defs)
	_position_panel(screen_position)

func show_forge_panel(forge: Node, blueprint: UnitBlueprint, blueprints: Array[UnitBlueprint], resource_defs: Array[ResourceDef], screen_position: Vector2) -> void:
	visible = true
	if _mode != &"forge" or _forge != forge or _blueprints.size() != blueprints.size():
		_mode = &"forge"
		_forge = forge
		_processor = null
		_miner = null
		_recipes.clear()
		_blueprints = blueprints.duplicate()
		_rebuild_forge_panel(forge)
	_update_forge_panel(forge, blueprint, resource_defs)
	_position_panel(screen_position)

func show_research_terminal_panel(terminal: Node, technology_defs: Array, resource_defs: Array[ResourceDef], screen_position: Vector2) -> void:
	visible = true
	if _mode != &"research" or _processor != terminal:
		_mode = &"research"
		_processor = terminal
		_miner = null
		_forge = null
		_recipes.clear()
		_blueprints.clear()
		_rebuild_research_terminal_panel(terminal)
	_update_research_terminal_panel(terminal, technology_defs, resource_defs)
	_position_panel(screen_position)

func hide_panel() -> void:
	visible = false
	_mode = &""
	_processor = null
	_miner = null
	_forge = null
	_blueprints.clear()

func _rebuild_processor_panel(processor: Node, recipes: Array[RecipeDef]) -> void:
	_clear_content()

	_list.add_child(_make_label(processor.call("get_display_name"), Color(0.96, 0.98, 1.0, 1.0), 15))
	_list.add_child(_make_label("配方", Color(0.72, 0.78, 0.84, 1.0), 12))

	var recipe_row := HBoxContainer.new()
	recipe_row.add_theme_constant_override("separation", 6)
	for recipe in recipes:
		var button := Button.new()
		button.text = recipe.display_name
		button.custom_minimum_size = Vector2(88, 28)
		button.pressed.connect(_on_processor_recipe_button_pressed.bind(processor, recipe.id), CONNECT_DEFERRED)
		recipe_row.add_child(button)
		_recipe_buttons[recipe.id] = button
	_list.add_child(recipe_row)

	_current_label = _make_label("", Color(0.9, 0.92, 0.95, 1.0), 13)
	_list.add_child(_current_label)
	_recipe_card = RecipeSummaryCardScript.new()
	_recipe_card.custom_minimum_size = Vector2(222, 0)
	_list.add_child(_recipe_card)
	_status_label = _make_label("", Color(0.9, 0.92, 0.95, 1.0), 13)
	_list.add_child(_status_label)
	_progress_label = _make_label("", Color(0.78, 0.88, 1.0, 1.0), 13)
	_list.add_child(_progress_label)
	_progress_bar = _make_progress_bar(184)
	_list.add_child(_progress_bar)

	_list.add_child(_make_label("原料缓存", Color(0.72, 0.80, 0.88, 1.0), 12))
	_input_cache_list = VBoxContainer.new()
	_input_cache_list.add_theme_constant_override("separation", 4)
	_list.add_child(_input_cache_list)
	_list.add_child(_make_label("产物缓存", Color(0.72, 0.80, 0.88, 1.0), 12))
	_output_cache_list = VBoxContainer.new()
	_output_cache_list.add_theme_constant_override("separation", 4)
	_list.add_child(_output_cache_list)
	size = get_combined_minimum_size()

func _update_processor_panel(processor: Node, resource_defs: Array[ResourceDef]) -> void:
	var selected_recipe: RecipeDef = processor.get("selected_recipe")
	if _current_label:
		_current_label.text = "当前：%s" % (selected_recipe.display_name if selected_recipe else "未选择")
	if _recipe_card:
		_recipe_card.call("setup", selected_recipe, resource_defs, processor.get("input_cache"), processor.get("output_cache"))
	if _status_label:
		_status_label.text = "状态：%s" % str(processor.get("status_text"))
	if _progress_label:
		_progress_label.text = _format_processor_progress_text(processor, selected_recipe)
	if _progress_bar:
		_progress_bar.value = float(processor.call("get_progress_ratio"))
	_rebuild_resource_stack_list(_input_cache_list, processor.get("input_cache"), resource_defs)
	_rebuild_resource_stack_list(_output_cache_list, processor.get("output_cache"), resource_defs)
	_refresh_recipe_button_states(selected_recipe)
	size = get_combined_minimum_size()

func _rebuild_miner_panel(miner: Node) -> void:
	_clear_content()

	_list.add_child(_make_label(miner.call("get_display_name"), Color(0.96, 0.98, 1.0, 1.0), 15))
	_list.add_child(_make_label("配方", Color(0.72, 0.78, 0.84, 1.0), 12))
	_current_label = _make_label("当前：开采", Color(0.9, 0.92, 0.95, 1.0), 13)
	_list.add_child(_current_label)

	_recipe_card = RecipeSummaryCardScript.new()
	_recipe_card.custom_minimum_size = Vector2(222, 0)
	_list.add_child(_recipe_card)
	_status_label = _make_label("", Color(0.9, 0.92, 0.95, 1.0), 13)
	_list.add_child(_status_label)
	_progress_label = _make_label("", Color(0.78, 0.88, 1.0, 1.0), 13)
	_list.add_child(_progress_label)
	_progress_bar = _make_progress_bar(184)
	_list.add_child(_progress_bar)

	_list.add_child(_make_label("产物缓存", Color(0.72, 0.80, 0.88, 1.0), 12))
	_output_cache_list = VBoxContainer.new()
	_output_cache_list.add_theme_constant_override("separation", 4)
	_list.add_child(_output_cache_list)
	size = get_combined_minimum_size()

func _update_miner_panel(miner: Node, resource_defs: Array[ResourceDef]) -> void:
	var mining_recipe: RecipeDef = miner.call("get_mining_recipe") if miner.has_method("get_mining_recipe") else null
	if _current_label:
		_current_label.text = "当前：开采"
	if _recipe_card:
		_recipe_card.call("setup", mining_recipe, resource_defs, miner.get("input_cache"), miner.get("output_cache"))
	if _status_label:
		_status_label.text = "状态：%s" % str(miner.get("status_text"))
	if _progress_label:
		_progress_label.text = _format_miner_progress_text(miner, mining_recipe)
	if _progress_bar:
		_progress_bar.value = float(miner.call("get_progress_ratio")) if miner.has_method("get_progress_ratio") else 0.0
	_rebuild_resource_stack_list(_output_cache_list, miner.get("output_cache"), resource_defs)
	size = get_combined_minimum_size()

func _rebuild_forge_panel(forge: Node) -> void:
	_clear_content()

	_list.add_child(_make_label(forge.call("get_display_name"), Color(0.96, 0.98, 1.0, 1.0), 15))
	_blueprint_label = _make_label("", Color(0.84, 0.90, 1.0, 1.0), 13)
	_list.add_child(_blueprint_label)
	_blueprint_parts_row = HBoxContainer.new()
	_blueprint_parts_row.add_theme_constant_override("separation", 8)
	_list.add_child(_blueprint_parts_row)
	_alive_label = _make_label("", Color(0.90, 0.94, 0.98, 1.0), 13)
	_list.add_child(_alive_label)
	_status_label = _make_label("", Color(0.90, 0.94, 0.98, 1.0), 13)
	_list.add_child(_status_label)
	_progress_label = _make_label("", Color(0.78, 0.88, 1.0, 1.0), 13)
	_list.add_child(_progress_label)
	_progress_bar = _make_progress_bar(206)
	_list.add_child(_progress_bar)

	_list.add_child(_make_label("生产成本", Color(0.72, 0.80, 0.88, 1.0), 12))
	_cost_list = VBoxContainer.new()
	_cost_list.add_theme_constant_override("separation", 4)
	_list.add_child(_cost_list)
	_rally_label = _make_label("", Color(0.86, 0.94, 0.82, 1.0), 13)
	_list.add_child(_rally_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	var rally_button := Button.new()
	rally_button.text = "设置集结点"
	rally_button.icon = _load_ui_icon(STATE_RALLY_ICON_PATH)
	rally_button.expand_icon = true
	rally_button.custom_minimum_size = Vector2(112, 30)
	rally_button.pressed.connect(_on_forge_rally_button_pressed.bind(forge), CONNECT_DEFERRED)
	action_row.add_child(rally_button)
	var blueprint_button := Button.new()
	blueprint_button.text = "选择蓝图"
	blueprint_button.icon = _load_ui_icon(BLUEPRINT_MENU_ICON_PATH)
	blueprint_button.expand_icon = true
	blueprint_button.custom_minimum_size = Vector2(96, 30)
	blueprint_button.pressed.connect(_on_forge_blueprint_picker_pressed.bind(forge), CONNECT_DEFERRED)
	action_row.add_child(blueprint_button)
	_list.add_child(action_row)
	size = get_combined_minimum_size()

func _update_forge_panel(forge: Node, blueprint: UnitBlueprint, resource_defs: Array[ResourceDef]) -> void:
	if _blueprint_label:
		_blueprint_label.text = "蓝图：%s v%s" % [
			blueprint.display_name if blueprint else "未绑定",
			blueprint.version if blueprint else 0,
		]
	_rebuild_blueprint_part_slots(_blueprint_parts_row, blueprint)
	if _alive_label:
		_alive_label.text = "存活：%s / %s" % [
			int(forge.call("get_alive_count")) if forge.has_method("get_alive_count") else 0,
			int(forge.get("target_alive_count")),
		]
	if _status_label:
		_status_label.text = "状态：%s" % str(forge.get("status_text"))
	if _progress_label:
		_progress_label.text = _format_forge_progress_text(forge, blueprint)
	if _progress_bar:
		_progress_bar.value = float(forge.call("get_progress_ratio")) if forge.has_method("get_progress_ratio") else 0.0
	_rebuild_resource_stack_list(_cost_list, blueprint.production_cost if blueprint else {}, resource_defs)
	if _rally_label:
		_rally_label.text = _format_forge_rally_text(forge)
	size = get_combined_minimum_size()

func _rebuild_research_terminal_panel(terminal: Node) -> void:
	_clear_content()
	_list.add_child(_make_label(terminal.call("get_display_name"), Color(0.96, 0.98, 1.0, 1.0), 15))
	_status_label = _make_label("", Color(0.90, 0.94, 0.98, 1.0), 13)
	_list.add_child(_status_label)
	_progress_label = _make_label("", Color(0.78, 0.88, 1.0, 1.0), 13)
	_list.add_child(_progress_label)
	_progress_bar = _make_progress_bar(206)
	_list.add_child(_progress_bar)
	var open_button := Button.new()
	open_button.text = "打开科技菜单"
	open_button.custom_minimum_size = Vector2(140, 30)
	open_button.pressed.connect(_on_technology_panel_button_pressed, CONNECT_DEFERRED)
	_list.add_child(open_button)
	size = get_combined_minimum_size()

func _update_research_terminal_panel(terminal: Node, _technology_defs: Array, _resource_defs: Array[ResourceDef]) -> void:
	var active: Variant = terminal.get("active_technology")
	if _status_label:
		_status_label.text = "状态：%s" % str(terminal.get("status_text"))
	if _progress_label:
		if active:
			_progress_label.text = "研究：%s  %.1fs / %.1fs" % [
				active.display_name,
				float(terminal.get("progress_seconds")),
				active.duration_seconds,
			]
		else:
			_progress_label.text = "研究：无"
	if _progress_bar:
		_progress_bar.value = float(terminal.call("get_progress_ratio")) if terminal.has_method("get_progress_ratio") else 0.0
	size = get_combined_minimum_size()

func _make_progress_bar(width: float) -> ProgressBar:
	var progress_bar := ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(width, 10)
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.show_percentage = false
	return progress_bar

func _refresh_recipe_button_states(selected_recipe: RecipeDef) -> void:
	for recipe_id in _recipe_buttons.keys():
		var button := _recipe_buttons[recipe_id] as Button
		if button:
			button.modulate = Color(0.68, 0.92, 1.0, 1.0) if selected_recipe and selected_recipe.id == recipe_id else Color.WHITE

func _format_forge_progress_text(forge: Node, blueprint: UnitBlueprint) -> String:
	var current_seconds := float(forge.get("progress_seconds"))
	var total_seconds := blueprint.production_time_seconds if blueprint else 0.0
	return "进度：%.1fs / %.1fs" % [current_seconds, total_seconds]

func _format_forge_rally_text(forge: Node) -> String:
	if not bool(forge.get("has_rally_point")):
		return "集结点：未设置"
	var cell: Vector2i = forge.get("rally_point_cell")
	return "集结点：%s, %s" % [cell.x, cell.y]

func _format_processor_progress_text(processor: Node, selected_recipe: RecipeDef) -> String:
	var current_seconds := float(processor.get("progress_seconds"))
	var total_seconds := selected_recipe.duration_seconds if selected_recipe else 0.0
	return "进度：%.1fs / %.1fs" % [current_seconds, total_seconds]

func _format_miner_progress_text(miner: Node, mining_recipe: RecipeDef) -> String:
	var current_seconds := float(miner.get("progress_seconds"))
	var total_seconds := mining_recipe.duration_seconds if mining_recipe else 0.0
	return "进度：%.1fs / %.1fs" % [current_seconds, total_seconds]

func _rebuild_resource_stack_list(list: VBoxContainer, resources: Dictionary, resource_defs: Array[ResourceDef]) -> void:
	if list == null:
		return
	var grid: GridContainer = null
	for child in list.get_children():
		if child.has_method("setup_from_resources"):
			grid = child as GridContainer
			break
	if grid == null:
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
		grid = ItemSlotGridScript.new()
		list.add_child(grid)
	grid.slot_size = Vector2(34, 34)
	grid.setup_from_resources(resources, resource_defs, {}, false, 4)

func _rebuild_blueprint_part_slots(row: HBoxContainer, blueprint: UnitBlueprint) -> void:
	if row == null:
		return
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	if blueprint == null:
		row.add_child(_make_label("未绑定蓝图", Color(0.62, 0.68, 0.74, 1.0), 12))
		return
	var chassis_slot := BlueprintPartSlotScript.new()
	chassis_slot.setup("底盘", blueprint.chassis_display_name, _load_ui_icon(blueprint.chassis_icon_path))
	row.add_child(chassis_slot)
	for index in blueprint.module_display_names.size():
		var module_slot := BlueprintPartSlotScript.new()
		var icon_path := blueprint.module_icon_paths[index] if index < blueprint.module_icon_paths.size() else ""
		module_slot.setup("模块", blueprint.module_display_names[index], _load_ui_icon(icon_path))
		row.add_child(module_slot)

func _clear_content() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	size = Vector2.ZERO
	_current_label = null
	_recipe_card = null
	_status_label = null
	_progress_label = null
	_progress_bar = null
	_input_cache_list = null
	_output_cache_list = null
	_recipe_buttons.clear()
	_blueprint_label = null
	_alive_label = null
	_rally_label = null
	_blueprint_parts_row = null
	_cost_list = null

func _position_panel(screen_position: Vector2) -> void:
	var popup_offset := Vector2(24, -16)
	var desired_position := screen_position + popup_offset
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := get_combined_minimum_size()
	if panel_size == Vector2.ZERO:
		panel_size = Vector2(196, 140)
	desired_position.x = clampf(desired_position.x, 8.0, maxf(8.0, viewport_size.x - panel_size.x - 8.0))
	desired_position.y = clampf(desired_position.y, 68.0, maxf(68.0, viewport_size.y - panel_size.y - 86.0))
	position = desired_position

func _make_panel_style() -> StyleBoxFlat:
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

func _make_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _load_ui_icon(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _on_processor_recipe_button_pressed(processor: Node, recipe_id: StringName) -> void:
	processor_recipe_selected.emit(processor, recipe_id)

func _on_forge_rally_button_pressed(forge: Node) -> void:
	forge_rally_point_requested.emit(forge)

func _on_forge_blueprint_picker_pressed(forge: Node) -> void:
	forge_blueprint_picker_requested.emit(forge, _blueprints)

func _on_technology_panel_button_pressed() -> void:
	technology_panel_requested.emit()
