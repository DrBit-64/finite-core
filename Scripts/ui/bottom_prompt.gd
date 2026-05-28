extends PanelContainer
class_name BottomPrompt

@export var default_duration_seconds: float = 2.4

var _label: Label = null
var _hide_timer: Timer = null

func _ready() -> void:
	_build_children()
	visible = false

func show_prompt(text: String, duration_seconds: float = 0.0, variant: StringName = &"info") -> void:
	_build_children()
	_label.text = text
	add_theme_stylebox_override("panel", _make_style(variant))
	visible = true
	if duration_seconds > 0.0:
		_hide_timer.start(duration_seconds)
	else:
		_hide_timer.stop()

func hide_prompt() -> void:
	if _hide_timer:
		_hide_timer.stop()
	visible = false

func _build_children() -> void:
	if _label != null:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
	margin.add_child(_label)

	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.timeout.connect(hide_prompt)
	add_child(_hide_timer)

func _make_style(variant: StringName) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	match variant:
		&"success":
			style.bg_color = Color(0.06, 0.20, 0.13, 0.88)
			style.border_color = Color(0.30, 0.84, 0.56, 0.9)
		&"warning":
			style.bg_color = Color(0.22, 0.14, 0.04, 0.90)
			style.border_color = Color(1.0, 0.62, 0.22, 0.92)
		&"error":
			style.bg_color = Color(0.24, 0.06, 0.06, 0.90)
			style.border_color = Color(1.0, 0.30, 0.28, 0.92)
		_:
			style.bg_color = Color(0.04, 0.05, 0.06, 0.88)
			style.border_color = Color(0.34, 0.46, 0.58, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	return style
