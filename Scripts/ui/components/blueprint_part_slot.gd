extends PanelContainer
class_name BlueprintPartSlot

const ItemIconSlotScript := preload("res://Scripts/ui/components/item_icon_slot.gd")

var _slot: PanelContainer
var _title_label: Label
var _name_label: Label

func _ready() -> void:
	_build()

func setup(title: String, display_name: String, icon: Texture2D) -> void:
	_build()
	_title_label.text = title
	_name_label.text = display_name
	_slot.setup(icon, "", Color(0.36, 0.62, 0.88, 0.9))

func _build() -> void:
	if _slot != null:
		return
	add_theme_stylebox_override("panel", _make_part_style())

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 4)
	margin.add_child(root)

	_title_label = Label.new()
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 12)
	_title_label.add_theme_color_override("font_color", Color(0.72, 0.80, 0.88, 1.0))
	root.add_child(_title_label)

	_slot = ItemIconSlotScript.new()
	_slot.slot_size = Vector2(46, 46)
	_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(_slot)

	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.custom_minimum_size = Vector2(72, 0)
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_color", Color(0.90, 0.94, 0.98, 1.0))
	root.add_child(_name_label)

func _make_part_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.048, 0.58)
	style.border_color = Color(0.20, 0.28, 0.35, 0.82)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	return style
