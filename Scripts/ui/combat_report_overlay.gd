extends PanelContainer
class_name CombatReportOverlay

const ReportBuilderScript := preload("res://Scripts/ui/combat_report_builder.gd")
const WINDOW_SECONDS := 300.0
const REFRESH_INTERVAL_SECONDS := 0.5

var _event_log: Node = null
var _resource_defs: Array[ResourceDef] = []
var _blueprints: Array[UnitBlueprint] = []
var _active_category: StringName = &"resources"
var _refresh_seconds: float = 0.0

var _page_title: Label
var _content_list: VBoxContainer
var _resource_button: Button
var _robot_button: Button

func _ready() -> void:
	anchor_left = 0.04
	anchor_top = 0.08
	anchor_right = 0.96
	anchor_bottom = 0.93
	add_theme_stylebox_override("panel", _make_panel_style())
	_build_layout()
	_refresh()

func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_seconds += delta
	if _refresh_seconds >= REFRESH_INTERVAL_SECONDS:
		_refresh_seconds = 0.0
		_refresh()

func configure(event_log: Node, resource_defs: Array[ResourceDef], blueprints: Array[UnitBlueprint]) -> void:
	_event_log = event_log
	_resource_defs = resource_defs.duplicate()
	_blueprints = blueprints.duplicate()
	if is_inside_tree():
		_refresh()

func refresh_report() -> void:
	_refresh()

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
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	var title := _make_label("生产统计", 22, Color(0.96, 0.98, 1.0, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_make_label("最近 5 分钟", 13, Color(0.72, 0.80, 0.88, 1.0)))

	var refresh_button := Button.new()
	refresh_button.text = "刷新"
	refresh_button.custom_minimum_size = Vector2(72, 34)
	refresh_button.pressed.connect(_refresh)
	header.add_child(refresh_button)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(72, 34)
	close_button.pressed.connect(func() -> void:
		visible = false
	)
	header.add_child(close_button)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var category_list := VBoxContainer.new()
	category_list.custom_minimum_size = Vector2(150, 0)
	category_list.add_theme_constant_override("separation", 8)
	body.add_child(category_list)

	category_list.add_child(_make_label("分类", 13, Color(0.72, 0.80, 0.88, 1.0)))
	_resource_button = _make_category_button("资源", &"resources")
	category_list.add_child(_resource_button)
	_robot_button = _make_category_button("机器人", &"robots")
	category_list.add_child(_robot_button)

	var separator := VSeparator.new()
	body.add_child(separator)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	body.add_child(content)

	_page_title = _make_label("", 16, Color(0.88, 0.94, 1.0, 1.0))
	content.add_child(_page_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	_content_list = VBoxContainer.new()
	_content_list.custom_minimum_size = Vector2(880, 0)
	_content_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_content_list)

func _make_category_button(text: String, category: StringName) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(142, 38)
	button.pressed.connect(_on_category_pressed.bind(category))
	return button

func _on_category_pressed(category: StringName) -> void:
	_active_category = category
	_refresh()

func _refresh() -> void:
	if _content_list == null:
		return
	for child in _content_list.get_children():
		child.queue_free()

	var report: Dictionary = ReportBuilderScript.build_report(_event_log, _blueprints, _resource_defs, WINDOW_SECONDS)
	if _active_category == &"robots":
		_rebuild_robot_page(report.get("robots", []))
	else:
		_rebuild_resource_page(report.get("resources", []))
	_refresh_category_button_states()

func _rebuild_resource_page(rows: Array) -> void:
	_page_title.text = "资源统计"
	_content_list.add_child(_make_table_row(["资源", "产出", "消耗", "净变化"], true))
	if rows.is_empty():
		_content_list.add_child(_make_label("最近 5 分钟暂无资源变化", 14, Color(0.72, 0.78, 0.84, 1.0)))
		return
	for row in rows:
		_content_list.add_child(_make_table_row([
			str(row.get("display_name", row.get("resource_id", "未知资源"))),
			str(int(row.get("produced", 0))),
			str(int(row.get("consumed", 0))),
			_format_signed(int(row.get("net", 0))),
		]))

func _rebuild_robot_page(rows: Array) -> void:
	_page_title.text = "机器人统计"
	_content_list.add_child(_make_table_row(["蓝图", "生产", "损失", "击杀", "模板触发", "规则触发"], true))
	if rows.is_empty():
		_content_list.add_child(_make_label("最近 5 分钟暂无机器人数据", 14, Color(0.72, 0.78, 0.84, 1.0)))
		return
	for row in rows:
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 3)
		block.add_child(_make_table_row([
			"%s v%s" % [str(row.get("display_name", row.get("blueprint_id", "未知蓝图"))), int(row.get("blueprint_version", 0))],
			str(int(row.get("produced", 0))),
			str(int(row.get("lost", 0))),
			str(int(row.get("kills", 0))),
			str(int(row.get("template_triggered", 0))),
			str(int(row.get("rule_triggered", 0))),
		]))
		var loss_reasons: Dictionary = row.get("loss_reasons", {})
		if not loss_reasons.is_empty():
			block.add_child(_make_detail_label("损失原因：%s" % _format_counts(loss_reasons)))
		_append_trigger_details(block, "战术模板触发明细：", row.get("templates", {}))
		_append_trigger_details(block, "底层规则触发明细：", row.get("rules", {}))
		var never_templates: Array = row.get("never_triggered_templates", [])
		if not never_templates.is_empty():
			block.add_child(_make_detail_label("从未触发模板：%s" % " / ".join(never_templates)))
		var never_rules: Array = row.get("never_triggered_rules", [])
		if not never_rules.is_empty():
			block.add_child(_make_detail_label("从未触发规则：%s" % " / ".join(never_rules)))
		_content_list.add_child(block)
		_content_list.add_child(HSeparator.new())

