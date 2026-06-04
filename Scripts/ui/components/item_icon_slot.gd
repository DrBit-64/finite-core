extends PanelContainer
class_name ItemIconSlot

@export var slot_size: Vector2 = Vector2(48, 48)

var _icon_rect: TextureRect
var _quantity_label: Label
var _root: Control
var _tooltip_value: String = ""

static var _shared_tooltip_layer: CanvasLayer = null
static var _shared_tooltip_panel: PanelContainer = null
static var _shared_tooltip_label: Label = null
static var _shared_tooltip_owner_id: int = 0

func _ready() -> void:
	_build()

func setup(icon: Texture2D, quantity_text: String = "", border_color: Color = Color(0.30, 0.36, 0.42, 0.9), tooltip: String = "") -> void:
	_build()
	custom_minimum_size = slot_size
	add_theme_stylebox_override("panel", _make_slot_style(border_color))
	_tooltip_value = tooltip
	if _root:
		_root.custom_minimum_size = slot_size
	_icon_rect.texture = icon
	_quantity_label.text = quantity_text
	_quantity_label.visible = not quantity_text.is_empty()

func _build() -> void:
	if _icon_rect != null:
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = slot_size
	add_theme_stylebox_override("panel", _make_slot_style(Color(0.30, 0.36, 0.42, 0.9)))

	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.custom_minimum_size = slot_size
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_icon_rect = TextureRect.new()
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon_rect.offset_left = 5.0
	_icon_rect.offset_top = 5.0
	_icon_rect.offset_right = -5.0
	_icon_rect.offset_bottom = -5.0
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_root.add_child(_icon_rect)

	_quantity_label = Label.new()
	_quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quantity_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_quantity_label.offset_left = -34.0
	_quantity_label.offset_top = -18.0
	_quantity_label.offset_right = -4.0
	_quantity_label.offset_bottom = -2.0
	_quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_quantity_label.add_theme_font_size_override("font_size", 11)
	_quantity_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	_quantity_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04, 0.95))
	_quantity_label.add_theme_constant_override("outline_size", 3)
	_root.add_child(_quantity_label)

func _process(_delta: float) -> void:
	if _tooltip_value.is_empty() or not is_visible_in_tree():
		_hide_custom_tooltip()
		return
	if _is_pointer_over_slot():
		_show_custom_tooltip()
	else:
		_hide_custom_tooltip()

func _show_custom_tooltip() -> void:
	if _tooltip_value.is_empty():
		return
	_ensure_shared_tooltip()
	_shared_tooltip_owner_id = get_instance_id()
	_shared_tooltip_label.text = _tooltip_value
	_shrink_shared_tooltip_to_text()
	_position_custom_tooltip()
	_shared_tooltip_layer.visible = true

func _hide_custom_tooltip() -> void:
	if _shared_tooltip_owner_id != get_instance_id():
		return
	if _shared_tooltip_layer:
		_shared_tooltip_layer.visible = false
	_shared_tooltip_owner_id = 0

func _exit_tree() -> void:
	_hide_custom_tooltip()

func _position_custom_tooltip() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var tooltip_size := _shared_tooltip_panel.size
	if tooltip_size == Vector2.ZERO:
		tooltip_size = _shared_tooltip_panel.get_combined_minimum_size()
	var desired_position := get_global_rect().position + Vector2(slot_size.x + 7.0, -2.0)
	desired_position.x = clampf(desired_position.x, 6.0, maxf(6.0, viewport_size.x - tooltip_size.x - 6.0))
	desired_position.y = clampf(desired_position.y, 6.0, maxf(6.0, viewport_size.y - tooltip_size.y - 6.0))
	_shared_tooltip_panel.position = desired_position

func _is_pointer_over_slot() -> bool:
	return get_global_rect().grow(2.0).has_point(get_viewport().get_mouse_position())

func _shrink_shared_tooltip_to_text() -> void:
	_shared_tooltip_label.size = Vector2.ZERO
	_shared_tooltip_panel.size = Vector2.ZERO
	_shared_tooltip_panel.size = _shared_tooltip_panel.get_combined_minimum_size()

func _ensure_shared_tooltip() -> void:
	if _shared_tooltip_layer != null and is_instance_valid(_shared_tooltip_layer):
		if _shared_tooltip_layer.get_parent() == null:
			get_tree().root.add_child(_shared_tooltip_layer)
		return

	_shared_tooltip_layer = CanvasLayer.new()
	_shared_tooltip_layer.layer = 220
	_shared_tooltip_layer.visible = false

	_shared_tooltip_panel = PanelContainer.new()
	_shared_tooltip_panel.visible = true
	_shared_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shared_tooltip_panel.add_theme_stylebox_override("panel", _make_tooltip_style())
	_shared_tooltip_layer.add_child(_shared_tooltip_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 4)
	_shared_tooltip_panel.add_child(margin)

	_shared_tooltip_label = Label.new()
	_shared_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shared_tooltip_label.add_theme_font_size_override("font_size", 12)
	_shared_tooltip_label.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0, 1.0))
	margin.add_child(_shared_tooltip_label)

	get_tree().root.add_child(_shared_tooltip_layer)

func _make_slot_style(border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.048, 0.82)
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	return style

func _make_tooltip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.03, 0.038, 0.96)
	style.border_color = Color(0.40, 0.50, 0.58, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style
