extends HBoxContainer
class_name ItemStackRow

const ItemIconSlotScript := preload("res://Scripts/ui/components/item_icon_slot.gd")

var _slot: PanelContainer
var _name_label: Label
var _amount_label: Label

func _ready() -> void:
	_build()

func setup(display_name: String, icon: Texture2D, current_amount: int, required_amount: int = -1) -> void:
	_build()
	var enough := required_amount < 0 or current_amount >= required_amount
	_slot.setup(
		icon,
		_format_quantity_badge(current_amount),
		Color(0.36, 0.78, 0.60, 0.92) if enough else Color(0.95, 0.30, 0.28, 0.96),
		"%s：%s" % [display_name, _format_amount(current_amount, required_amount)]
	)
	_name_label.text = display_name
	_amount_label.text = _format_amount(current_amount, required_amount)
	_amount_label.add_theme_color_override("font_color", Color(0.86, 0.94, 0.86, 1.0) if enough else Color(1.0, 0.34, 0.30, 1.0))

func _build() -> void:
	if _slot != null:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)

	_slot = ItemIconSlotScript.new()
	_slot.slot_size = Vector2(34, 34)
	add_child(_slot)

	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	add_child(text_box)

	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", Color(0.90, 0.94, 0.98, 1.0))
	text_box.add_child(_name_label)

	_amount_label = Label.new()
	_amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_amount_label.add_theme_font_size_override("font_size", 12)
	text_box.add_child(_amount_label)

func _format_amount(current_amount: int, required_amount: int) -> String:
	if required_amount < 0:
		return "%d" % current_amount
	return "%d / %d" % [current_amount, required_amount]

func _format_quantity_badge(current_amount: int) -> String:
	if current_amount <= 0:
		return ""
	return "%d" % current_amount