func _append_trigger_details(block: VBoxContainer, title: String, items: Dictionary) -> void:
	if items.is_empty():
		return
	block.add_child(_make_detail_label(title))
	var item_rows: Array = items.values()
	item_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	for item in item_rows:
		var triggered := int(item.get("triggered", 0))
		var detail := _make_detail_label("  %s：%d 次" % [str(item.get("display_name", item.get("name", "未命名"))), triggered])
		if triggered <= 0:
			detail.add_theme_color_override("font_color", Color(1.0, 0.68, 0.48, 1.0))
		block.add_child(detail)

func _make_table_row(values: Array[String], is_header: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(880, 30 if is_header else 28)
	row.add_theme_constant_override("separation", 8)
	var widths := [360.0, 82.0, 82.0, 82.0, 110.0, 110.0]
	for index in range(values.size()):
		var label := _make_label(
			values[index],
			13 if is_header else 14,
			Color(0.72, 0.80, 0.88, 1.0) if is_header else Color(0.90, 0.94, 0.98, 1.0)
		)
		label.custom_minimum_size = Vector2(widths[index], 0)
		row.add_child(label)
	return row

func _make_detail_label(text: String) -> Label:
	var label := _make_label(text, 13, Color(0.74, 0.82, 0.88, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _refresh_category_button_states() -> void:
	if _resource_button:
		_resource_button.modulate = Color(0.68, 0.92, 1.0, 1.0) if _active_category == &"resources" else Color.WHITE
	if _robot_button:
		_robot_button.modulate = Color(0.68, 0.92, 1.0, 1.0) if _active_category == &"robots" else Color.WHITE

func _format_counts(counts: Dictionary) -> String:
	var parts: Array[String] = []
	for key in counts.keys():
		parts.append("%s %d" % [_format_loss_reason(str(key)), int(counts[key])])
	parts.sort()
	return " / ".join(parts)

func _format_loss_reason(reason: String) -> String:
	match reason:
		"destroyed":
			return "被击毁"
		"lifespan_expired":
			return "寿命耗尽"
		_:
			return reason

func _format_signed(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return str(value)

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.048, 0.985)
	style.border_color = Color(0.30, 0.46, 0.58, 0.96)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style
