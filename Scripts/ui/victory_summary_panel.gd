extends PanelContainer
class_name VictorySummaryPanel

var _summary_label: Label

func _ready() -> void:
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -230.0
	offset_top = -180.0
	offset_right = 230.0
	offset_bottom = 180.0
	add_theme_stylebox_override("panel", _make_panel_style())
	_build_layout()

func show_summary(summary: Dictionary) -> void:
	if _summary_label == null:
		return
	_summary_label.text = _format_summary(summary)
	visible = true

func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "胜利摘要"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(func() -> void:
		visible = false
	)
	header.add_child(close_button)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.add_theme_font_size_override("font_size", 15)
	_summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_summary_label)

func _format_summary(summary: Dictionary) -> String:
	var lines: Array[String] = [
		"已摧毁：%s" % str(summary.get("target", "敌巢")),
		"战斗总用时：%.1fs" % float(summary.get("elapsed_seconds", 0.0)),
		"生产机器人：%d" % int(summary.get("robots_produced", 0)),
		"损失机器人：%d" % int(summary.get("robots_lost", 0)),
		"击败守军：%d" % int(summary.get("enemies_killed", 0)),
		"规则触发：%d 次" % int(summary.get("rules_triggered", 0)),
	]
	var rule_names: Dictionary = summary.get("rule_names", {})
	if not rule_names.is_empty():
		lines.append("")
		lines.append("规则触发明细：")
		for rule_name in rule_names.keys():
			lines.append("  %s：%d 次" % [String(rule_name), int(rule_names[rule_name])])
	var reward: Dictionary = summary.get("reward", {})
	if not reward.is_empty():
		lines.append("")
		lines.append("敌巢奖励：%s" % JSON.stringify(reward))
	return "\n".join(lines)

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.048, 0.98)
	style.border_color = Color(0.34, 0.78, 0.60, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style
