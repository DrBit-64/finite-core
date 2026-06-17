extends PanelContainer
class_name VictorySummaryPanel

const TECHNOLOGY_UNLOCKED_ICON := preload("res://Resources/art/ui/technology_unlocked.svg")
const INITIAL_SENSOR_COIL_ICON := preload("res://Resources/art/resources/initial_sensor_coil.svg")

var _summary_label: Label
var _reward_row: HBoxContainer
var _reward_item_icon: TextureRect
var _reward_label: Label

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
	_update_reward_row(summary)
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

	_reward_row = HBoxContainer.new()
	_reward_row.visible = false
	_reward_row.add_theme_constant_override("separation", 8)
	root.add_child(_reward_row)

	var unlock_icon := TextureRect.new()
	unlock_icon.texture = TECHNOLOGY_UNLOCKED_ICON
	unlock_icon.custom_minimum_size = Vector2(22, 22)
	unlock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	unlock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reward_row.add_child(unlock_icon)

	_reward_item_icon = TextureRect.new()
	_reward_item_icon.custom_minimum_size = Vector2(28, 28)
	_reward_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reward_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reward_row.add_child(_reward_item_icon)

	_reward_label = Label.new()
	_reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reward_label.add_theme_font_size_override("font_size", 15)
	_reward_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_row.add_child(_reward_label)

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
	return "\n".join(lines)

func _update_reward_row(summary: Dictionary) -> void:
	if _reward_row == null:
		return
	var reward: Dictionary = summary.get("reward", {})
	if reward.is_empty():
		_reward_row.visible = false
		return
	var reward_text := _format_reward_text(reward)
	_reward_row.visible = true
	if _reward_item_icon:
		_reward_item_icon.texture = _get_reward_item_icon(reward)
	if _reward_label:
		_reward_label.text = "敌巢奖励：%s" % reward_text

func _format_reward_text(reward: Dictionary) -> String:
	if reward.has("technology_item"):
		return str(reward.get("technology_item", "未知科技物品"))
	return JSON.stringify(reward)

func _get_reward_item_icon(reward: Dictionary) -> Texture2D:
	if str(reward.get("technology_item", "")) == "初级感应线圈":
		return INITIAL_SENSOR_COIL_ICON
	return TECHNOLOGY_UNLOCKED_ICON

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
